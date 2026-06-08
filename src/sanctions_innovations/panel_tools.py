"""Generic panel-building infrastructure: FeatureSpec, source plugins, PanelBuilder."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Dict, Iterable, List, Optional, Sequence, Tuple
import io
import json
import time
import pathlib
import requests
import pandas as pd


# ── Generic helpers ────────────────────────────────────────────────────────────

def _ensure_cache_dir(cache_dir: str | pathlib.Path) -> pathlib.Path:
    p = pathlib.Path(cache_dir)
    p.mkdir(parents=True, exist_ok=True)
    return p


def _as_year_int(s) -> Optional[int]:
    try:
        return int(s)
    except Exception:
        return None


def _standardize_panel(df: pd.DataFrame) -> pd.DataFrame:
    """Enforce canonical schema: iso3 (str), year (int), value (float)."""
    out = df.copy()
    if "iso3" not in out.columns or "year" not in out.columns:
        raise ValueError("Expected columns iso3 and year.")
    out["iso3"] = out["iso3"].astype(str).str.upper()
    out["year"] = out["year"].map(_as_year_int)
    out = out.dropna(subset=["iso3", "year"])
    out["year"] = out["year"].astype(int)
    return out


# ── Feature spec ───────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class FeatureSpec:
    """Declarative definition of a single panel feature."""
    name: str
    source_key: str
    series_code: str
    params: Dict[str, object] = None
    transform: Optional[Callable[[pd.Series], pd.Series]] = None

    def __post_init__(self):
        if self.params is None:
            object.__setattr__(self, "params", {})


# ── Base source interface ──────────────────────────────────────────────────────

class FeatureSource:
    """Plugin that fetches one series and returns a long DataFrame: iso3, year, value."""

    def fetch_series(
        self,
        series_code: str,
        *,
        countries: Optional[Sequence[str]] = None,
        years: Optional[Tuple[int, int]] = None,
        **kwargs,
    ) -> pd.DataFrame:
        raise NotImplementedError


# ── World Bank WDI source ──────────────────────────────────────────────────────

class WorldBankSource(FeatureSource):
    """
    World Bank Indicators API.
    URL: https://api.worldbank.org/v2/country/all/indicator/{IND}?format=json&per_page=20000
    """

    def __init__(self, session: Optional[requests.Session] = None, sleep_s: float = 0.1):
        self.s = session or requests.Session()
        self.sleep_s = sleep_s

    def fetch_series(
        self,
        series_code: str,
        *,
        countries: Optional[Sequence[str]] = None,
        years: Optional[Tuple[int, int]] = None,
        drop_aggregates: bool = True,
        **kwargs,
    ) -> pd.DataFrame:
        url = f"https://api.worldbank.org/v2/country/all/indicator/{series_code}"
        params = {"format": "json", "per_page": 20000}
        r = self.s.get(url, params=params, timeout=60)
        r.raise_for_status()
        payload = r.json()

        if not isinstance(payload, list) or len(payload) < 2:
            raise ValueError(f"Unexpected WB response for {series_code}: {payload[:200]}")

        rows = payload[1]
        out_rows = []
        for row in rows:
            c = row.get("countryiso3code") or row.get("country", {}).get("id")
            year = row.get("date")
            val = row.get("value")
            if c in (None, ""):
                continue
            y = _as_year_int(year)
            if y is None:
                continue
            out_rows.append((str(c).upper(), y, val))

        df = pd.DataFrame(out_rows, columns=["iso3", "year", "value"])
        df = _standardize_panel(df)

        if years is not None:
            y0, y1 = years
            df = df[(df["year"] >= y0) & (df["year"] <= y1)]
        if countries is not None:
            keep = {c.upper() for c in countries}
            df = df[df["iso3"].isin(keep)]

        time.sleep(self.sleep_s)
        return df


# ── OWID grapher CSV source ────────────────────────────────────────────────────

class OWIDGrapherSource(FeatureSource):
    """
    OWID "grapher" datasets pulled as CSV:
      https://ourworldindata.org/grapher/{chart_id}.csv
    """

    def __init__(self, session: Optional[requests.Session] = None, sleep_s: float = 0.1):
        self.s = session or requests.Session()
        self.sleep_s = sleep_s

    def fetch_series(
        self,
        series_code: str,
        *,
        countries: Optional[Sequence[str]] = None,
        years: Optional[Tuple[int, int]] = None,
        value_column: Optional[str] = None,
        **kwargs,
    ) -> pd.DataFrame:
        url = f"https://ourworldindata.org/grapher/{series_code}.csv"
        r = self.s.get(url, timeout=60)
        r.raise_for_status()

        df = pd.read_csv(io.StringIO(r.text))

        if "Code" not in df.columns or "Year" not in df.columns:
            raise ValueError(f"Unexpected OWID schema for {series_code}: columns={df.columns.tolist()}")

        if value_column is None:
            candidates = [c for c in df.columns if c not in ("Entity", "Code", "Year", "Day", "Date")]
            if len(candidates) != 1:
                raise ValueError(f"Provide value_column for {series_code}. Candidates={candidates}")
            value_column = candidates[0]

        out = df.rename(columns={"Code": "iso3", "Year": "year"})[["iso3", "year", value_column]]
        out = out.rename(columns={value_column: "value"})
        out = _standardize_panel(out)

        if years is not None:
            y0, y1 = years
            out = out[(out["year"] >= y0) & (out["year"] <= y1)]
        if countries is not None:
            keep = {c.upper() for c in countries}
            out = out[out["iso3"].isin(keep)]

        time.sleep(self.sleep_s)
        return out


# ── UNdata SDMX REST source ────────────────────────────────────────────────────

class UNDataSDMXSource(FeatureSource):
    """UNdata SDMX REST (CSV format)."""

    def __init__(self, base_url: str = "http://data.un.org/ws/rest/data", session: Optional[requests.Session] = None):
        self.base_url = base_url.rstrip("/")
        self.s = session or requests.Session()

    def fetch_series(
        self,
        series_code: str,
        *,
        countries: Optional[Sequence[str]] = None,
        years: Optional[Tuple[int, int]] = None,
        dataflow: str,
        key: str,
        geo_col: str = "REF_AREA",
        time_col: str = "TIME_PERIOD",
        value_col: str = "OBS_VALUE",
        **kwargs,
    ) -> pd.DataFrame:
        params = {"format": "csv"}
        if years is not None:
            y0, y1 = years
            params["startPeriod"] = str(y0)
            params["endPeriod"] = str(y1)

        url = f"{self.base_url}/{dataflow}/{key}"
        r = self.s.get(url, params=params, timeout=120)
        r.raise_for_status()

        df = pd.read_csv(io.StringIO(r.text))
        for col in (geo_col, time_col, value_col):
            if col not in df.columns:
                raise ValueError(f"UN SDMX missing {col}. Columns={df.columns.tolist()}")

        out = df.rename(columns={geo_col: "iso3", time_col: "year", value_col: "value"})[["iso3", "year", "value"]]
        out = _standardize_panel(out)

        if countries is not None:
            keep = {c.upper() for c in countries}
            out = out[out["iso3"].isin(keep)]
        return out


# ── HTTP CSV source ────────────────────────────────────────────────────────────

class HTTPCSVSource(FeatureSource):
    """Downloads a CSV from a URL and extracts iso3/year/value from specified columns."""

    def __init__(self, session: Optional[requests.Session] = None):
        self.s = session or requests.Session()

    def fetch_series(
        self,
        series_code: str,
        *,
        url: str,
        iso3_col: str,
        year_col: str,
        value_col: str,
        countries: Optional[Sequence[str]] = None,
        years: Optional[Tuple[int, int]] = None,
        **kwargs,
    ) -> pd.DataFrame:
        r = self.s.get(url, timeout=120)
        r.raise_for_status()
        df = pd.read_csv(io.StringIO(r.text))

        out = df.rename(columns={iso3_col: "iso3", year_col: "year", value_col: "value"})[["iso3", "year", "value"]]
        out = _standardize_panel(out)

        if years is not None:
            y0, y1 = years
            out = out[(out["year"] >= y0) & (out["year"] <= y1)]
        if countries is not None:
            keep = {c.upper() for c in countries}
            out = out[out["iso3"].isin(keep)]
        return out


# ── Panel builder ──────────────────────────────────────────────────────────────

class PanelBuilder:
    def __init__(self, sources: Dict[str, FeatureSource], cache_dir: str = ".panel_cache"):
        self.sources = sources
        self.cache_dir = _ensure_cache_dir(cache_dir)

    def _cache_path(self, feature: FeatureSpec, years, countries) -> pathlib.Path:
        ytag = f"{years[0]}-{years[1]}" if years else "all-years"
        ctag = "all" if countries is None else f"{len(countries)}c"
        safe_name = feature.name.replace("/", "_")
        return self.cache_dir / f"{feature.source_key}__{safe_name}__{feature.series_code}__{ytag}__{ctag}.parquet"

    def fetch_feature(
        self,
        feature: FeatureSpec,
        *,
        countries=None,
        years=None,
        use_cache: bool = False,
        force: bool = False,
    ) -> pd.DataFrame:
        cache_path = self._cache_path(feature, years, countries)

        if use_cache and cache_path.exists() and not force:
            return pd.read_parquet(cache_path)

        src = self.sources[feature.source_key]
        df = src.fetch_series(
            feature.series_code,
            countries=countries,
            years=years,
            **(feature.params or {}),
        )

        if feature.transform is not None:
            df = df.copy()
            df["value"] = feature.transform(df["value"])

        df = df.rename(columns={"value": feature.name})

        if use_cache:
            df.to_parquet(cache_path, index=False)

        return df

    def build_panel(
        self,
        features: Sequence[FeatureSpec],
        *,
        countries=None,
        years=None,
        use_cache: bool = True,
        force: bool = False,
    ) -> pd.DataFrame:
        pieces: List[pd.DataFrame] = []
        for f in features:
            df_f = self.fetch_feature(f, countries=countries, years=years, use_cache=use_cache, force=force)
            pieces.append(df_f)

        panel = None
        for p in pieces:
            if panel is None:
                panel = p
            else:
                panel = panel.merge(p, on=["iso3", "year"], how="outer")

        assert panel is not None
        panel = panel.sort_values(["iso3", "year"]).reset_index(drop=True)
        return panel

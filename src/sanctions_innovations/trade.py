"""IMF DOT loading, cleaning, and bilateral trade table construction."""
import requests
import pandas as pd
from countrygroups import EUROPEAN_UNION


def wb_iso3_map() -> dict:
    """Return {lower-case country name: ISO3} from the World Bank country API."""
    session = requests.Session()
    meta, rows = session.get(
        "https://api.worldbank.org/v2/country",
        params={"format": "json", "per_page": 400, "page": 1},
    ).json()
    rows = rows[:]
    for page in range(2, int(meta["pages"]) + 1):
        rows += session.get(
            "https://api.worldbank.org/v2/country",
            params={"format": "json", "per_page": 400, "page": page},
        ).json()[1]
    return {r["name"].strip().lower(): r["id"].upper() for r in rows if r.get("name") and r.get("id")}


def clean_imf_dot(
    imf_dot_df: pd.DataFrame,
    name_to_iso3: dict,
    code_to_iso3: dict,
    skip_countries: list = None,
) -> pd.DataFrame:
    """
    Map counterparty ISO3 codes in IMF DOT data and drop aggregate regions.

    Returns a clean DataFrame with columns [year, iso3, counterparty_iso3, obs_value].
    """
    skip_countries = skip_countries or ["EMU", "WLD", "EUU", "AFR", "SSF"]
    to_drop = [c for c in imf_dot_df if imf_dot_df[c].nunique() <= 1]
    df = (
        imf_dot_df.drop(columns=to_drop)
        .assign(
            counterparty=lambda x: x.COMP_BREAKDOWN_1_LABEL.str.replace("Counterpart: ", ""),
            country_code=lambda x: x.COMP_BREAKDOWN_1.str.replace("IMF_CNT_COUNTRY_", "").astype(int),
            counterparty_iso3=lambda x: x.COMP_BREAKDOWN_1_LABEL.str.replace("Counterpart: ", "").str.lower().map(name_to_iso3),
        )
    )
    df["counterparty_iso3"] = df["counterparty_iso3"].fillna(df["country_code"].map(code_to_iso3))
    df = df.dropna(subset="counterparty_iso3")
    df = df[~(df.counterparty_iso3.isin(skip_countries) | df.REF_AREA.isin(skip_countries))]
    df = df[["TIME_PERIOD", "REF_AREA", "counterparty_iso3", "OBS_VALUE"]]
    df.columns = ["year", "iso3", "counterparty_iso3", "obs_value"]
    return df


def build_bilateral(imf_exports: pd.DataFrame) -> pd.DataFrame:
    """
    Build a symmetric bilateral trade DataFrame from IMF DOT exports.

    Uses the mirror-flow approach: c's imports from i = i's reported exports to c.

    Input columns:  [year, iso3, counterparty_iso3, obs_value]
    Output columns: [year, c, i, export_volume, import_volume, trade_volume]
    """
    exp = imf_exports[["year", "iso3", "counterparty_iso3", "obs_value"]].copy()
    exp.columns = ["year", "c", "i", "exp_c_i"]
    imp = imf_exports[["year", "iso3", "counterparty_iso3", "obs_value"]].copy()
    imp.columns = ["year", "i", "c", "exp_i_c"]
    return (
        exp.merge(imp, on=["year", "c", "i"], how="outer")
        .assign(
            export_volume=lambda x: x["exp_c_i"].fillna(0.0),
            import_volume=lambda x: x["exp_i_c"].fillna(0.0),
            trade_volume=lambda x: x[["export_volume", "import_volume"]].sum(axis=1),
        )
        [["year", "c", "i", "export_volume", "import_volume", "trade_volume"]]
    )


def build_bilateral_eu_one(bilateral: pd.DataFrame, eu_members=None) -> pd.DataFrame:
    """
    Collapse EU member states into a single 'EU' aggregate node in the bilateral table.

    Non-EU country trade with any EU member is summed and attributed to 'EU' as partner.
    Returns a bilateral DataFrame with the same column structure as the input.
    """
    eu = set(eu_members) if eu_members else set(EUROPEAN_UNION)
    eu_as_partner = (
        bilateral[bilateral["i"].isin(eu)]
        .groupby(["year", "c"])[["export_volume", "import_volume", "trade_volume"]]
        .sum().reset_index().assign(i="EU")
    )
    eu_as_country = (
        bilateral[bilateral["c"].isin(eu)]
        .groupby(["year", "i"])[["export_volume", "import_volume", "trade_volume"]]
        .sum().reset_index().assign(c="EU")
    )
    return pd.concat([
        bilateral[~bilateral["i"].isin(eu) & ~bilateral["c"].isin(eu)],
        eu_as_partner,
        eu_as_country,
    ], ignore_index=True)

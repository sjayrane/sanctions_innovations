"""Patent data loading and gap-fill logic."""
import pandas as pd


def _full_year_range(group: pd.DataFrame) -> pd.Index:
    """Return a complete year index spanning [min_year, max_year] for a patent group."""
    years = group.index.get_level_values("priority_year")
    return pd.Index(range(years.min(), years.max() + 1), name="priority_year")


def fill_gaps_of_low_countries(df, min_annual_patents: int = 10,
                               analysis_start = None, analysis_end = None):
    
    analysis_start = analysis_start or df.index.get_level_values("priority_year").min()
    analysis_end = analysis_end or df.index.get_level_values("priority_year").max()
    
    annual = df.groupby(level=["iso3", "priority_year"])["frac_classical_inv"].sum()
    window = annual[
        annual.index.get_level_values("priority_year").isin(range(analysis_start, analysis_end + 1))
    ]
    country_min = window.groupby(level="iso3").min()

    low_countries = country_min[country_min < min_annual_patents].index
    high_countries = country_min[country_min >= min_annual_patents].index
    low_tuples = [
        (iso3, yr)
        for iso3 in low_countries
        if iso3 in df.index.get_level_values("iso3")
        for yr in _full_year_range(df.loc[[iso3]])
    ]
    low_df = df.loc[df.index.get_level_values("iso3").isin(low_countries)].reindex(
        pd.MultiIndex.from_tuples(low_tuples, names=["iso3", "priority_year"])
    )
    low_df["frac_classical_inv"] = low_df["frac_classical_inv"].fillna(0)
    low_df[low_df.columns] = low_df.groupby("iso3")[list(low_df.columns)].ffill().bfill()

    high_df = df.loc[df.index.get_level_values("iso3").isin(high_countries)].copy()

    result = pd.concat([low_df, high_df]).sort_index()
    return result
    

def load_and_prepare_patents(
    path: str,
) -> tuple[pd.DataFrame, list]:
    """
    Load patent CSV, drop bad country codes, and gap-fill low-patent countries.

    Low-patent countries (min annual count < min_annual_patents in the analysis
    window) have internal year gaps filled with zero. High-patent countries keep
    only observed years. The final DataFrame is clipped to [analysis_start, analysis_end].

    Returns (patents_df, missing_codes) where missing_codes are ctry_codes with no ISO3.
    """
    df = pd.read_csv(path).astype({"iso3": str, "frac_classical_inv": float})

    missing_codes = df[(df.iso3 == "nan") | df.iso3.isna()].ctry_code.unique()
    df = df[(df.iso3 != "nan") & df.iso3.str.strip().ne("") & df.iso3.notna()]
    df = df[df.priority_year.astype(int) != 9999]
    df = df.set_index(["iso3", "priority_year"]).sort_index()
    
    return df, list(missing_codes)

"""
GSDB sanctions loading, panel construction, and sanction intensity index computation.

Sections:
  1. Constants
  2. GSDB loading and binary panel helpers (from build_panel_utils.py)
  3. Private rolling-trade helpers (from sanction_indexes.py)
  4. Sanction indicator builders (from sanction_indexes.py)
  5. Index computation functions (from sanction_indexes.py)
"""
import logging
import numpy as np
import pandas as pd
import pyreadstat
from countrygroups import EUROPEAN_UNION, UN_REGIONAL_GROUPS, BRICS, OECD, OPEC


# ── 1. Constants ───────────────────────────────────────────────────────────────

SENDERS_ISO3 = {
    "US": {"USA"},
    "UN": set(UN_REGIONAL_GROUPS),
    "EU": set(EUROPEAN_UNION),
    "BRICS": set(BRICS),
    "OECD": set(OECD),
    "OPEC": set(OPEC),
}

SENDERS = {
    "US": {"United States"},
    "UN": {"UN"},
    "EU": {"EU"},
}

EXPORT_IMPORT_SANCTION_GROUPS = {
    'exp_part': 0.5,
    'exp_compl,imp_compl': 2,
    'exp_part,imp_part': 1,
    'imp_part': 0.5,
    'imp_compl': 1,
    'exp_part,imp_compl': 1.5,
    'exp_compl': 1,
    'exp_compl,imp_part': 1.5,
}


# ── 2. GSDB loading and binary panel helpers ───────────────────────────────────

def load_gsdb_data(dta_path: str, csv_path: str):
    """
    Load GSDB dyadic sanctions from .dta + .csv, reconcile country ISO3 codes.

    Returns (sanctions_df, gsdb_cases) where:
      - sanctions_df  : year-exploded dyadic rows, ready for make_sanction_panel
      - gsdb_cases    : case-level rows (one row per case, before year explosion),
                        used for the Li & Li index
    """
    sanctions_dta, _ = pyreadstat.read_dta(dta_path, apply_value_formats=True)

    state_to_iso3 = (
        sanctions_dta.groupby('sanctioned_state').sanctioned_state_iso3.first().to_dict()
        | sanctions_dta.groupby('sanctioning_state').sanctioning_state_iso3.first().to_dict()
        | {'Jordan': 'JOR'}
    )

    gsdb_all = pd.read_csv(csv_path).assign(
        sanctioned_state_iso3=lambda x: x.sanctioned_state.map(state_to_iso3),
        sanctioning_state_iso3=lambda x: x.sanctioning_state.map(state_to_iso3),
    )
    matched = gsdb_all[gsdb_all.sanctioned_state_iso3.notna() & gsdb_all.sanctioning_state_iso3.notna()]
    unmatched = gsdb_all[~(gsdb_all.sanctioned_state_iso3.notna() & gsdb_all.sanctioning_state_iso3.notna())].copy()

    comma_countries = [
        ('Korea, South', 'South Korea'), ('Korea, North', 'North Korea'),
        ('Gambia, The', 'Gambia'), ('Egypt, Arab Rep.', 'Egypt'),
        ('Congo, Democratic Republic of the', 'Congo'), ('Yemen, North', 'Yemen'),
    ]
    for left, right in comma_countries:
        unmatched['sanctioned_state'] = unmatched.sanctioned_state.str.replace(left, right).str.strip()
        unmatched['sanctioning_state'] = unmatched.sanctioning_state.str.replace(left, right).str.strip()

    unmatched['sanctioned_state'] = unmatched.sanctioned_state.str.split(', ')
    unmatched['sanctioning_state'] = unmatched.sanctioning_state.str.split(', ')
    unmatched = unmatched.explode('sanctioned_state').explode('sanctioning_state')

    for left, right in comma_countries:
        unmatched['sanctioned_state'] = unmatched.sanctioned_state.str.replace(right, left).str.strip()
        unmatched['sanctioning_state'] = unmatched.sanctioning_state.str.replace(right, left).str.strip()

    eu_un_map = {'EU': 'EU', 'UN': 'UN'}
    unmatched = unmatched.assign(
        sanctioned_state_iso3=lambda x: x.sanctioned_state.map(state_to_iso3).fillna(x.sanctioned_state.map(eu_un_map)),
        sanctioning_state_iso3=lambda x: x.sanctioning_state.map(state_to_iso3).fillna(x.sanctioning_state.map(eu_un_map)),
    )
    to_drop = unmatched[unmatched.sanctioned_state_iso3.isna()].sanctioned_state.unique()

    gsdb_cases = pd.concat([
        matched[matched.sanctioned_state_iso3 != ''],
        unmatched[unmatched.sanctioned_state_iso3.notna() & (unmatched.sanctioned_state_iso3 != '')],
    ], ignore_index=True)
    gsdb_cases = gsdb_cases[~gsdb_cases.sanctioned_state.isin(to_drop)]

    sanctions_df = gsdb_cases.assign(
        year=lambda x: x.apply(lambda row: range(row['begin'], row['end'] + 1), axis=1)
    ).explode('year')

    return sanctions_df, gsdb_cases


def compute_li_li_index(gsdb_cases: pd.DataFrame, senders=None, sanction_types=None) -> pd.DataFrame:
    """
    Compute the Li & Li (2021) sanction intensity index.

    For each sanctioned country, sums binary sanction-type indicators over active
    years, restricted to cases initiated by the specified senders.

    Returns a (iso3, year) MultiIndexed DataFrame of per-type sanction counts.
    """
    senders = senders or ['United States', 'EU', 'UN']
    sanction_types = sanction_types or ['trade', 'arms', 'military', 'financial', 'travel', 'other']

    relevant = gsdb_cases[
        gsdb_cases.sanctioning_state.isin(senders)
        | sum(gsdb_cases.sanctioning_state.str.contains(f'{s},') for s in senders) > 0
    ].drop_duplicates('case_id')

    data = {
        iso3: pd.DataFrame(0, index=np.arange(df.begin.min(), df.end.max() + 1), columns=sanction_types)
        for iso3, df in relevant.groupby('sanctioned_state_iso3')
    }
    for iso3, df in relevant.drop_duplicates('case_id').groupby('sanctioned_state_iso3'):
        for _, row in df.iterrows():
            for s in sanction_types:
                data[iso3].loc[row.begin: row.end, s] += row[s]

    return pd.concat([
        data[iso3].set_index(pd.MultiIndex.from_product([[iso3], data[iso3].index]))
        for iso3 in data
    ]).sort_index()


def make_sanction_panel(
    df: pd.DataFrame,
    senders=None,
    senders_iso3=None,
    categories=("arms", "military", "trade", "financial", "travel"),
) -> pd.DataFrame:
    """
    Aggregate a dyadic sanctions DataFrame to a (country, year) panel of binary indicators.

    Pass either `senders` (keyed by display name) or `senders_iso3` (keyed by ISO3 set).
    """
    sender_col = 'sanctioning_state_iso3' if senders_iso3 is not None else 'sanctioning_state'
    senders = senders if senders else senders_iso3
    df = df.copy()
    df['export_import_sanction_groups'] = df.descr_trade.map(EXPORT_IMPORT_SANCTION_GROUPS)
    for cat in categories:
        df[cat] = df[cat].astype(bool)

    for name, country_set in senders.items():
        df[f"sender_{name}"] = df[sender_col].isin(country_set)
    df["sender_OTHER"] = ~df[[f"sender_{name}" for name in senders]].any(axis=1)

    sender_names = list(senders.keys()) + ["OTHER"]
    out_cols = []
    for sender in sender_names:
        flag_col = f"sender_{sender}"
        col_any = f"sanctioned_by_{sender}"
        df[col_any] = df[flag_col]
        out_cols.append(col_any)
        for cat in categories:
            col_name = f"{sender}_{cat}"
            df[col_name] = df[flag_col] & df[cat]
            out_cols.append(col_name)

    df["any_sanctions"] = df[[f"sender_{s}" for s in sender_names]].any(axis=1)
    out_cols.append("any_sanctions")
    for cat in categories:
        df[f"any_{cat}"] = df[cat]
        out_cols.append(f"any_{cat}")

    panel = (
        df.groupby(["sanctioned_state_iso3", "year"])[out_cols]
          .max().astype(int).sort_index()
    )
    panel.index.set_names(["country", "year"], inplace=True)
    return panel


def load_stata_sanctions(path: str, senders=SENDERS_ISO3) -> pd.DataFrame:
    """Load a GSDB .dta file and return a (country, year) sanction panel."""
    assert path.endswith('.dta')
    sanctions, _ = pyreadstat.read_dta(path, apply_value_formats=True)
    logging.warning(
        f'Dropping sanctioned states without valid ISO3:\n'
        f'{sanctions[sanctions.sanctioned_state_iso3 == ""].sanctioned_state.unique()}'
    )
    sanctions = sanctions[sanctions.sanctioned_state_iso3 != '']
    return make_sanction_panel(sanctions, senders_iso3=senders).sort_index()


# ── 3. Private rolling-trade helpers ──────────────────────────────────────────

def _rolling_trade_share(bilateral, window, shift, volume_col):
    """Rolling pre-period bilateral trade shares: returns (c, i) × year DataFrame."""
    all_years = sorted(bilateral['year'].astype(int).unique())
    pivot = (
        bilateral
        .pivot_table(index=['c', 'i'], columns='year', values=volume_col, fill_value=0.0)
        .reindex(columns=all_years, fill_value=0.0)
    )

    def _roll(df):
        return df.T.rolling(window=window, min_periods=1).sum().shift(shift).T

    rolling_bilateral = _roll(pivot)
    rolling_total_c = _roll(pivot.groupby(level='c').sum())
    c_idx = rolling_bilateral.index.get_level_values('c')
    denom = rolling_total_c.loc[c_idx].values
    with np.errstate(invalid='ignore', divide='ignore'):
        _arr = np.where(denom > 0, rolling_bilateral.values / denom, 0.0)
    return pd.DataFrame(
        _arr,
        index=rolling_bilateral.index,
        columns=rolling_bilateral.columns,
    ).clip(0.0, 1.0)


def _rolling_abs(bilateral_df, window, shift, volume_col):
    """Rolling sum of absolute bilateral flows: returns (c, i) × year DataFrame."""
    all_years = sorted(bilateral_df['year'].astype(int).unique())
    pivot = (
        bilateral_df
        .pivot_table(index=['c', 'i'], columns='year', values=volume_col, fill_value=0.0)
        .reindex(columns=all_years, fill_value=0.0)
    )
    return pivot.T.rolling(window=window, min_periods=1).sum().shift(shift).T


def _make_dyadic_indicator(dyadic_sanctions_og, desc_pattern, eu_members):
    """
    Filter dyadic sanctions to rows where descr_trade matches desc_pattern,
    then expand EU-as-sender and EU-as-target rows to individual member ISO3s.
    Returns a deduplicated (i, c, year) DataFrame.
    """
    mask = (
        dyadic_sanctions_og['descr_trade'].fillna('').str.contains(desc_pattern, regex=True)
        & dyadic_sanctions_og['sanctioning_state_iso3'].notna()
    )
    base = (
        dyadic_sanctions_og[mask]
        .rename(columns={'sanctioned_state_iso3': 'c', 'sanctioning_state_iso3': 'i'})
        [['i', 'c', 'year']].drop_duplicates()
    )
    non_eu = base[(base['i'] != 'EU') & (base['c'] != 'EU')]
    eu_i = base[base['i'] == 'EU'].drop(columns=['i']).merge(pd.DataFrame({'i': list(eu_members)}), how='cross')
    eu_c = base[base['c'] == 'EU'].drop(columns=['c']).merge(pd.DataFrame({'c': list(eu_members)}), how='cross')
    return pd.concat([non_eu, eu_i, eu_c], ignore_index=True).drop_duplicates()


def _eu_one_dyadic_indicator(dyadic_sanctions_og, desc_pattern):
    """
    Same as _make_dyadic_indicator but keeps EU as the 'EU' aggregate node —
    no expansion to individual members. Drops c='EU' rows since EU is never sanctioned.
    """
    mask = (
        dyadic_sanctions_og['descr_trade'].fillna('').str.contains(desc_pattern, regex=True)
        & dyadic_sanctions_og['sanctioning_state_iso3'].notna()
    )
    base = (
        dyadic_sanctions_og[mask]
        .rename(columns={'sanctioned_state_iso3': 'c', 'sanctioning_state_iso3': 'i'})
        [['i', 'c', 'year']].drop_duplicates()
    )
    return base[base['c'] != 'EU'].copy()


def _share_weighted_intensity(indicator, share_long, share_col, panel_index, col):
    """Core aggregation: Σ_i share_ci × sanction_ic → (iso3, year) Series aligned to panel_index."""
    return (
        indicator
        .merge(share_long, on=['c', 'i', 'year'], how='left')
        .fillna({share_col: 0.0})
        .groupby(['c', 'year'])[share_col].sum()
        .reset_index().rename(columns={'c': 'iso3', share_col: col})
        .set_index(['iso3', 'year'])[col]
        .reindex(panel_index).fillna(0.0)
    )


def _dir_total_shares(bilateral_df, window):
    """
    Compute X_ci/T_c and M_ci/T_c where T_c = Σ_j(X_cj + M_cj).
    Returns (export_share_long, import_share_long) as (c, i, year) long DataFrames.
    """
    X = _rolling_abs(bilateral_df, window=window, shift=1, volume_col='export_volume')
    M = _rolling_abs(bilateral_df, window=window, shift=1, volume_col='import_volume')
    T_c = (X + M).groupby(level='c').sum()
    c_idx = X.index.get_level_values('c')
    denom = T_c.loc[c_idx].values
    with np.errstate(invalid='ignore', divide='ignore'):
        _exp_arr = np.where(denom > 0, X.values / denom, 0.0)
        _imp_arr = np.where(denom > 0, M.values / denom, 0.0)
    exp_share = pd.DataFrame(
        _exp_arr,
        index=X.index, columns=X.columns,
    ).clip(0.0, 1.0)
    imp_share = pd.DataFrame(
        _imp_arr,
        index=M.index, columns=M.columns,
    ).clip(0.0, 1.0)
    exp_long = exp_share.rename_axis(columns='year').stack().reset_index(name='export_share')
    imp_long = imp_share.rename_axis(columns='year').stack().reset_index(name='import_share')
    return exp_long, imp_long


# ── 4. Sanction indicator builders ────────────────────────────────────────────

def build_sanction_indicators(dyadic_sanctions_og: pd.DataFrame, eu_members=None):
    """
    Build all four dyadic sanction indicator tables from raw GSDB dyadic data.

    Returns:
        sanction_indicator         — trade==1 sanctions, EU expanded to members
        sanction_indicator_eu_one  — trade==1 sanctions, EU kept as single 'EU' node
        import_sanction_indicator  — imp_compl/imp_part, EU expanded
        export_sanction_indicator  — exp_compl/exp_part, EU expanded
    """
    eu = set(eu_members) if eu_members else set(EUROPEAN_UNION)

    raw = (
        dyadic_sanctions_og[dyadic_sanctions_og['trade'] == 1]
        .rename(columns={'sanctioned_state_iso3': 'c', 'sanctioning_state_iso3': 'i'})
        [['i', 'c', 'year']].drop_duplicates()
    )
    non_eu = raw[(raw['i'] != 'EU') & (raw['c'] != 'EU')]
    eu_expanded = pd.concat([
        raw[raw['i'] == 'EU'].drop(columns=['i']).merge(pd.DataFrame({'i': list(eu)}), how='cross'),
        raw[raw['c'] == 'EU'].drop(columns=['c']).merge(pd.DataFrame({'c': list(eu)}), how='cross'),
    ], ignore_index=True)
    sanction_indicator = pd.concat([non_eu, eu_expanded], ignore_index=True).drop_duplicates(subset=['i', 'c', 'year'])
    sanction_indicator_eu_one = raw[raw['c'] != 'EU'].copy()

    import_sanction_indicator = _make_dyadic_indicator(dyadic_sanctions_og, r'\bimp_compl\b|\bimp_part\b', eu)
    export_sanction_indicator = _make_dyadic_indicator(dyadic_sanctions_og, r'\bexp_compl\b|\bexp_part\b', eu)

    return sanction_indicator, sanction_indicator_eu_one, import_sanction_indicator, export_sanction_indicator


# ── 5. Index computation functions ────────────────────────────────────────────

def compute_trade_share_weighted(panel: pd.DataFrame, bilateral, sanction_indicator, window=10) -> pd.DataFrame:
    """
    Index 1: Trade-share weighted sanction intensity (EU-expanded).

    SanctionIntensity_ct = Σ_i VolumeShare_ci^pre × TradeSanction_ict

    Any active trade sanction (trade==1 in GSDB). EU sanctions expanded to individual
    member states. Computed for export, import, and total trade volume shares.

    Adds columns: sanction_intensity_{export,import,trade}_volume_{window}
    """
    result = panel.copy()
    for volume_col in ['export_volume', 'import_volume', 'trade_volume']:
        col = f'sanction_intensity_{volume_col}_{window}'
        share = _rolling_trade_share(bilateral, window=window, shift=1, volume_col=volume_col)
        share_long = share.rename_axis(columns='year').stack().reset_index(name='share')
        result[col] = _share_weighted_intensity(sanction_indicator, share_long, 'share', result.index, col)
    return result


def compute_trade_share_weighted_eu_one(panel: pd.DataFrame, bilateral_eu_one, sanction_indicator_eu_one, window=10) -> pd.DataFrame:
    """
    Index 1b: Trade-share weighted sanction intensity (EU-as-one).

    Same formula as Index 1, but EU member states are aggregated into a single 'EU'
    trade node and EU sanctions remain attributed to 'EU' rather than individual members.

    Adds columns: sanction_intensity_{export,import,trade}_volume_{window}_eu_as_one
    """
    result = panel.copy()
    for volume_col in ['export_volume', 'import_volume', 'trade_volume']:
        col = f'sanction_intensity_{volume_col}_{window}_eu_as_one'
        share = _rolling_trade_share(bilateral_eu_one, window=window, shift=1, volume_col=volume_col)
        share_long = share.rename_axis(columns='year').stack().reset_index(name='share')
        result[col] = _share_weighted_intensity(sanction_indicator_eu_one, share_long, 'share', result.index, col)
    return result


def compute_multi_window(
    panel: pd.DataFrame,
    bilateral,
    bilateral_eu_one,
    sanction_indicator,
    sanction_indicator_eu_one,
    windows=(5, 15, 20),
) -> pd.DataFrame:
    """
    Index 1c: Trade-share weighted intensity for additional lookback windows.

    Runs Indices 1 and 1b for each window in `windows`. Window 10 is assumed already
    computed; pass any combination of other values.

    Adds columns: sanction_intensity_{export,import,trade}_volume_{w}[_eu_as_one]
    for each w in windows, both EU variants, all three volume types.
    """
    result = panel.copy()
    volume_cols = ['export_volume', 'import_volume', 'trade_volume']
    variants = [
        (bilateral,        sanction_indicator,       ''),
        (bilateral_eu_one, sanction_indicator_eu_one, '_eu_as_one'),
    ]
    for window in windows:
        for bil, sanc_ind, suffix in variants:
            for volume_col in volume_cols:
                col = f'sanction_intensity_{volume_col}_{window}{suffix}'
                share = _rolling_trade_share(bil, window=window, shift=1, volume_col=volume_col)
                share_long = share.rename_axis(columns='year').stack().reset_index(name='share')
                result[col] = _share_weighted_intensity(sanc_ind, share_long, 'share', result.index, col)
    return result


def compute_directional(
    panel: pd.DataFrame,
    bilateral,
    bilateral_eu_one,
    import_sanction_indicator,
    export_sanction_indicator,
    dyadic_sanctions_og,
    window=10,
) -> pd.DataFrame:
    """
    Index 2: Directional trade-share weighted sanction intensity (sanctioned country perspective).

    2a — Export disruption (sanction_intensity_sanctioned_country_exports):
        Σ_i ExportShare_ci^pre × ImportSanction_ic
        i restricts imports FROM c → c loses export market in i → weight by c's export share to i.

    2b — Import disruption (sanction_intensity_sanctioned_country_imports):
        Σ_i ImportShare_ci^pre × ExportSanction_ic
        i restricts exports TO c → c loses import supply from i → weight by c's import share from i.

    Computed for both EU-expanded and EU-as-one variants.

    Adds columns:
        sanction_intensity_sanctioned_country_exports[_eu_as_one]
        sanction_intensity_sanctioned_country_imports[_eu_as_one]
    """
    result = panel.copy()

    exp_share = (
        _rolling_trade_share(bilateral, window=window, shift=1, volume_col='export_volume')
        .rename_axis(columns='year').stack().reset_index(name='export_share')
    )
    imp_share = (
        _rolling_trade_share(bilateral, window=window, shift=1, volume_col='import_volume')
        .rename_axis(columns='year').stack().reset_index(name='import_share')
    )

    col_exp = 'sanction_intensity_sanctioned_country_exports'
    col_imp = 'sanction_intensity_sanctioned_country_imports'
    result[col_exp] = _share_weighted_intensity(import_sanction_indicator, exp_share, 'export_share', result.index, col_exp)
    result[col_imp] = _share_weighted_intensity(export_sanction_indicator, imp_share, 'import_share', result.index, col_imp)

    imp_sanc_eu1 = _eu_one_dyadic_indicator(dyadic_sanctions_og, r'\bimp_compl\b|\bimp_part\b')
    exp_sanc_eu1 = _eu_one_dyadic_indicator(dyadic_sanctions_og, r'\bexp_compl\b|\bexp_part\b')

    exp_share_eu1 = (
        _rolling_trade_share(bilateral_eu_one, window=window, shift=1, volume_col='export_volume')
        .rename_axis(columns='year').stack().reset_index(name='export_share')
    )
    imp_share_eu1 = (
        _rolling_trade_share(bilateral_eu_one, window=window, shift=1, volume_col='import_volume')
        .rename_axis(columns='year').stack().reset_index(name='import_share')
    )

    col_exp_eu1 = 'sanction_intensity_sanctioned_country_exports_eu_as_one'
    col_imp_eu1 = 'sanction_intensity_sanctioned_country_imports_eu_as_one'
    result[col_exp_eu1] = _share_weighted_intensity(imp_sanc_eu1, exp_share_eu1, 'export_share', result.index, col_exp_eu1)
    result[col_imp_eu1] = _share_weighted_intensity(exp_sanc_eu1, imp_share_eu1, 'import_share', result.index, col_imp_eu1)

    return result


def compute_gdp_normalised(
    panel: pd.DataFrame,
    bilateral,
    import_sanction_indicator,
    export_sanction_indicator,
    window=10,
) -> pd.DataFrame:
    """
    Index 3: GDP-normalised directional trade-weighted sanction intensity.

    SanctionIntensity_GDP(c,t) =
        [Σ_i M_pre(c,i)×ExportSanction(i,c,t) + Σ_i X_pre(c,i)×ImportSanction(i,c,t)] / GDP_pre(c)

    Directional logic (crossed assignment):
        ExportSanction: i restricts exports TO c → c loses imports from i → weight by M_pre(c,i)
        ImportSanction: i restricts imports FROM c → c loses exports to i → weight by X_pre(c,i)

    Uses absolute bilateral trade levels normalised by pre-period GDP.
    Requires panel column 'gdp_const_2015_usd' (WDI NY.GDP.MKTP.KD).

    Adds column: sanction_intensity_gdp
    """
    result = panel.copy()

    M_pre = _rolling_abs(bilateral, window=window, shift=1, volume_col='import_volume')
    X_pre = _rolling_abs(bilateral, window=window, shift=1, volume_col='export_volume')
    M_pre_long = M_pre.rename_axis(columns='year').stack().reset_index(name='M_pre')
    X_pre_long = X_pre.rename_axis(columns='year').stack().reset_index(name='X_pre')

    gdp_pre_long = (
        result['gdp_const_2015_usd'].dropna()
        .unstack(level='year').astype(float)
        .T.rolling(window=window, min_periods=1).mean().shift(1).T
        .rename_axis(index='c', columns='year')
        .stack().reset_index(name='GDP_pre')
    )

    dyads = (
        export_sanction_indicator[['i', 'c', 'year']].assign(export_sanction=1)
        .merge(import_sanction_indicator[['i', 'c', 'year']].assign(import_sanction=1),
               on=['i', 'c', 'year'], how='outer')
        .fillna({'export_sanction': 0, 'import_sanction': 0})
        .merge(M_pre_long, on=['c', 'i', 'year'], how='left').fillna({'M_pre': 0.0})
        .merge(X_pre_long, on=['c', 'i', 'year'], how='left').fillna({'X_pre': 0.0})
    )
    dyads['numerator'] = dyads['M_pre'] * dyads['export_sanction'] + dyads['X_pre'] * dyads['import_sanction']

    col = 'sanction_intensity_gdp'
    intensity = (
        dyads.groupby(['c', 'year'])['numerator'].sum().reset_index()
        .merge(gdp_pre_long, on=['c', 'year'], how='left')
        .rename(columns={'c': 'iso3'})
    )
    intensity[col] = np.where(
        intensity['GDP_pre'].notna() & (intensity['GDP_pre'] > 0),
        intensity['numerator'] / intensity['GDP_pre'],
        np.nan,
    )
    result[col] = intensity.set_index(['iso3', 'year'])[col].reindex(result.index).fillna(0.0)
    return result


def compute_gdp_normalised_lag1(
    panel: pd.DataFrame,
    bilateral,
    import_sanction_indicator,
    export_sanction_indicator,
    window=10,
) -> pd.DataFrame:
    """
    Index 3b: GDP-normalised directional trade-weighted sanction intensity with lagged GDP denominator.

    Same numerator as Index 3 (rolling pre-period absolute bilateral trade volumes),
    but the denominator is GDP_{c,t-1} (one-year lag) instead of the rolling pre-period mean.

    SanctionIntensity_GDP_lag1(c,t) =
        [Σ_i M_pre(c,i)×ExportSanction(i,c,t) + Σ_i X_pre(c,i)×ImportSanction(i,c,t)] / GDP_{c,t-1}

    Adds column: sanction_intensity_gdp_lag1
    """
    result = panel.copy()

    M_pre = _rolling_abs(bilateral, window=window, shift=1, volume_col='import_volume')
    X_pre = _rolling_abs(bilateral, window=window, shift=1, volume_col='export_volume')
    M_pre_long = M_pre.rename_axis(columns='year').stack().reset_index(name='M_pre')
    X_pre_long = X_pre.rename_axis(columns='year').stack().reset_index(name='X_pre')

    gdp_lag1_long = (
        result['gdp_const_2015_usd'].dropna()
        .unstack(level='year').astype(float)
        .T.shift(1).T
        .rename_axis(index='c', columns='year')
        .stack().reset_index(name='GDP_lag1')
    )

    dyads = (
        export_sanction_indicator[['i', 'c', 'year']].assign(export_sanction=1)
        .merge(import_sanction_indicator[['i', 'c', 'year']].assign(import_sanction=1),
               on=['i', 'c', 'year'], how='outer')
        .fillna({'export_sanction': 0, 'import_sanction': 0})
        .merge(M_pre_long, on=['c', 'i', 'year'], how='left').fillna({'M_pre': 0.0})
        .merge(X_pre_long, on=['c', 'i', 'year'], how='left').fillna({'X_pre': 0.0})
    )
    dyads['numerator'] = dyads['M_pre'] * dyads['export_sanction'] + dyads['X_pre'] * dyads['import_sanction']

    col = 'sanction_intensity_gdp_lag1'
    intensity = (
        dyads.groupby(['c', 'year'])['numerator'].sum().reset_index()
        .merge(gdp_lag1_long, on=['c', 'year'], how='left')
        .rename(columns={'c': 'iso3'})
    )
    intensity[col] = np.where(
        intensity['GDP_lag1'].notna() & (intensity['GDP_lag1'] > 0),
        intensity['numerator'] / intensity['GDP_lag1'],
        np.nan,
    )
    result[col] = intensity.set_index(['iso3', 'year'])[col].reindex(result.index).fillna(0.0)
    return result


def compute_gdp_normalised_nominal(
    panel: pd.DataFrame,
    bilateral,
    import_sanction_indicator,
    export_sanction_indicator,
    window=10,
) -> pd.DataFrame:
    """
    Index 3d: GDP-normalised directional trade-weighted sanction intensity using nominal GDP.

    Identical to Index 3, but the denominator uses nominal GDP in current USD (WDI NY.GDP.MKTP.CD)
    instead of constant 2015 USD. The denominator is a rolling pre-period mean over `window` years.

    SanctionIntensity_GDP_nominal(c,t) =
        [Σ_i M_pre(c,i)×ExportSanction(i,c,t) + Σ_i X_pre(c,i)×ImportSanction(i,c,t)] / GDP_nominal_pre(c)

    Requires panel column 'gdp_tot_nominal' (WDI NY.GDP.MKTP.CD).

    Adds column: sanction_intensity_gdp_nominal
    """
    result = panel.copy()

    M_pre = _rolling_abs(bilateral, window=window, shift=1, volume_col='import_volume')
    X_pre = _rolling_abs(bilateral, window=window, shift=1, volume_col='export_volume')
    M_pre_long = M_pre.rename_axis(columns='year').stack().reset_index(name='M_pre')
    X_pre_long = X_pre.rename_axis(columns='year').stack().reset_index(name='X_pre')

    gdp_pre_long = (
        result['gdp_tot_nominal'].dropna()
        .unstack(level='year').astype(float)
        .T.rolling(window=window, min_periods=1).mean().shift(1).T
        .rename_axis(index='c', columns='year')
        .stack().reset_index(name='GDP_nominal_pre')
    )

    dyads = (
        export_sanction_indicator[['i', 'c', 'year']].assign(export_sanction=1)
        .merge(import_sanction_indicator[['i', 'c', 'year']].assign(import_sanction=1),
               on=['i', 'c', 'year'], how='outer')
        .fillna({'export_sanction': 0, 'import_sanction': 0})
        .merge(M_pre_long, on=['c', 'i', 'year'], how='left').fillna({'M_pre': 0.0})
        .merge(X_pre_long, on=['c', 'i', 'year'], how='left').fillna({'X_pre': 0.0})
    )
    dyads['numerator'] = dyads['M_pre'] * dyads['export_sanction'] + dyads['X_pre'] * dyads['import_sanction']

    col = 'sanction_intensity_gdp_nominal'
    intensity = (
        dyads.groupby(['c', 'year'])['numerator'].sum().reset_index()
        .merge(gdp_pre_long, on=['c', 'year'], how='left')
        .rename(columns={'c': 'iso3'})
    )
    intensity[col] = np.where(
        intensity['GDP_nominal_pre'].notna() & (intensity['GDP_nominal_pre'] > 0),
        intensity['numerator'] / intensity['GDP_nominal_pre'],
        np.nan,
    )
    result[col] = intensity.set_index(['iso3', 'year'])[col].reindex(result.index).fillna(0.0)
    return result


def compute_gdp_normalised_gdp5(
    panel: pd.DataFrame,
    bilateral,
    import_sanction_indicator,
    export_sanction_indicator,
    window=10,
) -> pd.DataFrame:
    """
    Index 3c: GDP-normalised directional trade-weighted sanction intensity with 5-year rolling GDP denominator.

    Same numerator as Index 3 (rolling pre-period absolute bilateral trade volumes),
    but the denominator uses a 5-year rolling pre-period mean of GDP instead of 10 years.

    SanctionIntensity_GDP5(c,t) =
        [Σ_i M_pre(c,i)×ExportSanction(i,c,t) + Σ_i X_pre(c,i)×ImportSanction(i,c,t)] / GDP5_pre(c)

    Adds column: sanction_intensity_gdp5
    """
    result = panel.copy()

    M_pre = _rolling_abs(bilateral, window=window, shift=1, volume_col='import_volume')
    X_pre = _rolling_abs(bilateral, window=window, shift=1, volume_col='export_volume')
    M_pre_long = M_pre.rename_axis(columns='year').stack().reset_index(name='M_pre')
    X_pre_long = X_pre.rename_axis(columns='year').stack().reset_index(name='X_pre')

    gdp_pre_long = (
        result['gdp_const_2015_usd'].dropna()
        .unstack(level='year').astype(float)
        .T.rolling(window=5, min_periods=1).mean().shift(1).T
        .rename_axis(index='c', columns='year')
        .stack().reset_index(name='GDP_pre5')
    )

    dyads = (
        export_sanction_indicator[['i', 'c', 'year']].assign(export_sanction=1)
        .merge(import_sanction_indicator[['i', 'c', 'year']].assign(import_sanction=1),
               on=['i', 'c', 'year'], how='outer')
        .fillna({'export_sanction': 0, 'import_sanction': 0})
        .merge(M_pre_long, on=['c', 'i', 'year'], how='left').fillna({'M_pre': 0.0})
        .merge(X_pre_long, on=['c', 'i', 'year'], how='left').fillna({'X_pre': 0.0})
    )
    dyads['numerator'] = dyads['M_pre'] * dyads['export_sanction'] + dyads['X_pre'] * dyads['import_sanction']

    col = 'sanction_intensity_gdp5'
    intensity = (
        dyads.groupby(['c', 'year'])['numerator'].sum().reset_index()
        .merge(gdp_pre_long, on=['c', 'year'], how='left')
        .rename(columns={'c': 'iso3'})
    )
    intensity[col] = np.where(
        intensity['GDP_pre5'].notna() & (intensity['GDP_pre5'] > 0),
        intensity['numerator'] / intensity['GDP_pre5'],
        np.nan,
    )
    result[col] = intensity.set_index(['iso3', 'year'])[col].reindex(result.index).fillna(0.0)
    return result

    # NOTE: dead code copied verbatim from sanction_indexes.py — unreachable after return above
    def _compute_variant(bil, imp_ind, exp_ind, suffix):
        exp_share = (
            _rolling_trade_share(bil, window=window, shift=1, volume_col='export_volume')
            .rename_axis(columns='year').stack().reset_index(name='export_share')
        )
        imp_share = (
            _rolling_trade_share(bil, window=window, shift=1, volume_col='import_volume')
            .rename_axis(columns='year').stack().reset_index(name='import_share')
        )
        dyads = (
            imp_ind[['i', 'c', 'year']].drop_duplicates().assign(imp_sanc=1)
            .merge(exp_ind[['i', 'c', 'year']].drop_duplicates().assign(exp_sanc=1),
                   on=['i', 'c', 'year'], how='outer')
            .fillna({'imp_sanc': 0, 'exp_sanc': 0})
            .merge(exp_share, on=['c', 'i', 'year'], how='left').fillna({'export_share': 0.0})
            .merge(imp_share, on=['c', 'i', 'year'], how='left').fillna({'import_share': 0.0})
        )
        dyads['contrib'] = dyads['export_share'] * dyads['imp_sanc'] + dyads['import_share'] * dyads['exp_sanc']
        col = f'sanction_intensity_combined_directional_{window}{suffix}'
        result[col] = (
            dyads.groupby(['c', 'year'])['contrib'].sum()
            .reset_index().rename(columns={'c': 'iso3', 'contrib': col})
            .set_index(['iso3', 'year'])[col]
            .reindex(result.index).fillna(0.0)
        )

    _compute_variant(bilateral, import_sanction_indicator, export_sanction_indicator, '')
    _compute_variant(
        bilateral_eu_one,
        _eu_one_dyadic_indicator(dyadic_sanctions_og, r'\bimp_compl\b|\bimp_part\b'),
        _eu_one_dyadic_indicator(dyadic_sanctions_og, r'\bexp_compl\b|\bexp_part\b'),
        '_eu_as_one',
    )
    return result


def compute_combined_dir_total(
    panel: pd.DataFrame,
    bilateral,
    bilateral_eu_one,
    import_sanction_indicator,
    export_sanction_indicator,
    dyadic_sanctions_og,
    window=10,
) -> pd.DataFrame:
    """
    Index 8: Combined directional total-trade normalised sanction intensity.

    SanctionIntensity(c,t) =
        Σ_i [X_ci/T_c × ImportSanction_ic + M_ci/T_c × ExportSanction_ic]

    T_c = Σ_j(X_cj^pre + M_cj^pre) — c's total pre-period trade with all partners.
    Using a single total-trade denominator for both export and import disruption puts
    both sides on the same scale. Computed for EU-expanded and EU-as-one variants.

    Adds columns: sanction_intensity_combined_dir_total_{window}[_eu_as_one]
    """
    result = panel.copy()

    def _compute_variant(bil, imp_ind, exp_ind, suffix):
        exp_long, imp_long = _dir_total_shares(bil, window=window)
        dyads = (
            imp_ind[['i', 'c', 'year']].drop_duplicates().assign(imp_sanc=1)
            .merge(exp_ind[['i', 'c', 'year']].drop_duplicates().assign(exp_sanc=1),
                   on=['i', 'c', 'year'], how='outer')
            .fillna({'imp_sanc': 0, 'exp_sanc': 0})
            .merge(exp_long, on=['c', 'i', 'year'], how='left').fillna({'export_share': 0.0})
            .merge(imp_long, on=['c', 'i', 'year'], how='left').fillna({'import_share': 0.0})
        )
        dyads['contrib'] = dyads['export_share'] * dyads['imp_sanc'] + dyads['import_share'] * dyads['exp_sanc']
        col = f'sanction_intensity_combined_dir_total_{window}{suffix}'
        result[col] = (
            dyads.groupby(['c', 'year'])['contrib'].sum()
            .reset_index().rename(columns={'c': 'iso3', 'contrib': col})
            .set_index(['iso3', 'year'])[col]
            .reindex(result.index).fillna(0.0)
        )

    _compute_variant(bilateral, import_sanction_indicator, export_sanction_indicator, '')
    _compute_variant(
        bilateral_eu_one,
        _eu_one_dyadic_indicator(dyadic_sanctions_og, r'\bimp_compl\b|\bimp_part\b'),
        _eu_one_dyadic_indicator(dyadic_sanctions_og, r'\bexp_compl\b|\bexp_part\b'),
        '_eu_as_one',
    )
    return result


def compute_combined_dir_total_full_only(
    panel: pd.DataFrame,
    bilateral,
    bilateral_eu_one,
    dyadic_sanctions_og,
    window=10,
) -> pd.DataFrame:
    """
    Index 8f: Combined directional total-trade normalised sanction intensity — full sanctions only.

    Identical to Index 8, except partial sanctions (exp_part, imp_part) are excluded:
    ExportSanction = 1 only for exp_compl; ImportSanction = 1 only for imp_compl.

    SanctionIntensity(c,t) =
        Σ_i [X_ci/T_c × ImportSanction_compl_ic + M_ci/T_c × ExportSanction_compl_ic]

    Adds columns: sanction_intensity_combined_dir_total_{window}_full[_eu_as_one_full]
    """
    result = panel.copy()
    eu = set(EUROPEAN_UNION)

    imp_full = _make_dyadic_indicator(dyadic_sanctions_og, r'\bimp_compl\b', eu)
    exp_full = _make_dyadic_indicator(dyadic_sanctions_og, r'\bexp_compl\b', eu)

    def _compute_variant(bil, imp_ind, exp_ind, suffix):
        exp_long, imp_long = _dir_total_shares(bil, window=window)
        dyads = (
            imp_ind[['i', 'c', 'year']].drop_duplicates().assign(imp_sanc=1)
            .merge(exp_ind[['i', 'c', 'year']].drop_duplicates().assign(exp_sanc=1),
                   on=['i', 'c', 'year'], how='outer')
            .fillna({'imp_sanc': 0, 'exp_sanc': 0})
            .merge(exp_long, on=['c', 'i', 'year'], how='left').fillna({'export_share': 0.0})
            .merge(imp_long, on=['c', 'i', 'year'], how='left').fillna({'import_share': 0.0})
        )
        dyads['contrib'] = dyads['export_share'] * dyads['imp_sanc'] + dyads['import_share'] * dyads['exp_sanc']
        col = f'sanction_intensity_combined_dir_total_{window}{suffix}'
        result[col] = (
            dyads.groupby(['c', 'year'])['contrib'].sum()
            .reset_index().rename(columns={'c': 'iso3', 'contrib': col})
            .set_index(['iso3', 'year'])[col]
            .reindex(result.index).fillna(0.0)
        )

    _compute_variant(bilateral, imp_full, exp_full, '_full')
    _compute_variant(
        bilateral_eu_one,
        _eu_one_dyadic_indicator(dyadic_sanctions_og, r'\bimp_compl\b'),
        _eu_one_dyadic_indicator(dyadic_sanctions_og, r'\bexp_compl\b'),
        '_eu_as_one_full',
    )
    return result


def compute_episode_trade_share_eu_one(
    panel: pd.DataFrame,
    bilateral_eu_one,
    dyadic_sanctions_og,
) -> pd.DataFrame:
    """
    Episode-onset trade-share weighted sanction intensity (EU-as-one).

    Same formula as Index 1b, but the bilateral trade share used as weight is
    fixed at the year immediately before the sanction episode (case_id) starts,
    rather than a rolling pre-period average.

    SanctionIntensity_ct = Σ_i Share_ci^{t0-1} × TradeSanction_ict

    where t0 = min(year) for the episode (case_id) covering pair (c, i) and
    Share_ci^{t0-1} is the point-in-time bilateral trade share in year t0-1.

    Adds column: sanction_intensity_episode_trade_share_eu_one
    """
    result = panel.copy()

    # ── 1. Trade sanctions with EU-as-one format and case_id ──────────────────
    mask = (
        (dyadic_sanctions_og['trade'] == 1)
        & dyadic_sanctions_og['sanctioning_state_iso3'].notna()
        & (dyadic_sanctions_og['sanctioning_state_iso3'] != '')
    )
    dyadic = (
        dyadic_sanctions_og[mask]
        .rename(columns={'sanctioned_state_iso3': 'c', 'sanctioning_state_iso3': 'i'})
        [['case_id', 'i', 'c', 'year']].drop_duplicates()
    )
    dyadic = dyadic[dyadic['c'] != 'EU'].copy()

    # ── 2. Episode start year per (case_id, c, i) ─────────────────────────────
    episode_start = (
        dyadic.groupby(['case_id', 'c', 'i'])['year'].min()
        .reset_index().rename(columns={'year': 'start_year'})
    )

    # ── 3. Point-in-time bilateral trade shares from bilateral_eu_one ─────────
    all_years = sorted(bilateral_eu_one['year'].astype(int).unique())
    pivot = (
        bilateral_eu_one
        .pivot_table(index=['c', 'i'], columns='year', values='trade_volume', fill_value=0.0)
        .reindex(columns=all_years, fill_value=0.0)
    )
    total_c = pivot.groupby(level='c').sum()
    c_idx = pivot.index.get_level_values('c')
    share_matrix = pd.DataFrame(
        np.where(total_c.loc[c_idx].values > 0, pivot.values / total_c.loc[c_idx].values, 0.0),
        index=pivot.index,
        columns=pivot.columns,
    ).clip(0.0, 1.0)
    share_long = share_matrix.rename_axis(columns='year').stack().reset_index(name='share')

    # ── 4. Look up share at start_year - 1 for each episode ───────────────────
    episode_start = episode_start.copy()
    episode_start['lookup_year'] = episode_start['start_year'] - 1
    episode_shares = (
        episode_start
        .merge(
            share_long.rename(columns={'year': 'lookup_year'}),
            on=['c', 'i', 'lookup_year'], how='left',
        )
        .fillna({'share': 0.0})
        [['case_id', 'c', 'i', 'share']]
    )

    # ── 5. Attach fixed onset share to each active sanction year ──────────────
    active = dyadic.merge(episode_shares, on=['case_id', 'c', 'i'], how='left').fillna({'share': 0.0})

    # ── 6. Aggregate to (iso3, year) and align to panel ───────────────────────
    col = 'sanction_intensity_episode_trade_share_eu_one'
    result[col] = (
        active.groupby(['c', 'year'])['share'].sum()
        .reset_index().rename(columns={'c': 'iso3', 'share': col})
        .set_index(['iso3', 'year'])[col]
        .reindex(panel.index).fillna(0.0)
    )
    return result


def compute_episode_combined_dir_total_eu_one(
    panel: pd.DataFrame,
    bilateral_eu_one,
    dyadic_sanctions_og,
) -> pd.DataFrame:
    """
    Episode-onset combined directional total-trade normalised sanction intensity (EU-as-one).
    Same formula as the rolling combined directional total-trade index, but X_ci/T_c and
    M_ci/T_c are fixed at the year immediately before each sanction episode (case_id) starts.

    SanctionIntensity_ct = Σ_i [X_ci^{t0-1}/T_c^{t0-1} × ImportSanction_ict
                               + M_ci^{t0-1}/T_c^{t0-1} × ExportSanction_ict]

    Adds column: sanction_intensity_episode_combined_dir_total_eu_one
    """
    result = panel.copy()

    # ── 1. Sanction indicators with case_id (EU-as-one) ───────────────────────
    def _ind_with_cid(desc_pattern):
        mask = (
            dyadic_sanctions_og['descr_trade'].fillna('').str.contains(desc_pattern, regex=True)
            & dyadic_sanctions_og['sanctioning_state_iso3'].notna()
        )
        df = (
            dyadic_sanctions_og[mask]
            .rename(columns={'sanctioned_state_iso3': 'c', 'sanctioning_state_iso3': 'i'})
            [['case_id', 'i', 'c', 'year']].drop_duplicates()
        )
        return df[df['c'] != 'EU'].copy()

    imp_with_cid = _ind_with_cid(r'\bimp_compl\b|\bimp_part\b').assign(imp_sanc=1)
    exp_with_cid = _ind_with_cid(r'\bexp_compl\b|\bexp_part\b').assign(exp_sanc=1)

    dyadic = (
        imp_with_cid.merge(exp_with_cid, on=['case_id', 'i', 'c', 'year'], how='outer')
        .fillna({'imp_sanc': 0, 'exp_sanc': 0})
    )

    # ── 2. Episode onset year per (case_id, c, i) ─────────────────────────────
    episode_start = (
        dyadic.groupby(['case_id', 'c', 'i'])['year'].min()
        .reset_index().rename(columns={'year': 'start_year'})
    )
    episode_start['lookup_year'] = episode_start['start_year'] - 1

    # ── 3. Point-in-time bilateral X_ci/T_c and M_ci/T_c for each year ────────
    bil = bilateral_eu_one.copy()
    all_years = sorted(bil['year'].astype(int).unique())

    X_pivot = (bil.pivot_table(index=['c', 'i'], columns='year', values='export_volume', fill_value=0.0)
               .reindex(columns=all_years, fill_value=0.0))
    M_pivot = (bil.pivot_table(index=['c', 'i'], columns='year', values='import_volume', fill_value=0.0)
               .reindex(columns=all_years, fill_value=0.0))
    T_c = (X_pivot + M_pivot).groupby(level='c').sum()
    c_idx = X_pivot.index.get_level_values('c')
    denom = T_c.loc[c_idx].values

    with np.errstate(invalid='ignore', divide='ignore'):
        _exp_arr = np.where(denom > 0, X_pivot.values / denom, 0.0)
        _imp_arr = np.where(denom > 0, M_pivot.values / denom, 0.0)

    exp_share_long = (
        pd.DataFrame(_exp_arr,
                     index=X_pivot.index, columns=X_pivot.columns)
        .clip(0.0, 1.0).rename_axis(columns='year').stack().reset_index(name='export_share')
    )
    imp_share_long = (
        pd.DataFrame(_imp_arr,
                     index=M_pivot.index, columns=M_pivot.columns)
        .clip(0.0, 1.0).rename_axis(columns='year').stack().reset_index(name='import_share')
    )

    # ── 4. Look up shares at start_year - 1 ───────────────────────────────────
    episode_exp = (
        episode_start
        .merge(exp_share_long.rename(columns={'year': 'lookup_year'}),
               on=['c', 'i', 'lookup_year'], how='left')
        .fillna({'export_share': 0.0})[['case_id', 'c', 'i', 'export_share']]
    )
    episode_imp = (
        episode_start
        .merge(imp_share_long.rename(columns={'year': 'lookup_year'}),
               on=['c', 'i', 'lookup_year'], how='left')
        .fillna({'import_share': 0.0})[['case_id', 'c', 'i', 'import_share']]
    )

    # ── 5. Attach fixed onset shares to each active sanction year ─────────────
    active = (
        dyadic
        .merge(episode_exp, on=['case_id', 'c', 'i'], how='left').fillna({'export_share': 0.0})
        .merge(episode_imp, on=['case_id', 'c', 'i'], how='left').fillna({'import_share': 0.0})
    )
    active['contrib'] = active['export_share'] * active['imp_sanc'] + active['import_share'] * active['exp_sanc']

    # ── 6. Aggregate to (iso3, year) and align to panel ───────────────────────
    col = 'sanction_intensity_episode_combined_dir_total_eu_one'
    result[col] = (
        active.groupby(['c', 'year'])['contrib'].sum()
        .reset_index().rename(columns={'c': 'iso3', 'contrib': col})
        .set_index(['iso3', 'year'])[col]
        .reindex(panel.index).fillna(0.0)
    )
    return result

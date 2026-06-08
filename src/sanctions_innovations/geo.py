"""Country-code conversion and country-group membership helpers."""
import pandas as pd
import pycountry
import country_converter as coco
from countrygroups import EUROPEAN_UNION, UN_REGIONAL_GROUPS, BRICS, OECD, OPEC


def iso2_to_iso3(code: str) -> str | None:
    """Convert ISO 3166-1 alpha-2 code to alpha-3. Returns None on failure."""
    try:
        return pycountry.countries.get(alpha_2=code).alpha_3
    except Exception:
        return None


def convert_to_iso3(code, to: str = "ISO3") -> str | None:
    """Convert a country code or name to ISO3 via country_converter."""
    if pd.isna(code):
        return None
    c = str(code).strip().upper()
    return coco.convert(c, to=to, not_found=None)


def get_country_converter() -> coco.CountryConverter:
    """Return a CountryConverter instance."""
    return coco.CountryConverter()


def build_senders_iso3() -> dict:
    """
    Return the ISO3-keyed sender groupings used with make_sanction_panel.

    Keys: US, UN, EU, BRICS, OECD, OPEC.
    """
    return {
        "US": {"USA"},
        "UN": set(UN_REGIONAL_GROUPS),
        "EU": set(EUROPEAN_UNION),
        "BRICS": set(BRICS),
        "OECD": set(OECD),
        "OPEC": set(OPEC),
    }

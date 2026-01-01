from __future__ import annotations
from dataclasses import dataclass
from typing import Dict, List, Optional, Iterable
import re

@dataclass(frozen=True)
class Offer:
    sku: str
    canonical: str
    title: str
    supplier: str
    unit: str
    price_gbp: float
    in_stock: bool = True

def _norm(s: str) -> str:
    s = s.lower().strip()
    s = s.replace("’", "'")
    s = re.sub(r"[^a-z0-9x\. ]+", " ", s)
    s = re.sub(r"\s+", " ", s)
    return s

def _tokens(s: str) -> List[str]:
    s = _norm(s)
    parts = [p for p in s.split(" ") if p]
    # helpful expansions/aliases
    out = []
    for p in parts:
        if p in ("pdf",):   # user typing "pdf" as shorthand for ply (demo)
            out += ["ply", "plywood"]
        else:
            out.append(p)
    return out

# Supplier meta (used for copy + insights)
SUPPLIERS: Dict[str, Dict] = {
    # Nationals
    "Screwfix": {
        "delivery_gbp": 6.99, "lead_days": 1, "local": False, "type": "National",
        "copy": "Fast delivery, strong range, good for fixings."
    },
    "Toolstation": {
        "delivery_gbp": 5.99, "lead_days": 2, "local": False, "type": "National",
        "copy": "Competitive pricing, reliable delivery."
    },
    "Jewson": {
        "delivery_gbp": 22.50, "lead_days": 3, "local": False, "type": "Merchant",
        "copy": "Trade merchant pricing & account-style range."
    },
    "MKM": {
        "delivery_gbp": 18.00, "lead_days": 3, "local": False, "type": "Merchant",
        "copy": "Merchant stock & wider building materials."
    },

    # Local merchants (demo “buy local” story)
    "Cheshire Timber & Sheet (Local)": {
        "delivery_gbp": 9.95, "lead_days": 1, "local": True, "type": "Local",
        "copy": "Local stock, quick turnaround, support nearby trade."
    },
    "Stockport Builders Merchant (Local)": {
        "delivery_gbp": 12.50, "lead_days": 1, "local": True, "type": "Local",
        "copy": "Local trade counter, next-day delivery in-area."
    },
    "Manchester Fixings Depot (Local)": {
        "delivery_gbp": 4.50, "lead_days": 1, "local": True, "type": "Local",
        "copy": "Great for fixings, often cheapest delivered."
    },
}

# Canonical products (demo scope)
CATALOG: Dict[str, Dict] = {
    "timber_cls_3x2_2.4m": {"unit":"each", "label":"CLS Timber 3x2 (38x63) 2.4m", "keywords":["3x2","cls","38x63","2.4","2400","timber"]},
    "timber_cls_4x2_2.4m": {"unit":"each", "label":"CLS Timber 4x2 (38x89) 2.4m", "keywords":["4x2","cls","38x89","2.4","2400","timber"]},

    "sheet_osb_18_2440x1220": {"unit":"sheet", "label":"OSB3 18mm 2440x1220 (8x4)", "keywords":["osb","osb3","18","18mm","8x4","2440","1220","sheet"]},
    "sheet_mdf_18_2440x1220": {"unit":"sheet", "label":"MDF 18mm 2440x1220 (8x4)", "keywords":["mdf","18","18mm","8x4","2440","1220","sheet"]},
    "sheet_ply_18_2440x1220": {"unit":"sheet", "label":"Plywood 18mm 2440x1220 (8x4)", "keywords":["ply","plywood","18","18mm","8x4","2440","1220","sheet","pdf"]},

    "fix_screws_5x80_200": {"unit":"box", "label":"Wood Screws 5x80mm (Box 200)", "keywords":["screw","screws","wood","5x80","5","80","box","200"]},
    "fix_screws_4x40_200": {"unit":"box", "label":"Wood Screws 4x40mm (Box 200)", "keywords":["screw","screws","wood","4x40","4","40","box","200"]},
}

def get_label(canonical: str) -> str:
    return CATALOG.get(canonical, {}).get("label", canonical)

def get_unit(canonical: str) -> str:
    return CATALOG.get(canonical, {}).get("unit", "each")

# Supplier offers (tuned so SPLIT baskets show clear savings vs single supplier)
OFFERS: List[Offer] = [
    # 3x2 2.4
    Offer("SF-CLS32-24",  "timber_cls_3x2_2.4m", "CLS 38x63mm 2.4m", "Screwfix", "each", 3.35),
    Offer("TS-CLS32-24",  "timber_cls_3x2_2.4m", "CLS Timber 38x63 2.4m", "Toolstation", "each", 3.10),
    Offer("JW-CLS32-24",  "timber_cls_3x2_2.4m", "C16 CLS 38x63 2.4m", "Jewson", "each", 3.70),
    Offer("MKM-CLS32-24", "timber_cls_3x2_2.4m", "CLS 38x63 C16 2.4m", "MKM", "each", 3.55),
    Offer("CT-CLS32-24",  "timber_cls_3x2_2.4m", "CLS 38x63 2.4m (Local)", "Cheshire Timber & Sheet (Local)", "each", 3.25),
    Offer("SBM-CLS32-24", "timber_cls_3x2_2.4m", "CLS 38x63 2.4m (Local)", "Stockport Builders Merchant (Local)", "each", 3.30),

    # 4x2 2.4
    Offer("SF-CLS42-24",  "timber_cls_4x2_2.4m", "CLS 38x89mm 2.4m", "Screwfix", "each", 5.05),
    Offer("TS-CLS42-24",  "timber_cls_4x2_2.4m", "CLS Timber 38x89 2.4m", "Toolstation", "each", 4.70),
    Offer("JW-CLS42-24",  "timber_cls_4x2_2.4m", "C16 CLS 38x89 2.4m", "Jewson", "each", 5.35),
    Offer("MKM-CLS42-24", "timber_cls_4x2_2.4m", "CLS 38x89 C16 2.4m", "MKM", "each", 5.15),
    Offer("CT-CLS42-24",  "timber_cls_4x2_2.4m", "CLS 38x89 2.4m (Local)", "Cheshire Timber & Sheet (Local)", "each", 4.95),
    Offer("SBM-CLS42-24", "timber_cls_4x2_2.4m", "CLS 38x89 2.4m (Local)", "Stockport Builders Merchant (Local)", "each", 5.05),

    # OSB 18
    Offer("SF-OSB18-8x4",  "sheet_osb_18_2440x1220", "OSB3 18mm 2440x1220", "Screwfix", "sheet", 21.25),
    Offer("TS-OSB18-8x4",  "sheet_osb_18_2440x1220", "OSB3 18mm 8x4", "Toolstation", "sheet", 22.40),
    Offer("JW-OSB18-8x4",  "sheet_osb_18_2440x1220", "OSB3 18mm 2440x1220", "Jewson", "sheet", 24.80),
    Offer("MKM-OSB18-8x4", "sheet_osb_18_2440x1220", "OSB3 18mm 2440x1220", "MKM", "sheet", 23.95),
    Offer("CT-OSB18-8x4",  "sheet_osb_18_2440x1220", "OSB3 18mm 8x4 (Local)", "Cheshire Timber & Sheet (Local)", "sheet", 20.90),
    Offer("SBM-OSB18-8x4", "sheet_osb_18_2440x1220", "OSB3 18mm 8x4 (Local)", "Stockport Builders Merchant (Local)", "sheet", 21.40),

    # MDF 18
    Offer("SF-MDF18-8x4",  "sheet_mdf_18_2440x1220", "MDF 18mm 2440x1220", "Screwfix", "sheet", 29.20),
    Offer("TS-MDF18-8x4",  "sheet_mdf_18_2440x1220", "MDF 18mm 8x4", "Toolstation", "sheet", 27.25),
    Offer("JW-MDF18-8x4",  "sheet_mdf_18_2440x1220", "MDF 18mm 2440x1220", "Jewson", "sheet", 31.30),
    Offer("MKM-MDF18-8x4", "sheet_mdf_18_2440x1220", "MDF 18mm 2440x1220", "MKM", "sheet", 28.95),
    Offer("CT-MDF18-8x4",  "sheet_mdf_18_2440x1220", "MDF 18mm 8x4 (Local)", "Cheshire Timber & Sheet (Local)", "sheet", 26.95),
    Offer("SBM-MDF18-8x4", "sheet_mdf_18_2440x1220", "MDF 18mm 8x4 (Local)", "Stockport Builders Merchant (Local)", "sheet", 27.40),

    # PLY 18 (accept "pdf" too)
    Offer("SF-PLY18-8x4",  "sheet_ply_18_2440x1220", "Plywood 18mm 2440x1220", "Screwfix", "sheet", 42.50),
    Offer("TS-PLY18-8x4",  "sheet_ply_18_2440x1220", "Plywood 18mm 8x4", "Toolstation", "sheet", 38.50),
    Offer("JW-PLY18-8x4",  "sheet_ply_18_2440x1220", "Plywood 18mm 2440x1220", "Jewson", "sheet", 44.00),
    Offer("MKM-PLY18-8x4", "sheet_ply_18_2440x1220", "Plywood 18mm 2440x1220", "MKM", "sheet", 43.25),
    Offer("CT-PLY18-8x4",  "sheet_ply_18_2440x1220", "Plywood 18mm 8x4 (Local)", "Cheshire Timber & Sheet (Local)", "sheet", 37.90),
    Offer("SBM-PLY18-8x4", "sheet_ply_18_2440x1220", "Plywood 18mm 8x4 (Local)", "Stockport Builders Merchant (Local)", "sheet", 39.20),

    # Screws (generic "screws" should show both)
    Offer("SF-SCR580-200",  "fix_screws_5x80_200", "Wood Screws 5x80mm (200)", "Screwfix", "box", 12.99),
    Offer("TS-SCR580-200",  "fix_screws_5x80_200", "Wood Screws 5x80 (200)", "Toolstation", "box", 12.20),
    Offer("JW-SCR580-200",  "fix_screws_5x80_200", "Wood Screws 5x80mm (200)", "Jewson", "box", 14.25),
    Offer("MKM-SCR580-200", "fix_screws_5x80_200", "Wood Screws 5x80mm (200)", "MKM", "box", 13.60),
    Offer("MFD-SCR580-200", "fix_screws_5x80_200", "Wood Screws 5x80mm (200) (Local)", "Manchester Fixings Depot (Local)", "box", 10.95),

    Offer("SF-SCR440-200",  "fix_screws_4x40_200", "Wood Screws 4x40mm (200)", "Screwfix", "box", 9.65),
    Offer("TS-SCR440-200",  "fix_screws_4x40_200", "Wood Screws 4x40 (200)", "Toolstation", "box", 8.79),
    Offer("JW-SCR440-200",  "fix_screws_4x40_200", "Wood Screws 4x40mm (200)", "Jewson", "box", 10.50),
    Offer("MKM-SCR440-200", "fix_screws_4x40_200", "Wood Screws 4x40mm (200)", "MKM", "box", 10.10),
    Offer("MFD-SCR440-200", "fix_screws_4x40_200", "Wood Screws 4x40mm (200) (Local)", "Manchester Fixings Depot (Local)", "box", 8.35),
]

def canonicalise_strict(q: str) -> Optional[str]:
    t = _tokens(q)

    # quick wins
    joined = " ".join(t)

    if ("3x2" in joined or "38x63" in joined) and any(x in joined for x in ("2.4","2400")):
        return "timber_cls_3x2_2.4m"
    if ("4x2" in joined or "38x89" in joined) and any(x in joined for x in ("2.4","2400")):
        return "timber_cls_4x2_2.4m"

    if "osb" in joined and ("18" in joined):
        return "sheet_osb_18_2440x1220"
    if "mdf" in joined and ("18" in joined):
        return "sheet_mdf_18_2440x1220"
    if ("ply" in joined or "plywood" in joined) and ("18" in joined):
        return "sheet_ply_18_2440x1220"

    if "5x80" in joined:
        return "fix_screws_5x80_200"
    if "4x40" in joined:
        return "fix_screws_4x40_200"

    return None

def _catalog_match_any(q_tokens: List[str], canon: str) -> bool:
    meta = CATALOG.get(canon, {})
    keys = set(_tokens(" ".join(meta.get("keywords", []))) + _tokens(meta.get("label","")))
    # match if any meaningful token overlaps
    meaningful = [x for x in q_tokens if len(x) >= 2]
    return any(t in keys for t in meaningful)

def search_offers(q: str) -> List[Offer]:
    """
    Smarter demo search:
      - strict canonical match when obvious
      - otherwise fuzzy match across catalog keywords (so 'screws', 'ply', 'pdf', 'osb', '3x2' works)
    """
    q_tokens = _tokens(q)
    if not q_tokens:
        return []

    strict = canonicalise_strict(q)
    if strict:
        return [o for o in OFFERS if o.canonical == strict and o.in_stock]

    # fuzzy: return offers for any catalog item that matches query tokens
    matched_canons = [canon for canon in CATALOG.keys() if _catalog_match_any(q_tokens, canon)]
    if not matched_canons:
        return []

    return [o for o in OFFERS if o.canonical in matched_canons and o.in_stock]

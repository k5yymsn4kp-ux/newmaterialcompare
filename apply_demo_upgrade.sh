#!/usr/bin/env bash
set -euo pipefail

# -----------------------
# 1) Demo data + smarter search + more suppliers (incl. local)
# -----------------------
cat > app/suppliers/demo.py <<'EOF'
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
EOF

# -----------------------
# 2) Main app: add LOCAL option insight + stronger savings messaging
# -----------------------
cat > app/main.py <<'EOF'
from __future__ import annotations
from typing import Dict, List, Optional
from fastapi import FastAPI, Request, Form
from fastapi.responses import RedirectResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.sessions import SessionMiddleware
from fastapi.templating import Jinja2Templates

from app.suppliers.demo import SUPPLIERS, search_offers, get_label, get_unit, Offer

app = FastAPI(title="Material Compare (Demo)")
app.add_middleware(SessionMiddleware, secret_key="demo-secret-change-me")

app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")

def _basket(request: Request) -> Dict[str, int]:
    request.session.setdefault("basket", {})
    return request.session["basket"]

def _add_item(request: Request, canonical: str, qty: int) -> None:
    b = _basket(request)
    b[canonical] = int(b.get(canonical, 0)) + int(qty)
    request.session["basket"] = b

def _remove_item(request: Request, canonical: str) -> None:
    b = _basket(request)
    b.pop(canonical, None)
    request.session["basket"] = b

def _clear(request: Request) -> None:
    request.session["basket"] = {}

def _fmt_gbp(x: float) -> str:
    return f"£{x:,.2f}"

def _offers_for_basket(basket: Dict[str, int]) -> Dict[str, List[Offer]]:
    # Use label search, then filter back to canonical line
    out: Dict[str, List[Offer]] = {}
    for canon in basket.keys():
        out[canon] = [o for o in search_offers(get_label(canon)) if o.canonical == canon]
    return out

def _cheapest(offers: List[Offer]) -> Optional[Offer]:
    return sorted(offers, key=lambda o: o.price_gbp)[0] if offers else None

def _cheapest_for_supplier(offers: List[Offer], supplier: str) -> Optional[Offer]:
    xs = [o for o in offers if o.supplier == supplier]
    return _cheapest(xs)

def _total_for_lines(lines: List[dict], supplier_set: set[str]) -> dict:
    items_total = sum(l["line_total"] for l in lines)
    delivery_total = sum(SUPPLIERS[s]["delivery_gbp"] for s in supplier_set)
    lead_days = max((SUPPLIERS[s]["lead_days"] for s in supplier_set), default=0)
    return {"items_total": items_total, "delivery_total": delivery_total, "lead_days": lead_days, "total": items_total + delivery_total}

def compute_split_best(basket: Dict[str,int], offers_map: Dict[str, List[Offer]]) -> dict:
    split_lines = []
    suppliers_used: set[str] = set()

    for canon, qty in basket.items():
        best = _cheapest(offers_map.get(canon, []))
        if not best:
            continue
        split_lines.append({
            "canonical": canon,
            "label": get_label(canon),
            "qty": qty,
            "unit": get_unit(canon),
            "supplier": best.supplier,
            "unit_price": best.price_gbp,
            "line_total": qty * best.price_gbp
        })
        suppliers_used.add(best.supplier)

    # breakdown
    breakdown: Dict[str, dict] = {}
    for s in suppliers_used:
        breakdown[s] = {
            "meta": SUPPLIERS[s],
            "items_total": 0.0,
            "delivery": SUPPLIERS[s]["delivery_gbp"],
            "lead_days": SUPPLIERS[s]["lead_days"],
            "lines": []
        }
    for l in split_lines:
        b = breakdown[l["supplier"]]
        b["items_total"] += l["line_total"]
        b["lines"].append({"label": l["label"], "qty": l["qty"], "line_total": l["line_total"]})

    totals = _total_for_lines(split_lines, suppliers_used)
    return {"lines": split_lines, "breakdown": breakdown, **totals}

def compute_single_best(basket: Dict[str,int], offers_map: Dict[str, List[Offer]]) -> Optional[dict]:
    options = []
    for s in SUPPLIERS.keys():
        lines = []
        ok = True
        for canon, qty in basket.items():
            offer = _cheapest_for_supplier(offers_map.get(canon, []), s)
            if not offer:
                ok = False
                break
            lines.append({
                "canonical": canon,
                "label": get_label(canon),
                "qty": qty,
                "unit": get_unit(canon),
                "supplier": s,
                "unit_price": offer.price_gbp,
                "line_total": qty * offer.price_gbp
            })
        if ok:
            totals = _total_for_lines(lines, {s})
            options.append({"supplier": s, "lines": lines, **totals})
    return sorted(options, key=lambda x: x["total"])[0] if options else None

def compute_local_best(basket: Dict[str,int], offers_map: Dict[str, List[Offer]]) -> Optional[dict]:
    local_suppliers = {s for s, m in SUPPLIERS.items() if m.get("local")}
    # Split across local suppliers only
    lines = []
    suppliers_used: set[str] = set()

    for canon, qty in basket.items():
        local_offers = [o for o in offers_map.get(canon, []) if o.supplier in local_suppliers]
        best = _cheapest(local_offers)
        if not best:
            # if any line can't be satisfied locally in demo, we return None
            return None
        lines.append({
            "canonical": canon,
            "label": get_label(canon),
            "qty": qty,
            "unit": get_unit(canon),
            "supplier": best.supplier,
            "unit_price": best.price_gbp,
            "line_total": qty * best.price_gbp
        })
        suppliers_used.add(best.supplier)

    totals = _total_for_lines(lines, suppliers_used)
    return {"lines": lines, "suppliers_used": suppliers_used, **totals}

def compute_insights(basket: Dict[str,int]) -> dict:
    if not basket:
        return {"split_best": None, "single_best": None, "local_best": None, "fastest": None, "headline": None, "bullets": []}

    offers_map = _offers_for_basket(basket)
    split_best = compute_split_best(basket, offers_map)
    single_best = compute_single_best(basket, offers_map)
    local_best = compute_local_best(basket, offers_map)

    # Fastest option: compare split vs local vs single (lead first, then total)
    candidates = []
    candidates.append({"type":"split", "lead_days": split_best["lead_days"], "total": split_best["total"]})
    if single_best:
        candidates.append({"type":"single", "lead_days": single_best["lead_days"], "total": single_best["total"], "supplier": single_best["supplier"]})
    if local_best:
        candidates.append({"type":"local", "lead_days": local_best["lead_days"], "total": local_best["total"]})
    fastest = sorted(candidates, key=lambda x: (x["lead_days"], x["total"]))[0] if candidates else None

    bullets: List[str] = []

    if single_best:
        diff = single_best["total"] - split_best["total"]
        if diff > 0.01:
            headline = f"Save {_fmt_gbp(diff)} by splitting your basket."
            bullets.append(f"Best split total: {_fmt_gbp(split_best['total'])} vs best single supplier: {_fmt_gbp(single_best['total'])}.")
        elif diff < -0.01:
            headline = f"Save {_fmt_gbp(-diff)} by using one supplier ({single_best['supplier']})."
            bullets.append(f"Best single supplier total: {_fmt_gbp(single_best['total'])} vs split: {_fmt_gbp(split_best['total'])}.")
        else:
            headline = "Split vs single supplier is roughly the same — choose based on delivery."
            bullets.append(f"Split: {_fmt_gbp(split_best['total'])} · Single: {_fmt_gbp(single_best['total'])}.")
    else:
        headline = "No single supplier covers every line — splitting is required (demo)."
        bullets.append(f"Best split total: {_fmt_gbp(split_best['total'])} across {len(split_best['breakdown'])} supplier(s).")

    # Local narrative
    if local_best:
        # compare local to split_best
        local_delta = local_best["total"] - split_best["total"]
        if local_delta <= 0.01:
            bullets.append(f"Local option matches/beats price: {_fmt_gbp(local_best['total'])} (support local, deliver in {local_best['lead_days']} day).")
        else:
            bullets.append(f"Buy local option: {_fmt_gbp(local_best['total'])} (only +{_fmt_gbp(local_delta)} vs best price split).")
    else:
        bullets.append("Local option not available for all items in demo (we can expand local coverage).")

    if fastest:
        if fastest["type"] == "single":
            bullets.append(f"Fastest: single supplier ({fastest['supplier']}) in {fastest['lead_days']} day(s).")
        elif fastest["type"] == "local":
            bullets.append(f"Fastest: buy local in {fastest['lead_days']} day(s).")
        else:
            bullets.append(f"Fastest: split order in {fastest['lead_days']} day(s).")

    return {
        "split_best": split_best,
        "single_best": single_best,
        "local_best": local_best,
        "fastest": fastest,
        "headline": headline,
        "bullets": bullets
    }

@app.get("/", response_class=HTMLResponse)
def home(request: Request, q: str = ""):
    offers = search_offers(q) if q else []
    grouped: Dict[str, List[Offer]] = {}
    for o in offers:
        grouped.setdefault(o.supplier, []).append(o)
    for s in grouped:
        grouped[s] = sorted(grouped[s], key=lambda x: x.price_gbp)

    basket = _basket(request)
    return templates.TemplateResponse("index.html", {
        "request": request,
        "q": q,
        "grouped": grouped,
        "suppliers_meta": SUPPLIERS,
        "basket_count": sum(basket.values()),
        "label_for": get_label,
        "unit_for": get_unit,
    })

@app.post("/add")
def add_to_basket(request: Request, canonical: str = Form(...), qty: int = Form(1), return_to: str = Form("/")):
    _add_item(request, canonical, max(1, int(qty)))
    return RedirectResponse(url=return_to, status_code=303)

@app.get("/basket", response_class=HTMLResponse)
def basket_view(request: Request):
    basket = _basket(request)
    lines = [{"canonical": c, "label": get_label(c), "qty": q, "unit": get_unit(c)} for c, q in basket.items()]
    insights = compute_insights(basket)
    return templates.TemplateResponse("basket.html", {
        "request": request,
        "basket_lines": lines,
        "insights": insights,
        "gbp": _fmt_gbp,
        "suppliers_meta": SUPPLIERS
    })

@app.post("/remove")
def remove(request: Request, canonical: str = Form(...)):
    _remove_item(request, canonical)
    return RedirectResponse(url="/basket", status_code=303)

@app.post("/clear")
def clear(request: Request):
    _clear(request)
    return RedirectResponse(url="/basket", status_code=303)
EOF

# -----------------------
# 3) Copywriting + layout (home)
# -----------------------
cat > app/templates/index.html <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Material Compare (Demo)</title>
  <link rel="stylesheet" href="/static/style.css" />
</head>
<body>
  <header class="topbar">
    <div class="brand">
      <div class="logo">MC</div>
      <div>
        <div class="title">Material Compare</div>
        <div class="subtitle">Compare UK suppliers · smart basket insights · buy local when it makes sense</div>
      </div>
    </div>
    <a class="basket" href="/basket">Basket <span class="pill">{{ basket_count }}</span></a>
  </header>

  <main class="wrap">
    <section class="hero">
      <div class="hero-left">
        <div class="tag">Investor demo · mocked pricing</div>
        <h1>Stop overpaying for materials.</h1>
        <p class="lead">
          Search common items (3x2, sheets, screws) and we’ll show the best price, delivery and
          whether splitting the basket saves money — plus a “buy local” option.
        </p>

        <div class="bullets">
          <div class="bullet"><span class="dot"></span><span><strong>Smart basket:</strong> cheapest single supplier vs cheapest split order</span></div>
          <div class="bullet"><span class="dot"></span><span><strong>Delivery-aware:</strong> includes delivery + lead time in totals</span></div>
          <div class="bullet"><span class="dot"></span><span><strong>Buy local:</strong> show a local trade option (where available)</span></div>
        </div>

        <div class="trust">
          Built for UK builders & site teams. Familiar supplier view, fast comparisons, clear totals.
        </div>
      </div>

      <div class="hero-right card">
        <h2>Search materials</h2>
        <p class="muted">Examples: <span class="chip">3x2</span> <span class="chip">4x2</span> <span class="chip">osb</span> <span class="chip">mdf</span> <span class="chip">pdf</span> <span class="chip">screws</span></p>

        <form method="get" action="/" class="search">
          <input name="q" value="{{ q }}" placeholder="Try: 3x2, OSB 18, MDF, pdf, screws, 5x80..." />
          <button type="submit">Compare</button>
        </form>

        <div class="mini">
          <div class="mini-row"><span class="mini-k">Why it matters</span><span class="mini-v">Most jobs lose time + margin on procurement.</span></div>
          <div class="mini-row"><span class="mini-k">What we fix</span><span class="mini-v">Split baskets, delivery costs, and local options.</span></div>
        </div>
      </div>
    </section>

    {% if q and not grouped %}
      <section class="card">
        <h2>No results</h2>
        <p class="muted">This is a demo matcher. Try “screws”, “3x2”, “osb”, “mdf”, “pdf”, or add sizes like “OSB 18”.</p>
      </section>
    {% endif %}

    {% if grouped %}
      <section class="results-head">
        <h2>Results for “{{ q }}”</h2>
        <p class="muted">Add items from multiple suppliers, then open Basket for split vs single supplier savings.</p>
      </section>

      <section class="grid">
        {% for supplier, offers in grouped.items() %}
          <div class="card">
            <div class="supplier-head">
              <div>
                <h3>{{ supplier }}</h3>
                <div class="muted small">
                  {{ suppliers_meta[supplier].type }}{% if suppliers_meta[supplier].local %} · Local{% endif %}
                  · Delivery £{{ '%.2f'|format(suppliers_meta[supplier].delivery_gbp) }}
                  · Lead {{ suppliers_meta[supplier].lead_days }} day(s)
                </div>
              </div>
              <div class="badge">Demo</div>
            </div>

            <div class="muted small" style="margin-top:6px;">{{ suppliers_meta[supplier].copy }}</div>

            <table class="table">
              <thead>
                <tr>
                  <th>Item</th>
                  <th class="right">Unit</th>
                  <th class="right">Price</th>
                  <th class="right">Add</th>
                </tr>
              </thead>
              <tbody>
                {% for o in offers %}
                  <tr>
                    <td>
                      <div class="item-title">{{ label_for(o.canonical) }}</div>
                      <div class="muted small">{{ o.title }}</div>
                    </td>
                    <td class="right">{{ o.unit }}</td>
                    <td class="right">£{{ '%.2f'|format(o.price_gbp) }}</td>
                    <td class="right">
                      <form method="post" action="/add" class="addform">
                        <input type="hidden" name="canonical" value="{{ o.canonical }}" />
                        <input type="hidden" name="return_to" value="/?q={{ q | urlencode }}" />
                        <input class="qty" type="number" name="qty" value="1" min="1" />
                        <button type="submit">Add</button>
                      </form>
                    </td>
                  </tr>
                {% endfor %}
              </tbody>
            </table>

            <div class="note">
              <strong>Pro tip:</strong> Add timber + sheet + screws to see a clear split-basket saving in Basket.
            </div>
          </div>
        {% endfor %}
      </section>
    {% endif %}

    <section class="footer-copy">
      <div class="footer-card">
        <h3>What makes this valuable</h3>
        <p class="muted">
          Builders don’t just need “cheapest price” — they need the cheapest <strong>delivered</strong> basket,
          with the right lead time and the option to keep spend local.
        </p>
      </div>
      <div class="footer-card">
        <h3>Next step after demo</h3>
        <p class="muted">
          Replace demo pricing with live feeds (APIs/merchant integrations), add postcode-based delivery logic,
          and expand catalog coverage (sheet sizes, insulation, plasterboard, fixings, sealants).
        </p>
      </div>
    </section>
  </main>
</body>
</html>
EOF

# -----------------------
# 4) Basket page copy + Local option display
# -----------------------
cat > app/templates/basket.html <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Basket · Material Compare (Demo)</title>
  <link rel="stylesheet" href="/static/style.css" />
</head>
<body>
  <header class="topbar">
    <div class="brand">
      <div class="logo">MC</div>
      <div>
        <div class="title">Basket</div>
        <div class="subtitle">Smart insights · delivery-aware totals · buy local option</div>
      </div>
    </div>
    <a class="basket" href="/">Back to search</a>
  </header>

  <main class="wrap">
    <section class="card">
      <h2>Your basket</h2>

      {% if not basket_lines %}
        <p class="muted">Basket is empty. Go back and add timber/sheets/screws.</p>
      {% else %}
        <table class="table">
          <thead>
            <tr>
              <th>Item</th>
              <th class="right">Qty</th>
              <th class="right">Unit</th>
              <th class="right">Remove</th>
            </tr>
          </thead>
          <tbody>
            {% for line in basket_lines %}
              <tr>
                <td>{{ line.label }}</td>
                <td class="right">{{ line.qty }}</td>
                <td class="right">{{ line.unit }}</td>
                <td class="right">
                  <form method="post" action="/remove">
                    <input type="hidden" name="canonical" value="{{ line.canonical }}" />
                    <button type="submit" class="btn-danger">Remove</button>
                  </form>
                </td>
              </tr>
            {% endfor %}
          </tbody>
        </table>

        <form method="post" action="/clear" style="margin-top:12px;">
          <button type="submit" class="btn-ghost">Clear basket</button>
        </form>
      {% endif %}
    </section>

    {% if insights and basket_lines %}
      <section class="insight card">
        <h2>{{ insights.headline }}</h2>
        <ul class="insight-list">
          {% for b in insights.bullets %}
            <li>{{ b }}</li>
          {% endfor %}
        </ul>
      </section>

      <section class="grid-2">
        <div class="card">
          <h3>Totals comparison</h3>

          <div class="kpis">
            <div class="kpi">
              <div class="kpi-label">Best split basket</div>
              <div class="kpi-value">{{ gbp(insights.split_best.total) }}</div>
              <div class="muted small">Delivery {{ gbp(insights.split_best.delivery_total) }} · Lead {{ insights.split_best.lead_days }} day(s)</div>
            </div>

            {% if insights.single_best %}
            <div class="kpi">
              <div class="kpi-label">Best single supplier</div>
              <div class="kpi-value">{{ gbp(insights.single_best.total) }}</div>
              <div class="muted small">{{ insights.single_best.supplier }} · Delivery {{ gbp(insights.single_best.delivery_total) }} · Lead {{ insights.single_best.lead_days }} day(s)</div>
            </div>
            {% else %}
            <div class="kpi">
              <div class="kpi-label">Best single supplier</div>
              <div class="kpi-value">N/A</div>
              <div class="muted small">No single supplier covers all lines (demo)</div>
            </div>
            {% endif %}

            {% if insights.local_best %}
            <div class="kpi">
              <div class="kpi-label">Buy local option</div>
              <div class="kpi-value">{{ gbp(insights.local_best.total) }}</div>
              <div class="muted small">Delivery {{ gbp(insights.local_best.delivery_total) }} · Lead {{ insights.local_best.lead_days }} day(s)</div>
            </div>
            {% endif %}
          </div>

          {% if insights.fastest %}
            <div class="note">
              <strong>Fastest option:</strong>
              {% if insights.fastest.type == 'single' %}
                Single supplier ({{ insights.fastest.supplier }})
              {% elif insights.fastest.type == 'local' %}
                Buy local option
              {% else %}
                Split basket
              {% endif %}
              · {{ insights.fastest.lead_days }} day(s) · Total {{ gbp(insights.fastest.total) }}
            </div>
          {% endif %}
        </div>

        <div class="card">
          <h3>Split basket breakdown</h3>

          {% for supplier, block in insights.split_best.breakdown.items() %}
            <div class="split-block">
              <div class="split-head">
                <div>
                  <strong>{{ supplier }}</strong>
                  <span class="muted">· Delivery {{ gbp(block.delivery) }} · Lead {{ block.lead_days }} day(s)</span>
                </div>
              </div>
              <ul class="lines">
                {% for l in block.lines %}
                  <li>
                    <span>{{ l.label }} × {{ l.qty }}</span>
                    <span class="muted">{{ gbp(l.line_total) }}</span>
                  </li>
                {% endfor %}
              </ul>
              <div class="split-foot">
                <span>Items total</span><span>{{ gbp(block.items_total) }}</span>
              </div>
            </div>
          {% endfor %}

          <div class="split-total">
            <div><strong>Split total</strong></div>
            <div><strong>{{ gbp(insights.split_best.total) }}</strong></div>
          </div>
        </div>
      </section>
    {% endif %}
  </main>
</body>
</html>
EOF

# -----------------------
# 5) White Screwfix-style UI
# -----------------------
cat > app/static/style.css <<'EOF'
:root{
  --bg:#ffffff;
  --card:#ffffff;
  --muted:#5f6368;
  --text:#111827;
  --line:#e5e7eb;
  --soft:#f5f6f8;
  --accent:#2563eb;
  --accent2:#0ea5e9;
  --danger:#dc2626;
}

*{box-sizing:border-box}
body{
  margin:0;
  font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Inter,Helvetica,Arial,sans-serif;
  background:var(--bg);
  color:var(--text);
}

a{color:inherit;text-decoration:none}

.wrap{max-width:1160px;margin:0 auto;padding:18px}

.topbar{
  display:flex;align-items:center;justify-content:space-between;
  padding:14px 18px;
  border-bottom:1px solid var(--line);
  background:#fff;
  position:sticky;top:0;z-index:10;
}

.brand{display:flex;gap:12px;align-items:center}
.logo{
  width:38px;height:38px;border-radius:10px;
  background:var(--accent);
  color:#fff;font-weight:900;
  display:flex;align-items:center;justify-content:center;
}
.title{font-weight:900;letter-spacing:.2px}
.subtitle{font-size:12px;color:var(--muted);margin-top:2px}

.basket{
  display:flex;gap:10px;align-items:center;
  padding:10px 12px;border:1px solid var(--line);
  border-radius:12px;background:#fff;
}
.pill{
  min-width:28px;text-align:center;
  padding:3px 8px;border-radius:999px;
  background:var(--soft);border:1px solid var(--line);
  color:var(--text);font-weight:800;
}

.card{
  background:var(--card);
  border:1px solid var(--line);
  border-radius:14px;
  padding:16px;
}

.hero{
  display:grid;
  grid-template-columns: 1.25fr .9fr;
  gap:14px;
  margin-top:14px;
}
@media (max-width: 980px){ .hero{grid-template-columns:1fr} }

.tag{
  display:inline-flex;align-items:center;
  padding:6px 10px;border-radius:999px;
  background:var(--soft);border:1px solid var(--line);
  font-size:12px;color:var(--muted);
  margin-bottom:10px;
}
h1{margin:0 0 10px;font-size:34px;letter-spacing:-.02em}
h2{margin:0 0 10px;font-size:18px}
h3{margin:0 0 10px;font-size:16px}
.lead{color:var(--muted);font-size:15px;line-height:1.5;margin:0 0 12px}

.bullets{display:flex;flex-direction:column;gap:10px;margin-top:8px}
.bullet{display:flex;gap:10px;align-items:flex-start;color:var(--text)}
.dot{width:10px;height:10px;border-radius:999px;background:var(--accent2);margin-top:6px;flex:0 0 auto}
.trust{margin-top:12px;color:var(--muted);font-size:13px}

.search{display:flex;gap:10px;margin-top:10px}
.search input{
  flex:1;padding:12px 12px;border-radius:12px;border:1px solid var(--line);
  background:#fff;color:var(--text);
}
button{
  padding:10px 12px;border-radius:12px;border:1px solid var(--line);
  background:var(--accent);color:#fff;cursor:pointer;font-weight:800;
}
button:hover{filter:brightness(0.98)}
.btn-ghost{background:#fff;color:var(--text);border:1px solid var(--line)}
.btn-danger{background:var(--danger);color:#fff;border:1px solid #b91c1c}

.muted{color:var(--muted)}
.small{font-size:12px}

.chip{
  display:inline-block;padding:5px 10px;border-radius:999px;
  border:1px solid var(--line);background:var(--soft);
  margin-right:6px;font-size:12px;color:var(--text);
}

.results-head{margin-top:14px}
.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:14px;margin-top:12px}
.grid-2{display:grid;grid-template-columns:repeat(2,1fr);gap:14px;margin-top:14px}
@media (max-width: 980px){.grid,.grid-2{grid-template-columns:1fr}}

.supplier-head{display:flex;align-items:flex-start;justify-content:space-between;gap:10px}
.badge{
  font-size:12px;padding:6px 10px;border-radius:999px;
  border:1px solid var(--line);background:var(--soft);color:var(--muted)
}

.table{width:100%;border-collapse:collapse;margin-top:10px}
.table th,.table td{padding:10px 8px;border-bottom:1px solid var(--line);vertical-align:top}
.table th{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.right{text-align:right}
.item-title{font-weight:900}
.addform{display:flex;gap:8px;justify-content:flex-end;align-items:center}
.qty{
  width:62px;padding:8px;border-radius:10px;border:1px solid var(--line);
  background:#fff;color:var(--text);text-align:right;
}

.note{
  margin-top:12px;padding:10px 12px;border-radius:12px;
  border:1px dashed #c7d2fe;background:#eef2ff;color:#1e3a8a;
}

.mini{margin-top:12px;border-top:1px solid var(--line);padding-top:12px}
.mini-row{display:flex;justify-content:space-between;gap:10px;padding:6px 0}
.mini-k{color:var(--muted);font-size:12px}
.mini-v{font-weight:700;font-size:12px}

.insight{margin-top:14px;background:#f8fafc}
.insight-list{margin:8px 0 0 18px;color:var(--muted)}
.kpis{display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-top:12px}
@media (max-width: 700px){.kpis{grid-template-columns:1fr}}
.kpi{padding:12px;border-radius:12px;border:1px solid var(--line);background:#fff}
.kpi-label{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.kpi-value{font-size:22px;font-weight:1000;margin-top:6px}

.split-block{margin-top:10px;padding:12px;border-radius:12px;border:1px solid var(--line);background:#fff}
.split-head{display:flex;justify-content:space-between;gap:10px;margin-bottom:8px}
.lines{list-style:none;margin:0;padding:0}
.lines li{display:flex;justify-content:space-between;gap:10px;padding:6px 0;border-bottom:1px solid var(--line)}
.lines li:last-child{border-bottom:none}
.split-foot{display:flex;justify-content:space-between;gap:10px;margin-top:8px;color:var(--muted)}
.split-total{display:flex;justify-content:space-between;gap:10px;margin-top:12px;padding-top:10px;border-top:1px solid var(--line)}

.footer-copy{display:grid;grid-template-columns:repeat(2,1fr);gap:14px;margin:18px 0}
@media (max-width: 980px){.footer-copy{grid-template-columns:1fr}}
.footer-card{border:1px solid var(--line);border-radius:14px;padding:14px;background:var(--soft)}
EOF

echo "✅ Upgrade applied. Restart uvicorn now."
echo "If uvicorn is running: CTRL+C then run:"
echo "source .venv/bin/activate && python -m uvicorn app.main:app --reload --port 8000"

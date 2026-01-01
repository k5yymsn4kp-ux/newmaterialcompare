#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/suppliers app/templates app/static
touch app/__init__.py app/suppliers/__init__.py

cat > requirements.txt <<'EOF'
fastapi==0.115.6
uvicorn[standard]==0.32.1
jinja2==3.1.4
python-multipart==0.0.12
EOF

cat > app/suppliers/demo.py <<'EOF'
from __future__ import annotations
from dataclasses import dataclass
from typing import Dict, List, Optional
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

SUPPLIERS = {
    "Screwfix":    {"delivery_gbp": 6.99, "lead_days": 1},
    "Toolstation": {"delivery_gbp": 5.99, "lead_days": 2},
    "Jewson":      {"delivery_gbp": 22.50, "lead_days": 3},
    "MKM":         {"delivery_gbp": 18.00, "lead_days": 3},
}

CATALOG: Dict[str, Dict] = {
    "timber_cls_3x2_2.4m": {"unit":"each", "label":"CLS Timber 3x2 (38x63) 2.4m"},
    "timber_cls_4x2_2.4m": {"unit":"each", "label":"CLS Timber 4x2 (38x89) 2.4m"},
    "sheet_osb_18_2440x1220": {"unit":"sheet","label":"OSB3 18mm 2440x1220"},
    "sheet_mdf_18_2440x1220": {"unit":"sheet","label":"MDF 18mm 2440x1220"},
    "sheet_ply_18_2440x1220": {"unit":"sheet","label":"Plywood 18mm 2440x1220"},
    "fix_screws_5x80_200": {"unit":"box","label":"Wood Screws 5x80mm (Box 200)"},
    "fix_screws_4x40_200": {"unit":"box","label":"Wood Screws 4x40mm (Box 200)"},
}

OFFERS: List[Offer] = [
    Offer("SF-CLS32-24", "timber_cls_3x2_2.4m", "CLS 38x63mm 2.4m", "Screwfix", "each", 3.25),
    Offer("TS-CLS32-24", "timber_cls_3x2_2.4m", "CLS Timber 38x63 2.4m", "Toolstation", "each", 3.10),
    Offer("JW-CLS32-24", "timber_cls_3x2_2.4m", "C16 CLS 38x63 2.4m", "Jewson", "each", 3.55),
    Offer("MKM-CLS32-24","timber_cls_3x2_2.4m", "CLS 38x63 C16 2.4m", "MKM", "each", 3.35),

    Offer("SF-CLS42-24", "timber_cls_4x2_2.4m", "CLS 38x89mm 2.4m", "Screwfix", "each", 4.90),
    Offer("TS-CLS42-24", "timber_cls_4x2_2.4m", "CLS Timber 38x89 2.4m", "Toolstation", "each", 4.70),
    Offer("JW-CLS42-24", "timber_cls_4x2_2.4m", "C16 CLS 38x89 2.4m", "Jewson", "each", 5.20),
    Offer("MKM-CLS42-24","timber_cls_4x2_2.4m", "CLS 38x89 C16 2.4m", "MKM", "each", 5.05),

    Offer("SF-OSB18-8x4","sheet_osb_18_2440x1220", "OSB3 18mm 2440x1220", "Screwfix", "sheet", 21.99),
    Offer("TS-OSB18-8x4","sheet_osb_18_2440x1220", "OSB3 18mm 8x4", "Toolstation", "sheet", 20.75),
    Offer("JW-OSB18-8x4","sheet_osb_18_2440x1220", "OSB3 18mm 2440x1220", "Jewson", "sheet", 24.50),
    Offer("MKM-OSB18-8x4","sheet_osb_18_2440x1220", "OSB3 18mm 2440x1220", "MKM", "sheet", 23.80),

    Offer("SF-MDF18-8x4","sheet_mdf_18_2440x1220", "MDF 18mm 2440x1220", "Screwfix", "sheet", 28.49),
    Offer("TS-MDF18-8x4","sheet_mdf_18_2440x1220", "MDF 18mm 8x4", "Toolstation", "sheet", 27.25),
    Offer("JW-MDF18-8x4","sheet_mdf_18_2440x1220", "MDF 18mm 2440x1220", "Jewson", "sheet", 31.00),
    Offer("MKM-MDF18-8x4","sheet_mdf_18_2440x1220", "MDF 18mm 2440x1220", "MKM", "sheet", 29.90),

    Offer("SF-PLY18-8x4","sheet_ply_18_2440x1220", "Plywood 18mm 2440x1220", "Screwfix", "sheet", 39.99),
    Offer("TS-PLY18-8x4","sheet_ply_18_2440x1220", "Plywood 18mm 8x4", "Toolstation", "sheet", 38.50),
    Offer("JW-PLY18-8x4","sheet_ply_18_2440x1220", "Plywood 18mm 2440x1220", "Jewson", "sheet", 44.00),
    Offer("MKM-PLY18-8x4","sheet_ply_18_2440x1220", "Plywood 18mm 2440x1220", "MKM", "sheet", 42.75),

    Offer("SF-SCR580-200","fix_screws_5x80_200", "Wood Screws 5x80mm (200)", "Screwfix", "box", 12.99),
    Offer("TS-SCR580-200","fix_screws_5x80_200", "Wood Screws 5x80 (200)", "Toolstation", "box", 11.49),
    Offer("JW-SCR580-200","fix_screws_5x80_200", "Wood Screws 5x80mm (200)", "Jewson", "box", 14.25),
    Offer("MKM-SCR580-200","fix_screws_5x80_200", "Wood Screws 5x80mm (200)", "MKM", "box", 13.60),

    Offer("SF-SCR440-200","fix_screws_4x40_200", "Wood Screws 4x40mm (200)", "Screwfix", "box", 9.49),
    Offer("TS-SCR440-200","fix_screws_4x40_200", "Wood Screws 4x40 (200)", "Toolstation", "box", 8.79),
    Offer("JW-SCR440-200","fix_screws_4x40_200", "Wood Screws 4x40mm (200)", "Jewson", "box", 10.50),
    Offer("MKM-SCR440-200","fix_screws_4x40_200", "Wood Screws 4x40mm (200)", "MKM", "box", 10.10),
]

def _norm(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9x ]+", " ", s)
    s = re.sub(r"\s+", " ", s)
    return s

def canonicalise(q: str) -> Optional[str]:
    t = _norm(q)
    if ("3x2" in t or "38x63" in t) and ("2.4" in t or "2400" in t or "2 4" in t): return "timber_cls_3x2_2.4m"
    if ("4x2" in t or "38x89" in t) and ("2.4" in t or "2400" in t or "2 4" in t): return "timber_cls_4x2_2.4m"
    if "osb" in t and "18" in t: return "sheet_osb_18_2440x1220"
    if "mdf" in t and "18" in t: return "sheet_mdf_18_2440x1220"
    if ("ply" in t or "plywood" in t) and "18" in t: return "sheet_ply_18_2440x1220"
    if "5x80" in t or ("screw" in t and "5" in t and "80" in t): return "fix_screws_5x80_200"
    if "4x40" in t or ("screw" in t and "4" in t and "40" in t): return "fix_screws_4x40_200"
    return None

def search_offers(q: str) -> List[Offer]:
    canon = canonicalise(q)
    if not canon: return []
    return [o for o in OFFERS if o.canonical == canon and o.in_stock]

def get_label(canonical: str) -> str:
    return CATALOG.get(canonical, {}).get("label", canonical)

def get_unit(canonical: str) -> str:
    return CATALOG.get(canonical, {}).get("unit", "each")
EOF

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

def _add(request: Request, canonical: str, qty: int) -> None:
    b = _basket(request)
    b[canonical] = int(b.get(canonical, 0)) + int(qty)
    request.session["basket"] = b

def _remove(request: Request, canonical: str) -> None:
    b = _basket(request)
    b.pop(canonical, None)
    request.session["basket"] = b

def _clear(request: Request) -> None:
    request.session["basket"] = {}

def _fmt(x: float) -> str:
    return f"£{x:,.2f}"

def _offers_for_basket(basket: Dict[str,int]) -> Dict[str, List[Offer]]:
    out: Dict[str, List[Offer]] = {}
    for canon in basket.keys():
        out[canon] = [o for o in search_offers(get_label(canon)) if o.canonical == canon]
    return out

def _cheapest(offers: List[Offer]) -> Optional[Offer]:
    return sorted(offers, key=lambda o: o.price_gbp)[0] if offers else None

def _cheapest_for_supplier(offers: List[Offer], supplier: str) -> Optional[Offer]:
    xs = [o for o in offers if o.supplier == supplier]
    return _cheapest(xs)

def compute_insights(basket: Dict[str,int]) -> Dict:
    if not basket: return {"split_best": None, "single_best": None, "fastest": None, "msg": None}
    offers_map = _offers_for_basket(basket)

    # Split best
    split_lines = []
    suppliers_used = set()
    for canon, qty in basket.items():
        best = _cheapest(offers_map.get(canon, []))
        if not best: continue
        split_lines.append((canon, qty, best))
        suppliers_used.add(best.supplier)
    split_items = sum(qty * o.price_gbp for _, qty, o in split_lines)
    split_delivery = sum(SUPPLIERS[s]["delivery_gbp"] for s in suppliers_used)
    split_total = split_items + split_delivery
    split_lead = max((SUPPLIERS[s]["lead_days"] for s in suppliers_used), default=0)

    breakdown = {s: {"delivery": SUPPLIERS[s]["delivery_gbp"], "lead_days": SUPPLIERS[s]["lead_days"], "items_total": 0.0, "lines": []} for s in suppliers_used}
    for canon, qty, o in split_lines:
        breakdown[o.supplier]["items_total"] += qty * o.price_gbp
        breakdown[o.supplier]["lines"].append({"label": get_label(canon), "qty": qty, "line_total": qty * o.price_gbp})

    split_best = {"total": split_total, "lead_days": split_lead, "breakdown": breakdown}

    # Single best
    single_options = []
    for s in SUPPLIERS.keys():
        ok = True
        items_total = 0.0
        for canon, qty in basket.items():
            offer = _cheapest_for_supplier(offers_map.get(canon, []), s)
            if not offer:
                ok = False
                break
            items_total += qty * offer.price_gbp
        if ok:
            total = items_total + SUPPLIERS[s]["delivery_gbp"]
            single_options.append({"supplier": s, "total": total, "lead_days": SUPPLIERS[s]["lead_days"]})
    single_best = sorted(single_options, key=lambda x: x["total"])[0] if single_options else None

    if single_best:
        diff = single_best["total"] - split_best["total"]
        msg = f"Save {_fmt(diff)} by splitting across suppliers." if diff > 0.01 else (
              f"Save {_fmt(-diff)} by ordering from one supplier ({single_best['supplier']})." if diff < -0.01 else
              "Split vs single supplier is roughly the same cost.")
    else:
        msg = "No single supplier covers every line in your basket (demo). Splitting is required."

    # Fastest
    fastest = {"type":"split", "lead_days": split_best["lead_days"], "total": split_best["total"]}
    if single_best and (single_best["lead_days"], single_best["total"]) < (fastest["lead_days"], fastest["total"]):
        fastest = {"type":"single", "supplier": single_best["supplier"], "lead_days": single_best["lead_days"], "total": single_best["total"]}

    return {"split_best": split_best, "single_best": single_best, "fastest": fastest, "msg": msg}

@app.get("/", response_class=HTMLResponse)
def home(request: Request, q: str = ""):
    offers = search_offers(q) if q else []
    grouped = {}
    for o in offers:
        grouped.setdefault(o.supplier, []).append(o)
    for s in grouped:
        grouped[s] = sorted(grouped[s], key=lambda x: x.price_gbp)

    basket = _basket(request)
    return templates.TemplateResponse("index.html", {
        "request": request,
        "q": q,
        "grouped": grouped,
        "suppliers": SUPPLIERS,
        "basket_count": sum(basket.values()),
        "label_for": get_label,
    })

@app.post("/add")
def add(request: Request, canonical: str = Form(...), qty: int = Form(1), return_to: str = Form("/")):
    _add(request, canonical, max(1, int(qty)))
    return RedirectResponse(url=return_to, status_code=303)

@app.get("/basket", response_class=HTMLResponse)
def basket_view(request: Request):
    basket = _basket(request)
    lines = [{"canonical": c, "label": get_label(c), "qty": q, "unit": get_unit(c)} for c, q in basket.items()]
    insights = compute_insights(basket)
    return templates.TemplateResponse("basket.html", {"request": request, "lines": lines, "insights": insights, "fmt": _fmt})

@app.post("/remove")
def remove(request: Request, canonical: str = Form(...)):
    _remove(request, canonical)
    return RedirectResponse(url="/basket", status_code=303)

@app.post("/clear")
def clear(request: Request):
    _clear(request)
    return RedirectResponse(url="/basket", status_code=303)
EOF

cat > app/templates/index.html <<'EOF'
<!doctype html><html><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Material Compare (Demo)</title><link rel="stylesheet" href="/static/style.css">
</head><body>
<header class="topbar">
  <div class="brand"><div class="logo">MC</div>
    <div><div class="title">Material Compare</div><div class="subtitle">Demo UK materials comparison</div></div>
  </div>
  <a class="basket" href="/basket">Basket <span class="pill">{{ basket_count }}</span></a>
</header>

<main class="wrap">
  <section class="card">
    <h1>Search materials</h1>
    <p class="muted">Try: <span class="chip">3x2 2.4</span> <span class="chip">OSB 18</span> <span class="chip">5x80 screws</span></p>
    <form method="get" action="/" class="search">
      <input name="q" value="{{ q }}" placeholder="e.g. 4x2 2.4m, OSB 18mm, 5x80 screws...">
      <button type="submit">Compare</button>
    </form>
  </section>

  {% if q and not grouped %}
  <section class="card"><h2>No results</h2><p class="muted">Demo matcher. Use the example searches above.</p></section>
  {% endif %}

  {% if grouped %}
  <section class="grid">
    {% for supplier, offers in grouped.items() %}
    <div class="card">
      <div class="supplier-head">
        <div><h2>{{ supplier }}</h2>
          <div class="muted">Delivery £{{ '%.2f'|format(suppliers[supplier].delivery_gbp) }} · Lead {{ suppliers[supplier].lead_days }} day(s)</div>
        </div>
        <div class="badge">Demo</div>
      </div>

      <table class="table">
        <thead><tr><th>Item</th><th class="right">Unit</th><th class="right">Price</th><th class="right">Add</th></tr></thead>
        <tbody>
          {% for o in offers %}
          <tr>
            <td><div class="item-title">{{ label_for(o.canonical) }}</div><div class="muted small">{{ o.title }}</div></td>
            <td class="right">{{ o.unit }}</td>
            <td class="right">£{{ '%.2f'|format(o.price_gbp) }}</td>
            <td class="right">
              <form method="post" action="/add" class="addform">
                <input type="hidden" name="canonical" value="{{ o.canonical }}">
                <input type="hidden" name="return_to" value="/?q={{ q|urlencode }}">
                <input class="qty" type="number" name="qty" value="1" min="1">
                <button type="submit">Add</button>
              </form>
            </td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
      <div class="note"><strong>Tip:</strong> Add a few items then open Basket for split vs single insights.</div>
    </div>
    {% endfor %}
  </section>
  {% endif %}
</main>
</body></html>
EOF

cat > app/templates/basket.html <<'EOF'
<!doctype html><html><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Basket · Material Compare</title><link rel="stylesheet" href="/static/style.css">
</head><body>
<header class="topbar">
  <div class="brand"><div class="logo">MC</div>
    <div><div class="title">Basket</div><div class="subtitle">Smart insights (demo)</div></div>
  </div>
  <a class="basket" href="/">Back to search</a>
</header>

<main class="wrap">
  <section class="card">
    <h1>Your basket</h1>
    {% if not lines %}
      <p class="muted">Basket is empty. Go back and add a few items.</p>
    {% else %}
      <table class="table">
        <thead><tr><th>Item</th><th class="right">Qty</th><th class="right">Unit</th><th class="right">Remove</th></tr></thead>
        <tbody>
          {% for l in lines %}
          <tr>
            <td>{{ l.label }}</td><td class="right">{{ l.qty }}</td><td class="right">{{ l.unit }}</td>
            <td class="right">
              <form method="post" action="/remove">
                <input type="hidden" name="canonical" value="{{ l.canonical }}">
                <button type="submit" class="danger">Remove</button>
              </form>
            </td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
      <form method="post" action="/clear" style="margin-top:12px;"><button type="submit" class="ghost">Clear basket</button></form>
    {% endif %}
  </section>

  {% if insights and lines %}
  <section class="grid-2">
    <div class="card">
      <h2>Smart insight</h2>
      <p class="muted">{{ insights.msg }}</p>

      <div class="kpis">
        <div class="kpi">
          <div class="kpi-label">Best split total</div>
          <div class="kpi-value">{{ fmt(insights.split_best.total) }}</div>
          <div class="muted small">Lead {{ insights.split_best.lead_days }} day(s)</div>
        </div>

        {% if insights.single_best %}
        <div class="kpi">
          <div class="kpi-label">Best single supplier</div>
          <div class="kpi-value">{{ fmt(insights.single_best.total) }}</div>
          <div class="muted small">{{ insights.single_best.supplier }} · Lead {{ insights.single_best.lead_days }} day(s)</div>
        </div>
        {% else %}
        <div class="kpi">
          <div class="kpi-label">Best single supplier</div>
          <div class="kpi-value">N/A</div>
          <div class="muted small">No single supplier covers all lines (demo)</div>
        </div>
        {% endif %}
      </div>

      {% if insights.fastest %}
      <div class="note">
        <strong>Fastest option:</strong>
        {% if insights.fastest.type == 'single' %}
          Single supplier ({{ insights.fastest.supplier }})
        {% else %}
          Split order
        {% endif %}
        · {{ insights.fastest.lead_days }} day(s) · Total {{ fmt(insights.fastest.total) }}
      </div>
      {% endif %}
    </div>

    <div class="card">
      <h2>Best split breakdown</h2>
      {% for supplier, block in insights.split_best.breakdown.items() %}
        <div class="split-block">
          <div class="split-head">
            <div><strong>{{ supplier }}</strong> <span class="muted">· Lead {{ block.lead_days }} day(s)</span></div>
            <div class="muted">Delivery {{ fmt(block.delivery) }}</div>
          </div>
          <ul class="lines">
            {% for x in block.lines %}
              <li><span>{{ x.label }} × {{ x.qty }}</span><span class="muted">{{ fmt(x.line_total) }}</span></li>
            {% endfor %}
          </ul>
          <div class="split-foot"><span>Items</span><span>{{ fmt(block.items_total) }}</span></div>
        </div>
      {% endfor %}
    </div>
  </section>
  {% endif %}
</main>
</body></html>
EOF

cat > app/static/style.css <<'EOF'
:root{--bg:#0b1220;--card:#111a2e;--muted:#aab3c5;--text:#e8edf7;--line:#22304f;--accent:#5eead4;--danger:#ff6b6b}
*{box-sizing:border-box}body{margin:0;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Inter,Helvetica,Arial,sans-serif;background:linear-gradient(180deg,#070b14,#0b1220);color:var(--text)}
a{color:inherit;text-decoration:none}
.wrap{max-width:1100px;margin:0 auto;padding:18px}
.topbar{display:flex;align-items:center;justify-content:space-between;padding:14px 18px;border-bottom:1px solid var(--line);background:rgba(10,16,30,.7);backdrop-filter:blur(8px);position:sticky;top:0}
.brand{display:flex;gap:12px;align-items:center}
.logo{width:38px;height:38px;border-radius:12px;background:rgba(94,234,212,.15);border:1px solid rgba(94,234,212,.35);display:flex;align-items:center;justify-content:center;font-weight:800;color:var(--accent)}
.title{font-weight:800}
.subtitle{font-size:12px;color:var(--muted);margin-top:2px}
.basket{display:flex;gap:10px;align-items:center;padding:10px 12px;border:1px solid var(--line);border-radius:14px;background:rgba(17,26,46,.8)}
.pill{min-width:28px;text-align:center;padding:3px 8px;border-radius:999px;background:rgba(94,234,212,.15);border:1px solid rgba(94,234,212,.35);color:var(--accent);font-weight:700}
.card{background:rgba(17,26,46,.75);border:1px solid var(--line);border-radius:18px;padding:16px;box-shadow:0 10px 30px rgba(0,0,0,.25)}
.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:14px;margin-top:14px}
.grid-2{display:grid;grid-template-columns:repeat(2,1fr);gap:14px;margin-top:14px}
@media (max-width:900px){.grid,.grid-2{grid-template-columns:1fr}}
h1{margin:0 0 10px;font-size:20px}h2{margin:0 0 10px;font-size:16px}
.muted{color:var(--muted)}.small{font-size:12px}
.search{display:flex;gap:10px;margin-top:10px}
.search input{flex:1;padding:12px;border-radius:14px;border:1px solid var(--line);background:#0c1324;color:var(--text)}
button{padding:10px 12px;border-radius:14px;border:1px solid rgba(94,234,212,.35);background:rgba(94,234,212,.12);color:var(--text);cursor:pointer;font-weight:700}
button.ghost{border:1px solid var(--line);background:transparent}
button.danger{border:1px solid rgba(255,107,107,.45);background:rgba(255,107,107,.15)}
.table{width:100%;border-collapse:collapse;margin-top:10px}
.table th,.table td{padding:10px 8px;border-bottom:1px solid var(--line);vertical-align:top}
.table th{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.right{text-align:right}.item-title{font-weight:750}
.supplier-head{display:flex;align-items:flex-start;justify-content:space-between;gap:10px}
.badge{font-size:12px;padding:6px 10px;border-radius:999px;border:1px solid var(--line);background:rgba(255,255,255,.04);color:var(--muted)}
.addform{display:flex;gap:8px;justify-content:flex-end;align-items:center}
.qty{width:62px;padding:8px;border-radius:12px;border:1px solid var(--line);background:#0c1324;color:var(--text);text-align:right}
.note{margin-top:12px;padding:10px 12px;border-radius:14px;border:1px dashed rgba(94,234,212,.35);background:rgba(94,234,212,.07)}
.chip{display:inline-block;padding:5px 10px;border-radius:999px;border:1px solid var(--line);background:rgba(255,255,255,.04);margin-right:6px;font-size:12px}
.kpis{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:12px}
@media (max-width:700px){.kpis{grid-template-columns:1fr}}
.kpi{padding:12px;border-radius:16px;border:1px solid var(--line);background:rgba(255,255,255,.03)}
.kpi-label{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.kpi-value{font-size:22px;font-weight:900;margin-top:6px}
.split-block{margin-top:10px;padding:12px;border-radius:16px;border:1px solid var(--line);background:rgba(255,255,255,.03)}
.split-head{display:flex;justify-content:space-between;gap:10px;margin-bottom:8px}
.lines{list-style:none;margin:0;padding:0}
.lines li{display:flex;justify-content:space-between;gap:10px;padding:6px 0;border-bottom:1px solid rgba(34,48,79,.6)}
.lines li:last-child{border-bottom:none}
.split-foot{display:flex;justify-content:space-between;gap:10px;margin-top:8px;color:var(--muted)}
EOF

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "✅ Installed. Now run:"
echo "   source .venv/bin/activate && uvicorn app.main:app --reload --port 8000"
echo "Open: http://127.0.0.1:8000"

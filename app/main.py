from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from datetime import datetime
import uuid
import random

app = FastAPI()
app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")

VAT_RATE = 0.20

SUPPLIERS = ["Toolstation", "Screwfix", "MKM", "Jewson", "Huws Gray"]

SUPPLIER_PRICE_TYPE = {
    "Toolstation": "Online",
    "Screwfix": "Online",
    "MKM": "My account",
    "Jewson": "My account",
    "Huws Gray": "My account",
}

# -------------------------
# DEMO CATALOGUE (hundreds of items)
# -------------------------
def make_prices(category: str, base: float, rng: random.Random):
    """
    Demo realism:
    - Merchants (MKM/Jewson/Huws Gray) cheaper on timber/sheet/insulation/plaster
    - Toolstation/Screwfix cheaper on fixings/tools/consumables
    """
    # Baselines (multipliers)
    if category in ("timber", "sheet", "insulation", "drylining", "aggregates"):
        ts = base * rng.uniform(1.06, 1.18)
        sf = base * rng.uniform(1.08, 1.22)
        mkm = base * rng.uniform(0.92, 1.02)
        jew = base * rng.uniform(0.94, 1.05)
        huw = base * rng.uniform(0.90, 1.01)
    else:  # fixings/tools/consumables
        ts = base * rng.uniform(0.92, 1.03)
        sf = base * rng.uniform(0.90, 1.02)
        mkm = base * rng.uniform(1.05, 1.20)
        jew = base * rng.uniform(1.08, 1.24)
        huw = base * rng.uniform(1.04, 1.18)

    def r2(x): return float(f"{x:.2f}")
    return {
        "Toolstation": r2(ts),
        "Screwfix": r2(sf),
        "MKM": r2(mkm),
        "Jewson": r2(jew),
        "Huws Gray": r2(huw),
    }

def generate_demo_products():
    rng = random.Random(42)

    catalogue = []
    pid = 1

    # Anchor “hero” items (so search demos well)
    anchors = [
        ("timber", "CLS Timber 4x2 2.4m", 5.10),
        ("timber", "CLS Timber 3x2 2.4m", 3.95),
        ("sheet", "18mm OSB Board 2440x1220", 19.60),
        ("sheet", "18mm MDF Board 2440x1220", 28.90),
        ("sheet", "Structural Plywood 18mm 2440x1220", 35.40),
        ("fixings", "TurboGold Screws 5x80 (box 100)", 10.99),
        ("fixings", "Angle Brackets 50mm (pack 10)", 6.50),
        ("insulation", "PIR Insulation 50mm 2400x1200", 28.00),
        ("drylining", "12.5mm Plasterboard 2400x1200", 9.80),
        ("aggregates", "Building Sand Bulk Bag", 52.00),
    ]
    for cat, name, base in anchors:
        catalogue.append({
            "id": pid,
            "category": cat,
            "name": name,
            "prices": make_prices(cat, base, rng)
        })
        pid += 1

    # Build large catalogue (feels like thousands)
    specs = {
        "timber": [
            ("C16 CLS 3x2", [2.4, 3.0, 3.6, 4.8], 3.70),
            ("C16 CLS 4x2", [2.4, 3.0, 3.6, 4.8], 4.90),
            ("C24 Joist 7x2", [3.0, 3.6, 4.2, 4.8], 10.50),
            ("C24 Joist 8x2", [3.0, 3.6, 4.2, 4.8], 12.20),
        ],
        "sheet": [
            ("OSB3", [9, 11, 18], 16.50),
            ("MDF", [9, 12, 18], 22.00),
            ("Plywood Structural", [12, 18], 28.50),
            ("Chipboard Flooring T&G", [18, 22], 24.00),
        ],
        "insulation": [
            ("PIR Board", [25, 50, 75, 100], 18.00),
            ("Mineral Wool Roll", [100, 170, 200], 9.50),
            ("Acoustic Slab", [50, 75], 15.00),
        ],
        "drylining": [
            ("Plasterboard Tapered Edge", [9.5, 12.5, 15], 7.80),
            ("Moisture Resistant Board", [12.5], 10.20),
            ("Fireline Board", [12.5, 15], 11.50),
            ("Metal Stud Track 3m", [50, 70], 6.00),
        ],
        "fixings": [
            ("Wood Screws", ["4x40", "4x50", "5x80", "5x100"], 7.50),
            ("Masonry Screws", ["7.5x100", "7.5x120", "7.5x150"], 12.00),
            ("Wall Plugs (pack 100)", ["red", "brown", "blue"], 4.50),
            ("Nails (kg)", ["clout", "lost head", "galv round wire"], 6.20),
        ],
        "tools": [
            ("Diamond Blade 115mm", ["general", "tile"], 14.00),
            ("Multi-tool Blades (set)", ["wood", "metal", "mixed"], 12.50),
            ("Expanding Foam 750ml", ["gun grade", "hand held"], 7.20),
        ],
        "aggregates": [
            ("Sharp Sand Bulk Bag", [1], 50.00),
            ("Ballast Bulk Bag", [1], 52.00),
            ("Type 1 MOT Bulk Bag", [1], 54.00),
            ("Cement 25kg", [1], 6.80),
        ]
    }

    # Generate ~600 products (good enough for demo, feels big)
    # If you want more later, we can set target to 1500+.
    for cat, rows in specs.items():
        for row in rows:
            name_base, variants, base_price = row
            for v in variants:
                for pack in [1, 2, 5, 10]:
                    # Keep naming realistic
                    if cat in ("timber",):
                        if isinstance(v, (int, float)):
                            name = f"{name_base} {v}m"
                        else:
                            name = f"{name_base} {v}"
                        base = base_price * (v if isinstance(v, (int, float)) else 1.0) / 2.4
                    elif cat in ("sheet", "insulation", "drylining"):
                        if isinstance(v, (int, float)):
                            name = f"{name_base} {v}mm 2440x1220"
                        else:
                            name = f"{name_base} {v}"
                        base = base_price * (v / 12 if isinstance(v, (int, float)) else 1.0)
                    elif cat in ("fixings", "tools"):
                        name = f"{name_base} {v} (pack {pack})"
                        base = base_price * (0.85 + (pack * 0.07))
                    else:
                        name = f"{name_base}"
                        base = base_price * (0.95 + (pack * 0.03))

                    catalogue.append({
                        "id": pid,
                        "category": cat,
                        "name": name,
                        "prices": make_prices(cat, max(1.25, base), rng)
                    })
                    pid += 1

                # Stop if too big (keep it responsive for demo)
                if len(catalogue) >= 650:
                    return catalogue

    return catalogue

PRODUCTS = generate_demo_products()

# -------------------------
# In-memory state (demo)
# -------------------------
BASKET = {}
SETTINGS = {"vat_mode": "ex", "purchase_mode": "single"}
JOBS = {}

def find_product(pid: int):
    for p in PRODUCTS:
        if p["id"] == pid:
            return p
    return None

def category_list():
    cats = {}
    for p in PRODUCTS:
        cats[p["category"]] = cats.get(p["category"], 0) + 1
    # nice order
    order = ["timber", "sheet", "insulation", "drylining", "fixings", "tools", "aggregates"]
    out = []
    for c in order:
        if c in cats:
            out.append((c, cats[c]))
    # any others
    for c, n in sorted(cats.items()):
        if c not in order:
            out.append((c, n))
    return out

def search_products(q: str, cat: str = ""):
    q = (q or "").strip().lower()
    cat = (cat or "").strip().lower()

    results = PRODUCTS

    if cat:
        results = [p for p in results if p["category"] == cat]

    if q:
        results = [p for p in results if q in p["name"].lower()]

    return results[:25]

def basket_items():
    items = []
    for pid, qty in BASKET.items():
        p = find_product(int(pid))
        if p and int(qty) > 0:
            items.append({"product": p, "qty": int(qty)})
    return items

def pick_split_supplier(product):
    prices = {s: float(product["prices"][s]) for s in SUPPLIERS}
    absolute_cheapest = min(SUPPLIERS, key=lambda s: prices[s])
    abs_price = prices[absolute_cheapest]

    cat = product.get("category", "")
    merchants = ["MKM", "Jewson", "Huws Gray"]

    if cat in ("timber", "sheet", "insulation", "drylining", "aggregates"):
        best_merchant = min(merchants, key=lambda s: prices[s])
        if prices[best_merchant] <= abs_price * 1.03:
            return best_merchant
    return absolute_cheapest

def calculate_totals(vat_mode: str, purchase_mode: str):
    items = basket_items()
    any_qty = len(items) > 0

    totals_ex_single = {s: 0.0 for s in SUPPLIERS}
    split_total_ex = 0.0
    split_picks = []

    for row in items:
        p = row["product"]
        qty = row["qty"]

        for s in SUPPLIERS:
            totals_ex_single[s] += float(p["prices"][s]) * qty

        chosen = pick_split_supplier(p)
        unit_ex = float(p["prices"][chosen])
        split_total_ex += unit_ex * qty
        split_picks.append({
            "name": p["name"],
            "qty": qty,
            "supplier": chosen,
            "unit_ex": unit_ex,
            "label": SUPPLIER_PRICE_TYPE.get(chosen, "Online")
        })

    totals_inc_single = {s: t * (1 + VAT_RATE) for s, t in totals_ex_single.items()}
    split_total_inc = split_total_ex * (1 + VAT_RATE)

    totals_mode_single = totals_ex_single if vat_mode == "ex" else totals_inc_single
    split_total_mode = split_total_ex if vat_mode == "ex" else split_total_inc

    best_single_supplier = None
    best_single_total_mode = None
    if any_qty:
        best_single_supplier = min(SUPPLIERS, key=lambda s: totals_mode_single[s])
        best_single_total_mode = totals_mode_single[best_single_supplier]

    saving_split_vs_best_single = None
    if any_qty and best_single_total_mode is not None:
        saving_split_vs_best_single = best_single_total_mode - split_total_mode

    return {
        "any_qty": any_qty,
        "items": items,
        "totals_ex_single": totals_ex_single,
        "totals_inc_single": totals_inc_single,
        "split_total_ex": split_total_ex,
        "split_total_inc": split_total_inc,
        "totals_mode_single": totals_mode_single,
        "split_total_mode": split_total_mode,
        "best_single_supplier": best_single_supplier,
        "best_single_total_mode": best_single_total_mode,
        "saving_split_vs_best_single": saving_split_vs_best_single,
        "split_picks": split_picks,
    }

@app.get("/", response_class=HTMLResponse)
def home(request: Request, q: str = "", cat: str = ""):
    results = search_products(q, cat)
    cats = category_list()
    basket_count = sum(int(v) for v in BASKET.values()) if BASKET else 0

    return templates.TemplateResponse(
        "home.html",
        {
            "request": request,
            "q": q,
            "cat": cat,
            "results": results,
            "categories": cats,
            "basket_count": basket_count
        }
    )

@app.post("/basket/add")
async def basket_add(request: Request):
    form = await request.form()
    pid = int(form.get("product_id"))
    qty = int(form.get("qty", 1))
    if qty < 1:
        qty = 1
    BASKET[pid] = BASKET.get(pid, 0) + qty
    return RedirectResponse(url="/", status_code=303)

@app.post("/basket/update")
async def basket_update(request: Request):
    form = await request.form()
    SETTINGS["vat_mode"] = form.get("vat_mode", SETTINGS["vat_mode"])
    SETTINGS["purchase_mode"] = form.get("purchase_mode", SETTINGS["purchase_mode"])

    for key, val in form.items():
        if key.startswith("qty_"):
            pid = int(key.replace("qty_", ""))
            try:
                q = int(val)
            except Exception:
                q = 0
            if q <= 0:
                BASKET.pop(pid, None)
            else:
                BASKET[pid] = q

    return RedirectResponse(url="/basket", status_code=303)

@app.post("/basket/clear")
async def basket_clear(request: Request):
    BASKET.clear()
    return RedirectResponse(url="/basket", status_code=303)

@app.get("/basket", response_class=HTMLResponse)
def basket_page(request: Request):
    vat_mode = SETTINGS["vat_mode"]
    purchase_mode = SETTINGS["purchase_mode"]
    data = calculate_totals(vat_mode, purchase_mode)

    best_single_total_mode = data.get("best_single_total_mode") or 0.0
    split_total_mode = data.get("split_total_mode") or 0.0
    mode_saving = (best_single_total_mode - split_total_mode) if data.get("any_qty") else 0.0

    return templates.TemplateResponse(
        "basket.html",
        {
            "request": request,
            "vat_mode": vat_mode,
            "purchase_mode": purchase_mode,
            "suppliers": SUPPLIERS,
            "supplier_price_type": SUPPLIER_PRICE_TYPE,
            "jobs": sorted(JOBS.items(), key=lambda x: x[1]["created"], reverse=True),
            "mode_saving": mode_saving,
            **data
        }
    )

@app.post("/jobs/save")
async def jobs_save(request: Request):
    form = await request.form()
    name = (form.get("job_name") or "").strip() or "Untitled job"
    job_id = uuid.uuid4().hex[:10]
    JOBS[job_id] = {
        "name": name,
        "created": datetime.utcnow().isoformat(),
        "vat_mode": SETTINGS["vat_mode"],
        "purchase_mode": SETTINGS["purchase_mode"],
        "basket": {str(k): int(v) for k, v in BASKET.items()},
    }
    return RedirectResponse(url="/basket", status_code=303)

@app.get("/jobs/load")
def jobs_load(job_id: str):
    if job_id in JOBS:
        j = JOBS[job_id]
        SETTINGS["vat_mode"] = j["vat_mode"]
        SETTINGS["purchase_mode"] = j["purchase_mode"]
        BASKET.clear()
        for k, v in j["basket"].items():
            BASKET[int(k)] = int(v)
    return RedirectResponse(url="/basket", status_code=303)

@app.post("/jobs/delete")
async def jobs_delete(request: Request):
    form = await request.form()
    job_id = form.get("job_id")
    if job_id in JOBS:
        del JOBS[job_id]
    return RedirectResponse(url="/basket", status_code=303)

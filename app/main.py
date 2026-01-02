from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from datetime import datetime
import uuid
import random
import re
from collections import Counter

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
# DEMO CATALOGUE (hundreds)
# -------------------------
def make_prices(category: str, base: float, rng: random.Random):
    """
    Demo realism:
    - Merchants cheaper on timber/sheet/insulation/drylining/aggregates
    - Toolstation/Screwfix cheaper on fixings/tools
    """
    if category in ("timber", "sheet", "insulation", "drylining", "aggregates"):
        ts = base * rng.uniform(1.06, 1.18)
        sf = base * rng.uniform(1.08, 1.22)
        mkm = base * rng.uniform(0.92, 1.02)
        jew = base * rng.uniform(0.94, 1.05)
        huw = base * rng.uniform(0.90, 1.01)
    else:
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
        catalogue.append({"id": pid, "category": cat, "name": name, "prices": make_prices(cat, base, rng)})
        pid += 1

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
            ("ForgeFast Wood Screws", ["4x40", "4x50", "5x80", "5x100"], 7.50),
            ("Spectre Multi-Purpose Screws", ["4x40", "4x60", "4x70", "5x80"], 8.20),
            ("TurboGold Screws", ["4x40", "4x50", "5x80", "5x100"], 7.90),
            ("Masonry Screws", ["7.5x100", "7.5x120", "7.5x150"], 12.00),
            ("Wall Plugs (pack 100)", ["red", "brown", "blue"], 4.50),
            ("Angle Brackets", ["50mm", "75mm", "100mm"], 6.20),
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
        ],
    }

    for cat, rows in specs.items():
        for name_base, variants, base_price in rows:
            for v in variants:
                for pack in [1, 2, 5, 10]:
                    if cat == "timber":
                        name = f"{name_base} {v}m"
                        base = base_price * (v / 2.4)
                    elif cat in ("sheet", "insulation", "drylining"):
                        name = f"{name_base} {v}mm 2440x1220"
                        base = base_price * (v / 12)
                    elif cat in ("fixings", "tools"):
                        if re.search(r"\d(\.\d)?x\d+", str(v)):
                            name = f"{name_base} {v} (box {max(100, pack*100)})"
                            base = base_price * (0.85 + (pack * 0.07))
                        else:
                            name = f"{name_base} {v} (pack {pack})"
                            base = base_price * (0.90 + (pack * 0.06))
                    else:
                        name = f"{name_base}"
                        base = base_price * (0.95 + (pack * 0.03))

                    catalogue.append({"id": pid, "category": cat, "name": name, "prices": make_prices(cat, max(1.25, base), rng)})
                    pid += 1
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

# -------------------------
# Helpers
# -------------------------
def find_product(pid: int):
    for p in PRODUCTS:
        if p["id"] == pid:
            return p
    return None

def supplier_prices_sorted(product):
    rows = []
    for s in SUPPLIERS:
        rows.append({
            "supplier": s,
            "label": SUPPLIER_PRICE_TYPE.get(s, "Online"),
            "price": float(product["prices"][s]),
        })
    rows.sort(key=lambda r: r["price"])
    return rows

def best_and_second(product):
    rows = supplier_prices_sorted(product)
    best = rows[0]
    second = rows[1] if len(rows) > 1 else None
    saving = 0.0
    if second:
        saving = max(0.0, float(second["price"]) - float(best["price"]))
    return best, second, saving, rows

def category_list():
    cats = {}
    for p in PRODUCTS:
        cats[p["category"]] = cats.get(p["category"], 0) + 1
    order = ["timber", "sheet", "insulation", "drylining", "fixings", "tools", "aggregates"]
    out = []
    for c in order:
        if c in cats:
            out.append((c, cats[c]))
    for c, n in sorted(cats.items()):
        if c not in order:
            out.append((c, n))
    return out

def search_pool(q: str, cat: str = ""):
    q = (q or "").strip().lower()
    cat = (cat or "").strip().lower()
    results = PRODUCTS
    if cat:
        results = [p for p in results if p["category"] == cat]
    if q:
        results = [p for p in results if q in p["name"].lower()]
    return results

def parse_screw_size(name: str):
    m = re.search(r"(\d+(?:\.\d+)?)x(\d+)", name.lower())
    if not m:
        return None, None
    return float(m.group(1)), int(m.group(2))

def derive_facets(items):
    brands = Counter()
    diams = Counter()
    lengths = Counter()
    cats = Counter()

    for p in items:
        cats[p["category"]] += 1
        first = p["name"].split(" ")[0].strip()
        if first and first[0].isalpha() and len(first) <= 12:
            brands[first] += 1

        d, l = parse_screw_size(p["name"])
        if d is not None and l is not None:
            diams[str(d).rstrip("0").rstrip(".")] += 1
            lengths[str(l)] += 1

    return {
        "brands": brands.most_common(10),
        "diameters": diams.most_common(10),
        "lengths": lengths.most_common(10),
        "categories": cats.most_common(),
    }

def apply_filters(items, brand: str = "", diameter: str = "", length: str = ""):
    brand = (brand or "").strip()
    diameter = (diameter or "").strip()
    length = (length or "").strip()
    out = items

    if brand:
        out = [p for p in out if p["name"].split(" ")[0].strip() == brand]

    if diameter or length:
        filtered = []
        for p in out:
            d, l = parse_screw_size(p["name"])
            if diameter and (d is None or str(d).rstrip("0").rstrip(".") != diameter):
                continue
            if length and (l is None or str(l) != length):
                continue
            filtered.append(p)
        out = filtered

    return out

def sort_items(items, sort: str):
    if sort == "price_asc":
        return sorted(items, key=lambda p: best_and_second(p)[0]["price"])
    if sort == "price_desc":
        return sorted(items, key=lambda p: best_and_second(p)[0]["price"], reverse=True)
    if sort == "alpha":
        return sorted(items, key=lambda p: p["name"].lower())
    return items

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

def calculate_totals(vat_mode: str):
    items = basket_items()
    any_qty = len(items) > 0

    totals_ex_single = {s: 0.0 for s in SUPPLIERS}
    split_total_ex = 0.0

    for row in items:
        p = row["product"]
        qty = row["qty"]
        for s in SUPPLIERS:
            totals_ex_single[s] += float(p["prices"][s]) * qty

        chosen = pick_split_supplier(p)
        split_total_ex += float(p["prices"][chosen]) * qty

    totals_inc_single = {s: t * (1 + VAT_RATE) for s, t in totals_ex_single.items()}
    split_total_inc = split_total_ex * (1 + VAT_RATE)

    totals_mode_single = totals_ex_single if vat_mode == "ex" else totals_inc_single
    split_total_mode = split_total_ex if vat_mode == "ex" else split_total_inc

    best_single_supplier = None
    best_single_total_mode = None
    if any_qty:
        best_single_supplier = min(SUPPLIERS, key=lambda s: totals_mode_single[s])
        best_single_total_mode = totals_mode_single[best_single_supplier]

    mode_saving = 0.0
    if any_qty and best_single_total_mode is not None:
        mode_saving = best_single_total_mode - split_total_mode

    return {
        "any_qty": any_qty,
        "items": items,
        "totals_ex_single": totals_ex_single,
        "totals_inc_single": totals_inc_single,
        "totals_mode_single": totals_mode_single,
        "split_total_mode": split_total_mode,
        "best_single_supplier": best_single_supplier,
        "best_single_total_mode": best_single_total_mode,
        "mode_saving": mode_saving,
    }

# -------------------------
# Routes
# -------------------------
@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    cats = category_list()
    basket_count = sum(int(v) for v in BASKET.values()) if BASKET else 0
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "categories": cats, "basket_count": basket_count},
    )

@app.get("/search", response_class=HTMLResponse)
def search_page(
    request: Request,
    q: str = "",
    cat: str = "",
    brand: str = "",
    diameter: str = "",
    length: str = "",
    sort: str = "relevance",
):
    pool = search_pool(q, cat)
    facets = derive_facets(pool)
    filtered = apply_filters(pool, brand=brand, diameter=diameter, length=length)
    filtered = sort_items(filtered, sort)

    cards = []
    for p in filtered[:48]:
        best, second, saving, rows = best_and_second(p)
        # mark top 2 for mini table styling
        for i, r in enumerate(rows):
            r["is_best"] = (i == 0)
            r["is_second"] = (i == 1)
        cards.append({
            **p,
            "best_supplier": best["supplier"],
            "best_price": float(best["price"]),
            "best_label": best["label"],
            "second_supplier": second["supplier"] if second else "",
            "second_price": float(second["price"]) if second else 0.0,
            "save_vs_second": float(f"{saving:.2f}"),
            "mini_rows": rows[:5],  # show top 5 suppliers (we have 5 total anyway)
        })

    basket_count = sum(int(v) for v in BASKET.values()) if BASKET else 0

    return templates.TemplateResponse(
        "search.html",
        {
            "request": request,
            "q": q,
            "cat": cat,
            "brand": brand,
            "diameter": diameter,
            "length": length,
            "sort": sort,
            "basket_count": basket_count,
            "facets": facets,
            "results_total": len(filtered),
            "cards": cards,
        }
    )

@app.get("/product/{pid}", response_class=HTMLResponse)
def product_page(request: Request, pid: int):
    p = find_product(pid)
    if not p:
        return RedirectResponse(url="/search", status_code=303)

    best, second, saving, rows = best_and_second(p)
    for i, r in enumerate(rows):
        r["is_best"] = (i == 0)
        r["is_second"] = (i == 1)

    basket_count = sum(int(v) for v in BASKET.values()) if BASKET else 0

    return templates.TemplateResponse(
        "product.html",
        {
            "request": request,
            "p": p,
            "basket_count": basket_count,
            "best_supplier": best["supplier"],
            "best_price": float(best["price"]),
            "save_vs_second": float(f"{saving:.2f}"),
            "second_supplier": second["supplier"] if second else "",
            "second_price": float(second["price"]) if second else 0.0,
            "price_rows": rows,
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
    next_url = form.get("next") or "/search"
    return RedirectResponse(url=next_url, status_code=303)

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
    data = calculate_totals(vat_mode)

    return templates.TemplateResponse(
        "basket.html",
        {
            "request": request,
            "vat_mode": vat_mode,
            "purchase_mode": purchase_mode,
            "suppliers": SUPPLIERS,
            "supplier_price_type": SUPPLIER_PRICE_TYPE,
            "jobs": sorted(JOBS.items(), key=lambda x: x[1]["created"], reverse=True),
            **data,
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

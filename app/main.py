from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.sessions import SessionMiddleware
import random
import re

# --------------------------------------------------
# APP SETUP
# --------------------------------------------------

app = FastAPI()
app.add_middleware(SessionMiddleware, secret_key="dev-secret")

app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")

# --------------------------------------------------
# SUPPLIERS
# --------------------------------------------------

SUPPLIERS = [
    ("Toolstation", "Online"),
    ("Screwfix", "Online"),
    ("MKM", "My account"),
    ("Jewson", "My account"),
    ("Huws Gray", "My account"),
]

CATEGORY_TITLES = {
    "timber": "Timber & Carcassing",
    "sheet": "Sheet Materials",
    "fixings": "Fixings",
    "insulation": "Insulation",
    "drylining": "Drylining",
    "aggregates": "Aggregates",
    "tools": "Tools & Consumables",
}

# --------------------------------------------------
# DEMO PRODUCT CATALOGUE
# --------------------------------------------------

RAW_PRODUCTS = [
    {"id": 1, "category": "timber", "name": "CLS Timber 4x2 2.4m", "base": 5.10, "brand": "Generic"},
    {"id": 2, "category": "timber", "name": "CLS Timber 3x2 2.4m", "base": 3.95, "brand": "Generic"},
    {"id": 3, "category": "sheet", "name": "OSB Board 18mm 2440x1220", "base": 19.60, "brand": "Sterling"},
    {"id": 4, "category": "sheet", "name": "MDF Board 18mm 2440x1220", "base": 28.90, "brand": "Medite"},
    {"id": 5, "category": "fixings", "name": "TurboGold Screws 5x80 (box 100)", "base": 10.99, "brand": "TurboGold"},
    {"id": 6, "category": "drylining", "name": "Plasterboard 12.5mm 2400x1200", "base": 9.80, "brand": "British Gypsum"},
    {"id": 7, "category": "aggregates", "name": "Cement 25kg", "base": 6.80, "brand": "Blue Circle"},
    {"id": 8, "category": "insulation", "name": "PIR Insulation 50mm 2400x1200", "base": 28.00, "brand": "Celotex"},
]

def gen_prices(base):
    # Bias: TS/SF often higher on heavy building materials; merchants cheaper (demo)
    return {
        "Toolstation": round(base * random.uniform(1.06, 1.16), 2),
        "Screwfix": round(base * random.uniform(1.08, 1.20), 2),
        "MKM": round(base * random.uniform(0.90, 1.02), 2),
        "Jewson": round(base * random.uniform(0.93, 1.05), 2),
        "Huws Gray": round(base * random.uniform(0.88, 1.01), 2),
    }

PRODUCTS = []
for p in RAW_PRODUCTS:
    prices = gen_prices(p["base"])
    sorted_rows = sorted(prices.items(), key=lambda x: x[1])
    best_supplier, best_price = sorted_rows[0]

    mini_rows = []
    for i, (s, price) in enumerate(sorted_rows[:4]):
        label = next(l for n, l in SUPPLIERS if n == s)
        mini_rows.append({
            "supplier": s,
            "label": label,
            "price": float(price),
            "is_best": i == 0,
            "is_second": i == 1,
        })

    PRODUCTS.append({
        **p,
        "prices": prices,
        "best_supplier": best_supplier,
        "best_price": float(best_price),
        "best_label": next(l for n, l in SUPPLIERS if n == best_supplier),
        "mini_rows": mini_rows,
    })

# --------------------------------------------------
# FACETS
# --------------------------------------------------

def extract_number(pattern, text):
    m = re.search(pattern, text)
    return m.group(1) if m else None

def build_facets(items):
    brands = {}
    diameters = {}
    lengths = {}

    for p in items:
        brands[p["brand"]] = brands.get(p["brand"], 0) + 1

        # For fixings like 5x80
        d = extract_number(r"(\d+)x", p["name"])
        l = extract_number(r"x(\d+)", p["name"])
        if d:
            diameters[d] = diameters.get(d, 0) + 1
        if l:
            lengths[l] = lengths.get(l, 0) + 1

    return {
        "brands": sorted(brands.items()),
        "diameters": sorted(diameters.items(), key=lambda x: int(x[0])),
        "lengths": sorted(lengths.items(), key=lambda x: int(x[0])),
    }

# --------------------------------------------------
# BASKET (SESSION)
# --------------------------------------------------

def get_basket(request: Request):
    basket = request.session.get("basket", {})
    if not isinstance(basket, dict):
        basket = {}
    return basket

def basket_count(request: Request):
    return sum(int(v) for v in get_basket(request).values())

# --------------------------------------------------
# SEARCH HELPERS
# --------------------------------------------------

def norm(s: str) -> str:
    s = (s or "").lower().strip()
    s = re.sub(r"\s+", " ", s)
    return s

def search_products(q: str):
    qn = norm(q)
    if not qn:
        return []
    results = []
    for p in PRODUCTS:
        hay = norm(p["name"] + " " + p.get("brand", "") + " " + p.get("category", ""))
        if qn in hay:
            results.append(p)
    return results

# --------------------------------------------------
# ROUTES
# --------------------------------------------------

@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    categories = [(k, sum(1 for p in PRODUCTS if p["category"] == k)) for k in CATEGORY_TITLES.keys()]
    return templates.TemplateResponse("home.html", {
        "request": request,
        "categories": categories,
        "basket_count": basket_count(request),
    })

@app.get("/search", response_class=HTMLResponse)
def search_page(request: Request, q: str = ""):
    results = search_products(q)
    facets = build_facets(results)

    # Use the same template as category so it looks consistent
    return templates.TemplateResponse("category.html", {
        "request": request,
        "cat": "search",
        "cat_title": f"Search results for “{q}”" if q else "Search",
        "cat_intro": "Price-first results. Add quantities and compare basket totals.",
        "cards": results,
        "results_total": len(results),
        "facets": facets,
        "page": 1,
        "total_pages": 1,
        "basket_count": basket_count(request),
        "q": q,
        "brand": "",
        "diameter": "",
        "length": "",
        "sort": "relevance",
    })

@app.get("/category/{cat}", response_class=HTMLResponse)
def category_page(
    request: Request,
    cat: str,
    q: str = "",
    brand: str = "",
    diameter: str = "",
    length: str = "",
    sort: str = "relevance",
    page: int = 1,
):
    # Filter by category
    results = [p for p in PRODUCTS if p["category"] == cat]

    # Optional: light filters (brand/diam/length) so the template doesn't break
    if brand:
        results = [p for p in results if p.get("brand") == brand]

    if diameter:
        results = [p for p in results if extract_number(r"(\d+)x", p["name"]) == diameter]

    if length:
        results = [p for p in results if extract_number(r"x(\d+)", p["name"]) == length]

    facets = build_facets(results)

    return templates.TemplateResponse("category.html", {
        "request": request,
        "cat": cat,
        "cat_title": CATEGORY_TITLES.get(cat, cat.title()),
        "cat_intro": "Add quantities. Compare suppliers. Price-first for quoting.",
        "cards": results,
        "results_total": len(results),
        "facets": facets,
        "page": page,
        "total_pages": 1,
        "basket_count": basket_count(request),
        "q": q,
        "brand": brand,
        "diameter": diameter,
        "length": length,
        "sort": sort,
    })

@app.post("/basket/add")
async def basket_add(request: Request):
    form = await request.form()
    pid = str(form.get("product_id") or "")
    if not pid:
        return RedirectResponse("/basket", status_code=303)

    qty = int(form.get("qty", 1))
    if qty < 1:
        qty = 1

    basket = get_basket(request)
    basket[pid] = int(basket.get(pid, 0)) + qty
    request.session["basket"] = basket

    next_url = form.get("next") or "/basket"
    return RedirectResponse(next_url, status_code=303)

@app.get("/basket", response_class=HTMLResponse)
def basket_page(request: Request):
    basket = get_basket(request)
    items = []
    total = 0.0

    for pid, qty in basket.items():
        p = next((p for p in PRODUCTS if str(p["id"]) == str(pid)), None)
        if not p:
            continue

        qty = int(qty)
        line = float(p["best_price"]) * qty
        total += line

        items.append({
            "product": p,
            "qty": qty,
            "line_total": round(line, 2),
        })

    return templates.TemplateResponse("basket.html", {
        "request": request,
        "items": items,
        "total": round(total, 2),
        "basket_count": basket_count(request),
    })




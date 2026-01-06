from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.sessions import SessionMiddleware
import random
from app.suppliers.demo import search_offers

# --------------------------------------------------
# APP SETUP (MUST BE FIRST)
# --------------------------------------------------

app = FastAPI()

# Session basket (persists across requests)
app.add_middleware(SessionMiddleware, secret_key="dev-secret-change-me")

app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")

# --------------------------------------------------
# SUPPLIERS (DEMO LOGIC)
# --------------------------------------------------

SUPPLIERS = ["Toolstation", "Screwfix", "MKM", "Jewson", "Huws Gray"]


def generate_prices(base):
    return {
        "Toolstation": round(base * random.uniform(1.05, 1.15), 2),
        "Screwfix": round(base * random.uniform(1.07, 1.18), 2),
        "MKM": round(base * random.uniform(0.90, 1.00), 2),
        "Jewson": round(base * random.uniform(0.93, 1.05), 2),
        "Huws Gray": round(base * random.uniform(0.88, 0.98), 2),
    }


# --------------------------------------------------
# PRODUCTS (MATCH TEMPLATE EXPECTATIONS)
# --------------------------------------------------

RAW_PRODUCTS = [
    {"id": 1, "category": "timber", "name": "CLS Timber 4x2 2.4m", "base": 5.10, "brand": "Generic"},
    {"id": 2, "category": "timber", "name": "CLS Timber 3x2 2.4m", "base": 3.95, "brand": "Generic"},
    {"id": 3, "category": "sheet", "name": "OSB Board 18mm 2440x1220", "base": 19.60, "brand": "Sterling"},
    {"id": 4, "category": "sheet", "name": "MDF Board 18mm 2440x1220", "base": 28.90, "brand": "Medite"},
    {"id": 5, "category": "fixings", "name": "Wood Screws 5x80 Box 100", "base": 10.99, "brand": "Forgefix"},
]

PRODUCTS = []
for p in RAW_PRODUCTS:
    prices = generate_prices(p["base"])
    best_supplier = min(prices, key=prices.get)
    PRODUCTS.append({
        **p,
        "prices": prices,
        "best_supplier": best_supplier,
        "best_price": float(prices[best_supplier]),
    })

CATEGORY_TITLES = {
    "timber": "Timber & Carcassing",
    "sheet": "Sheet Materials",
    "fixings": "Fixings",
}

# Category counts FOR HOME TEMPLATE
CATEGORIES = [(k, sum(1 for p in PRODUCTS if p["category"] == k)) for k in CATEGORY_TITLES]

# --------------------------------------------------
# HELPERS
# --------------------------------------------------

def paginate_results(items, page=1, per_page=12):
    total_pages = (len(items) + per_page - 1) // per_page
    if page < 1:
        page = 1
    start = (page - 1) * per_page
    end = page * per_page
    return items[start:end], total_pages


def build_facets(items):
    brands = {}
    for p in items:
        brands[p["brand"]] = brands.get(p["brand"], 0) + 1
    return {"brands": sorted(brands.items())}


def get_basket(request: Request):
    basket = request.session.get("basket", {})
    # Ensure it's always { "1": 2, "5": 1 } style
    if not isinstance(basket, dict):
        basket = {}
    return basket


def basket_count(request: Request) -> int:
    basket = get_basket(request)
    return sum(int(v) for v in basket.values())


# --------------------------------------------------
# ROUTES
# --------------------------------------------------

@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    return templates.TemplateResponse(
        "home.html",
        {
            "request": request,
            "categories": CATEGORIES,
            "basket_count": basket_count(request),
        }
    )


@app.get("/category/{cat}", response_class=HTMLResponse)
def category_page(
    request: Request,
    cat: str,
    page: int = 1,
):
    filtered = [p for p in PRODUCTS if p["category"] == cat]
    cards, total_pages = paginate_results(filtered, page)
    facets = build_facets(filtered)
facets = {
    "brands": [],
    "diameters": [],
    "lengths": [],
}

    return templates.TemplateResponse(
        "category.html",
        {
            "request": request,
            "cat": cat,
            "cat_title": CATEGORY_TITLES.get(cat, cat.title()),
            "cards": cards,
            "page": page,
            "total_pages": total_pages,
            "basket_count": basket_count(request),
            "facets": facets,
            "results_total": len(filtered),
        }
    )
@app.get("/search", response_class=HTMLResponse)
def search(
    request: Request,
    q: str = "",
    cat: str = "",
    brand: str = "",
    diameter: str = "",
    length: str = "",
    sort: str = "best",
):
    offers = search_offers(q) if q else []

    if cat:
        offers = [o for o in offers if getattr(o, "category", "") == cat]

    if brand:
        offers = [o for o in offers if str(getattr(o, "brand", 
"")).lower() == brand.lower()]

    if diameter:
        offers = [o for o in offers if str(getattr(o, "diameter", "")) == 
str(diameter)]

    if length:
        offers = [o for o in offers if str(getattr(o, "length", "")) == 
str(length)]

    if sort == "price_asc":
        offers = sorted(offers, key=lambda o: float(getattr(o, "price", 
10**9)))
    elif sort == "price_desc":
        offers = sorted(offers, key=lambda o: float(getattr(o, "price", 
0)), reverse=True)

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
            "offers": offers,
        },
    )


@app.post("/basket/add")
async def basket_add(request: Request):
    form = await request.form()

    # Template should post "product_id". If it posts "pid" instead, we support both.
    pid_raw = form.get("product_id") or form.get("pid")
    if pid_raw is None:
        return RedirectResponse("/basket", status_code=303)

    pid = int(pid_raw)
    qty = int(form.get("qty", 1))
    if qty < 1:
        qty = 1

    basket = get_basket(request)
    basket[str(pid)] = int(basket.get(str(pid), 0)) + qty
    request.session["basket"] = basket

    return RedirectResponse("/basket", status_code=303)


@app.get("/basket", response_class=HTMLResponse)
def basket_page(request: Request):
    basket = get_basket(request)

    items = []
    total = 0.0

    for pid_str, qty in basket.items():
        pid = int(pid_str)
        qty = int(qty)

        p = next((p for p in PRODUCTS if p["id"] == pid), None)
        if not p:
            continue

        line_total = float(p["best_price"]) * qty
        total += line_total

        items.append({
            "product": p,
            "qty": qty,
            "line_total": round(line_total, 2),
        })

    return templates.TemplateResponse(
        "basket.html",
        {
            "request": request,
            "items": items,
            "total": round(total, 2),
            "basket_count": basket_count(request),
        }
    )


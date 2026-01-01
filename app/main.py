from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from datetime import datetime
import uuid

app = FastAPI()
app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")

VAT_RATE = 0.20
SUPPLIERS = ["Toolstation", "Screwfix", "MKM", "Jewson"]

# Demo “logged-in” price basis labels
SUPPLIER_PRICE_TYPE = {
    "Toolstation": "Online",
    "Screwfix": "Online",
    "MKM": "My account",
    "Jewson": "My account",
}

# Demo catalogue (pretend this is 1000s)
PRODUCTS = [
    {"id": 1, "name": "CLS Timber 4x2 2.4m", "prices": {"Toolstation": 5.42, "Screwfix": 5.89, "MKM": 6.10, "Jewson": 6.45}},
    {"id": 2, "name": "18mm OSB Board 2440x1220", "prices": {"Toolstation": 19.80, "Screwfix": 21.50, "MKM": 22.90, "Jewson": 24.10}},
    {"id": 3, "name": "18mm MDF Board 2440x1220", "prices": {"Toolstation": 28.40, "Screwfix": 29.95, "MKM": 31.10, "Jewson": 33.20}},
    {"id": 4, "name": "Structural Plywood 18mm 2440x1220", "prices": {"Toolstation": 33.90, "Screwfix": 35.50, "MKM": 36.80, "Jewson": 39.10}},
    {"id": 5, "name": "CLS Timber 3x2 2.4m", "prices": {"Toolstation": 4.28, "Screwfix": 4.59, "MKM": 4.85, "Jewson": 5.10}},
]

# -------------------------
# In-memory “session” state (demo)
# -------------------------
# basket: {product_id: qty}
BASKET = {}
# settings (persist across pages)
SETTINGS = {
    "vat_mode": "ex",          # ex/inc
    "purchase_mode": "single", # single/split
}

# Saved jobs (project folders) - demo only
JOBS = {}  # job_id -> dict

def find_product(pid: int):
    for p in PRODUCTS:
        if p["id"] == pid:
            return p
    return None

def search_products(q: str):
    q = (q or "").strip().lower()
    if not q:
        return PRODUCTS[:25]
    results = [p for p in PRODUCTS if q in p["name"].lower()]
    return results[:25]

def basket_items():
    items = []
    for pid, qty in BASKET.items():
        p = find_product(int(pid))
        if p and int(qty) > 0:
            items.append({"product": p, "qty": int(qty)})
    return items

def calculate_totals(vat_mode: str, purchase_mode: str):
    items = basket_items()
    any_qty = len(items) > 0

    totals_ex_single = {s: 0.0 for s in SUPPLIERS}
    split_total_ex = 0.0
    split_picks = []

    for row in items:
        p = row["product"]
        qty = row["qty"]

        # single supplier totals
        for s in SUPPLIERS:
            totals_ex_single[s] += float(p["prices"][s]) * qty

        # split pick (cheapest unit)
        cheapest_supplier = min(SUPPLIERS, key=lambda s: float(p["prices"][s]))
        cheapest_unit_ex = float(p["prices"][cheapest_supplier])
        split_total_ex += cheapest_unit_ex * qty
        split_picks.append({
            "name": p["name"],
            "qty": qty,
            "supplier": cheapest_supplier,
            "unit_ex": cheapest_unit_ex,
            "label": SUPPLIER_PRICE_TYPE.get(cheapest_supplier, "Online")
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
def home(request: Request, q: str = ""):
    results = search_products(q)
    return templates.TemplateResponse(
        "home.html",
        {
            "request": request,
            "q": q,
            "results": results,
            "basket_count": sum(int(v) for v in BASKET.values()) if BASKET else 0
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
    # settings
    SETTINGS["vat_mode"] = form.get("vat_mode", SETTINGS["vat_mode"])
    SETTINGS["purchase_mode"] = form.get("purchase_mode", SETTINGS["purchase_mode"])

    # quantities
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

    return templates.TemplateResponse(
        "basket.html",
        {
            "request": request,
            "vat_mode": vat_mode,
            "purchase_mode": purchase_mode,
            "suppliers": SUPPLIERS,
            "supplier_price_type": SUPPLIER_PRICE_TYPE,
            "jobs": sorted(JOBS.items(), key=lambda x: x[1]["created"], reverse=True),
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

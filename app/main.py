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
        "product_img": product_img,
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


def product_img(canonical: str) -> str:
    return f"/static/products/{canonical}.jpg"

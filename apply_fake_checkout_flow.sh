#!/usr/bin/env bash
set -euo pipefail

# -----------------------
# 1) Add templates: search, checkout, confirm
# -----------------------
cat > app/templates/search.html <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Search · Material Compare (Demo)</title>
  <link rel="stylesheet" href="/static/style.css" />
</head>
<body>
  <header class="topbar">
    <div class="brand">
      <div class="logo">MC</div>
      <div>
        <div class="title">Search</div>
        <div class="subtitle">Compare items across suppliers · add to basket · checkout routes orders (demo)</div>
      </div>
    </div>
    <nav class="nav">
      <a href="/">Home</a>
      <a class="basket" href="/basket">Basket <span class="pill">{{ basket_count }}</span></a>
    </nav>
  </header>

  <main class="wrap">
    <section class="card">
      <form method="get" action="/search" class="search">
        <input name="q" value="{{ q }}" placeholder="Try: 3x2, 4x2, OSB, MDF, ply, screws..." />
        <button type="submit">Search</button>
      </form>
      {% if q %}
        <div class="muted small" style="margin-top:8px;">
          Tip: add 3–5 lines across timber + sheets + fixings, then open Basket for savings & checkout routing.
        </div>
      {% endif %}
    </section>

    {% if q and not grouped %}
      <section class="card">
        <h2>No results</h2>
        <p class="muted">Try “screws”, “3x2”, “4x2”, “osb 18”, “mdf”, “ply”.</p>
      </section>
    {% endif %}

    {% if grouped %}
      <section class="results-head">
        <h2>Results for “{{ q }}”</h2>
        <p class="muted">Stacked supplier view (Toolstation-style scanning). Cheapest unit prices shown — basket totals include delivery.</p>
      </section>

      <section class="stack">
        {% for supplier, offers in grouped.items() %}
          <div class="card supplier-card">
            <div class="supplier-bar">
              <div class="supplier-left">
                <img class="supplier-logo" src="{{ supplier_logo(supplier) }}" alt="{{ supplier }} logo" onerror="this.style.display='none'">
                <div>
                  <h3 style="margin:0;">{{ supplier }}</h3>
                  <div class="muted small">
                    {{ suppliers_meta[supplier].type }}{% if suppliers_meta[supplier].local %} · Local{% endif %}
                    · Delivery £{{ '%.2f'|format(suppliers_meta[supplier].delivery_gbp) }}
                    · Lead {{ suppliers_meta[supplier].lead_days }} day(s)
                  </div>
                </div>
              </div>

              <div class="supplier-right">
                <div class="muted small">Cheapest for this search</div>
                <div class="price-strong">
                  £{{ '%.2f'|format(offers[0].price_gbp) }}
                  <span class="pill2 best">Cheapest</span>
                </div>
              </div>
            </div>

            <div class="muted small" style="margin-top:8px;">{{ suppliers_meta[supplier].copy }}</div>

            <div class="offers">
              {% for o in offers %}
                <div class="offer-row">
                  <div class="offer-left">
                    <img class="thumb" src="/img/{{ o.canonical }}" alt="" onerror="this.style.display='none'">
                    <div>
                      <div class="item-title">{{ label_for(o.canonical) }}</div>
                      <div class="muted small">{{ o.title }}</div>
                    </div>
                  </div>

                  <div class="offer-mid muted small">
                    {{ o.unit }}
                  </div>

                  <div class="offer-price">
                    £{{ '%.2f'|format(o.price_gbp) }}
                  </div>

                  <div class="offer-add">
                    <form method="post" action="/add" class="addform">
                      <input type="hidden" name="canonical" value="{{ o.canonical }}" />
                      <input type="hidden" name="return_to" value="/search?q={{ q | urlencode }}" />
                      <input class="qty" type="number" name="qty" value="1" min="1" />
                      <button type="submit">Add</button>
                    </form>
                  </div>
                </div>
              {% endfor %}
            </div>

          </div>
        {% endfor %}
      </section>
    {% endif %}
  </main>
</body>
</html>
EOF

cat > app/templates/checkout.html <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Checkout · Material Compare (Demo)</title>
  <link rel="stylesheet" href="/static/style.css" />
</head>
<body>
  <header class="topbar">
    <div class="brand">
      <div class="logo">MC</div>
      <div>
        <div class="title">Checkout</div>
        <div class="subtitle">Review basket · see order routing · place orders (demo)</div>
      </div>
    </div>
    <nav class="nav">
      <a href="/search">Search</a>
      <a class="basket" href="/basket">Back to basket</a>
    </nav>
  </header>

  <main class="wrap">
    {% if not basket_lines %}
      <section class="card">
        <h2>Your basket is empty</h2>
        <p class="muted">Add items from search, then return here to checkout.</p>
        <a class="cta2" href="/search">Go to search</a>
      </section>
    {% else %}
      <section class="grid-2">
        <div class="card">
          <h2>Order summary</h2>
          <div class="kpis kpis-3">
            <div class="kpi">
              <div class="kpi-label">Best split total</div>
              <div class="kpi-value">{{ gbp(insights.split_best.total) }}</div>
              <div class="muted small">Lead {{ insights.split_best.lead_days }} day(s)</div>
            </div>
            <div class="kpi">
              <div class="kpi-label">Delivery</div>
              <div class="kpi-value">{{ gbp(insights.split_best.delivery_total) }}</div>
              <div class="muted small">{{ insights.split_best.breakdown|length }} supplier(s)</div>
            </div>
            <div class="kpi">
              <div class="kpi-label">Orders created</div>
              <div class="kpi-value">{{ insights.split_best.breakdown|length }}</div>
              <div class="muted small">One per supplier</div>
            </div>
          </div>

          <div class="note" style="margin-top:12px;">
            <strong>What happens next (demo):</strong> we place separate orders with each supplier, then show you one combined confirmation.
          </div>

          <h3 style="margin-top:14px;">Basket lines</h3>
          <table class="table tight">
            <thead>
              <tr>
                <th>Item</th>
                <th class="right">Qty</th>
                <th class="right">Unit</th>
              </tr>
            </thead>
            <tbody>
              {% for line in basket_lines %}
                <tr>
                  <td>{{ line.label }}</td>
                  <td class="right">{{ line.qty }}</td>
                  <td class="right">{{ line.unit }}</td>
                </tr>
              {% endfor %}
            </tbody>
          </table>

        </div>

        <div class="card">
          <h2>Order routing (best split)</h2>
          <p class="muted small">This is the “value” of the platform: you get the best delivered basket, without manually splitting orders.</p>

          {% for supplier, block in insights.split_best.breakdown.items() %}
            <div class="route">
              <div class="route-head">
                <div class="route-left">
                  <img class="supplier-logo" src="{{ supplier_logo(supplier) }}" alt="" onerror="this.style.display='none'">
                  <div>
                    <strong>{{ supplier }}</strong>
                    <div class="muted small">Delivery {{ gbp(block.delivery) }} · Lead {{ block.lead_days }} day(s)</div>
                  </div>
                </div>
                <div class="route-total">{{ gbp(block.items_total + block.delivery) }}</div>
              </div>

              <ul class="lines">
                {% for l in block.lines %}
                  <li>
                    <span>{{ l.label }} × {{ l.qty }}</span>
                    <span class="muted">{{ gbp(l.line_total) }}</span>
                  </li>
                {% endfor %}
              </ul>
            </div>
          {% endfor %}

          <form method="post" action="/checkout/confirm" style="margin-top:14px;">
            <button type="submit" class="btn-primary" style="width:100%;padding:12px 14px;font-weight:1000;">
              Place order (demo)
            </button>
          </form>

          <div class="muted small" style="margin-top:10px;">
            No payment in demo. This generates a confirmation page and clears the basket.
          </div>
        </div>
      </section>
    {% endif %}
  </main>
</body>
</html>
EOF

cat > app/templates/confirm.html <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Order confirmed · Material Compare (Demo)</title>
  <link rel="stylesheet" href="/static/style.css" />
</head>
<body>
  <header class="topbar">
    <div class="brand">
      <div class="logo">MC</div>
      <div>
        <div class="title">Order confirmed</div>
        <div class="subtitle">Demo confirmation · orders created with suppliers</div>
      </div>
    </div>
    <nav class="nav">
      <a href="/">Home</a>
      <a href="/search">Search</a>
    </nav>
  </header>

  <main class="wrap">
    <section class="card">
      <h2>Thanks — your order is placed (demo)</h2>
      <p class="muted">We’ve created supplier orders and combined them into one confirmation for you.</p>

      <div class="kpis kpis-3">
        <div class="kpi">
          <div class="kpi-label">Total paid</div>
          <div class="kpi-value">{{ gbp(total) }}</div>
          <div class="muted small">Includes delivery</div>
        </div>
        <div class="kpi">
          <div class="kpi-label">Supplier orders</div>
          <div class="kpi-value">{{ orders|length }}</div>
          <div class="muted small">Auto-split</div>
        </div>
        <div class="kpi">
          <div class="kpi-label">Max lead time</div>
          <div class="kpi-value">{{ lead_days }}d</div>
          <div class="muted small">Worst-case delivery</div>
        </div>
      </div>

      <h3 style="margin-top:14px;">Orders created</h3>
      <div class="stack">
        {% for o in orders %}
          <div class="card route">
            <div class="route-head">
              <div class="route-left">
                <img class="supplier-logo" src="{{ supplier_logo(o.supplier) }}" alt="" onerror="this.style.display='none'">
                <div>
                  <strong>{{ o.supplier }}</strong>
                  <div class="muted small">Order ref: {{ o.ref }} · Delivery {{ gbp(o.delivery) }} · Lead {{ o.lead_days }} day(s)</div>
                </div>
              </div>
              <div class="route-total">{{ gbp(o.total) }}</div>
            </div>
          </div>
        {% endfor %}
      </div>

      <div class="cta-band" style="margin-top:16px;">
        <div>
          <h2 style="margin:0;">Keep comparing</h2>
          <p class="muted" style="margin:6px 0 0;">Add more lines to see bigger savings and smarter routing.</p>
        </div>
        <a class="cta2" href="/search">New search</a>
      </div>
    </section>
  </main>
</body>
</html>
EOF

# -----------------------
# 2) Patch main.py: add /search + supplier_logo + checkout routes
# -----------------------
python - <<'PY'
from pathlib import Path
import re

p = Path("app/main.py")
t = p.read_text()

# Ensure random import
if "import random" not in t:
    t = t.replace("from typing import", "import random\nfrom typing import", 1)

# Add supplier_logo helper if missing
if "def supplier_logo(" not in t:
    insert_after = "def product_image"
    if insert_after in t:
        # insert before that route (helpers should be above routes)
        pass

    helper = """
def supplier_logo(supplier: str) -> str:
    s = supplier.lower()
    if "toolstation" in s:
        return "/static/logos/toolstation.svg"
    if "screwfix" in s:
        return "/static/logos/screwfix.svg"
    if "jewson" in s:
        return "/static/logos/jewson.svg"
    if "mkm" in s:
        return "/static/logos/mkm.svg"
    # Any local supplier
    if "local" in s or "(local)" in s:
        return "/static/logos/local.svg"
    return "/static/logos/local.svg"
"""
    # place after product_img helper if present, else after gbp
    if "def product_img" in t:
        t = re.sub(r"(def product_img\([^\)]*\):\n[^\n]*\n)", r"\1\n"+helper+"\n", t, count=1, flags=re.MULTILINE)
    elif "def gbp" in t:
        t = re.sub(r"(def gbp\([^\)]*\)[\s\S]*?\n)", r"\1\n"+helper+"\n", t, count=1)
    else:
        t = helper + "\n" + t

# Add /search route if missing
if '@app.get("/search"' not in t:
    search_route = """
@app.get("/search", response_class=HTMLResponse)
def search_page(request: Request, q: str = ""):
    offers = search_offers(q) if q else []
    grouped: Dict[str, List[Offer]] = {}
    for o in offers:
        grouped.setdefault(o.supplier, []).append(o)
    for s in grouped:
        grouped[s] = sorted(grouped[s], key=lambda x: x.price_gbp)

    basket = _basket(request)
    return templates.TemplateResponse("search.html", {
        "request": request,
        "q": q,
        "grouped": grouped,
        "suppliers_meta": SUPPLIERS,
        "basket_count": sum(basket.values()),
        "label_for": get_label,
        "unit_for": get_unit,
        "supplier_logo": supplier_logo,
    })
"""
    # insert after home() route block (after @app.get("/") ... def home)
    # safest: insert right after the existing home() function definition ends by finding first "@app.post" after it.
    m = re.search(r"@app\.post\(\"/add\"\)", t)
    if m:
        t = t[:m.start()] + search_route + "\n" + t[m.start():]
    else:
        t += "\n" + search_route

# Add checkout routes if missing
if '@app.get("/checkout"' not in t:
    checkout_routes = """
@app.get("/checkout", response_class=HTMLResponse)
def checkout_page(request: Request):
    basket = _basket(request)
    lines = [{"canonical": c, "label": get_label(c), "qty": q, "unit": get_unit(c)} for c, q in basket.items()]
    insights = compute_insights(basket)
    return templates.TemplateResponse("checkout.html", {
        "request": request,
        "basket_lines": lines,
        "insights": insights,
        "gbp": gbp,
        "supplier_logo": supplier_logo,
    })

@app.post("/checkout/confirm", response_class=HTMLResponse)
def checkout_confirm(request: Request):
    basket = _basket(request)
    insights = compute_insights(basket)
    split = insights.get("split_best")
    orders = []
    if split:
        for supplier, block in split["breakdown"].items():
            ref = f"MC-{random.randint(100000, 999999)}"
            total = block["items_total"] + block["delivery"]
            orders.append({
                "supplier": supplier,
                "ref": ref,
                "delivery": block["delivery"],
                "lead_days": block["lead_days"],
                "total": total
            })
        total = split["total"]
        lead_days = split["lead_days"]
    else:
        total = 0.0
        lead_days = 0

    # Clear basket after "placing order" (demo)
    _clear(request)

    return templates.TemplateResponse("confirm.html", {
        "request": request,
        "orders": orders,
        "total": total,
        "lead_days": lead_days,
        "gbp": gbp,
        "supplier_logo": supplier_logo,
    })
"""
    t += "\n" + checkout_routes

p.write_text(t)
print("✅ Added /search + /checkout + confirmation routes + supplier_logo helper.")
PY

# -----------------------
# 3) Patch index.html: homepage search forms should go to /search
# -----------------------
python - <<'PY'
from pathlib import Path
import re

p = Path("app/templates/index.html")
h = p.read_text()
h2 = re.sub(r'<form method="get" action="/"', '<form method="get" action="/search"', h)
p.write_text(h2)
print("✅ Homepage search now goes to /search.")
PY

# -----------------------
# 4) Patch basket.html: add a big checkout CTA
# -----------------------
python - <<'PY'
from pathlib import Path
import re

p = Path("app/templates/basket.html")
h = p.read_text()

if "Proceed to checkout" not in h:
    # Insert a CTA band after the insight section (first occurrence)
    insert = """
      <section class="cta-band" style="margin-top:16px;">
        <div>
          <h2 style="margin:0;">Ready to order?</h2>
          <p class="muted" style="margin:6px 0 0;">Checkout will route your basket into supplier orders (demo).</p>
        </div>
        <a class="cta2" href="/checkout">Proceed to checkout</a>
      </section>
"""
    h2, n = re.subn(r'(</section>\s*<section class="grid-2">)', r'</section>\n'+insert+r'\1', h, count=1)
    if n == 0:
        # fallback: append near end of main
        h2 = h.replace("</main>", insert + "\n</main>")
    p.write_text(h2)
    print("✅ Added checkout CTA to basket.")
else:
    print("✅ Basket already has checkout CTA.")
PY

# -----------------------
# 5) CSS add-ons for stacked layout + supplier bars + offer rows
# -----------------------
python - <<'PY'
from pathlib import Path
p = Path("app/static/style.css")
css = p.read_text()

if ".stack" not in css or ".supplier-logo" not in css:
    css += """

/* Search stacked layout */
.stack{display:flex;flex-direction:column;gap:12px}
.supplier-card{padding:14px}
.supplier-bar{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}
@media (max-width: 900px){.supplier-bar{flex-direction:column}}
.supplier-left{display:flex;gap:12px;align-items:center}
.supplier-logo{width:120px;height:36px;object-fit:contain;border-radius:10px}
.price-strong{font-weight:1000;font-size:18px;display:flex;gap:8px;align-items:center;justify-content:flex-end}
.offers{margin-top:12px;display:flex;flex-direction:column;gap:10px}
.offer-row{display:grid;grid-template-columns:1.2fr .25fr .25fr .4fr;gap:12px;align-items:center;border:1px solid var(--line);border-radius:14px;background:#fff;padding:10px}
@media (max-width: 900px){.offer-row{grid-template-columns:1fr;gap:10px}}
.offer-left{display:flex;gap:10px;align-items:flex-start}
.offer-price{font-weight:1000;text-align:right}
@media (max-width: 900px){.offer-price{text-align:left}}
.offer-add{display:flex;justify-content:flex-end}
@media (max-width: 900px){.offer-add{justify-content:flex-start}}
.route{border:1px solid var(--line);border-radius:14px;background:#fff;padding:12px}
.route-head{display:flex;justify-content:space-between;gap:12px;align-items:center}
.route-left{display:flex;gap:12px;align-items:center}
.route-total{font-weight:1000}
.btn-primary{background:#111827;color:#fff;border:1px solid rgba(0,0,0,.08);border-radius:12px}
"""
    p.write_text(css)
    print("✅ Added stacked search + checkout styling.")
else:
    print("✅ CSS already contains stacked layout styles.")
PY

echo "✅ Fake checkout flow + /search page installed."
echo "Restart uvicorn, then try: /search?q=osb and /checkout"

#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/static/logos

# --- Create simple SVG "logo tiles" (placeholder style, looks professional) ---
cat > app/static/logos/screwfix.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="64" viewBox="0 0 220 64">
  <rect x="0" y="0" width="220" height="64" rx="12" fill="#111827"/>
  <text x="18" y="40" font-family="Inter, Arial" font-size="22" font-weight="800" fill="#fff">Screwfix</text>
</svg>
EOF

cat > app/static/logos/toolstation.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="64" viewBox="0 0 220 64">
  <rect x="0" y="0" width="220" height="64" rx="12" fill="#2563eb"/>
  <text x="18" y="40" font-family="Inter, Arial" font-size="22" font-weight="800" fill="#fff">Toolstation</text>
</svg>
EOF

cat > app/static/logos/jewson.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="64" viewBox="0 0 220 64">
  <rect x="0" y="0" width="220" height="64" rx="12" fill="#0f766e"/>
  <text x="18" y="40" font-family="Inter, Arial" font-size="22" font-weight="800" fill="#fff">Jewson</text>
</svg>
EOF

cat > app/static/logos/mkm.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="64" viewBox="0 0 220 64">
  <rect x="0" y="0" width="220" height="64" rx="12" fill="#f97316"/>
  <text x="18" y="40" font-family="Inter, Arial" font-size="22" font-weight="800" fill="#111827">MKM</text>
</svg>
EOF

cat > app/static/logos/local.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="64" viewBox="0 0 220 64">
  <rect x="0" y="0" width="220" height="64" rx="12" fill="#f5f6f8" stroke="#e5e7eb"/>
  <text x="18" y="40" font-family="Inter, Arial" font-size="22" font-weight="900" fill="#111827">Local Trade</text>
</svg>
EOF

# --- Replace homepage template with a beefed-up, investor-ready layout ---
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
        <div class="subtitle">Compare delivered basket totals across UK suppliers — and buy local when it makes sense</div>
      </div>
    </div>

    <nav class="nav">
      <a href="#how">How it works</a>
      <a href="#local">Shop local</a>
      <a href="#about">About</a>
      <a class="basket" href="/basket">Basket <span class="pill">{{ basket_count }}</span></a>
    </nav>
  </header>

  <main class="wrap">
    <!-- HERO -->
    <section class="hero2">
      <div class="hero2-left">
        <div class="tag">Investor demo · mocked pricing</div>
        <h1>Stop guessing who’s cheapest — compare the delivered basket.</h1>
        <p class="lead">
          Builders don’t buy “one item”. They buy a basket. We compare price + delivery + lead time,
          and show whether splitting the basket saves money — with a buy-local option for trade counters.
        </p>

        <form method="get" action="/" class="search hero-search">
          <input name="q" value="{{ q }}" placeholder="Try: 3x2, 4x2, OSB 18, MDF, pdf, screws..." />
          <button type="submit">Compare now</button>
        </form>

        <div class="hero-metrics">
          <div class="metric"><div class="metric-k">Basket insight</div><div class="metric-v">Split vs single supplier</div></div>
          <div class="metric"><div class="metric-k">Delivery aware</div><div class="metric-v">Totals include delivery</div></div>
          <div class="metric"><div class="metric-k">Local options</div><div class="metric-v">Support nearby trade</div></div>
        </div>

        <div class="hint muted">
          Quick searches:
          <span class="chip">3x2</span>
          <span class="chip">osb</span>
          <span class="chip">mdf</span>
          <span class="chip">pdf</span>
          <span class="chip">screws</span>
        </div>
      </div>

      <div class="hero2-right">
        <div class="card">
          <h2>Featured offers (demo)</h2>
          <p class="muted small">These are “headline deals” to show how the platform can surface value instantly.</p>

          <div class="featured">
            <div class="featured-item">
              <div class="featured-top">
                <div class="featured-name">Plywood 18mm 8x4</div>
                <div class="featured-price">£36.90</div>
              </div>
              <div class="muted small">Best today: Cheshire Timber (Local) · Delivery included at basket stage</div>
            </div>

            <div class="featured-item">
              <div class="featured-top">
                <div class="featured-name">Wood Screws 5x80 (200)</div>
                <div class="featured-price">£9.75</div>
              </div>
              <div class="muted small">Best today: Manchester Fixings Depot (Local)</div>
            </div>

            <div class="featured-item">
              <div class="featured-top">
                <div class="featured-name">CLS 4x2 (2.4m)</div>
                <div class="featured-price">£4.70</div>
              </div>
              <div class="muted small">Best today: Toolstation</div>
            </div>
          </div>

          <a class="cta" href="/basket">Open basket insights →</a>
        </div>
      </div>
    </section>

    <!-- SUPPLIER STRIP -->
    <section class="supplier-strip">
      <div class="strip-title">Comparing suppliers like</div>
      <div class="logos">
        <img src="/static/logos/screwfix.svg" alt="Screwfix" />
        <img src="/static/logos/toolstation.svg" alt="Toolstation" />
        <img src="/static/logos/jewson.svg" alt="Jewson" />
        <img src="/static/logos/mkm.svg" alt="MKM" />
        <img src="/static/logos/local.svg" alt="Local Trade" />
      </div>
    </section>

    <!-- RESULTS -->
    {% if q and not grouped %}
      <section class="card">
        <h2>No results</h2>
        <p class="muted">Try “screws”, “3x2”, “4x2”, “osb 18”, “mdf”, “pdf”, or add sizes.</p>
      </section>
    {% endif %}

    {% if grouped %}
      <section class="results-head">
        <h2>Results for “{{ q }}”</h2>
        <p class="muted">Add items across suppliers then open Basket to see split vs single totals and savings.</p>
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
              <strong>Try this basket:</strong> add timber + plywood + screws → then Basket shows split savings + local option.
            </div>
          </div>
        {% endfor %}
      </section>
    {% endif %}

    <!-- HOW IT WORKS -->
    <section id="how" class="section">
      <div class="section-head2">
        <h2>How it works</h2>
        <p class="muted">Built for site teams: simple search, clear totals, and decision-ready insights.</p>
      </div>

      <div class="steps">
        <div class="step card">
          <div class="step-no">1</div>
          <h3>Search like you normally do</h3>
          <p class="muted">Type “3x2”, “osb”, “pdf”, “screws”. No perfect wording needed.</p>
        </div>
        <div class="step card">
          <div class="step-no">2</div>
          <h3>Add to basket</h3>
          <p class="muted">Mix suppliers. We’ll handle the comparison and totals.</p>
        </div>
        <div class="step card">
          <div class="step-no">3</div>
          <h3>See the smartest checkout</h3>
          <p class="muted">Best split vs best single supplier, plus a local-first option.</p>
        </div>
      </div>
    </section>

    <!-- SHOP LOCAL -->
    <section id="local" class="section">
      <div class="callout">
        <div>
          <h2>Shop local, without paying over the odds</h2>
          <p class="muted">
            Local merchants often win on speed, service and returns — but pricing is hard to compare.
            We surface local options next to national suppliers so you can choose confidently.
          </p>
          <ul class="ticklist">
            <li>Faster delivery windows for urgent jobs</li>
            <li>Simple returns and trade counter support</li>
            <li>Keep spend in your area (and relationships strong)</li>
          </ul>
        </div>
        <div class="callout-box">
          <div class="callout-k">Local-first checkout</div>
          <div class="callout-v">Shown in Basket insights</div>
          <div class="muted small">Demo currently includes Cheshire/Stockport/Manchester local suppliers.</div>
        </div>
      </div>
    </section>

    <!-- ABOUT -->
    <section id="about" class="section">
      <div class="about-grid">
        <div class="card">
          <h2>About Material Compare</h2>
          <p class="muted">
            We’re building the procurement layer for UK construction — a platform that helps builders
            find the best delivered basket price across suppliers, without the spreadsheet chaos.
          </p>
          <p class="muted">
            This demo is mocked pricing to show the user experience and the value of smart basket logic.
            Next step is swapping the demo feed for live integrations (merchant APIs, trade accounts and delivery rules).
          </p>
        </div>
        <div class="card">
          <h2>Why now</h2>
          <p class="muted">
            Margin pressure is real. The biggest waste is time + price uncertainty:
            multiple tabs, multiple delivery charges, inconsistent lead times.
          </p>
          <div class="quote">
            “The cheapest unit price isn’t the cheapest basket once delivery and lead time are included.”
          </div>
        </div>
      </div>
    </section>

    <!-- FOOTER CTA -->
    <section class="cta-band">
      <div>
        <h2>Ready to see the savings?</h2>
        <p class="muted">Add 3–5 items across categories and open Basket. The insight is the product.</p>
      </div>
      <a class="cta2" href="/">Start comparing</a>
    </section>

    <footer class="footer">
      <div class="muted small">© Material Compare (Demo). Mocked pricing for investor demonstration.</div>
    </footer>
  </main>
</body>
</html>
EOF

# --- Slight CSS additions: bigger layout, featured module, logo strip, sections ---
python - <<'PY'
import pathlib
p = pathlib.Path("app/static/style.css")
css = p.read_text()

css += """
/* ---------- Homepage beef-up ---------- */
.wrap{max-width:1260px}
.nav{display:flex;gap:14px;align-items:center}
.nav a{color:var(--muted);font-weight:700}
.nav a:hover{color:var(--text)}
.hero2{display:grid;grid-template-columns:1.35fr .95fr;gap:16px;margin-top:16px;align-items:start}
@media (max-width: 980px){.hero2{grid-template-columns:1fr}}
.hero-search{margin-top:14px}
.hero-metrics{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-top:14px}
@media (max-width: 900px){.hero-metrics{grid-template-columns:1fr}}
.metric{border:1px solid var(--line);border-radius:14px;background:var(--soft);padding:10px}
.metric-k{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.metric-v{font-weight:900;margin-top:6px}
.hint{margin-top:10px}

.featured{display:flex;flex-direction:column;gap:10px;margin-top:10px}
.featured-item{border:1px solid var(--line);border-radius:14px;padding:12px;background:#fff}
.featured-top{display:flex;justify-content:space-between;gap:10px;align-items:baseline}
.featured-name{font-weight:950}
.featured-price{font-weight:1000}
.cta{display:inline-block;margin-top:12px;font-weight:900;color:#1d4ed8}

.supplier-strip{margin-top:16px;border:1px solid var(--line);border-radius:14px;background:var(--soft);padding:14px}
.strip-title{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.08em;font-weight:800;margin-bottom:10px}
.logos{display:grid;grid-template-columns:repeat(5,1fr);gap:10px;align-items:center}
@media (max-width: 980px){.logos{grid-template-columns:repeat(2,1fr)}}
.logos img{width:100%;height:64px;object-fit:contain}

.section{margin-top:18px}
.section-head2{margin-bottom:10px}
.steps{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}
@media (max-width: 980px){.steps{grid-template-columns:1fr}}
.step-no{width:34px;height:34px;border-radius:999px;background:#dbeafe;color:#1d4ed8;display:flex;align-items:center;justify-content:center;font-weight:1000;margin-bottom:8px}

.callout{display:grid;grid-template-columns:1.2fr .8fr;gap:12px;border:1px solid var(--line);border-radius:14px;background:#fff;padding:16px}
@media (max-width: 980px){.callout{grid-template-columns:1fr}}
.ticklist{margin:10px 0 0 18px;color:var(--muted)}
.callout-box{border:1px solid var(--line);border-radius:14px;background:var(--soft);padding:14px}
.callout-k{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em;font-weight:900}
.callout-v{font-weight:1000;font-size:18px;margin-top:8px}

.about-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:12px}
@media (max-width: 980px){.about-grid{grid-template-columns:1fr}}
.quote{margin-top:10px;padding:12px;border-radius:14px;background:#f8fafc;border:1px dashed #cbd5e1;color:#0f172a;font-weight:800}

.cta-band{margin:18px 0;border:1px solid var(--line);border-radius:14px;background:#111827;color:#fff;padding:16px;display:flex;justify-content:space-between;align-items:center;gap:12px}
@media (max-width: 980px){.cta-band{flex-direction:column;align-items:flex-start}}
.cta-band .muted{color:#cbd5e1}
.cta2{background:#fff;color:#111827;border-radius:12px;padding:10px 12px;font-weight:1000;border:1px solid rgba(255,255,255,.2)}
.footer{padding:18px 0;border-top:1px solid var(--line);margin-top:16px}
"""
p.write_text(css)
print("✅ Homepage styles added.")
PY

echo "✅ Homepage beef-up applied."
echo "Restart uvicorn (CTRL+C), then:"
echo "source .venv/bin/activate && python -m uvicorn app.main:app --reload --port 8000"

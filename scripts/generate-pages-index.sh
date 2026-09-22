#!/usr/bin/env bash
# Generate docs/index.html for the fleet's GitHub Pages landing page.
# All branding and URLs come from the catalog (organization / displayName /
# pagesBase), so renaming the org needs no edit here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Inputs and outputs are overridable so the generator can be exercised against a
# fixture catalog without touching the committed page (see tests/pages-index.bats).
# FLEET_CATALOG is the same override check-repos-catalog.sh accepts.
REPOS_JSON="${FLEET_CATALOG:-${OPENPHYSICS_CATALOG:-$REPO_ROOT/structure/repos.json}}"
DOCS_DIR="${FLEET_DOCS_DIR:-${OPENPHYSICS_DOCS_DIR:-$REPO_ROOT/docs}}"
ASSETS_DIR="$DOCS_DIR/assets"
OUTPUT="$DOCS_DIR/index.html"
# Full-size ground-truth screenshots committed in this repo. The lightweight
# WebP thumbnails served by the page are derived from these.
SCREENSHOTS_DIR="${FLEET_SCREENSHOTS_DIR:-${OPENPHYSICS_SCREENSHOTS_DIR:-$REPO_ROOT/screenshots}}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

ORG="$(jq -r '.organization' "$REPOS_JSON")"
ORG_DISPLAY="$(jq -r '.displayName // .organization' "$REPOS_JSON")"
PAGES_BASE="$(jq -r '.pagesBase // "https://\(.organization | ascii_downcase).github.io"' "$REPOS_JSON")"

mkdir -p "$ASSETS_DIR" "$SCREENSHOTS_DIR"

# Build the card thumbnails with sharp (scripts/make-thumbnails.mjs). The committed
# full-size PNGs in screenshots/ are the ground truth; when this runs from a full
# workspace checkout they are first refreshed from the sibling sim repos, then each
# is downscaled to a small WebP under docs/assets/. Sharp is a dev dependency, so if
# node_modules is absent (e.g. a docs-only edit) we keep the already committed
# thumbnails rather than failing the whole page build — run `npm install` to refresh.
# make-thumbnails.mjs always writes to the repo's own screenshots/ + docs/assets/,
# so it only applies when this run targets that tree; an overridden output tree
# renders from whatever assets it was given.
if [[ "$DOCS_DIR" != "$REPO_ROOT/docs" ]]; then
  : # custom output tree — leave its assets/ as-is
elif [[ -f "$REPO_ROOT/node_modules/sharp/package.json" ]]; then
  node "$SCRIPT_DIR/make-thumbnails.mjs" || echo "warning: thumbnail regeneration failed; using committed docs/assets/*.webp" >&2
else
  echo "sharp not installed; skipping thumbnail regeneration (using committed docs/assets/*.webp). Run 'npm install' to refresh." >&2
fi

# Each line: name|displayName|url|hue|topics(comma-separated)@description
jq_program='
  .repos[]
  | select(.isSimulation == true and .status == "active")
  | select(.lineage == $category)
  | "\(.name)|\(.displayName // .name)|\(.deployedUrl // ($base + "/" + .name))|\((.name | explode | add) % 360)|\(.physicsTopics | join(","))@\(.description)"
'

new_sims="$(jq -r --arg category original --arg base "$PAGES_BASE" "$jq_program" "$REPOS_JSON" | sort)"
phet_sims="$(jq -r --arg category phet --arg base "$PAGES_BASE" "$jq_program" "$REPOS_JSON" | sort)"
naap_sims="$(jq -r --arg category naap --arg base "$PAGES_BASE" "$jq_program" "$REPOS_JSON" | sort)"

html_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

card_html() {
  local line="$1"
  local meta desc name title url hue topics
  meta="${line%%@*}"
  desc="${line#*@}"
  IFS='|' read -r name title url hue topics <<<"$meta"
  url="$(printf '%s' "$url" | sed -E 's#^(https?://)([^/]+)#\1\L\2#' | sed 's|/$||')"

  local monogram
  # `|| true` because an all-lowercase name makes grep exit 1, and under
  # `set -euo pipefail` that would abort the whole run before the fallback below.
  monogram="$(printf '%s' "$name" | grep -o '[A-Z]' | head -2 | tr -d '\n' || true)"
  if [[ -z "$monogram" ]]; then
    monogram="$(printf '%s' "$name" | head -c 2 | tr '[:lower:]' '[:upper:]')"
  fi

  local tags_html=""
  if [[ -n "$topics" ]]; then
    local topic
    local count=0
    IFS=',' read -ra topic_arr <<<"$topics"
    for topic in "${topic_arr[@]}"; do
      [[ $count -ge 3 ]] && break
      tags_html+="<span class=\"tag\">$(html_escape "$topic")</span>"
      count=$((count + 1))
    done
  fi

  local title_esc thumb_html img=""
  title_esc="$(html_escape "$title")"
  if [[ -f "$ASSETS_DIR/${name}.webp" ]]; then
    img="assets/${name}.webp"
  elif [[ -f "$ASSETS_DIR/${name}.png" ]]; then
    img="assets/${name}.png"
  fi
  if [[ -n "$img" ]]; then
    thumb_html="<div class=\"thumb\"><img src=\"${img}\" alt=\"${title_esc} simulation screenshot\" loading=\"lazy\" decoding=\"async\" width=\"1154\" height=\"753\"><span class=\"badge\">${monogram}</span></div>"
  else
    thumb_html="<div class=\"thumb placeholder\"><span>${monogram}</span></div>"
  fi

  cat <<CARD
        <a class="card" href="${url}/" style="--hue: ${hue};">
          ${thumb_html}
          <div class="card-body">
            <div class="card-head">
              <h3>${title_esc}</h3>
              <span class="card-arrow" aria-hidden="true">&rarr;</span>
            </div>
            <p>$(html_escape "$desc")</p>
            <div class="tags">${tags_html}</div>
          </div>
        </a>
CARD
}

count_lines() {
  [[ -z "$1" ]] && { echo 0; return; }
  printf '%s\n' "$1" | grep -c .
}

new_count="$(count_lines "$new_sims")"
phet_count="$(count_lines "$phet_sims")"
naap_count="$(count_lines "$naap_sims")"
total_count="$((new_count + phet_count + naap_count))"

{
  cat <<HEADER
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="$ORG_DISPLAY — open-source interactive physics simulations for the web.">
  <meta property="og:title" content="$ORG_DISPLAY Simulations">
  <meta property="og:description" content="Open-source interactive physics simulations for the web.">
  <meta name="theme-color" content="#0b1020">
  <title>$ORG_DISPLAY Simulations</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #080c18;
      --bg-2: #0d1326;
      --surface: rgba(255, 255, 255, 0.035);
      --surface-hover: rgba(255, 255, 255, 0.06);
      --text: #eef2fb;
      --muted: #98a6c8;
      --faint: #6c7896;
      --accent: #6f9bff;
      --border: rgba(255, 255, 255, 0.09);
      --radius: 16px;
      --maxw: 1140px;
    }

    * { box-sizing: border-box; }

    html { scroll-behavior: smooth; }

    body {
      margin: 0;
      font-family: "Inter", "Segoe UI", system-ui, -apple-system, sans-serif;
      color: var(--text);
      line-height: 1.6;
      min-height: 100vh;
      background: var(--bg);
      -webkit-font-smoothing: antialiased;
      overflow-x: hidden;
    }

    /* Animated aurora backdrop */
    .bg {
      position: fixed;
      inset: 0;
      z-index: -1;
      overflow: hidden;
      background:
        radial-gradient(60% 50% at 50% -5%, rgba(111, 155, 255, 0.20), transparent 70%),
        radial-gradient(40% 40% at 100% 0%, rgba(168, 85, 247, 0.12), transparent 70%),
        linear-gradient(180deg, var(--bg-2), var(--bg) 40%);
    }
    .bg::before, .bg::after {
      content: "";
      position: absolute;
      width: 45vw;
      height: 45vw;
      border-radius: 50%;
      filter: blur(90px);
      opacity: 0.5;
      animation: drift 22s ease-in-out infinite alternate;
    }
    .bg::before { background: radial-gradient(circle, rgba(91, 141, 239, 0.6), transparent 60%); top: -10vw; left: -8vw; }
    .bg::after  { background: radial-gradient(circle, rgba(168, 85, 247, 0.45), transparent 60%); bottom: -12vw; right: -8vw; animation-delay: -8s; }

    @keyframes drift {
      from { transform: translate(0, 0) scale(1); }
      to   { transform: translate(6vw, 4vw) scale(1.15); }
    }

    .wrap { max-width: var(--maxw); margin: 0 auto; padding: clamp(3rem, 8vw, 6rem) 1.5rem 4rem; }

    /* Hero */
    header { text-align: center; margin-bottom: 4rem; }
    .eyebrow {
      display: inline-block;
      font-size: 0.78rem;
      letter-spacing: 0.18em;
      text-transform: uppercase;
      color: var(--muted);
      padding: 0.35rem 0.9rem;
      border: 1px solid var(--border);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.03);
      margin-bottom: 1.5rem;
    }
    header h1 {
      margin: 0 0 1rem;
      font-size: clamp(2.5rem, 7vw, 4.25rem);
      font-weight: 800;
      letter-spacing: -0.03em;
      line-height: 1.05;
      background: linear-gradient(135deg, #ffffff 20%, #8fb2ff 60%, #c4a3ff 100%);
      -webkit-background-clip: text;
      background-clip: text;
      color: transparent;
    }
    header p { margin: 0 auto; max-width: 40rem; color: var(--muted); font-size: clamp(1rem, 2.5vw, 1.2rem); }

    .links { display: flex; flex-wrap: wrap; gap: 0.75rem; justify-content: center; margin-top: 2rem; }
    .links a {
      display: inline-flex;
      align-items: center;
      gap: 0.4rem;
      color: var(--text);
      text-decoration: none;
      padding: 0.6rem 1.2rem;
      border: 1px solid var(--border);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.04);
      font-size: 0.92rem;
      font-weight: 500;
      transition: background 0.18s, border-color 0.18s, transform 0.18s;
    }
    .links a:hover { background: rgba(111, 155, 255, 0.16); border-color: rgba(111, 155, 255, 0.4); transform: translateY(-1px); }
    .links a.primary { background: linear-gradient(135deg, #5b8def, #7c5bef); border-color: transparent; }
    .links a.primary:hover { filter: brightness(1.08); }

    /* Sections */
    section { margin-bottom: 3.5rem; }
    .section-head { display: flex; align-items: baseline; gap: 0.75rem; margin: 0 0 1.5rem; }
    .section-head h2 {
      margin: 0;
      font-size: 1.05rem;
      font-weight: 600;
      color: var(--text);
      text-transform: uppercase;
      letter-spacing: 0.1em;
    }
    .section-head .count {
      font-size: 0.8rem;
      color: var(--faint);
      padding: 0.1rem 0.55rem;
      border: 1px solid var(--border);
      border-radius: 999px;
    }
    .section-head::after {
      content: "";
      flex: 1;
      height: 1px;
      background: linear-gradient(90deg, var(--border), transparent);
    }

    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)); gap: 1.1rem; }

    /* Cards */
    .card {
      position: relative;
      display: flex;
      flex-direction: column;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      text-decoration: none;
      color: inherit;
      overflow: hidden;
      backdrop-filter: blur(8px);
      transition: transform 0.2s ease, border-color 0.2s ease, background 0.2s ease, box-shadow 0.2s ease;
    }
    .card::before {
      content: "";
      position: absolute;
      inset: 0 0 auto 0;
      height: 3px;
      z-index: 3;
      background: linear-gradient(90deg, hsl(var(--hue) 85% 65%), hsl(calc(var(--hue) + 45) 85% 62%));
      opacity: 0.95;
    }
    .card:hover {
      transform: translateY(-4px);
      background: var(--surface-hover);
      border-color: hsl(var(--hue) 70% 60% / 0.5);
      box-shadow: 0 16px 40px -16px hsl(var(--hue) 80% 55% / 0.55);
    }

    /* Screenshot preview */
    .thumb {
      position: relative;
      aspect-ratio: 1154 / 753;
      overflow: hidden;
      background: linear-gradient(135deg, hsl(var(--hue) 45% 16%), hsl(calc(var(--hue) + 45) 45% 12%));
      border-bottom: 1px solid var(--border);
    }
    .thumb img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      object-position: top center;
      display: block;
      transition: transform 0.45s ease;
    }
    .card:hover .thumb img { transform: scale(1.05); }
    .thumb::after {
      content: "";
      position: absolute;
      inset: 0;
      background: linear-gradient(180deg, transparent 50%, rgba(8, 12, 24, 0.55));
      pointer-events: none;
    }
    /* Fallback monogram tile when a sim has no screenshot committed yet */
    .thumb.placeholder { display: grid; place-items: center; }
    .thumb.placeholder span {
      font-size: 2.6rem;
      font-weight: 800;
      letter-spacing: 0.05em;
      color: hsl(var(--hue) 75% 80%);
      opacity: 0.9;
    }

    .badge {
      position: absolute;
      left: 0.85rem;
      bottom: 0.85rem;
      z-index: 2;
      display: grid;
      place-items: center;
      width: 42px;
      height: 42px;
      border-radius: 11px;
      font-weight: 700;
      font-size: 0.9rem;
      letter-spacing: 0.02em;
      color: #fff;
      background: linear-gradient(135deg, hsl(var(--hue) 80% 58%), hsl(calc(var(--hue) + 45) 78% 52%));
      box-shadow: 0 6px 18px -6px hsl(var(--hue) 80% 50% / 0.95);
    }

    .card-body { display: flex; flex: 1; flex-direction: column; padding: 1.3rem; }
    .card-head { display: flex; align-items: center; justify-content: space-between; gap: 0.6rem; margin-bottom: 0.4rem; }
    .card-arrow {
      font-size: 1.2rem;
      color: var(--faint);
      transition: transform 0.2s ease, color 0.2s ease;
    }
    .card:hover .card-arrow { transform: translate(3px, -3px); color: hsl(var(--hue) 85% 70%); }

    .card h3 { margin: 0; font-size: 1.1rem; font-weight: 650; color: var(--text); }
    .card p { margin: 0.5rem 0 1.1rem; flex: 1; font-size: 0.9rem; color: var(--muted); }

    .tags { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: auto; }
    .tag {
      font-size: 0.72rem;
      color: var(--muted);
      padding: 0.18rem 0.6rem;
      border: 1px solid var(--border);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.03);
      white-space: nowrap;
    }

    footer {
      margin-top: 4rem;
      padding-top: 2rem;
      border-top: 1px solid var(--border);
      text-align: center;
      color: var(--faint);
      font-size: 0.85rem;
    }
    footer a { color: var(--muted); text-decoration: none; }
    footer a:hover { color: var(--accent); }

    @media (prefers-reduced-motion: reduce) {
      .bg::before, .bg::after { animation: none; }
      html { scroll-behavior: auto; }
    }
  </style>
</head>
<body>
  <div class="bg" aria-hidden="true"></div>
  <div class="wrap">
    <header>
      <span class="eyebrow">Open-source physics for the web</span>
      <h1>$ORG_DISPLAY</h1>
      <p>Interactive simulations for waves, mechanics, optics, electromagnetism, and quantum circuits &mdash; free to explore, remix, and teach with.</p>
      <div class="links">
        <a class="primary" href="#simulations">Browse simulations</a>
        <a href="https://github.com/$ORG">GitHub Organization</a>
        <a href="https://github.com/$ORG/.github/blob/main/CONTRIBUTING.md">Contributing</a>
      </div>
    </header>

    <main id="simulations">
HEADER

  cat <<SECTION
    <section>
      <div class="section-head">
        <h2>Core Simulations</h2>
        <span class="count">${new_count}</span>
      </div>
      <div class="grid">
SECTION

  while IFS= read -r line; do
    [[ -n "$line" ]] && card_html "$line"
  done <<<"$new_sims"

  cat <<SECTION
      </div>
    </section>

    <section>
      <div class="section-head">
        <h2>Classic &amp; PhET Ports</h2>
        <span class="count">${phet_count}</span>
      </div>
      <div class="grid">
SECTION

  while IFS= read -r line; do
    [[ -n "$line" ]] && card_html "$line"
  done <<<"$phet_sims"

  cat <<SECTION
      </div>
    </section>

    <section>
      <div class="section-head">
        <h2>NAAP Astronomy Labs</h2>
        <span class="count">${naap_count}</span>
      </div>
      <div class="grid">
SECTION

  while IFS= read -r line; do
    [[ -n "$line" ]] && card_html "$line"
  done <<<"$naap_sims"

  cat <<FOOTER
      </div>
    </section>
    </main>

    <footer>
      <p>${total_count} live simulations &middot; Built with <a href="https://scenerystack.org/">SceneryStack</a> &middot; GNU Affero GPL v3 &middot;
      <a href="https://github.com/$ORG/Baton">$ORG/Baton</a></p>
    </footer>
  </div>
</body>
</html>
FOOTER
} >"$OUTPUT"

echo "Wrote $OUTPUT"

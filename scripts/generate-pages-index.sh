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
# Each line: name|displayName|url|hue|subject|lineage|topics(comma-separated)@description
# A simulation without a subject lands in an "Other" group rather than being
# silently filed under a real discipline (check-repos-catalog.sh requires one).
all_sims="$(jq -r --arg base "$PAGES_BASE" '
  .repos[]
  | select(.isSimulation == true and .status == "active")
  | "\(.name)|\(.displayName // .name)|\(.deployedUrl // ($base + "/" + .name))|\((.name | explode | add) % 360)|\(.subject // "other")|\(.lineage // "original")|\(.physicsTopics | join(","))@\(.description)"
' "$REPOS_JSON" | sort)"

# Display order of the subject groups and filter chips. Keep in step with the
# subject enum in structure/repos.schema.json; "other" is the fallback bucket.
SUBJECT_ORDER=(physics chemistry astronomy earth-science other)
COLLECTION_ORDER=(original phet naap)

subject_label() {
  case "$1" in
    physics) echo "Physics" ;;
    chemistry) echo "Chemistry" ;;
    astronomy) echo "Astronomy" ;;
    earth-science) echo "Earth Science" ;;
    *) echo "Other" ;;
  esac
}

collection_label() {
  case "$1" in
    original) echo "Core Simulations" ;;
    phet) echo "Classic & PhET Ports" ;;
    naap) echo "NAAP Astronomy Labs" ;;
    *) echo "$1" ;;
  esac
}

# Short provenance note shown next to the subject on a card.
collection_note() {
  case "$1" in
    phet) echo "PhET port" ;;
    naap) echo "NAAP lab" ;;
    *) echo "" ;;
  esac
}

html_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# html_escape plus double quotes, for values placed inside attribute="...".
attr_escape() {
  html_escape "$1" | sed 's/"/\&quot;/g'
}

# Rows of $all_sims whose field number $1 equals $2 (fields are |-separated; the
# description after @ may contain anything, but the fields before it cannot).
sims_where() {
  [[ -z "$all_sims" ]] && return 0
  printf '%s\n' "$all_sims" | awk -F'|' -v f="$1" -v v="$2" '$f == v'
}

card_html() {
  local line="$1"
  local meta desc name title url hue subject lineage topics
  meta="${line%%@*}"
  desc="${line#*@}"
  IFS='|' read -r name title url hue subject lineage topics <<<"$meta"
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

  local meta_html note
  meta_html="$(subject_label "$subject")"
  note="$(collection_note "$lineage")"
  if [[ -n "$note" ]]; then meta_html+=" &middot; ${note}"; fi

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

  # data-* attributes drive the client-side filter/grouping script; data-topics
  # carries every topic (not just the three rendered tags) so search finds them.
  cat <<CARD
        <a class="card" href="${url}/" style="--hue: ${hue};" data-subject="${subject}" data-collection="${lineage}" data-topics="$(attr_escape "${topics//,/, }")">
          ${thumb_html}
          <div class="card-body">
            <span class="card-meta">${meta_html}</span>
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

total_count="$(count_lines "$all_sims")"

# Subjects that actually have simulations, in display order.
present_subjects=()
for subject in "${SUBJECT_ORDER[@]}"; do
  if [[ -n "$(sims_where 5 "$subject")" ]]; then present_subjects+=("$subject"); fi
done

# Collections that actually have simulations, in display order.
present_collections=()
for lineage in "${COLLECTION_ORDER[@]}"; do
  if [[ -n "$(sims_where 6 "$lineage")" ]]; then present_collections+=("$lineage"); fi
done

{
  cat <<HEADER
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="$ORG_DISPLAY — open-source interactive physics, chemistry, and astronomy simulations for the web.">
  <meta property="og:title" content="$ORG_DISPLAY Simulations">
  <meta property="og:description" content="Open-source interactive physics, chemistry, and astronomy simulations for the web.">
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

    [hidden] { display: none !important; }

    .sr-only {
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border: 0;
    }

    /* Filter toolbar (revealed by the script; without JS the page is grouped by subject) */
    .toolbar {
      display: flex;
      flex-direction: column;
      gap: 0.9rem;
      margin: 0 0 2.5rem;
      padding: 1rem 1.1rem;
      background: rgba(13, 19, 38, 0.82);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
    }
    @media (min-width: 720px) {
      .toolbar { position: sticky; top: 0.75rem; z-index: 10; }
    }

    .chips { display: flex; flex-wrap: wrap; gap: 0.5rem; }
    .chip {
      display: inline-flex;
      align-items: center;
      gap: 0.45rem;
      font: inherit;
      font-size: 0.88rem;
      font-weight: 500;
      color: var(--muted);
      padding: 0.4rem 0.95rem;
      border: 1px solid var(--border);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.03);
      cursor: pointer;
      transition: background 0.18s, border-color 0.18s, color 0.18s;
    }
    .chip:hover { color: var(--text); background: rgba(111, 155, 255, 0.12); border-color: rgba(111, 155, 255, 0.35); }
    .chip[aria-pressed="true"] {
      color: #fff;
      background: linear-gradient(135deg, #5b8def, #7c5bef);
      border-color: transparent;
    }
    .chip-count {
      font-size: 0.75rem;
      min-width: 1.6em;
      padding: 0 0.4rem;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.08);
      text-align: center;
    }
    .chip[aria-pressed="true"] .chip-count { background: rgba(255, 255, 255, 0.22); }

    .controls { display: flex; flex-wrap: wrap; gap: 0.6rem 1rem; align-items: center; }
    .field { display: inline-flex; align-items: center; gap: 0.5rem; font-size: 0.85rem; color: var(--faint); }
    .field-search { flex: 1 1 16rem; }
    .field input, .field select {
      font: inherit;
      font-size: 0.9rem;
      color: var(--text);
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 0.45rem 0.75rem;
    }
    .field input { width: 100%; }
    .field select option { background: var(--bg-2); color: var(--text); }
    .field input:focus-visible, .field select:focus-visible, .chip:focus-visible, .empty button:focus-visible {
      outline: 2px solid var(--accent);
      outline-offset: 2px;
    }
    .status { margin: 0; font-size: 0.82rem; color: var(--faint); }

    .empty { text-align: center; color: var(--muted); padding: 3rem 1rem; }
    .empty button {
      font: inherit;
      color: var(--text);
      margin-top: 0.5rem;
      padding: 0.5rem 1.1rem;
      border: 1px solid var(--border);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.05);
      cursor: pointer;
    }
    .empty button:hover { background: rgba(111, 155, 255, 0.16); }

    .card-meta {
      font-size: 0.7rem;
      font-weight: 600;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      color: hsl(var(--hue) 70% 72%);
      margin-bottom: 0.3rem;
    }

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
      <span class="eyebrow">Open-source science for the web</span>
      <h1>$ORG_DISPLAY</h1>
      <p>Interactive simulations for physics, chemistry, and astronomy &mdash; from waves, optics, and quantum mechanics to titrations, molecules, and the night sky &mdash; free to explore, remix, and teach with.</p>
      <div class="links">
        <a class="primary" href="#simulations">Browse simulations</a>
        <a href="https://github.com/$ORG">GitHub Organization</a>
        <a href="https://github.com/$ORG/.github/blob/main/CONTRIBUTING.md">Contributing</a>
      </div>
    </header>

    <main id="simulations">
      <div class="toolbar" id="sim-toolbar" hidden>
        <div class="chips" role="group" aria-label="Filter by subject">
          <button type="button" class="chip" data-subject-filter="all" aria-pressed="true">All <span class="chip-count">${total_count}</span></button>
HEADER

  for subject in "${present_subjects[@]}"; do
    printf '          <button type="button" class="chip" data-subject-filter="%s" aria-pressed="false">%s <span class="chip-count">%s</span></button>\n' \
      "$subject" "$(subject_label "$subject")" "$(count_lines "$(sims_where 5 "$subject")")"
  done

  cat <<TOOLBAR
        </div>
        <div class="controls">
          <label class="field field-search">
            <span class="sr-only">Search simulations</span>
            <input type="search" id="sim-search" placeholder="Search by name, topic, or keyword" autocomplete="off" spellcheck="false">
          </label>
          <label class="field">
            <span>Collection</span>
            <select id="sim-collection">
              <option value="all">All</option>
TOOLBAR

  for lineage in "${present_collections[@]}"; do
    printf '              <option value="%s">%s</option>\n' "$lineage" "$(html_escape "$(collection_label "$lineage")")"
  done

  cat <<TOOLBAR
            </select>
          </label>
          <label class="field">
            <span>Group by</span>
            <select id="sim-group">
              <option value="subject">Subject</option>
              <option value="collection">Collection</option>
              <option value="none">None (A&ndash;Z)</option>
            </select>
          </label>
        </div>
        <p class="status" id="sim-status" aria-live="polite"></p>
      </div>

      <div id="sim-groups">
TOOLBAR

  # Static fallback (and first paint): grouped by subject, A-Z by repo name.
  for subject in "${present_subjects[@]}"; do
    rows="$(sims_where 5 "$subject")"
    cat <<SECTION
      <section>
        <div class="section-head">
          <h2>$(html_escape "$(subject_label "$subject")")</h2>
          <span class="count">$(count_lines "$rows")</span>
        </div>
        <div class="grid">
SECTION
    while IFS= read -r line; do
      [[ -n "$line" ]] && card_html "$line"
    done <<<"$rows"
    cat <<SECTION
        </div>
      </section>
SECTION
  done

  # Label tables for the script, in display order.
  subjects_js=""
  for subject in "${present_subjects[@]}"; do
    subjects_js+="[\"$subject\", \"$(subject_label "$subject")\"], "
  done
  collections_js=""
  for lineage in "${present_collections[@]}"; do
    collections_js+="[\"$lineage\", \"$(collection_label "$lineage")\"], "
  done

  cat <<FOOTER
      </div>

      <div class="empty" id="sim-empty" hidden>
        <p>No simulations match these filters.</p>
        <button type="button" id="sim-reset">Clear filters</button>
      </div>
    </main>

    <footer>
      <p>${total_count} live simulations &middot; Built with <a href="https://scenerystack.org/">SceneryStack</a> &middot; GNU Affero GPL v3 &middot;
      <a href="https://github.com/$ORG/Baton">$ORG/Baton</a></p>
    </footer>
  </div>

  <script>
    // Subject filter, collection filter, search, and grouping. State is mirrored
    // in the query string (?subject=chemistry&group=collection&q=orbit) so a
    // filtered view can be shared as a link.
    (() => {
      const SUBJECTS = [${subjects_js%, }];
      const COLLECTIONS = [${collections_js%, }];
      const GROUPS = ["subject", "collection", "none"];

      const toolbar = document.getElementById("sim-toolbar");
      const groupsEl = document.getElementById("sim-groups");
      const search = document.getElementById("sim-search");
      const collectionSelect = document.getElementById("sim-collection");
      const groupSelect = document.getElementById("sim-group");
      const status = document.getElementById("sim-status");
      const empty = document.getElementById("sim-empty");
      const chips = Array.from(toolbar.querySelectorAll("[data-subject-filter]"));

      const fold = (s) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
      const cards = Array.from(groupsEl.querySelectorAll(".card"));
      for (const card of cards) {
        card.dataset.title = card.querySelector("h3").textContent;
        card.dataset.search = fold(card.textContent + " " + (card.dataset.topics || ""));
      }
      cards.sort((a, b) => a.dataset.title.localeCompare(b.dataset.title));

      const known = (value, list, fallback) => (list.includes(value) ? value : fallback);
      const params = new URLSearchParams(location.search);
      const state = {
        subject: known(params.get("subject"), SUBJECTS.map(([k]) => k), "all"),
        collection: known(params.get("collection"), COLLECTIONS.map(([k]) => k), "all"),
        group: known(params.get("group"), GROUPS, "subject"),
        q: params.get("q") || ""
      };

      function writeUrl() {
        const next = new URLSearchParams();
        if (state.subject !== "all") next.set("subject", state.subject);
        if (state.collection !== "all") next.set("collection", state.collection);
        if (state.group !== "subject") next.set("group", state.group);
        if (state.q.trim()) next.set("q", state.q.trim());
        const qs = next.toString();
        history.replaceState(null, "", (qs ? "?" + qs : location.pathname) + location.hash);
      }

      function section(label, list) {
        const el = document.createElement("section");
        const head = document.createElement("div");
        head.className = "section-head";
        const h2 = document.createElement("h2");
        h2.textContent = label;
        const count = document.createElement("span");
        count.className = "count";
        count.textContent = String(list.length);
        head.append(h2, count);
        const grid = document.createElement("div");
        grid.className = "grid";
        grid.append(...list);
        el.append(head, grid);
        return el;
      }

      function render() {
        const terms = fold(state.q).split(/\s+/).filter(Boolean);
        const base = cards.filter((c) =>
          (state.collection === "all" || c.dataset.collection === state.collection) &&
          terms.every((t) => c.dataset.search.includes(t))
        );

        for (const chip of chips) {
          const key = chip.dataset.subjectFilter;
          const n = key === "all" ? base.length : base.filter((c) => c.dataset.subject === key).length;
          chip.querySelector(".chip-count").textContent = String(n);
          chip.setAttribute("aria-pressed", String(key === state.subject));
        }

        const visible = base.filter((c) => state.subject === "all" || c.dataset.subject === state.subject);
        let groups;
        if (state.group === "subject") {
          groups = SUBJECTS.map(([key, label]) => [label, visible.filter((c) => c.dataset.subject === key)]);
        } else if (state.group === "collection") {
          groups = COLLECTIONS.map(([key, label]) => [label, visible.filter((c) => c.dataset.collection === key)]);
        } else {
          groups = [["All Simulations", visible]];
        }
        groupsEl.replaceChildren(...groups.filter(([, list]) => list.length > 0).map(([label, list]) => section(label, list)));

        empty.hidden = visible.length > 0;
        status.textContent = visible.length === cards.length
          ? "Showing all " + cards.length + " simulations"
          : "Showing " + visible.length + " of " + cards.length + " simulations";
        writeUrl();
      }

      for (const chip of chips) {
        chip.addEventListener("click", () => {
          state.subject = chip.dataset.subjectFilter;
          render();
        });
      }
      search.addEventListener("input", () => { state.q = search.value; render(); });
      collectionSelect.addEventListener("change", () => { state.collection = collectionSelect.value; render(); });
      groupSelect.addEventListener("change", () => { state.group = groupSelect.value; render(); });
      document.getElementById("sim-reset").addEventListener("click", () => {
        state.subject = "all";
        state.collection = "all";
        state.q = "";
        search.value = "";
        collectionSelect.value = "all";
        render();
        search.focus();
      });

      search.value = state.q;
      collectionSelect.value = state.collection;
      groupSelect.value = state.group;
      toolbar.hidden = false;
      render();
    })();
  </script>
</body>
</html>
FOOTER
} >"$OUTPUT"

echo "Wrote $OUTPUT"

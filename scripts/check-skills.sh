#!/usr/bin/env bash
# Validate the SceneryStack skills collection (Baton/skills/).
#
# Each skill is a folder containing a SKILL.md (the standard Claude Code layout, also
# what the scenerystack plugin ships — see .claude-plugin/). This enforces that every
# skill is well-formed and that the README index stays in sync with the folders on
# disk — the kind of drift that rots silently as the collection grows.
#
#   scripts/check-skills.sh
#
# Exit non-zero on any failure so CI can gate on it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$(cd "$SCRIPT_DIR/../skills" && pwd)"
README="$SKILLS_DIR/README.md"
PLUGIN_JSON="$BATON_ROOT/.claude-plugin/plugin.json"

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
pass() { echo "OK: $1"; }

[ -f "$README" ] || { echo "FAIL: skills/README.md is missing"; exit 1; }

# Collect skill folders (every directory holding a SKILL.md).
mapfile -t SKILL_DIRS < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

skill_count=0
for name in "${SKILL_DIRS[@]}"; do
  path="$SKILLS_DIR/$name/SKILL.md"
  if [ ! -f "$path" ]; then
    fail "$name/: folder has no SKILL.md"
    continue
  fi
  skill_count=$((skill_count + 1))

  # 1. Frontmatter block must open on line 1 and close.
  if [ "$(head -n1 "$path")" != "---" ]; then
    fail "$name: SKILL.md must start with a '---' frontmatter block on line 1"
    continue
  fi
  frontmatter="$(awk 'NR>1 && /^---[[:space:]]*$/{exit} NR>1{print}' "$path")"

  # 2. name: present and matches the folder name.
  fm_name="$(printf '%s\n' "$frontmatter" | sed -n 's/^name:[[:space:]]*//p' | head -n1)"
  if [ -z "$fm_name" ]; then
    fail "$name: frontmatter is missing a 'name:' field"
  elif [ "$fm_name" != "$name" ]; then
    fail "$name: frontmatter name '$fm_name' must match folder name '$name'"
  fi

  # 3. description: present, phrased as a trigger ("Use when/whenever/to …"),
  #    and substantial enough to actually disambiguate when the skill applies.
  fm_desc="$(printf '%s\n' "$frontmatter" | sed -n 's/^description:[[:space:]]*//p' | head -n1)"
  if [ -z "$fm_desc" ]; then
    fail "$name: frontmatter is missing a 'description:' field"
  else
    case "$fm_desc" in
      "Use "*) : ;;
      *) fail "$name: description should be a trigger starting with 'Use …'. Found: '${fm_desc:0:40}…'" ;;
    esac
    [ "${#fm_desc}" -ge 40 ] || fail "$name: description is too short to be a useful trigger (<40 chars)"
    [ "${#fm_desc}" -le 280 ] || fail "$name: description is too long for skill matching (>280 chars; ${#fm_desc})"
  fi

  # 4. TEMPLATE body sections.
  grep -q '^## Rules' "$path" || fail "$name: missing '## Rules' section"
  grep -q '^## Common mistakes' "$path" || fail "$name: missing '## Common mistakes' section"
  grep -q '^Related skills:' "$path" || fail "$name: missing footer 'Related skills:' line"

  # 5. Every scenerystack-* token in the body resolves to an existing skill folder.
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    [ -f "$SKILLS_DIR/$ref/SKILL.md" ] || fail "$name: references unknown skill '$ref'"
  done < <(grep -oE 'scenerystack-[a-z0-9-]+' "$path" | sort -u)

  # 6. Listed in the README index.
  if ! grep -q "\`$name\`" "$README"; then
    fail "$name: skill is not referenced in skills/README.md index"
  fi
done

# 7. Reverse direction: every scenerystack-* skill referenced in the README must exist.
mapfile -t REFERENCED < <(grep -oE 'scenerystack-[a-z0-9-]+' "$README" | sort -u)
for ref in "${REFERENCED[@]}"; do
  [ -f "$SKILLS_DIR/$ref/SKILL.md" ] || fail "README references '$ref' but skills/$ref/SKILL.md does not exist"
done

# 8. Each skill folder has exactly one README index link of the form [`name`](...).
for name in "${SKILL_DIRS[@]}"; do
  count="$(grep -cF "[\`$name\`]" "$README" || true)"
  [ "$count" -eq 1 ] || fail "$name: expected exactly one README index link [\`$name\`], found $count"
done

# 9. Plugin version must bump when skills change relative to origin/main (honor-system → CI).
if [ -f "$PLUGIN_JSON" ] && command -v git >/dev/null 2>&1; then
  if git -C "$BATON_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$BATON_ROOT" rev-parse --verify origin/main >/dev/null 2>&1; then
      changed="$(git -C "$BATON_ROOT" diff --name-only origin/main -- skills/ .claude-plugin/plugin.json 2>/dev/null || true)"
      skills_changed="$(printf '%s\n' "$changed" | grep -E '^skills/' || true)"
      if [ -n "$skills_changed" ]; then
        local_ver="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON" | head -n1)"
        main_ver="$(git -C "$BATON_ROOT" show origin/main:.claude-plugin/plugin.json 2>/dev/null \
          | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)"
        if [ -n "$main_ver" ] && [ "$local_ver" = "$main_ver" ]; then
          fail "skills/** changed vs origin/main but .claude-plugin/plugin.json version is still '$local_ver' — bump it"
        fi
      fi
    fi
  fi
fi

if [ "$FAIL" -ne 0 ]; then
  echo "Skills check failed."
  exit 1
fi

pass "validated $skill_count skill folder(s); README index in sync"
echo "Skills check passed."

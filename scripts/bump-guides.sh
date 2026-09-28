#!/bin/sh
# Refresh the pinned guide commits and digests in skills/iam-tools/SKILL.md from each tool repository's main.
# Prints PR notes (one section per changed guide, with its diff) to stdout; prints nothing when every pin is current.
#   usage: scripts/bump-guides.sh        needs: gh (authenticated), curl, shasum
set -eu

SKILL=skills/iam-tools/SKILL.md
ORG=act-security-labs

for t in iam-expand iam-shrink iam-convert iam-truth; do
  path="skills/$t/SKILL.md"
  new=$(gh api "repos/$ORG/$t/commits?path=$path&sha=main&per_page=1" -q '.[0].sha')
  sha=$(curl -fsSL --proto '=https' --max-redirs 0 "https://raw.githubusercontent.com/$ORG/$t/$new/$path" | shasum -a 256 | cut -d' ' -f1)
  old=$(grep -E "^\| \`$t\` \| \`[0-9a-f]{40}\` \| \`[0-9a-f]{64}\` \|$" "$SKILL" | tr -d '`|' | awk '{print $2}')
  [ "$old" = "$new" ] && continue
  sed -i.bak -E "s/^\| \`$t\` \| \`[0-9a-f]{40}\` \| \`[0-9a-f]{64}\` \|$/| \`$t\` | \`$new\` | \`$sha\` |/" "$SKILL"
  rm -f "$SKILL.bak"
  printf '## %s: %s -> %s\n\nhttps://github.com/%s/%s/compare/%s...%s\n\n```diff\n' "$t" "$(printf %.7s "$old")" "$(printf %.7s "$new")" "$ORG" "$t" "$old" "$new"
  gh api "repos/$ORG/$t/compare/$old...$new" -q ".files[] | select(.filename == \"$path\") | .patch"
  printf '```\n\n'
done

#!/bin/bash
set -exo pipefail

# --- Validate Environment ---
required_vars=("REPO_OWNER" "REPO_NAME" "GITHUB_TOKEN")
for var in "${required_vars[@]}"; do
  [ -z "${!var}" ] && { echo "Error: $var not set"; exit 1; }
done

# --- Git Setup ---
git fetch --tags --force >/dev/null
COMMIT_HASH=$(git rev-parse HEAD)

# --- Version Calculation ---
YEAR=$(date +'%y')
MONTH=$(date +'%-m')
DAY=$(date +'%-d')

LATEST_TAG=$(git tag --list --sort=-v:refname | head -n1)
if [[ -z "$LATEST_TAG" ]]; then
  NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.1"
  PREVIOUS_COMMIT="$(git rev-list --max-parents=0 HEAD)"
else
  PREVIOUS_COMMIT="$LATEST_TAG"
  if [[ "$LATEST_TAG" =~ v${YEAR}.${MONTH}.${DAY}.* ]]; then
    INCREMENT="${LATEST_TAG##*.}"
    NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.$((INCREMENT + 1))"
  else
    NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.1"
  fi
fi

# --- Get All Merged PRs Since Last Release ---
PR_SEARCH_URL="https://api.github.com/search/issues?q=repo:${REPO_OWNER}/${REPO_NAME}+is:pr+is:merged+merged:>$(git log -1 --format=%cd --date=iso8601 "$PREVIOUS_COMMIT")"
PR_DATA=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" "$PR_SEARCH_URL")

# --- Categorize PRs ---
declare -A CATEGORIES
declare -A TYPE_EMOJIS=(
  [feat]="✨ Features" [fix]="🐛 Fixes" [docs]="📝 Docs"
  [test]="🧪 Tests" [ci]="🔧 CI/CD" [cd]="🚀 Deployment"
  [task]="📌 Tasks" [chore]="🧹 Chores"
)

total_prs=$(echo "$PR_DATA" | jq '.items | length')
for (( i=0; i<total_prs; i++ )); do
  title=$(echo "$PR_DATA" | jq -r ".items[$i].title")
  number=$(echo "$PR_DATA" | jq -r ".items[$i].number")
  type=$(echo "$title" | cut -d: -f1 | tr '[:upper:]' '[:lower:]')
  
  [[ ! "$type" =~ ^(feat|fix|docs|test|ci|cd|task|chore)$ ]] && type="other"
  CATEGORIES["$type"]+="* #$number - ${title#*:}\n"
done

# --- Generate Release Notes ---
RELEASE_BODY="## What's Changed in ${NEW_VERSION}\n\n"

for type in "${!CATEGORIES[@]}"; do
  [[ "$type" == "other" ]] && continue
  emoji=${TYPE_EMOJIS[$type]:-📦 Other}
  RELEASE_BODY+="### ${emoji}\n${CATEGORIES[$type]}\n"
done

[[ -n "${CATEGORIES[other]}" ]] && 
  RELEASE_BODY+="### 📦 Other\n${CATEGORIES[other]}\n"

RELEASE_BODY+="\n**Full Changelog:** https://github.com/${REPO_OWNER}/${REPO_NAME}/compare/${PREVIOUS_COMMIT}...${NEW_VERSION}"

# --- Create Release ---
curl -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "$(jq -n \
    --arg tag "$NEW_VERSION" \
    --arg name "$NEW_VERSION" \
    --arg body "$RELEASE_BODY" \
    '{
      "tag_name": $tag,
      "name": $name,
      "body": $body,
      "draft": false,
      "prerelease": false
    }')" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases"

echo "✅ Release ${NEW_VERSION} created with ${total_prs} PRs!"
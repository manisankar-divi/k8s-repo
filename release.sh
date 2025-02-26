#!/bin/bash

# Exit on error and print commands
set -eo pipefail

# Validate environment variables
required_vars=("REPO_OWNER" "REPO_NAME" "GITHUB_TOKEN")
for var in "${required_vars[@]}"; do
  if [[ -z "${!var}" ]]; then
    echo "Error: $var environment variable must be set"
    exit 1
  fi
done

# Date components with zero-padded sequence
YEAR=$(date +'%y')
MONTH=$(date +'%-m')
DAY=$(date +'%-d')
SEQUENCE_LENGTH=3  # Supports up to 999 daily releases

# Fetch all tags from remote
git fetch --tags >/dev/null 2>&1

# Find latest tag for today using version sort
TODAYS_PATTERN="v${YEAR}.${MONTH}.${DAY}.*"
LATEST_TAG=$(git tag --list "$TODAYS_PATTERN" --sort=-version:refname | head -n1)

# Calculate next sequence number
if [[ -n "$LATEST_TAG" ]]; then
  CURRENT_SEQ=$(echo "$LATEST_TAG" | awk -F. '{print $4}')
  NEXT_SEQ=$(printf "%0${SEQUENCE_LENGTH}d" $((10#$CURRENT_SEQ + 1)))
else
  NEXT_SEQ=$(printf "%0${SEQUENCE_LENGTH}d" 1)
fi

NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.${NEXT_SEQ}"
echo "🔄 New Release Version: $NEW_VERSION"

# Find previous release (any version)
PREVIOUS_TAG=$(git tag --list --sort=-version:refname | grep -E '^v[0-9]{2}\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
echo "📌 Previous Release Version: ${PREVIOUS_TAG:-None}"

# Get all commits since last release
COMMITS_SINCE_LAST_RELEASE=$(
  if [[ -n "$PREVIOUS_TAG" ]]; then
    git log --pretty=format:"%H" "${PREVIOUS_TAG}..HEAD"
  else
    git log --pretty=format:"%H"
  fi
)

# Collect PR information
PR_CATEGORIES=()
declare -A CATEGORY_MAP=(
  ["feat"]="Features ✨"
  ["fix"]="Bug Fixes 🐛"
  ["docs"]="Documentation 📝"
  ["task"]="Tasks 📌"
  ["ci"]="CI/CD 🔧"
  ["cd"]="CI/CD 🔧"
  ["test"]="Tests 🧪"
)

while IFS= read -r commit_hash; do
  PR_DATA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/search/issues?q=repo:$REPO_OWNER/$REPO_NAME+is:pr+is:merged+sha:$commit_hash")

  PR_TITLE=$(echo "$PR_DATA" | jq -r '.items[0].title // empty')
  PR_NUMBER=$(echo "$PR_DATA" | jq -r '.items[0].number // empty')
  
  if [[ -n "$PR_TITLE" ]]; then
    PREFIX=$(echo "$PR_TITLE" | awk '{print tolower($1)}' | tr -d ':')
    CATEGORY=${CATEGORY_MAP["$PREFIX"]:-"Other 📂"}
    
    SHORT_HASH=$(echo "$commit_hash" | cut -c1-7)
    ENTRY="[#${PR_NUMBER}](${GITHUB_URL:-https://github.com}/$REPO_OWNER/$REPO_NAME/pull/$PR_NUMBER) - $PR_TITLE ([$SHORT_HASH](https://github.com/$REPO_OWNER/$REPO_NAME/commit/$commit_hash))"
    
    PR_CATEGORIES+=("$CATEGORY"$'\n'"- $ENTRY")
  fi
done <<< "$COMMITS_SINCE_LAST_RELEASE"

# Generate organized release notes
RELEASE_BODY="## What's Changed 🚀\n\n"
RELEASE_BODY+="**New Release Version**: $NEW_VERSION\n\n"

if [[ ${#PR_CATEGORIES[@]} -gt 0 ]]; then
  RELEASE_BODY+="$(printf "%s\n" "${PR_CATEGORIES[@]}" | sort -u | awk 'BEGIN {RS="\n\n"; FS="\n"; OFS="\n"} !seen[$1]++ {print $2}')\n"
else
  RELEASE_BODY+="No associated PRs found\n"
fi

# Create GitHub release
curl -sSfL -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases" \
  -d "$(jq -n \
    --arg tag "$NEW_VERSION" \
    --arg name "$NEW_VERSION" \
    --arg body "$RELEASE_BODY" \
    '{
      "tag_name": $tag,
      "name": $name,
      "body": $body,
      "draft": false,
      "prerelease": false,
      "generate_release_notes": false
    }')"

echo "✅ Release created successfully: $NEW_VERSION"

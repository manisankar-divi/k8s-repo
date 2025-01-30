#!/bin/bash

# Exit on errors
set -e
set -x

# Ensure environment variables are set
if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: Missing required environment variables."
  exit 1
fi

# Get today's date version
YEAR=$(date +'%y')
MONTH=$(date +'%-m')
DAY=$(date +'%-d')

# Fetch latest tag for today
git fetch --tags
LATEST_TAG=$(git tag --list "v${YEAR}.${MONTH}.${DAY}.*" --sort=-version:refname | head -n 1)

NEXT_INCREMENT=1
if [ -n "$LATEST_TAG" ]; then
  LATEST_INCREMENT=$(echo "$LATEST_TAG" | awk -F'.' '{print $NF}')
  NEXT_INCREMENT=$((LATEST_INCREMENT + 1))
fi

NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.${NEXT_INCREMENT}"
echo "New Release: $NEW_VERSION"

# Fetch merged PRs
PRS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls?state=closed")

# Initialize categories
FEAT_COMMITS=()
FIX_COMMITS=()
DOCS_COMMITS=()
TEST_COMMITS=()
CICD_COMMITS=()
TASK_COMMITS=()
OTHER_COMMITS=()

# Process each PR
for PR in $(echo "$PRS" | jq -r '.[] | select(.merged_at != null) | .number'); do
  PR_JSON=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR")

  PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
  PR_AUTHOR=$(echo "$PR_JSON" | jq -r '.user.login')

  # Fetch the merge commit (squash & merge)
  MAIN_COMMIT=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR/merge" | jq -r '.sha')

  SHORT_COMMIT=${MAIN_COMMIT:0:7} # Extract short commit hash

  # Format entry with squash and merge commit ID
  ENTRY="$SHORT_COMMIT: $PR_TITLE (#$PR)"

  # Categorize commits
  if [[ "$PR_TITLE" =~ ^feat: ]]; then
    FEAT_COMMITS+=("$ENTRY")
  elif [[ "$PR_TITLE" =~ ^fix: ]]; then
    FIX_COMMITS+=("$ENTRY")
  elif [[ "$PR_TITLE" =~ ^docs: ]]; then
    DOCS_COMMITS+=("$ENTRY")
  elif [[ "$PR_TITLE" =~ ^test: ]]; then
    TEST_COMMITS+=("$ENTRY")
  elif [[ "$PR_TITLE" =~ ^ci|cd: ]]; then
    CICD_COMMITS+=("$ENTRY")
  elif [[ "$PR_TITLE" =~ ^task: ]]; then
    TASK_COMMITS+=("$ENTRY")
  else
    OTHER_COMMITS+=("$ENTRY")
  fi
done

# Generate release notes
RELEASE_NOTES="### What's Changed\n"
RELEASE_NOTES="$RELEASE_NOTES\n## New Release: $NEW_VERSION\n"

generate_section() {
  local TITLE="$1"
  local COMMITS=("${!2}")

  if [ ${#COMMITS[@]} -gt 0 ]; then
    RELEASE_NOTES="$RELEASE_NOTES\n### $TITLE\n"
    for COMMIT in "${COMMITS[@]}"; do
      RELEASE_NOTES="$RELEASE_NOTES\n- $COMMIT"
    done
  fi
}

generate_section "Features ✨" FEAT_COMMITS[@]
generate_section "Bug Fixes 🐛" FIX_COMMITS[@]
generate_section "Documentation 📖" DOCS_COMMITS[@]
generate_section "Testing 🧪" TEST_COMMITS[@]
generate_section "CI/CD ⚙️" CICD_COMMITS[@]
generate_section "Tasks ✅" TASK_COMMITS[@]
generate_section "Other Changes" OTHER_COMMITS[@]

# Save to file
echo -e "$RELEASE_NOTES" >CHANGELOG.md

# Commit and push changes
git add CHANGELOG.md
git commit -m "Update CHANGELOG.md for release $NEW_VERSION"
git push origin main

# Tag and push
git tag "$NEW_VERSION"
git push origin "$NEW_VERSION"

# Create GitHub release
curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
  -d "{\"tag_name\": \"$NEW_VERSION\", \"name\": \"$NEW_VERSION\", \"body\": \"$RELEASE_NOTES\", \"draft\": false, \"prerelease\": false}" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases"

echo "Release published: $NEW_VERSION"

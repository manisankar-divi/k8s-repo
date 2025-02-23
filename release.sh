#!/bin/bash
set -eux

# --- Environment Checks ---
[ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ] && { echo "Error: REPO_OWNER/REPO_NAME not set"; exit 1; }
[ -z "$GITHUB_TOKEN" ] && { echo "Error: GITHUB_TOKEN not set"; exit 1; }

# --- Date Components (Fixed) ---
YEAR=$(date -u +'%y')     # 24 for 2024
MONTH=$(date -u +'%m')    # 03 for March
DAY=$(date -u +'%d')      # 01 for 1st
MONTH=${MONTH#0}          # Remove leading zero → 3
DAY=${DAY#0}              # Remove leading zero → 1

# --- Fetch Tags ---
git fetch --tags >/dev/null 2>&1

# --- Get Latest Tag for Today ---
LATEST_TAG=$(git tag --list "v${YEAR}.${MONTH}.${DAY}.*" | awk -F. '{print $NF,$0}' | sort -nr | head -1 | cut -d' ' -f2)
NEXT_INCREMENT=$(( ${LATEST_TAG##*.:-0} + 1 ))

NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.${NEXT_INCREMENT}"
echo "New release version: $NEW_VERSION"

# ... rest of your script ...
# Step 2: Fetch the previous release tag for changelog link (not today)
PREVIOUS_TAG=$(git tag --list | grep -v "v${YEAR}.${MONTH}.${DAY}." | sort -V | tail -n1)

if [ -z "$PREVIOUS_TAG" ]; then
  FULL_CHANGELOG_LINK="No previous version found for diff comparison."
else
  FULL_CHANGELOG_LINK="https://github.com/$REPO_OWNER/$REPO_NAME/compare/$PREVIOUS_TAG...$NEW_VERSION"
fi

# Step 3: Get the latest commit hash (HEAD) after merging
LAST_COMMIT_HASH=$(git rev-parse HEAD)

# Step 4: Find the PR associated with this merge commit
MERGED_PR=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls?state=closed&sort=updated&direction=desc" | \
  jq -r --arg HASH "$LAST_COMMIT_HASH" '.[] | select(.merge_commit_sha == $HASH)')

# Extract PR title
PR_TITLE=$(echo "$MERGED_PR" | jq -r '.title')

if [[ -z "$PR_TITLE" || "$PR_TITLE" == "null" ]]; then
  echo "Error: No matching PR found for commit $LAST_COMMIT_HASH."
  exit 1
fi

# Step 5: Categorize PR title based on type
case "$PR_TITLE" in
"feat"*) CATEGORY="Features ✨" ;;
"fix"*) CATEGORY="Bug Fixes 🐛" ;;
"docs"*) CATEGORY="Documentation 📝" ;;
"task"*) CATEGORY="Tasks 📌" ;;
"ci"* | "cd"*) CATEGORY="CI/CD 🔧" ;;
"test"*) CATEGORY="Tests 🧪" ;;
*) CATEGORY="Other 📂" ;;
esac

# Shorten commit hash for display
SHORT_COMMIT_HASH=$(echo "$LAST_COMMIT_HASH" | cut -c1-7)

# Step 6: Generate release notes
RELEASE_NOTES="*What's Changed* 🚀\n"
RELEASE_NOTES="$RELEASE_NOTES\n 🔄 *New Release:* $NEW_VERSION\n"
RELEASE_NOTES="$RELEASE_NOTES\n *$CATEGORY* \n- *[$SHORT_COMMIT_HASH](https://github.com/$REPO_OWNER/$REPO_NAME/commit/$LAST_COMMIT_HASH)*: $PR_TITLE\n\n"

# Step 7: Output release notes
echo -e "$RELEASE_NOTES"

# Step 8: Create GitHub release
curl -X POST -H "Authorization: token $GITHUB_TOKEN" \
  -d "{\"tag_name\": \"$NEW_VERSION\", \"name\": \"$NEW_VERSION\", \"body\": \"$RELEASE_NOTES\"}" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases"

echo "✅ Release notes generated and release created successfully!"

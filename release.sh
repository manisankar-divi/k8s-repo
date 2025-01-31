#!/bin/bash

# Exit script on error
set -e
set -x

# Ensure required environment variables are set
if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
  echo "Error: REPO_OWNER and REPO_NAME environment variables must be set."
  exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN environment variable is not set. Exiting."
  exit 1
fi

# Step 1: Get the current date in YYYY.M.D format (no leading zeros)
CURRENT_DATE=$(date +'%Y.%m.%d')

# Extract YEAR, MONTH, DAY without leading zeros
YEAR=$(date +'%y')   # Last two digits (e.g., 25 for 2025)
MONTH=$(date +'%-m') # Remove leading zeros (e.g., 1 for January)
DAY=$(date +'%-d')   # Remove leading zeros (e.g., 5 for 5th)

# Fetch all tags from the remote repository to ensure they're available locally
git fetch --tags

# Get all tags of the form v<year>.<month>.<day>.<increment> (e.g., v25.1.31.9)
LATEST_TAGS=$(git tag --list "v${YEAR}.${MONTH}.${DAY}.*" | sort -V | tail -n 1)

# Extract the incremental part (e.g., 9 from v25.1.31.9)
if [ -z "$LATEST_TAGS" ]; then
  NEXT_INCREMENT=1
else
  # Extract the increment from the latest tag (e.g., v25.1.31.9 -> 9)
  LATEST_INCREMENT=$(echo "$LATEST_TAGS" | awk -F'.' '{print $NF}')
  NEXT_INCREMENT=$((LATEST_INCREMENT + 1))
fi

# Format the new version with leading zeros for the increment (e.g., 10 → 10)
NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.${NEXT_INCREMENT}"

echo "New release to publish: $NEW_VERSION"

# Step 2: Fetch the commits for the current release (make sure you use valid commit ranges)
# Ensure that both the previous tag and the new tag exist
if git rev-parse "$LATEST_TAGS" >/dev/null 2>&1 && git rev-parse "$NEW_VERSION" >/dev/null 2>&1; then
  COMMITS=$(git log "$LATEST_TAGS".."$NEW_VERSION" --oneline)
else
  echo "Error: One of the tags $LATEST_TAGS or $NEW_VERSION does not exist in the repository."
  exit 1
fi

# Check if there are any commits (this would be the case for a new release)
if [ -z "$COMMITS" ]; then
  FULL_CHANGELOG="No changes in this release."
else
  # Format the list of commits to include in the changelog
  FULL_CHANGELOG=$(echo "$COMMITS" | while read commit; do
    SHORT_COMMIT_HASH=$(echo "$commit" | cut -d ' ' -f 1)
    COMMIT_MESSAGE=$(echo "$commit" | cut -d ' ' -f 2-)
    echo "- *[$SHORT_COMMIT_HASH](https://github.com/$REPO_OWNER/$REPO_NAME/commit/$SHORT_COMMIT_HASH)*: $COMMIT_MESSAGE"
  done)
fi

# Step 3: Generate release notes with emojis
RELEASE_NOTES="*What's Changed* 🚀\n"
RELEASE_NOTES="$RELEASE_NOTES\n 🔄 *New Release:* $NEW_VERSION\n"

# Categorize commits based on type
case "$COMMIT_TYPE" in
"feat") CATEGORY="Features ✨" ;;
"fix") CATEGORY="Bug Fixes 🐛" ;;
"docs") CATEGORY="Documentation 📝 " ;;
"task") CATEGORY="Tasks 📌" ;;
"ci" | "cd") CATEGORY="CI/CD 🔧" ;;
"test") CATEGORY="Tests 🧪 " ;;
*) CATEGORY="Other 📂" ;;
esac

# Append commit message with emojis
RELEASE_NOTES="$RELEASE_NOTES\n *$CATEGORY* \n$FULL_CHANGELOG\n"

# Output release notes
echo -e "$RELEASE_NOTES"

curl -X POST -H "Authorization: token $GITHUB_TOKEN" \
  -d "{\"tag_name\": \"$NEW_VERSION\", \"name\": \"$NEW_VERSION\", \"body\": \"$RELEASE_NOTES\"}" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases"

echo "✅ Release notes generated and release created successfully!"

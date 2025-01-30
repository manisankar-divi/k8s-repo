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

# Fetch tags and find the latest increment for the current day
git fetch --tags

# Get all tags of the form v<year>.<month>.<day>.<increment> (e.g., v25.1.30.9)
LATEST_TAGS=$(git tag --list "v${YEAR}.${MONTH}.${DAY}.*" | sort -V | tail -n 1)

# Extract the incremental part (e.g., 9 from v25.1.30.9)
if [ -z "$LATEST_TAGS" ]; then
  NEXT_INCREMENT=1
else
  # Extract the increment from the latest tag
  LATEST_INCREMENT=$(echo "$LATEST_TAGS" | awk -F'.' '{print $NF}')
  NEXT_INCREMENT=$((LATEST_INCREMENT + 1))
fi

# Format the new version with leading zeros for the increment (e.g., 10 → 10)
NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.${NEXT_INCREMENT}"
PREVIOUS_VERSION="${LATEST_TAGS:-None}"

echo "New release to publish: $NEW_VERSION"
echo "Previous release: $PREVIOUS_VERSION"

# Step 2: Fetch the latest closed PR and categorize commits based on PR title
PR_TITLE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls?state=closed" | jq -r '.[0].title')

# Check if PR title matches required format
if [[ "$PR_TITLE" =~ ^(feat|fix|docs|test|ci|cd|task): ]]; then
  COMMIT_TYPE=$(echo "$PR_TITLE" | awk -F ':' '{print $1}')
else
  echo "Error: PR title does not match required format."
  exit 1
fi

# Step 3: Get the squash commit (single commit from squashed PR)
SQUASH_COMMIT_HASH=$(git log -n 1 --pretty=format:"%H")

# Fetch commit message
SQUASH_COMMIT_MESSAGE=$(git log -n 1 --pretty=format:"%s" "$SQUASH_COMMIT_HASH")
SQUASH_COMMIT_AUTHOR=$(git log -n 1 --pretty=format:"%aN")

# Clean the commit message
CLEAN_COMMIT_MESSAGE=$(echo "$SQUASH_COMMIT_MESSAGE" | sed 's/ (.*)//g')

# Shorten commit hash
SHORT_COMMIT_HASH=$(echo "$SQUASH_COMMIT_HASH" | cut -c1-7)

# Step 4: Generate release notes with emojis
RELEASE_NOTES="🚀 *What's Changed* \n\n"
RELEASE_NOTES="$RELEASE_NOTES\n\n 🔄 *Previous Release:* $PREVIOUS_VERSION ➝ *New Release:* $NEW_VERSION\n"

# Categorize commits based on type
case "$COMMIT_TYPE" in
"feat") CATEGORY="✨ Features✨" ;;
"fix") CATEGORY="🐛 Bug Fixes" ;;
"docs") CATEGORY="📝 Documentation" ;;
"task") CATEGORY="📌 Tasks" ;;
"ci" | "cd") CATEGORY="🔧 CI/CD" ;;
"test") CATEGORY="🧪 Tests" ;;
*) CATEGORY="📂 Other" ;;
esac

# Append commit message with emojis
RELEASE_NOTES="$RELEASE_NOTES\n *$CATEGORY* \n- *[$SHORT_COMMIT_HASH](https://github.com/$REPO_OWNER/$REPO_NAME/commit/$SQUASH_COMMIT_HASH)*: $CLEAN_COMMIT_MESSAGE"

# Add Full Changelog link
if [ "$PREVIOUS_VERSION" != "None" ]; then
  FULL_CHANGELOG_LINK="https://github.com/$REPO_OWNER/$REPO_NAME/compare/$PREVIOUS_VERSION...$NEW_VERSION"
  RELEASE_NOTES="$RELEASE_NOTES\n📜 *Full Changelog:* [$PREVIOUS_VERSION...$NEW_VERSION]($FULL_CHANGELOG_LINK)"
else
  RELEASE_NOTES="$RELEASE_NOTES\n📜 *Full Changelog:* No previous version found for diff comparison."
fi

# Output release notes
echo -e "$RELEASE_NOTES"

# Step 5: Update CHANGELOG.md
echo -e "$RELEASE_NOTES\n$(cat changelog.md)" >changelog.md

# Commit and push changelog update
git add changelog.md
git commit -m "📜 Update changelog for $NEW_VERSION release"
git push origin main # Change 'main' to your branch name if different

# Step 6: Create GitHub Release
curl -X POST -H "Authorization: token $GITHUB_TOKEN" \
  -d "{\"tag_name\": \"$NEW_VERSION\", \"name\": \"$NEW_VERSION\", \"body\": \"$RELEASE_NOTES\"}" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases"

echo "✅ Release notes generated, changelog updated, and release created successfully!"

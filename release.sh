#!/usr/bin/env bash
# Exit script on error
set -e
set -x

# Ensure required environment variables are set
: "${REPO_OWNER:?REPO_OWNER is not set}"
: "${REPO_NAME:?REPO_NAME is not set}"
: "${PERSONAL_ACCESS_TOKEN:?PERSONAL_ACCESS_TOKEN is not set}"

# Retrieve the current branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "production" ]]; then
  echo "Current branch is '$CURRENT_BRANCH'. Release can only be made from 'production' branch."
  exit 1
fi

# Retrieve the latest commit subject and body
LAST_COMMIT_SUBJECT=$(git log -1 --format=%s)
LAST_COMMIT_BODY=$(git log -1 --format=%b)

# Validate commit message format
if [[ ! "$LAST_COMMIT_SUBJECT" =~ ^(fix:|feat:|patch:|docs:|task:|ci:|cd:|test:|add:|remove:|update:) ]]; then
  echo "Invalid commit message format. Must start with a valid prefix."
  exit 1
fi

echo "Valid commit message detected. Proceeding with release process..."

# Extract description from commit body
DESCRIPTION=$(echo "$LAST_COMMIT_BODY" | sed -n '/^Description:-/,$p' | sed -n 's/^[[:space:]]*-\s*//p')

# Generate version components
YEAR=$(date +%y)
MONTH=$(date +%-m)
DAY=$(date +%-d)

# Fetch tags and determine the next version
git fetch --tags
LATEST_TAG=$(git tag --list "v$YEAR.$MONTH.$DAY.*" | sort -t. -k4 -n | tail -n1)
if [[ -z "$LATEST_TAG" ]]; then
  NEXT_INCREMENT=1
else
  NEXT_INCREMENT=$(($(echo "$LATEST_TAG" | awk -F. '{print $4}') + 1))
fi
NEW_VERSION="v$YEAR.$MONTH.$DAY.$NEXT_INCREMENT"
echo "🚀 New version: $NEW_VERSION"

# Determine the previous tag for changelog
PREVIOUS_TAG=$(git tag --list | grep -v "^v$YEAR\.$MONTH\.$DAY\." | sort -V | tail -n1)

# Retrieve short commit hash
SHORT_COMMIT_HASH=$(git rev-parse --short HEAD)

# Determine release category based on commit subject
case "$LAST_COMMIT_SUBJECT" in
fix:*) CATEGORY='Bug Fixes 🐛' ;;
feat:*) CATEGORY='Features ✨' ;;
patch:*) CATEGORY='Patches 🔧' ;;
docs:*) CATEGORY='Documentation 📚' ;;
task:*) CATEGORY='Tasks 📝' ;;
ci:*) CATEGORY='CI Improvements ⚙️' ;;
cd:*) CATEGORY='CD Improvements 🚀' ;;
test:*) CATEGORY='Tests ✅' ;;
add:*) CATEGORY='Added ➕' ;;
remove:*) CATEGORY='Removed ➖' ;;
update:*) CATEGORY='Updated ♻️' ;;
*) CATEGORY='Miscellaneous 🧩' ;;
esac

# Construct release notes
RELEASE_NOTES="*What's Changed* 🚀

🔄 *New Release:* $NEW_VERSION

*$CATEGORY*
- *[$SHORT_COMMIT_HASH](https://github.com/$REPO_OWNER/$REPO_NAME/commit/$SHORT_COMMIT_HASH)*: $LAST_COMMIT_SUBJECT"

if [[ -n "$DESCRIPTION" ]]; then
  RELEASE_NOTES+="

*Description:*
- $DESCRIPTION"
fi

RELEASE_NOTES+="

Full Changelog: $FULL_CHANGELOG_LINK"

# Create JSON payload for the release
payload=$(jq -n \
  --arg tag "$NEW_VERSION" \
  --arg name "$NEW_VERSION" \
  --arg body "$RELEASE_NOTES" \
  '{tag_name: $tag, name: $name, body: $body}')

# Make API call to create the release
response=$(curl -sSL -X POST \
  -H "Authorization: token $PERSONAL_ACCESS_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d "$payload" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases")

# Check for errors in the response
if echo "$response" | jq -e '.message' >/dev/null; then
  echo "Error creating release:"
  echo "$response" | jq '.message'
  exit 1
fi

echo "Release $NEW_VERSION created successfully."


# #!/bin/bash

# # Exit script on error
# set -e
# set -x

# # Ensure required environment variables are set
# if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
#   echo "Error: REPO_OWNER and REPO_NAME environment variables must be set."
#   exit 1
# fi

# if [ -z "$GITHUB_TOKEN" ]; then
#   echo "Error: GITHUB_TOKEN environment variable is not set. Exiting."
#   exit 1
# fi

# # Get the current branch
# CURRENT_BRANCH=$(git branch --show-current)

# # Ensure we are merging from master to production
# if [[ "$CURRENT_BRANCH" != "production" ]]; then
#   echo "Not on production branch. Skipping release process."
#   exit 1
# fi

# # Get the last commit message
# LAST_COMMIT_MESSAGE=$(git log -1 --format=%s)

# # Check if commit message starts with fix:, feat:, or patch:
# if [[ ! "$LAST_COMMIT_MESSAGE" =~ ^(fix:|feat:|patch:|docs:|task:|ci:|cd:|test:) ]]; then
#   echo "Commit message does not match fix:, feat:, patch:, docs:, task:, ci:, cd:, or test:. Skipping release process."
#   exit 1
# fi

# echo "Valid commit message detected. Proceeding with release process..."

# # Get date components
# YEAR=$(date +'%y')   # Last 2 digits of year (25)
# MONTH=$(date +'%-m') # Month without leading zero (1-12)
# DAY=$(date +'%-d')   # Day without leading zero (1-31)

# # Fetch all tags
# git fetch --tags >/dev/null 2>&1

# # List all relevant tags for debugging
# echo "📌 Available tags:"
# git tag --list "v${YEAR}.${MONTH}.${DAY}.*"

# # Get latest increment for today's pattern
# LATEST_TAG=$(git tag --list "v${YEAR}.${MONTH}.${DAY}.*" | sort -t. -k4 -n | tail -n1)
# echo "✅ Latest tag for today: $LATEST_TAG"

# if [[ -z "$LATEST_TAG" ]]; then
#   # No existing tags for today
#   NEXT_INCREMENT=1
# else
#   # Extract current increment and add 1
#   LATEST_INCREMENT="${LATEST_TAG##*.}"
#   NEXT_INCREMENT=$((LATEST_INCREMENT + 1))
# fi

# # Format new version
# NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.${NEXT_INCREMENT}"
# echo "🚀 New version: $NEW_VERSION"

# # Step 2: Fetch the previous release tag for changelog link (not today)
# PREVIOUS_TAG=$(git tag --list | grep -v "v${YEAR}.${MONTH}.${DAY}." | sort -V | tail -n1)

# if [ -z "$PREVIOUS_TAG" ]; then
#   FULL_CHANGELOG_LINK="No previous version found for diff comparison."
# else
#   FULL_CHANGELOG_LINK="https://github.com/$REPO_OWNER/$REPO_NAME/compare/$PREVIOUS_TAG...$NEW_VERSION"
# fi

# # Step 3: Get the latest commit hash (HEAD) after merging
# #LAST_COMMIT_HASH=$(git rev-parse HEAD)
# #git log -1 --oneline | awk '{print $1}'

# # Shorten commit hash for display
# SHORT_COMMIT_HASH=$(git log -1 --oneline | awk '{print $1}')
# echo "Short Commit Hash: $SHORT_COMMIT_HASH"

# # Step 4: Categorize commit message based on type
# case "$LAST_COMMIT_MESSAGE" in
# "feat"*) CATEGORY="Features ✨" ;;
# "fix"*) CATEGORY="Bug Fixes 🐛" ;;
# "docs"*) CATEGORY="Documentation 📝" ;;
# "task"*) CATEGORY="Tasks 📌" ;;
# "ci"* | "cd"*) CATEGORY="CI/CD 🔧" ;;
# "test"*) CATEGORY="Tests 🧪" ;;
# "patch"*) CATEGORY="Patches 🩹" ;;
# *) CATEGORY="Other 📂" ;;
# esac

# # Step 5: Generate release notes
# RELEASE_NOTES="*What's Changed* 🚀\n"
# RELEASE_NOTES="$RELEASE_NOTES\n 🔄 *New Release:* $NEW_VERSION\n"
# RELEASE_NOTES="$RELEASE_NOTES\n *$CATEGORY* \n- *[$SHORT_COMMIT_HASH](https://github.com/$REPO_OWNER/$REPO_NAME/commit/$SHORT_COMMIT_HASH)*: $LAST_COMMIT_MESSAGE\n\n"

# # Step 6: Output release notes
# echo -e "$RELEASE_NOTES"

# # Step 7: Create GitHub release
# curl -X POST -H "Authorization: token $GITHUB_TOKEN" \
#   -d "{\"tag_name\": \"$NEW_VERSION\", \"name\": \"$NEW_VERSION\", \"body\": \"$RELEASE_NOTES\"}" \
#   "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases"

# echo "✅ Release notes generated and release created successfully!"
##

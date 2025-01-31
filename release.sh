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

# Get date components
YEAR=$(date +'%y')   # Last 2 digits of year (25)
MONTH=$(date +'%-m') # Month without leading zero (1-12)
DAY=$(date +'%-d')   # Day without leading zero (1-31)

# Fetch all tags
git fetch --tags >/dev/null 2>&1

# Get latest increment for today's pattern
LATEST_TAG=$(git tag --list "v${YEAR}.${MONTH}.${DAY}.*" | sort -t. -k4 -n | tail -n1)

if [[ -z "$LATEST_TAG" ]]; then
  # No existing tags for today
  NEXT_INCREMENT=1
else
  # Extract current increment and add 1
  LATEST_INCREMENT="${LATEST_TAG##*.}"
  NEXT_INCREMENT=$((LATEST_INCREMENT + 1))
fi

# Format new version
NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.${NEXT_INCREMENT}"

echo "New release version: $NEW_VERSION"

# Step 2: Fetch the previous release tag to use in changelog link
PREVIOUS_TAG=$(git tag --list "v${YEAR}.${MONTH}.${DAY}.*" | sort -V | tail -n 2 | head -n 1)
# Step 2: Fetch the previous release tag (last release from any day)
PREVIOUS_TAG=$(git tag --list | grep -v "v${YEAR}.${MONTH}.${DAY}." | sort -V | tail -n1)

if [ -z "$PREVIOUS_TAG" ]; then
  # No previous release found in entire history
  FULL_CHANGELOG_LINK="No previous version found for diff comparison."
else
  # Verify previous tag is actually older than new version
  if git merge-base --is-ancestor "$PREVIOUS_TAG" "$NEW_VERSION"; then
    FULL_CHANGELOG_LINK="https://github.com/$REPO_OWNER/$REPO_NAME/compare/$PREVIOUS_TAG...$NEW_VERSION"
  else
    FULL_CHANGELOG_LINK="Invalid version sequence - previous tag is not ancestor"
  fi
fi

echo "$PREVIOUS_TAG"
# Step 3: Fetch the latest closed PR and categorize commits based on PR title
PR_TITLE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls?state=closed" | jq -r '.[0].title')

# Check if PR title matches required format
if [[ "$PR_TITLE" =~ ^(feat|fix|docs|test|ci|cd|task): ]]; then
  COMMIT_TYPE=$(echo "$PR_TITLE" | awk -F ':' '{print $1}')
else
  echo "Error: PR title does not match required format."
  exit 1
fi

# Step 4: Get the squash commit (single commit from squashed PR)
SQUASH_COMMIT_HASH=$(git log -n 1 --pretty=format:"%H")

# Fetch commit message
SQUASH_COMMIT_MESSAGE=$(git log -n 1 --pretty=format:"%s" "$SQUASH_COMMIT_HASH")
SQUASH_COMMIT_AUTHOR=$(git log -n 1 --pretty=format:"%aN")

# Clean the commit message
CLEAN_COMMIT_MESSAGE=$(echo "$SQUASH_COMMIT_MESSAGE" | sed 's/ (.*)//g')

# Shorten commit hash
SHORT_COMMIT_HASH=$(echo "$SQUASH_COMMIT_HASH" | cut -c1-7)

# Step 5: Generate release notes with emoji
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
RELEASE_NOTES="$RELEASE_NOTES\n *$CATEGORY* \n- *[$SHORT_COMMIT_HASH](https://github.com/$REPO_OWNER/$REPO_NAME/commit/$SQUASH_COMMIT_HASH)*: $CLEAN_COMMIT_MESSAGE\n"

# Add Full Changelog link to the current version
RELEASE_NOTES="$RELEASE_NOTES\n📜 *Full Changelog:* [$NEW_VERSION](https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$NEW_VERSION)"

# Output release notes
echo -e "$RELEASE_NOTES"

curl -X POST -H "Authorization: token $GITHUB_TOKEN" \
  -d "{\"tag_name\": \"$NEW_VERSION\", \"name\": \"$NEW_VERSION\", \"body\": \"$RELEASE_NOTES\"}" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases"

echo "✅ Release notes generated and release created successfully!"

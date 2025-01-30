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

# Fetch tags and find the latest increment for the day
git fetch --tags
LATEST_TAG=$(git tag --list "v${YEAR}.${MONTH}.${DAY}.*" --sort=-version:refname | head -n 1)

# Extract the incremental part (pad with leading zeros for sorting)
if [ -z "$LATEST_TAG" ]; then
  NEXT_INCREMENT=1
else
  LATEST_INCREMENT=$(echo "$LATEST_TAG" | awk -F'.' '{print $NF}')
  NEXT_INCREMENT=$((LATEST_INCREMENT + 1))
fi

# Format the new version with leading zeros for the increment (e.g., 10 → 10)
NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.${NEXT_INCREMENT}"

echo "New release to publish: $NEW_VERSION"

# Step 2: Collect all commits in the PRs and categorize them based on PR title
# Fetch all closed PRs
PRS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls?state=closed")

# Initialize arrays to store commit hashes and messages
FEAT_COMMITS=()
FIX_COMMITS=()
DOCS_COMMITS=()
TEST_COMMITS=()
CICD_COMMITS=()
TASK_COMMITS=()
OTHER_COMMITS=()

# Loop through all closed PRs and categorize commits based on PR title
for PR in $(echo "$PRS" | jq -r '.[] | select(.merged_at != null) | .number'); do
  # Get the PR title
  PR_TITLE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR" | jq -r '.title')

  # Get the commit for the PR (this is the squashed commit)
  COMMIT_HASH=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR/merge" | jq -r '.sha')

  # Determine the commit type from PR title and categorize
  if [[ "$PR_TITLE" =~ ^feat: ]]; then
    CATEGORY="Features ✨"
    COMMIT_LIST=FEAT_COMMITS
  elif [[ "$PR_TITLE" =~ ^fix: ]]; then
    CATEGORY="Bug Fixes 🐛"
    COMMIT_LIST=FIX_COMMITS
  elif [[ "$PR_TITLE" =~ ^docs: ]]; then
    CATEGORY="Documentation 📝"
    COMMIT_LIST=DOCS_COMMITS
  elif [[ "$PR_TITLE" =~ ^test: ]]; then
    CATEGORY="Tests 🧪"
    COMMIT_LIST=TEST_COMMITS
  elif [[ "$PR_TITLE" =~ ^ci/cd: || "$PR_TITLE" =~ ^ci: || "$PR_TITLE" =~ ^cd: ]]; then
    CATEGORY="CI/CD 🔧"
    COMMIT_LIST=CICD_COMMITS
  elif [[ "$PR_TITLE" =~ ^task: ]]; then
    CATEGORY="Tasks 🗒️"
    COMMIT_LIST=TASK_COMMITS
  else
    CATEGORY="Other Changes"
    COMMIT_LIST=OTHER_COMMITS
  fi

  # Add the squashed commit to the respective list with the PR title
  if [ "$COMMIT_LIST" == "FEAT_COMMITS" ]; then
    FEAT_COMMITS+=("$COMMIT_HASH: $PR_TITLE")
  elif [ "$COMMIT_LIST" == "FIX_COMMITS" ]; then
    FIX_COMMITS+=("$COMMIT_HASH: $PR_TITLE")
  elif [ "$COMMIT_LIST" == "DOCS_COMMITS" ]; then
    DOCS_COMMITS+=("$COMMIT_HASH: $PR_TITLE")
  elif [ "$COMMIT_LIST" == "TEST_COMMITS" ]; then
    TEST_COMMITS+=("$COMMIT_HASH: $PR_TITLE")
  elif [ "$COMMIT_LIST" == "CICD_COMMITS" ]; then
    CICD_COMMITS+=("$COMMIT_HASH: $PR_TITLE")
  elif [ "$COMMIT_LIST" == "TASK_COMMITS" ]; then
    TASK_COMMITS+=("$COMMIT_HASH: $PR_TITLE")
  else
    OTHER_COMMITS+=("$COMMIT_HASH: $PR_TITLE")
  fi
done

# Step 3: Generate release notes
RELEASE_NOTES="### What's Changed\n"
RELEASE_NOTES="$RELEASE_NOTES\n#### New Release: $NEW_VERSION\n"

# Add feature commits to release notes if there are any
if [ ${#FEAT_COMMITS[@]} -gt 0 ]; then
  RELEASE_NOTES="$RELEASE_NOTES\n#### Features ✨\n"
  for COMMIT in "${FEAT_COMMITS[@]}"; do
    RELEASE_NOTES="$RELEASE_NOTES\n- [${COMMIT%%:*}](https://github.com/$REPO_OWNER/$REPO_NAME/commit/${COMMIT%%:*}): ${COMMIT#*:}"
  done
fi

# Add fix commits to release notes if there are any
if [ ${#FIX_COMMITS[@]} -gt 0 ]; then
  RELEASE_NOTES="$RELEASE_NOTES\n#### Bug Fixes 🐛\n"
  for COMMIT in "${FIX_COMMITS[@]}"; do
    RELEASE_NOTES="$RELEASE_NOTES\n- [${COMMIT%%:*}](https://github.com/$REPO_OWNER/$REPO_NAME/commit/${COMMIT%%:*}): ${COMMIT#*:}"
  done
fi

# Add documentation commits to release notes if there are any
if [ ${#DOCS_COMMITS[@]} -gt 0 ]; then
  RELEASE_NOTES="$RELEASE_NOTES\n#### Documentation 📝\n"
  for COMMIT in "${DOCS_COMMITS[@]}"; do
    RELEASE_NOTES="$RELEASE_NOTES\n- [${COMMIT%%:*}](https://github.com/$REPO_OWNER/$REPO_NAME/commit/${COMMIT%%:*}): ${COMMIT#*:}"
  done
fi

# Add test commits to release notes if there are any
if [ ${#TEST_COMMITS[@]} -gt 0 ]; then
  RELEASE_NOTES="$RELEASE_NOTES\n#### Tests 🧪\n"
  for COMMIT in "${TEST_COMMITS[@]}"; do
    RELEASE_NOTES="$RELEASE_NOTES\n- [${COMMIT%%:*}](https://github.com/$REPO_OWNER/$REPO_NAME/commit/${COMMIT%%:*}): ${COMMIT#*:}"
  done
fi

# Add CI/CD commits to release notes if there are any
if [ ${#CICD_COMMITS[@]} -gt 0 ]; then
  RELEASE_NOTES="$RELEASE_NOTES\n#### CI/CD 🔧\n"
  for COMMIT in "${CICD_COMMITS[@]}"; do
    RELEASE_NOTES="$RELEASE_NOTES\n- [${COMMIT%%:*}](https://github.com/$REPO_OWNER/$REPO_NAME/commit/${COMMIT%%:*}): ${COMMIT#*:}"
  done
fi

# Add task commits to release notes if there are any
if [ ${#TASK_COMMITS[@]} -gt 0 ]; then
  RELEASE_NOTES="$RELEASE_NOTES\n#### Tasks 🗒️\n"
  for COMMIT in "${TASK_COMMITS[@]}"; do
    RELEASE_NOTES="$RELEASE_NOTES\n- [${COMMIT%%:*}](https://github.com/$REPO_OWNER/$REPO_NAME/commit/${COMMIT%%:*}): ${COMMIT#*:}"
  done
fi

# Add other commits to release notes if there are any
if [ ${#OTHER_COMMITS[@]} -gt 0 ]; then
  RELEASE_NOTES="$RELEASE_NOTES\n#### Other Changes\n"
  for COMMIT in "${OTHER_COMMITS[@]}"; do
    RELEASE_NOTES="$RELEASE_NOTES\n- [${COMMIT%%:*}](https://github.com/$REPO_OWNER/$REPO_NAME/commit/${COMMIT%%:*}): ${COMMIT#*:}"
  done
fi

# Output the release notes to a file
echo -e "$RELEASE_NOTES" >CHANGELOG.md

# Step 4: Add, commit, and push CHANGELOG.md
git add CHANGELOG.md
git commit -m "Update CHANGELOG.md for release $NEW_VERSION"
git push origin main # or your default branch name

# Step 5: Create a new tag and push it to GitHub
git tag "$NEW_VERSION"
git push origin "$NEW_VERSION"

# Step 6: Create a GitHub release and associate it with the tag
RELEASE_BODY="$RELEASE_NOTES"
curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
  -d "{\"tag_name\": \"$NEW_VERSION\", \"name\": \"$NEW_VERSION\", \"body\": \"$RELEASE_BODY\", \"draft\": false, \"prerelease\": false}" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases"

echo "Release notes generated, saved to CHANGELOG.md, committed, and release published: $NEW_VERSION"


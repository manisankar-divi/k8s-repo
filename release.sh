#!/bin/bash

# Exit script on error and print commands
set -exo pipefail

# Check required dependencies
command -v git >/dev/null 2>&1 || { echo >&2 "Git is required but not installed. Aborting."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "curl is required but not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but not installed. Aborting."; exit 1; }

# Validate environment variables
required_vars=("REPO_OWNER" "REPO_NAME" "GITHUB_TOKEN")
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Error: $var environment variable is not set."
    exit 1
  fi
done

# Verify we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Not in a Git repository."
  exit 1
fi

# Get current commit hash
COMMIT_HASH=$(git rev-parse HEAD)
SHORT_HASH=$(git rev-parse --short HEAD)

# Check if commit already has a tag
if git describe --exact-match --tags "$COMMIT_HASH" >/dev/null 2>&1; then
  echo "Error: Commit $SHORT_HASH is already tagged."
  exit 1
fi

# Date components for versioning
YEAR=$(date +'%y')
MONTH=$(date +'%-m')
DAY=$(date +'%-d')

# Fetch latest tags from remote
git fetch --tags --force >/dev/null 2>&1

# Calculate new version number
LATEST_SAME_DAY_TAG=$(git tag --list "v${YEAR}.${MONTH}.${DAY}.*" | sort -Vr | head -n1)
if [[ -z "$LATEST_SAME_DAY_TAG" ]]; then
  NEXT_INCREMENT=1
else
  CURRENT_INCREMENT="${LATEST_SAME_DAY_TAG##*.}"
  NEXT_INCREMENT=$((CURRENT_INCREMENT + 1))
fi

NEW_VERSION="v${YEAR}.${MONTH}.${DAY}.${NEXT_INCREMENT}"

# Determine previous tag for changelog
PREVIOUS_TAG=$(git tag --list --sort=-v:refname | grep -v "$NEW_VERSION" | head -n1)
[ -z "$PREVIOUS_TAG" ] && PREVIOUS_TAG="$(git rev-list --max-parents=0 HEAD)"

# Get PR information associated with commit
PR_SEARCH_URL="https://api.github.com/search/issues?q=repo:${REPO_OWNER}/${REPO_NAME}+is:pr+is:merged+merge:${COMMIT_HASH}"
PR_RESPONSE=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" "$PR_SEARCH_URL")
PR_TITLE=$(echo "$PR_RESPONSE" | jq -r '.items[0].title // empty')

# Fallback to commit message if no PR found
if [ -z "$PR_TITLE" ]; then
  COMMIT_MESSAGE=$(git log -1 --pretty=%s "$COMMIT_HASH")
  PR_TITLE="$COMMIT_MESSAGE"
  echo "Warning: No associated PR found, using commit message as title"
fi

# Validate PR title format
if [[ ! "$PR_TITLE" =~ ^(feat|fix|docs|test|ci|cd|task|chore): ]]; then
  echo "Error: Invalid PR title format - '$PR_TITLE'"
  echo "Title must start with [feat|fix|docs|test|ci|cd|task|chore]:"
  exit 1
fi

# Categorize changes
declare -A TYPE_EMOJIS=(
  [feat]="Features ✨" 
  [fix]="Bug Fixes 🐛"
  [docs]="Documentation 📝"
  [test]="Tests 🧪"
  [ci]="CI/CD 🔧"
  [cd]="Deployment 🔧"
  [task]="Tasks 📌"
  [chore]="Chores 🧹"
)

TYPE=$(echo "$PR_TITLE" | cut -d: -f1)
CATEGORY=${TYPE_EMOJIS[$TYPE]:-📦 Other}

# Generate release notes
RELEASE_BODY=$(cat <<EOF
*What's Changed🚀 ($NEW_VERSION)*

**${CATEGORY}**
- [${SHORT_HASH}](https://github.com/${REPO_OWNER}/${REPO_NAME}/commit/${COMMIT_HASH}): ${PR_TITLE}

**📜Full Changelog:** https://github.com/${REPO_OWNER}/${REPO_NAME}/compare/${PREVIOUS_TAG}...${NEW_VERSION}
EOF
)

# Create GitHub release
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

echo "✅ Successfully created release ${NEW_VERSION}"

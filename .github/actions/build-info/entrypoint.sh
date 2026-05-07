#!/bin/bash
set -e

APP_NAME="$1"
INCLUDE_GIT="$2"

echo "========================================="
echo "  Build Info Reporter (Docker Action)"
echo "========================================="

# Generate a unique build ID
BUILD_ID="${APP_NAME}-$(date +%Y%m%d-%H%M%S)"
echo "build-id=${BUILD_ID}" >> "$GITHUB_OUTPUT"

# Gather git info if requested
if [ "$INCLUDE_GIT" = "true" ]; then
  SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  COMMIT_MSG=$(git log -1 --pretty=format:'%s' 2>/dev/null || echo "unknown")
  AUTHOR=$(git log -1 --pretty=format:'%an' 2>/dev/null || echo "unknown")
else
  SHORT_SHA="skipped"
  BRANCH="skipped"
  COMMIT_MSG="skipped"
  AUTHOR="skipped"
fi

echo "short-sha=${SHORT_SHA}" >> "$GITHUB_OUTPUT"
echo "branch=${BRANCH}" >> "$GITHUB_OUTPUT"

# Build the report
REPORT="App: ${APP_NAME} | Build: ${BUILD_ID} | SHA: ${SHORT_SHA} | Branch: ${BRANCH}"
echo "report=${REPORT}" >> "$GITHUB_OUTPUT"

# Print details to the log
echo ""
echo "📦 App:        ${APP_NAME}"
echo "🔖 Build ID:   ${BUILD_ID}"
echo "🔀 Branch:     ${BRANCH}"
echo "📝 Commit:     ${SHORT_SHA} - ${COMMIT_MSG}"
echo "👤 Author:     ${AUTHOR}"
echo "🐳 Container:  $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo "🕐 Timestamp:  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""
echo "✔ Build info captured"

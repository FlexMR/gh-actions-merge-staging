#!/bin/bash

set -e

echo "Debugging event:"
cat "$GITHUB_EVENT_PATH"

# set the branch to merge into, this could be configurable in the future
DESTINATION_BRANCH=staging

PR_NUMBER=$(jq -r ".pull_request.number" "$GITHUB_EVENT_PATH")
REPO_FULLNAME=$(jq -r ".repository.full_name" "$GITHUB_EVENT_PATH")
SOURCE_BRANCH=$(jq -r ".pull_request.head.ref" "$GITHUB_EVENT_PATH")
COMMENT_USER=$(jq -r ".sender.login" "$GITHUB_EVENT_PATH")

URI=https://api.github.com
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

echo "Using the following input:"
echo "  * pr number: $PR_NUMBER"
echo "  * repo_name: $REPO_FULLNAME"
echo "  * destination branch: $DESTINATION_BRANCH"
echo "  * branch to merge changes from: $SOURCE_BRANCH"
echo "  * user_name: $COMMENT_USER"
echo "  * user_email: $INPUT_USER_EMAIL"

git remote set-url origin https://x-access-token:${!INPUT_PUSH_TOKEN}@github.com/$GITHUB_REPOSITORY.git
git config --global user.name "$COMMENT_USER"
git config --global user.email "$INPUT_USER_EMAIL"

git fetch origin $SOURCE_BRANCH
git checkout -b $SOURCE_BRANCH origin/$SOURCE_BRANCH

git fetch origin $DESTINATION_BRANCH
git checkout -b $DESTINATION_BRANCH origin/$DESTINATION_BRANCH

if git merge-base --is-ancestor $SOURCE_BRANCH $DESTINATION_BRANCH; then
  echo "No merge is necessary"
  curl -s -H "${AUTH_HEADER}" -H "${API_HEADER}" -X POST -d "{\"body\": \":grey_question:  Nothing to merge into \`$DESTINATION_BRANCH\`, changes may have been manually merged.\"}" "${URI}/repos/$REPO_FULLNAME/issues/${PR_NUMBER}/comments"
  exit 0
fi;

echo "Trying to merge the '$SOURCE_BRANCH' branch ($(git log -1 --pretty=%H $SOURCE_BRANCH)) into the '$DESTINATION_BRANCH' branch ($(git log -1 --pretty=%H $DESTINATION_BRANCH))"

# Do the merge and push the branch
if git merge --no-ff --no-edit $SOURCE_BRANCH && git push origin $DESTINATION_BRANCH; then
  echo "Merge succeeded!"
  curl -s -H "${AUTH_HEADER}" -H "${API_HEADER}" -X POST -d "{\"body\": \":white_check_mark:  Merged $(git log -1 --pretty=%H $SOURCE_BRANCH) into \`$DESTINATION_BRANCH\` (see $(git log -1 --pretty=%H $DESTINATION_BRANCH))\"}" "${URI}/repos/$REPO_FULLNAME/issues/${PR_NUMBER}/comments"
  exit 0
fi;

echo "Merge failed!"
curl -s -H "${AUTH_HEADER}" -H "${API_HEADER}" -X POST -d "{\"body\": \":x:  Failed to merge changes into \`$DESTINATION_BRANCH\`, please attempt the merge manually.\"}" "${URI}/repos/$REPO_FULLNAME/issues/${PR_NUMBER}/comments"
curl -s -H "${AUTH_HEADER}" -H "${API_HEADER}" -X DELETE "${URI}/repos/$REPO_FULLNAME/issues/${PR_NUMBER}/labels/staging"
exit 1

#!/usr/bin/env bash
set -euo pipefail

export GH_PROMPT_DISABLED=1

query='query($reviewQuery: String!, $issueQuery: String!) {
  viewer {
    login
    repositories(first: 4, orderBy: {field: PUSHED_AT, direction: DESC},
      ownerAffiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]) {
      nodes { name nameWithOwner description url pushedAt isPrivate }
    }
    pullRequests(first: 12, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        number title url updatedAt isDraft mergeable reviewDecision
        repository { nameWithOwner }
        commits(last: 1) {
          nodes { commit { statusCheckRollup { state } } }
        }
      }
    }
  }
  reviewRequests: search(query: $reviewQuery, type: ISSUE, first: 12) {
    nodes {
      ... on PullRequest {
        number title url updatedAt isDraft
        repository { nameWithOwner }
      }
    }
  }
  assignedIssues: search(query: $issueQuery, type: ISSUE, first: 12) {
    nodes {
      ... on Issue {
        number title url updatedAt
        repository { nameWithOwner }
      }
    }
  }
}'

graphql_output="$(gh api graphql --cache 2m \
  -f query="$query" \
  -F reviewQuery='is:open is:pr review-requested:@me archived:false' \
  -F issueQuery='is:open is:issue assignee:@me archived:false')"

# Notifications are useful but non-essential: tokens without notification scope
# should still receive the GraphQL action center.
notifications_output="$(gh api --cache 2m -X GET notifications \
  -f all=false -f participating=false -F per_page=20 2>/dev/null || printf '[]')"

jq -cn \
  --argjson graph "$graphql_output" \
  --argjson notifications "$notifications_output" \
  '{
    viewer: $graph.data.viewer,
    reviewRequests: ($graph.data.reviewRequests.nodes // []),
    assignedIssues: ($graph.data.assignedIssues.nodes // []),
    notifications: ($notifications // [])
  }'

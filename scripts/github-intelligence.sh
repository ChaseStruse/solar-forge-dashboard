#!/usr/bin/env bash
set -euo pipefail

export GH_PROMPT_DISABLED=1

temp_dir="$(mktemp -d /tmp/solar-forge-github.XXXXXX)"
trap 'rm -rf "$temp_dir"' EXIT

query='query($reviewQuery: String!, $issueQuery: String!) {
  viewer {
    login
    followers { totalCount }
    following { totalCount }
    starredRepositories { totalCount }
    contributionsCollection {
      contributionCalendar { totalContributions }
    }
    pullRequests(first: 12, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) {
      totalCount
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

gh api graphql --cache 2m \
  -f query="$query" \
  -F reviewQuery='is:open is:pr review-requested:@me archived:false' \
  -F issueQuery='is:open is:issue assignee:@me archived:false' \
  >"$temp_dir/graphql.json"

# Paginate owned repositories so the repository and stars-earned totals remain
# exact for accounts with more than one API page of projects.
gh api --cache 2m --paginate --slurp -X GET user/repos \
  -f affiliation=owner -f sort=pushed -f direction=desc -F per_page=100 \
  >"$temp_dir/repositories.json"

# Notifications are useful but non-essential: tokens without notification scope
# should still receive the GraphQL action center.
if ! gh api --cache 2m -X GET notifications \
  -f all=false -f participating=false -F per_page=20 \
  >"$temp_dir/notifications.json" 2>/dev/null; then
  printf '[]' >"$temp_dir/notifications.json"
fi

jq -cn \
  --slurpfile graph "$temp_dir/graphql.json" \
  --slurpfile repositoryPages "$temp_dir/repositories.json" \
  --slurpfile notifications "$temp_dir/notifications.json" \
  '{
    viewer: ($graph[0].data.viewer + {
      repositories: {
        totalCount: ($repositoryPages[0] | add | length),
        nodes: [($repositoryPages[0] | add)[] | {
          name,
          nameWithOwner: .full_name,
          description,
          url: .html_url,
          pushedAt: .pushed_at,
          isPrivate: .private,
          stargazerCount: .stargazers_count
        }]
      }
    }),
    reviewRequests: ($graph[0].data.reviewRequests.nodes // []),
    assignedIssues: ($graph[0].data.assignedIssues.nodes // []),
    notifications: ($notifications[0] // [])
  }'

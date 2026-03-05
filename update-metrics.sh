#!/bin/bash
# Generates live metrics snapshot from GitHub for the dashboard
# Run: bash dashboard/update-metrics.sh
# Requires: gh CLI authenticated

ORG="WL-MadHacker"
OUTPUT="dashboard/metrics.json"
BYTES_PER_LINE=40

echo "Fetching repos for $ORG..."
repos=$(gh repo list "$ORG" --json name --limit 100 -q '.[].name')
repo_count=$(echo "$repos" | wc -l | tr -d ' ')

total_bytes=0
total_commits=0
repo_data="["

first=true
for repo in $repos; do
  # Get language bytes
  bytes=$(gh api "repos/$ORG/$repo/languages" 2>/dev/null | python -c "import sys,json; print(sum(json.load(sys.stdin).values()))" 2>/dev/null || echo "0")
  total_bytes=$((total_bytes + bytes))
  
  # Get commit count (up to 100)
  commits=$(gh api "repos/$ORG/$repo/commits?per_page=100" --jq 'length' 2>/dev/null || echo "0")
  total_commits=$((total_commits + commits))
  
  loc=$((bytes / BYTES_PER_LINE))
  
  if [ "$first" = true ]; then first=false; else repo_data+=","; fi
  repo_data+="{\"name\":\"$repo\",\"bytes\":$bytes,\"loc\":$loc,\"commits\":$commits}"
  
  echo "  $repo: $loc LOC, $commits commits"
done

repo_data+="]"

total_loc=$((total_bytes / BYTES_PER_LINE))
equiv_value=$(python -c "print(round($total_loc * 15 / 1000000, 1))")

# Generate JSON
cat > "$OUTPUT" << EOF
{
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "org": "$ORG",
  "totals": {
    "repos": $repo_count,
    "loc": $total_loc,
    "bytes": $total_bytes,
    "commits": $total_commits,
    "equivValueM": $equiv_value,
    "features": 160,
    "velocity": "18-36x"
  },
  "repos": $repo_data
}
EOF

echo ""
echo "=== METRICS SNAPSHOT ==="
echo "Repos: $repo_count"
echo "LOC: $total_loc"
echo "Commits: $total_commits"
echo "Equiv Value: \$${equiv_value}M/yr"
echo "Saved to: $OUTPUT"

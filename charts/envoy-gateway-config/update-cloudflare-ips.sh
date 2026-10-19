#!/usr/bin/env bash
# Refreshes files/cloudflare-ips.json from Cloudflare's published list of edge
# IP ranges. The external gateway trusts X-Forwarded-For only from these
# ranges, see templates/client-traffic-policy-external.yaml.
#
# Run by .github/workflows/update-cloudflare-ips.yaml every week. Safe to run
# by hand. Needs curl and jq.
set -euo pipefail

cd "$(dirname "$0")"
out=files/cloudflare-ips.json
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

curl -fsS --retry 3 https://api.cloudflare.com/client/v4/ips -o "$tmp"

# Stop on a failed or empty answer. Writing an empty list would make the
# gateway trust nobody, so Cloudflare-proxied hosts would see Cloudflare's IP
# as the client.
jq -e '.success == true
  and (.result.ipv4_cidrs | length) > 0
  and (.result.ipv6_cidrs | length) > 0' "$tmp" >/dev/null || {
  echo "unexpected answer from Cloudflare:" >&2
  cat "$tmp" >&2
  exit 1
}

# Sorted so the file only changes when the ranges change. The etag is left out
# for the same reason.
jq '{ipv4_cidrs: (.result.ipv4_cidrs | sort), ipv6_cidrs: (.result.ipv6_cidrs | sort)}' "$tmp" > "$out"
echo "wrote $out"

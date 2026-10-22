#!/usr/bin/env bash
# Raise (or lower) the minimum build that may still talk to the server.
#
#   tool/release/set_min_build.sh <platform> <build>
#   tool/release/set_min_build.sh show
#
# platform: ios | android | macos | windows | linux
# build:    the +N of pubspec "version: x.y.z+N" (0 = nobody is blocked)
#
# Builds below the minimum get 'update_required' on every request and show
# the "Update required" screen (supabase/migrations/20261103090000_mandatory_update.sql).
# Builds that send no x-app-build header (older than the mandatory update)
# are never blocked by this.
#
# Raise it only once the new build is actually downloadable on that store
# (App Store release live, GitHub release published), never right after a
# TestFlight upload: testers and everybody else would be locked out.
#
# Reads SUPABASE_ACCESS_TOKEN from fastlane/.env and the project ref from
# config/supabase.json. Neither is ever printed.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
# From a git worktree the secrets live in the main checkout.
main="$(git -C "$root" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')"
secrets="$root"
[ -f "$secrets/fastlane/.env" ] || secrets="${main:-$root}"

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

case "${1:-}" in
  show)
    sql="select key, value from internal.config where key like 'min_build_%' or key like 'store_url_%' order by key;"
    ;;
  ios|android|macos|windows|linux)
    [[ "${2:-}" =~ ^[0-9]{1,9}$ ]] || usage
    sql="insert into internal.config (key, value) values ('min_build_$1', '$2') on conflict (key) do update set value = excluded.value returning key, value;"
    ;;
  *) usage ;;
esac

token="${SUPABASE_ACCESS_TOKEN:-}"
if [ -z "$token" ] && [ -f "$secrets/fastlane/.env" ]; then
  token="$(sed -n 's/^SUPABASE_ACCESS_TOKEN=//p' "$secrets/fastlane/.env" | tr -d '"' | tr -d "'" | tail -1)"
fi
[ -n "$token" ] || { echo "SUPABASE_ACCESS_TOKEN missing (fastlane/.env)" >&2; exit 1; }
ref="$(sed -n 's#.*"SUPABASE_URL" *: *"https://\([a-z0-9]*\)\..*#\1#p' "$secrets/config/supabase.json" 2>/dev/null | head -1)"
[ -n "$ref" ] || { echo "Project ref not found (config/supabase.json)" >&2; exit 1; }

body="$(SQL="$sql" python3 -c 'import json, os; print(json.dumps({"query": os.environ["SQL"]}))')"
# The token goes through stdin (curl --config), never on the command line.
printf 'header = "Authorization: Bearer %s"\n' "$token" | curl -sS --fail-with-body --config - \
  -H 'Content-Type: application/json' -H 'User-Agent: oberta-set-min-build' \
  -X POST "https://api.supabase.com/v1/projects/$ref/database/query" --data "$body"
echo

#!/usr/bin/env bash
set +x
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  printf 'Usage: %s <secret-name>\n' "$0" >&2
  exit 1
fi

secret_name="$1"

# if ! token="$(./akeyless auth \
#   --access-type access_key \
#   --access-id "$AKEYLESS_ACCESS_ID" \
#   --access-key "$AKEYLESS_ACCESS_KEY" \
#   --json 2>/dev/null | jq -er '.token | select(type == "string" and length > 0)' 2>/dev/null)"; then
#   printf 'Akeyless authentication failed. Check credentials and Gateway connectivity.\n' >&2
#   exit 1
# fi

if ! credentials="$(./akeyless dynamic-secret get-value \
  --name "$AKEYLESS_DEFAULT_LOCATION/$secret_name" --json 2>/dev/null)"; then
  printf 'Could not fetch the dynamic secret. Check its name, permissions, and Gateway connectivity.\n' >&2
  exit 1
fi

if ! username="$(jq -er '.user // .username | select(type == "string" and length > 0)' <<< "$credentials" 2>/dev/null)" ||
   ! password="$(jq -er '.password | select(type == "string" and length > 0)' <<< "$credentials" 2>/dev/null)"; then
  printf 'The dynamic secret did not return a valid username and password.\n' >&2
  exit 1
fi

PGPASSWORD="$password" PGCONNECT_TIMEOUT=10 psql \
  --no-psqlrc --no-password --set=ON_ERROR_STOP=1 \
  --host localhost \
  --port "${POSTGRES_PORT:-5432}" \
  --dbname "${POSTGRES_DB:-postgres}" \
  --username "$username" \
  --command 'SELECT 1;'

printf 'PostgreSQL connection successful using dynamic secret: %s\n' "$secret_name"

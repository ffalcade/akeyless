#!/usr/bin/env bash
set +x
set -euo pipefail

if [[ $# -ne 2 || -z "$1" || -z "$2" ]]; then
  printf 'Usage: %s <secret-name> <target-name>\n' "$0" >&2
  exit 1
fi

secret_name="$1"
target_name="$2"

# if ! token="$(./akeyless auth \
#   --access-type access_key \
#   --access-id "$AKEYLESS_ACCESS_ID" \
#   --access-key "$AKEYLESS_ACCESS_KEY" \
#   --json 2>/dev/null | jq -er '.token | select(type == "string" and length > 0)' 2>/dev/null)"; then
#   printf 'Akeyless authentication failed. Check credentials and Gateway connectivity.\n' >&2
#   exit 1
# fi

run_akeyless() {
  local operation="$1"
  shift
  # if ! ./akeyless "$@" --token "$token" >/dev/null 2>&1; then
  if ! ./akeyless "$@" >/dev/null 2>&1; then
    printf 'Akeyless %s failed. Check permissions, resource names, and Gateway audit logs. Earlier successful creations remain in place.\n' "$operation" >&2
    exit 1
  fi
}

# run_akeyless 'target creation' 
./akeyless target create db \
  --name "$AKEYLESS_DEFAULT_LOCATION/$target_name" \
  --db-type postgres \
  --host "$POSTGRES_HOST" \
  --port "$POSTGRES_PORT" \
  --db-name postgres \
  --user-name "$POSTGRES_USERNAME" \
  --pwd "$POSTGRES_PASSWORD"

sql_admin="${POSTGRES_USERNAME//\"/\"\"}"
# run_akeyless 'dynamic secret creation' 
./akeyless dynamic-secret create postgresql \
  --name "$AKEYLESS_DEFAULT_LOCATION/$secret_name" \
  --target-name "$AKEYLESS_DEFAULT_LOCATION/$target_name" \
  --postgresql-statements "CREATE USER \"{{name}}\" WITH PASSWORD '{{password}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; GRANT CONNECT ON DATABASE postgres TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\";" \
  --postgresql-revoke-statement "REASSIGN OWNED BY \"{{name}}\" TO \"$sql_admin\"; DROP OWNED BY \"{{name}}\"; SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = '{{name}}'; DROP USER \"{{name}}\";" \
  --password-length 16

printf 'Created PostgreSQL target: %s\nCreated dynamic secret: %s\n' "$target_name" "$secret_name"

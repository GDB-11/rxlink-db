#!/usr/bin/env bash
# Applies the synthetic demo seeds (seeds/S*.sql) in order. DEMO/DEV ONLY: refuses to run if "Person"
# already has rows unless --force. The catalog DB must already be seeded (C006): seeds use its fixed codes.
# usage: apply-seeds.sh [--force] <psql-conninfo-or-dbname>   (PSQL env overrides the psql command)
set -euo pipefail
FORCE=0; if [[ "${1:-}" == "--force" ]]; then FORCE=1; shift; fi
DB=${1:?psql conninfo or database name}
PSQL=${PSQL:-psql}
DIR=$(cd "$(dirname "$0")/../seeds" && pwd)
if (( ! FORCE )); then
  n=$($PSQL -X -qtA -v ON_ERROR_STOP=1 "$DB" -c 'SELECT count(*) FROM "Person"')
  if [[ "$n" != 0 ]]; then echo "refusing: \"Person\" has $n rows (use --force to apply anyway)" >&2; exit 1; fi
fi
# Demo rows must not fill AuditLog with actor-less entries: skip the audit triggers when the role may.
PRELUDE=""
if $PSQL -X -q -v ON_ERROR_STOP=1 "$DB" -c "SET session_replication_role = replica" >/dev/null 2>&1; then
  PRELUDE="SET LOCAL session_replication_role = replica;"
else
  echo "warning: cannot set session_replication_role; seeds will write actor-less AuditLog rows" >&2
fi
for f in $(ls "$DIR"/S*.sql | sort); do
  echo "applying $(basename "$f")"
  { echo "$PRELUDE"; cat "$f"; } | $PSQL -X -q -v ON_ERROR_STOP=1 -1 "$DB"
done

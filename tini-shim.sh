#! /bin/bash
set -euo pipefail

cat <<EOF
Please update your scripts to use /sbin/tini going forward.
Previous path has been preserved for backwards compatibility in Alpine 3.4,
but WILL BE REMOVED in Alpine 3.5. (or Jenkins 2.107.1 or something like this for our case)

Now sleeping 2 minutes...
EOF

sleep 120

exec tini "$@"

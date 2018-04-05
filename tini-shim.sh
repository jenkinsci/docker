#! /bin/bash
set -euo pipefail

cat <<EOF
***************************************************************************
* WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING *
***************************************************************************
Please update your scripts to use /sbin/tini or simply tini going forward.
Previous path has been preserved for backwards compatibility,
but WILL BE REMOVED in the future. (around Jenkins >= 2.107.2+)

Now sleeping 2 minutes...
EOF

sleep 120

exec tini "$@"

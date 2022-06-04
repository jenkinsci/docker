#!/bin/sh

cat <<EOF
***************************************************************************
* WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING *
***************************************************************************
Please update your scripts to use /usr/bin/tini going forward.
The previous path has been preserved for backwards compatibility
but WILL BE REMOVED in the future (around Jenkins >= 2.345+).

Now sleeping 2 minutes...
EOF

sleep 120

exec /usr/bin/tini "$@"

ROOT_DIR="$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/"

shellcheck:
	# TODO: remove SC1117 exclusion when on shellcheck > 0.5.0
	$(ROOT_DIR)/tools/shellcheck -e SC1091 \
	                             -e SC1117 \
	                             jenkins-support \
	                             *.sh

.PHONY: shellcheck

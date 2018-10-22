ROOT_DIR="$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/"

shellcheck:
	$(ROOT_DIR)/tools/shellcheck -e SC1091 *.sh

.PHONY: shellcheck

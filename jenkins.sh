#! /bin/bash

set -e

JENKINS_HOME="${JENKINS_HOME:-/var/jenkins_home}"
JENKINS_REFS_ROOT="/usr/share/jenkins/ref"
JENKINS_WAR="/usr/share/jenkins/jenkins.war"

# Log some data to copy reference log file
log() {
    echo "[$(date)] $@" >> "$COPY_REFERENCE_FILE_LOG"
}

# Copy files from $1 into $JENKINS_HOME
# So the initial $JENKINS_HOME is set with expected content.
# Don't override, as this is just a reference setup, and user from UI
# can then change this, upgrade plugins, etc.
copy_reference_file() {
	f="${1%/}"
	b="${f%.override}"
	log "$f"

	rel="${b:23}"
	dir="$(dirname "${b}")"
	log "$f -> $rel"

	if [[ ! -e "$JENKINS_HOME/${rel}" || "$f" = *.override ]]
	then
		log "copy $rel to $JENKINS_HOME"
		mkdir -p "$JENKINS_HOME/${dir:23}"
		cp -r "${f}" "$JENKINS_HOME/${rel}"

		# pin plugins on initial copy
		if [[ "${rel}" == plugins/*.jpi ]]
        then
            touch "$JENKINS_HOME/${rel}.pinned"
        fi
	fi
}

prepare() {
    if ! touch "${COPY_REFERENCE_FILE_LOG}"
    then
        echo "Can not write to ${COPY_REFERENCE_FILE_LOG}. Wrong volume permissions?"
        exit 1
    fi

    log "Starting to copy files..."
    find "$JENKINS_REFS_ROOT" -type f -exec bash -c "copy_reference_file '{}'" \;
}

exec_jenkins() {
    eval "exec java $JAVA_OPTS -jar '$JENKINS_WAR' $JENKINS_OPTS \"\$@\""
}

exec_cmd() {
    exec "$@"
}

main() {
    prepare

    case "$1" in
        "--"*)
            # if `docker run` first argument start with `--`
            # the user is passing jenkins launcher arguments
            shift
            exec_jenkins "$@"
            ;;
        "")
            exec_jenkins
            ;;
        *)
            # As argument is not jenkins, assume user want to run his own process,
            # for sample a `bash` shell to explore this image
            exec_cmd "$@"
            ;;
    esac
}

export -f log
export -f copy_reference_file

main "$@"

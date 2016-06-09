#! /bin/bash

set -e

# Copy files from $JENKINS_REF into $JENKINS_HOME
# So the initial JENKINS-HOME is set with expected content.
# Don't override, as this is just a reference setup, and use from UI
# can then change this, upgrade plugins, etc.
copy_reference_file() {
  {
    src="${1%.override}"
    rel="${src#"$JENKINS_REF/"}"
    dst="$JENKINS_HOME/${rel}"

    if [[ ! -e "${dst}" || "$1" != "$src" ]]
    then
      echo -n "copy: "
      mkdir -p "$(dirname $dst)"
      cp -rv "${src}" "${dst}"

      # pin plugins on initial copy
      [[ "${rel}" == plugins/*.jpi ]] && touch "${dst}.pinned"
    else
      echo "skip: ‘${src}’"
    fi;
    echo
  } >> "$COPY_REFERENCE_FILE_LOG"
}

# Init
: ${JENKINS_REF:="/usr/share/jenkins/ref"} ${JENKINS_HOME:="/var/jenkins_home"}
export JENKINS_REF="${JENKINS_REF%/}" JENKINS_HOME="${JENKINS_HOME%/}"
export -f copy_reference_file 
touch "${COPY_REFERENCE_FILE_LOG}" || (echo "Can not write to ${COPY_REFERENCE_FILE_LOG}. Wrong volume permissions?" && exit 1)

# Copy
echo "--- Copying files at $(date)" >> "$COPY_REFERENCE_FILE_LOG"
find "$JENKINS_REF" -type f -exec bash -c "copy_reference_file '{}'" \;

# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then
  eval "exec java $JAVA_OPTS -jar /usr/share/jenkins/jenkins.war $JENKINS_OPTS \"\$@\""
fi

# As argument is not jenkins, assume user want to run his own process, for sample a `bash` shell to explore this image
exec "$@"

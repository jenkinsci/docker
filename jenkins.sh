#! /bin/bash -e

: "${JENKINS_WAR:="/usr/share/jenkins/jenkins.war"}"
: "${JENKINS_HOME:="/var/jenkins_home"}"

if [[ -n "${PRE_CLEAR_INIT_GROOVY_D}" ]]; then
  rm -rf "${JENKINS_HOME}/init.groovy.d"
fi

: "${COPY_REFERENCE_FILE_LOG:="${JENKINS_HOME}/copy_reference_file.log"}"
: "${REF:="/usr/share/jenkins/ref"}"

if ! [ -r "${JENKINS_HOME}" ] || ! [ -w "${JENKINS_HOME}" ]; then
        echo "INSTALL WARNING: User: ${USER} missing rw permissions on JENKINS_HOME: ${JENKINS_HOME}"
fi
touch "${COPY_REFERENCE_FILE_LOG}" || { echo "Can not write to ${COPY_REFERENCE_FILE_LOG}. Wrong volume permissions?"; exit 1; }
echo "--- Copying files at $(date)" >> "$COPY_REFERENCE_FILE_LOG"
find "${REF}" \( -type f -o -type l \) -exec bash -c '. /usr/local/bin/jenkins-support; for arg; do copy_reference_file "$arg"; done' _ {} +

# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then

  # shellcheck disable=SC2001
  effective_java_opts=$(sed -e 's/^ $//' <<<"$JAVA_OPTS $JENKINS_JAVA_OPTS")

  # read JAVA_OPTS and JENKINS_OPTS into arrays to avoid need for eval (and associated vulnerabilities)
  java_opts_array=()
  while IFS= read -r -d '' item; do
    java_opts_array+=( "$item" )
  done < <([[ $effective_java_opts ]] && xargs printf '%s\0' <<<"$effective_java_opts")

  readonly agent_port_property='jenkins.model.Jenkins.slaveAgentPort'
  if [ -n "${JENKINS_SLAVE_AGENT_PORT:-}" ] && [[ "${effective_java_opts:-}" != *"${agent_port_property}"* ]]; then
    java_opts_array+=( "-D${agent_port_property}=${JENKINS_SLAVE_AGENT_PORT}" )
  fi

  readonly lifecycle_property='hudson.lifecycle'
  if [[ "${JAVA_OPTS:-}" != *"${lifecycle_property}"* ]]; then
    java_opts_array+=( "-D${lifecycle_property}=hudson.lifecycle.ExitLifecycle" )
  fi

  if [[ "$DEBUG" ]] ; then
    java_opts_array+=( \
      '-Xdebug' \
      '-Xrunjdwp:server=y,transport=dt_socket,address=*:5005,suspend=y' \
    )
  fi

  jenkins_opts_array=( )
  while IFS= read -r -d '' item; do
    jenkins_opts_array+=( "$item" )
  done < <([[ $JENKINS_OPTS ]] && xargs printf '%s\0' <<<"$JENKINS_OPTS")

  exec java -Duser.home="$JENKINS_HOME" "${java_opts_array[@]}" -jar "${JENKINS_WAR}" "${jenkins_opts_array[@]}" "$@"
fi

# As argument is not jenkins, assume user wants to run a different process, for example a `bash` shell to explore this image
exec "$@"

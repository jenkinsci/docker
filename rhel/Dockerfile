ARG RHEL_TAG=9.8-1793179168
ARG RHEL_RELEASE_LINE=ubi9
FROM registry.access.redhat.com/${RHEL_RELEASE_LINE}/ubi:${RHEL_TAG} AS jre-and-war

SHELL ["/bin/bash", "-e", "-u", "-o", "pipefail", "-c"]

# This Build ARG is populated by Docker
# Ref. https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
ARG TARGETPLATFORM

ARG JAVA_RELEASE
COPY ./adoptium/jdk_installers.txt /tmp/jdk_installers.txt
COPY adoptium.key /usr/local/share/adoptium.key
ARG TEMP_JAVA_HOME=/opt/jdk
ENV PATH="${TEMP_JAVA_HOME}/bin:${PATH}"
RUN dnf install --disableplugin=subscription-manager --setopt=install_weak_deps=0 --setopt=tsflags=nodocs --allowerasing -y \
    ca-certificates \
    curl \
    gnupg \
    tar \
  && dnf clean --disableplugin=subscription-manager all \
  && java_zip_url="$(grep "jdk${JAVA_RELEASE}/${TARGETPLATFORM}/glibc" /tmp/jdk_installers.txt | cut -d' ' -f2)" \
  && mkdir -p "${TEMP_JAVA_HOME}" \
  && jdk_archive="/opt/jdk.zip" \
  && curl --silent --show-error --fail --location --output "${jdk_archive}" "${java_zip_url}" \
  && curl --silent --show-error --fail --location --output "${jdk_archive}.sig" "${java_zip_url}.sig" \
  && GNUPGHOME=$(mktemp -d) \
  && gpg --batch --homedir "${GNUPGHOME}" --import /usr/local/share/adoptium.key \
  && gpg --batch --homedir "${GNUPGHOME}" --verify "${jdk_archive}.sig" "${jdk_archive}" \
  && tar xzf "${jdk_archive}" --strip-components=1 -C "${TEMP_JAVA_HOME}" \
  && java --version \
  && jlink --version

# Generate smaller java runtime for JDK21 without unneeded files
# for now we include the full module path to maintain compatibility
# while still saving space (approx 200mb from the full distribution)
RUN case "$(jlink --version 2>&1)" in \
    "21."*) jlink \
              --strip-java-debug-attributes \
              --compress=zip-6 \
              --add-modules ALL-MODULE-PATH \
              --no-man-pages \
              --no-header-files \
              --output /javaruntime;; \
    # JDK 25 switches to a minimal module set for smaller images.
    # Modules on top of the base set, required by code that Jenkins core and plugins run on the agent:
    # - java.sql: hudson.util.Secret (credentials masking, e.g. withCredentials) via Stapler and commons-beanutils
    # - java.desktop: java.beans, used by commons-beanutils/commons-digester (e.g. warnings-ng XML report parsers)
    # - jdk.net: Apache HttpClient 5 (e.g. http_request plugin)
    # - java.naming: logback, used by tools started with the agent JVM (e.g. SonarScanner CLI)
    # - jdk.unsupported: sun.misc.Unsafe (e.g. Groovy in the agent script console)
    "25"*)  cp -r "${TEMP_JAVA_HOME}" /javaruntime;; \
    *) echo "ERROR: unmanaged jlink version pattern" && exit 1 ;; \
  esac;

# Jenkins version being bundled in this docker image
ARG JENKINS_VERSION=2.587
# Can be used to customize where jenkins.war get downloaded from
ARG WAR_URL=https://get.jenkins.io/war/${JENKINS_VERSION}/jenkins.war

COPY jenkins.io-2026.key /war/jenkins-key.pub
RUN curl -fsSL "${WAR_URL}" -o /war/jenkins.war \
  && curl -fsSL "${WAR_URL}.asc" -o /war/jenkins.war.asc \
  && gpg --import /war/jenkins-key.pub \
  && gpg --verify --trust-model direct /war/jenkins.war.asc /war/jenkins.war

FROM registry.access.redhat.com/${RHEL_RELEASE_LINE}/ubi:${RHEL_TAG} AS controller

ENV LANG=C.UTF-8

ARG TARGETARCH
ARG COMMIT_SHA

RUN dnf install --disableplugin=subscription-manager --setopt=install_weak_deps=0 --setopt=tsflags=nodocs -y \
        fontconfig \
        freetype \
        git \
        git-lfs \
        unzip \
        which \
        tzdata \
    && dnf clean --disableplugin=subscription-manager all

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=/var/jenkins_home
ARG REF=/usr/share/jenkins/ref

ENV JENKINS_HOME=$JENKINS_HOME
ENV JENKINS_SLAVE_AGENT_PORT=${agent_port}
ENV REF=$REF

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN mkdir -p $JENKINS_HOME \
  && chown ${uid}:${gid} $JENKINS_HOME \
  && groupadd -g ${gid} ${group} \
  && useradd -N -d "$JENKINS_HOME" -u ${uid} -g ${gid} -l -m -s /bin/bash ${user}

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# $REF (defaults to `/usr/share/jenkins/ref/`) contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN mkdir -p ${REF}/init.groovy.d

# Use tini as subreaper in Docker container to adopt zombie processes
ARG TINI_VERSION=v0.19.0
COPY tini_pub.gpg "${JENKINS_HOME}/tini_pub.gpg"
RUN curl -fsSL "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-${TARGETARCH}" -o /sbin/tini \
  && curl -fsSL "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-${TARGETARCH}.asc" -o /sbin/tini.asc \
  && gpg --no-tty --import "${JENKINS_HOME}/tini_pub.gpg" \
  && gpg --verify /sbin/tini.asc \
  && rm -rf /sbin/tini.asc /root/.gnupg \
  && chmod +x /sbin/tini

ENV JENKINS_UC=https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
RUN chown -R ${user} "$JENKINS_HOME" "$REF"

ARG PLUGIN_CLI_VERSION=2.15.0
ARG PLUGIN_CLI_URL=https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${PLUGIN_CLI_VERSION}/jenkins-plugin-manager-${PLUGIN_CLI_VERSION}.jar
RUN curl -fsSL ${PLUGIN_CLI_URL} -o /opt/jenkins-plugin-manager.jar \
  && echo "$(curl -fsSL "${PLUGIN_CLI_URL}.sha256")  /opt/jenkins-plugin-manager.jar" >/tmp/jpm_sha \
  && sha256sum -c --strict /tmp/jpm_sha \
  && rm -f /tmp/jpm_sha

# for main web interface:
EXPOSE ${http_port}

# will be used by attached agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG=$JENKINS_HOME/copy_reference_file.log

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"
COPY --from=jre-and-war /javaruntime $JAVA_HOME
COPY --from=jre-and-war /war/jenkins.war /usr/share/jenkins/jenkins.war

USER ${user}

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
COPY jenkins-plugin-cli.sh /bin/jenkins-plugin-cli

ARG JENKINS_VERSION=2.587
ENV JENKINS_VERSION=${JENKINS_VERSION}

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

# metadata labels
LABEL \
    org.opencontainers.image.vendor="Jenkins project" \
    org.opencontainers.image.title="Official Jenkins Docker image" \
    org.opencontainers.image.description="The Jenkins Continuous Integration and Delivery server" \
    org.opencontainers.image.version="${JENKINS_VERSION}" \
    org.opencontainers.image.url="https://www.jenkins.io/" \
    org.opencontainers.image.source="https://github.com/jenkinsci/docker" \
    org.opencontainers.image.revision="${COMMIT_SHA}" \
    org.opencontainers.image.licenses="MIT"

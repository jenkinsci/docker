ARG RHEL_TAG=9.7-1770238273
ARG RHEL_RELEASE_LINE=ubi9
FROM registry.access.redhat.com/${RHEL_RELEASE_LINE}/ubi:${RHEL_TAG} AS jre-and-war

ARG JAVA_VERSION=17.0.18_8

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY jdk-download-url.sh /usr/bin/jdk-download-url.sh
COPY jdk-download.sh /usr/bin/jdk-download.sh

RUN dnf install --disableplugin=subscription-manager --setopt=install_weak_deps=0 --setopt=tsflags=nodocs --allowerasing -y \
    ca-certificates \
    curl \
    jq \
    && dnf clean --disableplugin=subscription-manager all \
    && /usr/bin/jdk-download.sh

ENV PATH="/opt/jdk-${JAVA_VERSION}/bin:${PATH}"

# Generate smaller java runtime without unneeded files
# for now we include the full module path to maintain compatibility
# while still saving space (approx 200mb from the full distribution)
# hadolint ignore=SC2086
RUN java_major_version="$(jlink --version 2>&1 | cut -c1-2)"; \
    if [ "$java_major_version" = "25" ]; then \
      cp -r "/opt/jdk-${JAVA_VERSION}" /javaruntime; \
    else \
      case "$java_major_version" in \
        "17") options="--compress=2" ;; \
        "21") options="--compress=zip-6" ;; \
        *) echo "ERROR: unmanaged jlink version pattern" && exit 1 ;; \
      esac; \
      jlink \
        --strip-java-debug-attributes \
        ${options} \
        --add-modules ALL-MODULE-PATH \
        --no-man-pages \
        --no-header-files \
        --output /javaruntime; \
    fi

# Jenkins version being bundled in this docker image
ARG JENKINS_VERSION=2.549
# Can be used to customize where jenkins.war get downloaded from
ARG WAR_URL=https://get.jenkins.io/war/${JENKINS_VERSION}/jenkins.war

COPY jenkins.io-2026.key /war/jenkins-key.pub

# Not using ADD as it does not check Last-Modified header
# see https://github.com/docker/docker/issues/8331
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

ARG PLUGIN_CLI_VERSION=2.14.0
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

ARG JENKINS_VERSION=2.549

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

ARG BOOKWORM_TAG=20241111

######################################################
#                   BUILD STAGE                      #
######################################################
FROM debian:bookworm-"${BOOKWORM_TAG}" AS jre-build

ARG JAVA_VERSION=17.0.13_11

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY ["./jdk-download-url.sh", "./jdk-download.sh", "/usr/bin/"]

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        jq \
        && \

    echo "Downloading jdk" \
    && chmod +x /usr/bin/jdk-download.sh \
    && /usr/bin/jdk-download.sh && \

    echo "Cleaning up" \
    && apt-get autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/jdk-${JAVA_VERSION}/bin:${PATH}"

#--------------------------------------------------------------------#
# Generate smaller java runtime without unneeded files               #
# for now we include the full module path to maintain compatibility  #
# while still saving space (approx 200mb from the full distribution) #
#--------------------------------------------------------------------#
RUN case "$(jlink --version 2>&1)" in \
      "17."*) set -- "--compress=2" ;; \
      # the compression argument is different for JDK21
      "21."*) set -- "--compress=zip-6" ;; \
      *) echo "ERROR: unmanaged jlink version pattern" && exit 1 ;; \
    esac; \
    jlink \
      --strip-java-debug-attributes \
      "$1" \
      --add-modules ALL-MODULE-PATH \
      --no-man-pages \
      --no-header-files \
      --output /javaruntime


######################################################
#               CONTROLLER STAGE                     #
######################################################
FROM debian:bookworm-"${BOOKWORM_TAG}" AS controller

#----------------------------------------------------#
# jenkins version being bundled in this docker image #
#----------------------------------------------------#
ARG JENKINS_VERSION
ENV JENKINS_VERSION=${JENKINS_VERSION:-2.479}

ARG TARGETARCH
ARG COMMIT_SHA

#-----------------#
# metadata labels #
#-----------------#
LABEL \
    org.opencontainers.image.vendor="Jenkins project" \
    org.opencontainers.image.title="Official Jenkins Docker image" \
    org.opencontainers.image.description="The Jenkins Continuous Integration and Delivery server" \
    org.opencontainers.image.version="${JENKINS_VERSION}" \
    org.opencontainers.image.url="https://www.jenkins.io/" \
    org.opencontainers.image.source="https://github.com/jenkinsci/docker" \
    org.opencontainers.image.revision="${COMMIT_SHA}" \
    org.opencontainers.image.licenses="MIT"

#------------------------------#
# Installing required packages #
#------------------------------#
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        gpg \
        libfontconfig1 \
        libfreetype6 \
        procps \
        ssh-client \
        tini \
        unzip \
        tzdata \
        && \

    echo "Cleaning up" \
    && apt-get autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

#--------------------#
# Installing git-lfs #
#--------------------#
RUN curl -fsSL https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh -o /tmp/script.deb.sh \
    && bash /tmp/script.deb.sh \
    && rm -f /tmp/script.deb.sh \
    && apt-get install -y --no-install-recommends git-lfs \
    && git lfs install && \

    echo "Cleaning up" \
    && apt-get autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8

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

#---------------------------------------------------------------#
# Jenkins is run with user `jenkins`, uid = 1000                #
# If you bind mount a volume from the host or a data container, #
# ensure you use the same uid(e.g. 1000)                        #
#---------------------------------------------------------------#
RUN mkdir -p $JENKINS_HOME \
    && chown ${uid}:${gid} $JENKINS_HOME \
    && groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -l -m -s /bin/bash ${user}

#-----------------------------------------------------------------------------------#
# $REF (defaults to `/usr/share/jenkins/ref/`) contains all reference configuration #
# we want to set on a fresh new installation. Use it to bundle additional plugins   #
# or config file with your custom jenkins Docker image.                             #
#-----------------------------------------------------------------------------------#
RUN mkdir -p ${REF}/init.groovy.d

#------------------------------------------------------------------------#
# JENKINS_SHA: jenkins.war checksum, download will be validated using it #
#-----------------------------------------------------------------------------#
# JENKINS_URL: Can be used to customize where jenkins.war get downloaded from #
#-----------------------------------------------------------------------------#
ARG JENKINS_SHA=910ea36cef37c45087e39d65e335988e036fccea47c79cc5a52e721a10cb1b49
ARG JENKINS_URL="https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war"

#----------------------------------------------------------------------------------------------------------#
# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum #
# see https://github.com/docker/docker/issues/8331                                                         #
#----------------------------------------------------------------------------------------------------------#
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
    && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" >/tmp/jenkins_sha \
    && sha256sum -c --strict /tmp/jenkins_sha \
    && rm -f /tmp/jenkins_sha

ENV JENKINS_UC=https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
RUN chown -R ${user} "$JENKINS_HOME" "$REF"

ARG PLUGIN_CLI_VERSION=2.13.2
ARG PLUGIN_CLI_URL=https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${PLUGIN_CLI_VERSION}/jenkins-plugin-manager-${PLUGIN_CLI_VERSION}.jar
RUN curl -fsSL ${PLUGIN_CLI_URL} -o /opt/jenkins-plugin-manager.jar \
    && echo "$(curl -fsSL "${PLUGIN_CLI_URL}.sha256")  /opt/jenkins-plugin-manager.jar" >/tmp/jenkins_sha \
    && sha256sum -c --strict /tmp/jenkins_sha \
    && rm -f /tmp/jenkins_sha

ENV COPY_REFERENCE_FILE_LOG=$JENKINS_HOME/copy_reference_file.log

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

COPY --from=jre-build /javaruntime $JAVA_HOME

COPY ["./jenkins-support", "./jenkins.sh", "/usr/local/bin/"]
COPY ["./jenkins-plugin-cli.sh", "/bin/jenkins-plugin-cli"]

#---------------------------------------------------------------#
# Jenkins home directory is a volume, so configuration          #
# and build history can be persisted and survive image upgrades #
#---------------------------------------------------------------#
VOLUME $JENKINS_HOME

#------------------------------------------#
# ${http_port}:     for main web interface #
#------------------------------------------#
# ${agent_port}:    for attached agents    #
#------------------------------------------#
EXPOSE ${http_port} ${agent_port}

USER ${user}
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

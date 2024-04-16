#!/usr/bin/env ash
JAVA_MAJOR_VERSION=$(echo "$JAVA_VERSION" | cut -d'+' -f1 | cut -d'.' -f1) \
  && ARCHIVE_DIRECTORY=$(echo "$JAVA_VERSION" | sed -e 's/_/+/') \
  && ENCODED_ARCHIVE_DIRECTORY=$(echo "$ARCHIVE_DIRECTORY" | jq "@uri" -jRr) \
  && CONVERTED_ARCH=$(arch | sed -e 's/x86_64/x64/' -e 's/armv7l/arm/') \
  && wget --quiet https://github.com/adoptium/temurin"${JAVA_MAJOR_VERSION}"-binaries/releases/download/jdk-"${ENCODED_ARCHIVE_DIRECTORY}"/OpenJDK"${JAVA_MAJOR_VERSION}"U-jdk_"${CONVERTED_ARCH}"_alpine-linux_hotspot_"${JAVA_VERSION}".tar.gz -O /tmp/jdk.tar.gz \
  && tar -xzf /tmp/jdk.tar.gz -C /opt/ \
  && mv /opt/jdk-"${ARCHIVE_DIRECTORY}" /opt/jdk-${JAVA_VERSION} \
  && rm -f /tmp/jdk.tar.gz

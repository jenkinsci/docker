#!/bin/bash
# Script to import custom root CA certificates into the Java keystore.
# It handles .crt and .pem files mapped into the certs directory.

# Ensure JAVA_HOME is set, default to a common path if not
if [ -z "${JAVA_HOME}" ]; then
    if [ -d "/opt/java/openjdk" ]; then
        export JAVA_HOME="/opt/java/openjdk"
    elif [ -d "/usr/lib/jvm/java-11-openjdk" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
    fi
fi

if [ -z "${JAVA_HOME}" ]; then
    echo "ERROR: JAVA_HOME is not set and could not be determined." >&2
    exit 0 # Don't crash the container
fi

: "${REF:="/usr/share/jenkins/ref"}"
: "${JENKINS_CUSTOM_CERTS_DIR:="${REF}/certs"}"

CACERTS_KEYSTORE="${JAVA_HOME}/lib/security/cacerts"
CACERTS_PASSWORD="${CACERTS_PASSWORD:-changeit}"

if [ ! -d "${JENKINS_CUSTOM_CERTS_DIR}" ]; then
    exit 0
fi

echo "Scanning for custom certificates in ${JENKINS_CUSTOM_CERTS_DIR}..."

# Find certs and process them one by one
# Using a temp file for the list to avoid pipe subshell issues with while loop
cert_list=$(mktemp)
find "${JENKINS_CUSTOM_CERTS_DIR}" -maxdepth 1 -type f \( -name "*.crt" -o -name "*.pem" \) 2>/dev/null > "${cert_list}"

while read -r cert_file; do
    if [ -z "${cert_file}" ]; then continue; fi

    cert_name=$(basename "${cert_file}")
    alias="custom-${cert_name%.*}"

    echo "Checking: ${cert_name} (alias: ${alias})"
    
    # Check if already exists
    if keytool -list -keystore "${CACERTS_KEYSTORE}" -storepass "${CACERTS_PASSWORD}" -alias "${alias}" >/dev/null 2>&1; then
        echo "  Certificate alias '${alias}' already exists, skipping."
        continue
    fi

    echo "  Importing: ${cert_name} ..."
    if keytool -importcert -noprompt -keystore "${CACERTS_KEYSTORE}" -storepass "${CACERTS_PASSWORD}" -alias "${alias}" -file "${cert_file}" >/dev/null 2>&1; then
        echo "  Successfully imported ${cert_name}"
    else
        echo "  WARNING: Failed to import ${cert_name}. Check file format and permissions." >&2
    fi
done < "${cert_list}"

rm -f "${cert_list}"

echo "Custom CA certificate import process complete."
exit 0

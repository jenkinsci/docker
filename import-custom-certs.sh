#!/bin/bash
# Script to import custom root CA certificates into the Java keystore.
# It handles .crt and .pem files mapped into the certs directory.

: "${JAVA_HOME:?JAVA_HOME must be set}"
: "${REF:="/usr/share/jenkins/ref"}"
: "${JENKINS_CUSTOM_CERTS_DIR:="${REF}/certs"}"

CACERTS_KEYSTORE="${JAVA_HOME}/lib/security/cacerts"
CACERTS_PASSWORD="${CACERTS_PASSWORD:-changeit}"

if [ ! -d "${JENKINS_CUSTOM_CERTS_DIR}" ]; then
    exit 0
fi

# Find certs and process them one by one
find "${JENKINS_CUSTOM_CERTS_DIR}" -maxdepth 1 -type f \( -name "*.crt" -o -name "*.pem" \) 2>/dev/null | while read -r cert_file; do
    if [ -z "${cert_file}" ]; then continue; fi

    cert_name=$(basename "${cert_file}")
    alias="custom-${cert_name%.*}"

    # Check if already exists
    if keytool -list -keystore "${CACERTS_KEYSTORE}" -storepass "${CACERTS_PASSWORD}" -alias "${alias}" >/dev/null 2>&1; then
        echo "Certificate alias '${alias}' already exists, skipping."
        continue
    fi

    echo "Importing: ${cert_name} (alias: ${alias})"
    if keytool -importcert -noprompt -keystore "${CACERTS_KEYSTORE}" -storepass "${CACERTS_PASSWORD}" -alias "${alias}" -file "${cert_file}" >/dev/null 2>&1; then
        echo "Successfully imported ${cert_name}"
    else
        echo "WARNING: Failed to import ${cert_name}" >&2
    fi
done

echo "Custom CA certificate import process complete."
exit 0

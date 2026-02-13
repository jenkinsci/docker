#!/bin/bash
# Script to import custom root CA certificates into the Java keystore
# at container startup. This enables users to add custom root CA certificates
# by volume-mapping them into /usr/share/jenkins/ref/certs/ directory.
#
# Supported certificate formats: .crt, .pem
#
# Usage:
#   docker run -v /path/to/my-certs:/usr/share/jenkins/ref/certs:ro \
#     jenkins/jenkins:lts-jdk21
#
# Or set a custom directory:
#   docker run -e JENKINS_CUSTOM_CERTS_DIR=/custom/certs/path \
#     -v /path/to/my-certs:/custom/certs/path:ro \
#     jenkins/jenkins:lts-jdk21

set -e

: "${JAVA_HOME:?JAVA_HOME must be set}"
: "${REF:="/usr/share/jenkins/ref"}"
: "${JENKINS_CUSTOM_CERTS_DIR:="${REF}/certs"}"

CACERTS_KEYSTORE="${JAVA_HOME}/lib/security/cacerts"
CACERTS_PASSWORD="${CACERTS_PASSWORD:-changeit}"

import_custom_certs() {
    local cert_dir="${JENKINS_CUSTOM_CERTS_DIR}"

    # Skip if certs directory does not exist
    if [ ! -d "${cert_dir}" ]; then
        return 0
    fi

    # Find all certificate files (.crt and .pem)
    local cert_files
    cert_files=$(find "${cert_dir}" -maxdepth 1 -type f \( -name "*.crt" -o -name "*.pem" \) 2>/dev/null || true)

    # Skip if no certificate files found
    if [ -z "${cert_files}" ]; then
        return 0
    fi

    echo "Importing custom CA certificates from ${cert_dir}..."

    local imported=0
    local skipped=0
    local failed=0

    while IFS= read -r cert_file; do
        local alias
        alias=$(basename "${cert_file}" | sed 's/\.\(crt\|pem\)$//')

        # Check if alias already exists in keystore
        if keytool -list -keystore "${CACERTS_KEYSTORE}" \
            -storepass "${CACERTS_PASSWORD}" \
            -alias "custom-${alias}" >/dev/null 2>&1; then
            echo "  Certificate 'custom-${alias}' already exists in keystore, skipping."
            skipped=$((skipped + 1))
            continue
        fi

        # Import certificate
        if keytool -importcert -noprompt \
            -keystore "${CACERTS_KEYSTORE}" \
            -storepass "${CACERTS_PASSWORD}" \
            -alias "custom-${alias}" \
            -file "${cert_file}" 2>/dev/null; then
            echo "  Imported certificate: ${cert_file} (alias: custom-${alias})"
            imported=$((imported + 1))
        else
            echo "  WARNING: Failed to import certificate: ${cert_file}" >&2
            failed=$((failed + 1))
        fi
    done <<< "${cert_files}"

    echo "Custom CA certificates import complete: ${imported} imported, ${skipped} skipped, ${failed} failed."
}

import_custom_certs

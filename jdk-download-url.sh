#!/bin/sh

# Check if at least one argument was passed to the script
# If one argument was passed and JAVA_VERSION is set, assign the argument to OS
# If two arguments were passed, assign them to JAVA_VERSION and OS respectively
# If three arguments were passed, assign them to JAVA_VERSION, OS and ARCHS respectively
# If not, check if JAVA_VERSION and OS are already set. If they're not set, exit the script with an error message
if [ $# -eq 1 ] && [ -n "$JAVA_VERSION" ]; then
    OS=$1
elif [ $# -eq 2 ]; then
    JAVA_VERSION=$1
    OS=$2
elif [ $# -eq 3 ]; then
    JAVA_VERSION=$1
    OS=$2
    ARCHS=$3
elif [ -z "$JAVA_VERSION" ] && [ -z "$OS" ]; then
    echo "Error: No Java version and OS specified. Please set the JAVA_VERSION and OS environment variables or pass them as arguments." >&2
    exit 1
elif [ -z "$JAVA_VERSION" ]; then
    echo "Error: No Java version specified. Please set the JAVA_VERSION environment variable or pass it as an argument." >&2
    exit 1
elif [ -z "$OS" ]; then
    OS=$1
    if [ -z "$OS" ]; then
        echo "Error: No OS specified. Please set the OS environment variable or pass it as an argument." >&2
        exit 1
    fi
fi

# Check if ARCHS is set. If it's not set, assign the current architecture to it
if [ -z "$ARCHS" ]; then
    ARCHS=$(uname -m | sed -e 's/x86_64/x64/' -e 's/armv7l/arm/')
else
    # Convert ARCHS to an array
    OLD_IFS=$IFS
    IFS=','
    set -- "$ARCHS"
    ARCHS=""
    for arch in "$@"; do
        ARCHS="$ARCHS $arch"
    done
    IFS=$OLD_IFS
fi

# Check if jq and curl are installed
# If they are not installed, exit the script with an error message
if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo "jq and curl are required but not installed. Exiting with status 1." >&2
    exit 1
fi

# Replace underscores with plus signs in JAVA_VERSION
ARCHIVE_DIRECTORY=$(echo "$JAVA_VERSION" | tr '_' '+')

# URL encode ARCHIVE_DIRECTORY
ENCODED_ARCHIVE_DIRECTORY=$(echo "$ARCHIVE_DIRECTORY" | xargs -I {} printf %s {} | jq "@uri" -jRr)

# Determine the OS type for the URL
OS_TYPE="linux"
if [ "$OS" = "alpine" ]; then
    OS_TYPE="alpine-linux"
fi
if [ "$OS" = "windows" ]; then
    OS_TYPE="windows"
fi

# Initialize a variable to store the URL for the first architecture
FIRST_ARCH_URL=""

# Loop over the array of architectures
for ARCH in $ARCHS; do
    # Fetch the download URL from the Adoptium API
    URL="https://api.adoptium.net/v3/binary/version/jdk-${ENCODED_ARCHIVE_DIRECTORY}/${OS_TYPE}/${ARCH}/jdk/hotspot/normal/eclipse?project=jdk"

    if ! RESPONSE=$(curl -fsI "$URL"); then
        echo "Error: Failed to fetch the URL for architecture ${ARCH} from ${URL}. Exiting with status 1." >&2
        echo "Response: $RESPONSE" >&2
        exit 1
    fi

    # Extract the redirect URL from the HTTP response
    REDIRECTED_URL=$(echo "$RESPONSE" | grep -i location | awk '{print $2}' | tr -d '\r')

    # If no redirect URL was found, exit the script with an error message
    if [ -z "$REDIRECTED_URL" ]; then
        echo "Error: No redirect URL found for architecture ${ARCH} from ${URL}. Exiting with status 1." >&2
        echo "Response: $RESPONSE" >&2
        exit 1
    fi

    # Use curl to check if the URL is reachable
    # If the URL is not reachable, print an error message and exit the script with status 1
    if ! curl -v -fs "$REDIRECTED_URL" >/dev/null 2>&1; then
        echo "${REDIRECTED_URL}" is not reachable for architecture "${ARCH}". >&2
        exit 1
    fi

    # If FIRST_ARCH_URL is empty, store the current URL
    if [ -z "$FIRST_ARCH_URL" ]; then
        FIRST_ARCH_URL=$REDIRECTED_URL
    fi
done

# If all downloads are successful, print the URL for the first architecture
echo "$FIRST_ARCH_URL"

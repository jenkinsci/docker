#!/bin/bash

# This script fetches the latest tag from the Red Hat Container Catalog API for the images of the current RHEL release line.
# It ensures that `jq` and `curl` are installed, fetches the most recent tags, and processes them to find the unique tag associated to `latest`s.

# The Swagger API endpoints for the Red Hat Container Catalog API are documented at:
# https://catalog.redhat.com/api/containers/v1/ui/#/Repositories/graphql.images.get_images_by_repo

# The script uses the following parameters for the API request:
# - registry: registry.access.redhat.com
# - repository: <rhel_release_line>
# - page_size: 100
# - page: 0
# - sort_by: last_update_date[desc]

# The curl command fetches the JSON data containing the tags for the images of the RHEL release line passed in parameter,
# then parses it using `jq` to find the version associated with the "latest" tag.
# It focuses on tags that contain a hyphen, as these represent the long-form tag names.
# The script ensures that only one instance of each tag is kept, in case of duplicates.

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <rhel_release_line>"
  echo "Example:"
  echo "  $0 ubi9"
  exit 1
fi

release_line="$1"

# Correct URL of the Red Hat Container Catalog API for the release line
URL="https://catalog.redhat.com/api/containers/v1/repositories/registry/registry.access.redhat.com/repository/${release_line}/images?page_size=100&page=0&sort_by=last_update_date%5Bdesc%5D"

# Check if jq and curl are installed
# If they are not installed, exit the script with an error message
if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    >&2 echo "jq and curl are required but not installed. Exiting with status 1." >&2
    exit 1
fi

# Fetch release line from registry.access.redhat.com sorted by most recent update date, and keeping only the first page.
response=$(curl --silent --fail --location --connect-timeout 10 --retry 3 --retry-delay 2 --max-time 30 --header 'accept: application/json' "$URL")

# Check if the response is empty or null
if [ -z "$response" ] || [ "$response" == "null" ]; then
  >&2 echo "Error: Failed to fetch tags from the Red Hat Container Catalog API."
  exit 1
fi

# Parse the JSON response using jq to find the version associated with the "latest" tag
# - The response is expected to be a JSON object containing repository data.
# - The script uses `jq` to:
#   1. Iterate over all repositories in the `data` array.
#   2. Select repositories where at least one tag has the name "latest".
#   3. From those repositories, select tags that:
#      - Do not have the name "latest".
#      - Contain a hyphen in their name (indicating a long-form tag).
#   4. Extract the `name` of the matching tags.
#   5. Sort the tag names uniquely (`sort -u`).
#   6. Take the last tag in the sorted list (`tail -n 1`), which is assumed to be the most recent valid tag.
latest_tag=$(echo "$response" | jq -r '.data[].repositories[] | select(.tags[].name == "latest") | .tags[] | select(.name != "latest" and (.name | contains("-"))) | .name' | sort -u | tail -n 1)


# Check if the latest_tag is empty
if [ -z "$latest_tag" ]; then
  echo "Error: No valid tags found."
  exit 1
fi

# Output the latest tag version
echo "$latest_tag"
exit 0

#!/usr/bin/env bash
set -euxo pipefail

pr_numbers="$(gh pr list \
  --state open \
  --json number,labels,body \
  --jq '.[]
    | select(any(.labels[]; .name == "dependencies"))
    | select(any(.labels[]; .name | test("^jdk[0-9]+$")))
    | select((.body // "") | contains("<!-- pr-title-updated -->") | not)
    | .number')"

if [[ -z "${pr_numbers}" ]]; then
  echo 'No pull request with "dependencies" and "jdk<N>" labels not updated yet found'
  exit 0
fi

while read -r pr_number; do
  pr_data=$(gh pr view "${pr_number}" --json title,body,headRepository)

  body="$(jq -r '.body' <<< "${pr_data}")"
  architectures="$(grep '<summary>' <<< "${body}" | grep 'Bump' | sed -E 's|.*Installer URL for (.*)</summary>|\1|' | tr -d '\r' | sort)"

  if [[ -z "${architectures}" ]]; then
    echo "No architectures found in PR #${pr_number}, skipping"
    continue
  fi

  architecture_list=""
  while IFS= read -r architecture; do
    [[ -n "${architecture_list}" ]] && architecture_list+=", "
    architecture_list+="\`${architecture}\`"
  done <<< "${architectures}"

  title="$(jq -r '.title' <<< "${pr_data}") (${architecture_list})"
  updated_body="${body}<!-- pr-title-updated -->"

  gh pr edit "${pr_number}" --title "${title}" --body "${updated_body}"
done <<< "${pr_numbers}"

#!/usr/bin/env bash
set -euo pipefail

read_tag() {
    if [[ -f "$1" ]]; then head -n 1 "$1"; fi
}
validate_tag() {
    [[ -z "$1" || "$1" =~ ^v[0-9][a-zA-Z0-9._-]*$ ]] || {
        echo "Invalid Xray version: $1" >&2
        return 1
    }
}

local_stable=$(read_tag ReleaseTag)
local_pre=$(read_tag PreReleaseTag)
mode=${1:-auto}
if [[ "$mode" == manual ]]; then
    stable_version=${INPUT_STABLE:-$local_stable}
    pre_version=${INPUT_PRE:-$local_pre}
elif [[ "$mode" == auto ]]; then
    headers=(-H 'Accept: application/vnd.github+json')
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi
    api() {
        curl --fail --silent --show-error --retry 3 \
            "${headers[@]}" \
            "https://api.github.com/repos/XTLS/Xray-core/$1"
    }
    stable_version=$(api releases/latest | jq -er 'select(.draft == false and .prerelease == false) | .tag_name | select(type == "string" and length > 0)')
    pre_version=''
    page=1
    # Paginate until a pre-release is found or the release list is exhausted.
    while :; do
        releases=$(api "releases?per_page=100&page=$page")
        jq -e 'type == "array"' <<< "$releases" > /dev/null
        pre_version=$(jq -r '[.[] | select(.draft == false and .prerelease == true)][0].tag_name // empty' <<< "$releases")
        if [[ -n "$pre_version" ]] || [[ $(jq 'length' <<< "$releases") -lt 100 ]]; then
            break
        fi
        page=$((page + 1))
    done
else
    echo "Unknown mode: $mode" >&2
    exit 1
fi

validate_tag "$stable_version"
validate_tag "$pre_version"
should_build_stable=false
should_build_pre=false
if [[ -n "$stable_version" && ( "$mode" == manual || "$stable_version" != "$local_stable" ) ]]; then
    should_build_stable=true
fi
if [[ -n "$pre_version" && ( "$mode" == manual || "$pre_version" != "$local_pre" ) ]]; then
    should_build_pre=true
fi
printf 'Stable: %s -> %s; build=%s\n' "$local_stable" "$stable_version" "$should_build_stable"
printf 'Pre-release: %s -> %s; build=%s\n' "$local_pre" "$pre_version" "$should_build_pre"
{
    echo "stable_version=$stable_version"
    echo "pre_version=$pre_version"
    echo "should_build_stable=$should_build_stable"
    echo "should_build_pre=$should_build_pre"
} >> "$GITHUB_OUTPUT"

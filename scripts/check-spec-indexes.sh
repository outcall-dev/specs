#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/outcall-spec-check.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

failures=0

extract_ids() {
    prefix=$1
    shift
    sed -nE \
        -e "s/^(${prefix}-(FR|AS|IF|EC|SC)-[0-9][0-9][0-9])[[:space:]]+\[.*/\1/p" \
        -e "s/^#{1,6}[[:space:]]+(${prefix}-(FR|AS|IF|EC|SC)-[0-9][0-9][0-9])([:[:space:]].*)?$/\1/p" \
        -e "s/^\|[[:space:]]*(${prefix}-(FR|AS|IF|EC|SC)-[0-9][0-9][0-9])[[:space:]]*\|.*/\1/p" \
        -e "s/^#{1,6}[[:space:]]+((FR|AS|IF|EC|SC)-[0-9][0-9][0-9])([:[:space:]].*)?$/${prefix}-\1/p" \
        "$@"
}

for index in "$repo_root"/specs/*/index.md; do
    spec_dir=${index%/*}
    spec_name=${spec_dir##*/}
    spec_number=${spec_name%%-*}
    prefix=S$spec_number
    index_ids="$tmp_dir/$prefix.index"
    table_ids="$tmp_dir/$prefix.table"
    detail_ids="$tmp_dir/$prefix.details"

    extract_ids "$prefix" "$index" | sort -u >"$index_ids"
    sed -nE \
        "s/^\|[[:space:]]*(${prefix}-(FR|AS|IF|EC|SC)-[0-9][0-9][0-9])[[:space:]]*\|.*/\1/p" \
        "$index" | sort >"$table_ids"
    duplicates=$(uniq -d "$table_ids")
    if [ -n "$duplicates" ]; then
        printf '%s: duplicate index IDs:\n%s\n' "$index" "$duplicates" >&2
        failures=$((failures + 1))
    fi

    if ! awk -F '|' '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        /^\|[[:space:]]*S[0-9][0-9][0-9]-(FR|AS|IF|EC|SC)-[0-9][0-9][0-9][[:space:]]*\|/ {
            status = trim($(NF - 1))
            if (status !~ /^(Draft|Implemented|Deferred|Partial|In progress|Done)( |$)/) {
                printf "%s:%d: unsupported requirement status: %s\n", FILENAME, NR, status > "/dev/stderr"
                invalid = 1
            }
        }
        END { exit invalid }
    ' "$index"; then
        failures=$((failures + 1))
    fi

    : >"$detail_ids"
    has_details=false
    for detail in "$spec_dir"/*.md; do
        [ "$detail" = "$index" ] && continue
        has_details=true
        extract_ids "$prefix" "$detail" >>"$detail_ids"
    done
    [ "$has_details" = true ] || continue

    sort -o "$detail_ids" "$detail_ids"
    duplicates=$(uniq -d "$detail_ids")
    if [ -n "$duplicates" ]; then
        printf '%s: duplicate detail definitions:\n%s\n' "$spec_dir" "$duplicates" >&2
        failures=$((failures + 1))
    fi

    sort -u -o "$detail_ids" "$detail_ids"
    missing=$(comm -23 "$detail_ids" "$index_ids")
    orphaned=$(comm -13 "$detail_ids" "$index_ids")
    if [ -n "$missing" ]; then
        printf '%s: IDs missing from index.md:\n%s\n' "$spec_dir" "$missing" >&2
        failures=$((failures + 1))
    fi
    if [ -n "$orphaned" ]; then
        printf '%s: index IDs without a detail definition:\n%s\n' "$spec_dir" "$orphaned" >&2
        failures=$((failures + 1))
    fi
done

if [ "$failures" -ne 0 ]; then
    printf 'Spec index validation failed with %s issue group(s).\n' "$failures" >&2
    exit 1
fi

printf 'Spec indexes are internally consistent.\n'

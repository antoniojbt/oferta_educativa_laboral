#!/usr/bin/env bash

# Export tables from an Access .accdb file as UTF-8 CSVs.
#
# Usage:
#   accdb_to_csv_encodings_copy.sh -i DB.accdb [-o outdir]
#
# Each table "Foo Bar" becomes "Foo_Bar.csv" in the output directory. The script
# first attempts to decode using Windows-1252. If that fails it falls back to
# UTF-8. Names of tables requiring the fallback are logged.


# Bash safety
set -euo pipefail

# Defaults
PRIMARY_CHARSET="cp1252"
FALLBACK_CHARSET="utf-8"
DB_FILE=""
OUTDIR="."

usage() {
    cat <<EOF
Usage: $(basename "$0") -i input.accdb [-o outdir]

Export each table in the Access database as a UTF-8 CSV. Requires mdb-tools.

Options:
  -i FILE   Input .accdb database
  -o DIR    Output directory (default: current directory)
  -h        Show this help
EOF
}

while getopts "i:o:h" opt; do
    case "$opt" in
        i) DB_FILE="$OPTARG";;
        o) OUTDIR="$OPTARG";;
        h) usage; exit 0;;
        *) usage; exit 1;;
    esac
done

if [[ -z "$DB_FILE" ]]; then
    echo "Error: -i input.accdb is required" >&2
    usage
    exit 1
fi

command -v mdb-tables >/dev/null || { echo "mdb-tables not found" >&2; exit 1; }
command -v mdb-export >/dev/null || { echo "mdb-export not found" >&2; exit 1; }

mkdir -p "$OUTDIR"

# Log if encodings fail:
LOGFILE="$OUTDIR/failed_tables.log"
> "$LOGFILE"   # empty the logfile

# Get tables safely:
mapfile -t TABLES < <(mdb-tables -1 "$DB_FILE")

for t in "${TABLES[@]}"; do
    echo "Exporting table: $t..." >&2
    SAFE_NAME=$(echo "$t" | tr ' /' '_')
    TMPFILE="$(mktemp)"

    # Attempt export using the primary charset first
    if mdb-export -D '%Y-%m-%d %H:%M:%S' -d ',' -q '"' "$DB_FILE" "$t" \
        | iconv -f "$PRIMARY_CHARSET" -t utf-8//IGNORE > "$TMPFILE"; then
        echo "OK with $PRIMARY_CHARSET" >&2
    else
        echo "$PRIMARY_CHARSET failed, trying $FALLBACK_CHARSET..." >&2
        echo "$t" >> "$LOGFILE"

        # Retry with fallback encoding:
        if mdb-export -D '%Y-%m-%d %H:%M:%S' -d ',' -q '"' "$DB_FILE" "$t" \
            | iconv -f "$FALLBACK_CHARSET" -t utf-8//IGNORE > "$TMPFILE"; then
            echo "OK with $FALLBACK_CHARSET" >&2
        else
            echo "FAILED: Could not export $t with $FALLBACK_CHARSET" >&2
            rm -f "$TMPFILE"
            continue
        fi
    fi

    # Move temporary output to final file:
    mv "$TMPFILE" "$OUTDIR/${SAFE_NAME}.csv"
done

echo "Done." >&2
echo "Tables needing $FALLBACK_CHARSET decoding are in: $LOGFILE" >&2

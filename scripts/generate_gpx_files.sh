#!/bin/sh

# SPDX-FileCopyrightText: 2026 Jasper Ben Orschulko
# SPDX-License-Identifier: MIT

set -e

SCRIPT_DIR=$(dirname "$0")

usage() {
  echo "usage: ${0}:  [-f INPUT_FILE_NAME_WITHOUT_EXT] [optional: -i INPUT_DIR] [optional: -o OUTPUT_DIR]" >&2;
}

while getopts i:f:o:h option
do
  case $option in
    i)  INPUT_DIR="$OPTARG";;
    f)  INPUT_FILE_NAME_WITHOUT_EXT="$OPTARG";;
    o)  OUTPUT_DIR="$OPTARG";;
    h | ?) usage; exit 2;;
  esac
done

if test -z "$INPUT_FILE_NAME_WITHOUT_EXT"; then
  usage; exit 1;
fi

if test -z "$INPUT_DIR"; then
  INPUT_DIR="$SCRIPT_DIR"
fi

MIF_FILE="${INPUT_DIR}/${INPUT_FILE_NAME_WITHOUT_EXT}.mif"
MID_FILE="${INPUT_DIR}/${INPUT_FILE_NAME_WITHOUT_EXT}.mid"

if ! test -f "$MIF_FILE"; then
  echo "MIF file not found at ${MIF_FILE}" >&2
  exit 1
fi

if ! test -f "$MID_FILE"; then
  echo "MID file not found at ${MID_FILE}" >&2
  exit 1
fi

if test -z "${OUTPUT_DIR}"; then
  OUTPUT_DIR="${SCRIPT_DIR}"
fi
mkdir -p "${OUTPUT_DIR}"

DATE="$(date +%Y%m%d)"
TABLE_NAME="$(basename "${MIF_FILE}" .mif)"

# generate combined file
OUTPUT_FILE="${OUTPUT_DIR}/amsterdam-fietsnetten-gecombineerd_${DATE}.gpx"
ogr2ogr \
  -f GPX \
  -t_srs EPSG:4326 \
  -lco FORCE_GPX_TRACK=YES \
  -nlt LINESTRING \
  -dsco GPX_USE_EXTENSIONS=YES \
-sql "SELECT OBJECTNUMMER AS name, Label AS \"desc\" FROM \"${TABLE_NAME}\"" \
"$OUTPUT_FILE" \
"$MIF_FILE"

# set osmand style
xmlstarlet ed -L \
  -N gpx=http://www.topografix.com/GPX/1/1 \
  -i "/*[1]" -t attr -n "xmlns:osmand" -v "https://osmand.net/docs/technical/osmand-file-formats/osmand-gpx" \
  -s "/*[1][not(extensions)]" -t elem -n "extensions" \
  -s "/*[1]/extensions" -t elem -n "osmand:width" -v "medium" \
  -s "/*[1]/extensions" -t elem -n "osmand:show_start_finish" -v "false" \
  "$OUTPUT_FILE"

# validate file
ogrinfo "$OUTPUT_FILE"
echo "Successfully wrote ${OUTPUT_FILE}" >&2

# generate separate files for each fietspad type
set -- "Fietspad" "Fietspad (snorfiets niet toegestaan)" "Fietspad (onverplicht)" "Brom-/Fietspad" "Fietsstrook" "Fietsstraat" "Fiets op rijbaan" "Shared space" "Fietsoversteek" "Verbinding"
for TYPE; do
  TYPE_SANITIZED=$(echo "$TYPE" | tr '[:upper:]' '[:lower:]' | tr -C '[:alnum:]' '-' | sed 's/--*/-/g' | sed 's/-$//')
  OUTPUT_FILE="${OUTPUT_DIR}/amsterdam-fietsnetten-${TYPE_SANITIZED}_${DATE}.gpx"
  TYPE_WIDTH="medium"

  case $TYPE in
  "Fietspad")
    TYPE_COLOR="#75ff95"
    ;;
  "Fietspad (snorfiets niet toegestaan)")
    TYPE_COLOR="#ccff54"
    ;;
  "Fietspad (onverplicht)")
    TYPE_COLOR="#3dffa5"
    ;;
  "Brom-/Fietspad")
    TYPE_COLOR="#4ab0fd"
    ;;
  "Fietsstrook")
    TYPE_COLOR="#ffbb1d"
    ;;
  "Fietsstraat")
    TYPE_COLOR="#d72aff"
    ;;
  "Fiets op rijbaan")
    TYPE_COLOR="#ff5151"
    ;;
  "Shared space")
    TYPE_COLOR="#64ff89"
    TYPE_WIDTH="thin"
    ;;
  "Fietsoversteek")
    TYPE_COLOR="#ffbb1d"
    TYPE_WIDTH="thin"
    ;;
  "Verbinding")
    TYPE_COLOR="#ff5151"
    TYPE_WIDTH="thin"
    ;;
  *)
    ;;
  esac

  # check whether all defined types are present in mif file
  MATCH_COUNT=$(ogrinfo "$MIF_FILE" -sql "SELECT COUNT(*) FROM \"${TABLE_NAME}\" WHERE Label LIKE '${TYPE}%'" -q | awk '/COUNT_\*/{print $NF}')
  [ "$MATCH_COUNT" -ne 0 ] || { echo "Error: Empty result for type ${TYPE}" >&2; exit 1; }

  ogr2ogr \
    -f GPX \
    -t_srs EPSG:4326 \
    -lco FORCE_GPX_TRACK=YES \
    -nlt LINESTRING \
    -dsco GPX_USE_EXTENSIONS=YES \
    -sql "SELECT OBJECTNUMMER AS name, Label AS \"desc\" FROM \"${TABLE_NAME}\" WHERE Label LIKE '${TYPE}%'" \
    "$OUTPUT_FILE" \
    "$MIF_FILE"

  # set osmand style
  xmlstarlet ed -L \
    -N gpx=http://www.topografix.com/GPX/1/1 \
    -i "/*[1]" -t attr -n "xmlns:osmand" -v "https://osmand.net/docs/technical/osmand-file-formats/osmand-gpx" \
    -s "/*[1][not(extensions)]" -t elem -n "extensions" \
    -s "/*[1][not(extensions)]" -t elem -n "extensions" \
    -s "/*[1]/extensions" -t elem -n "osmand:show_start_finish" -v "false" \
    -s "/*[1]/extensions" -t elem -n "osmand:color" -v "$TYPE_COLOR" \
    -s "/*[1]/extensions" -t elem -n "osmand:width" -v "$TYPE_WIDTH" \
    "$OUTPUT_FILE"

  # validate file
  ogrinfo "$OUTPUT_FILE"
  echo "Successfully wrote ${OUTPUT_FILE}" >&2
done

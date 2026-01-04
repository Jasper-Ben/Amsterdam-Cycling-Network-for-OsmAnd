# SPDX-FileCopyrightText: 2026 Jasper Ben Orschulko
# SPDX-License-Identifier: MIT

.DEFAULT_GOAL := generate-gpx-files

MAKEFILE_PATH := $(abspath $(lastword ${MAKEFILE_LIST}))
MAKEFILE_DIR := $(dir ${MAKEFILE_PATH})

DATE := $(shell date +%Y%m%d)

INPUT_DIR ?= ${MAKEFILE_DIR}input
MIF_FILE ?= ${INPUT_DIR}/fietsnetten_${DATE}.mif
MID_FILE ?= ${INPUT_DIR}/fietsnetten_${DATE}.mid

OUTPUT_DIR ?= ${MAKEFILE_DIR}output

BASE_NAME := $(shell basename "${MIF_FILE}" .mif)

download-map-data:
	mkdir -p ${INPUT_DIR}
	test -f "${MIF_FILE}" || curl -SsfL "https://maps.amsterdam.nl/open_geodata/mif.php?KAARTLAAG=FIETSNETTEN&THEMA=fietsnetten" -o "${MIF_FILE}"
	test -f "${MID_FILE}" || curl -SsfL "https://maps.amsterdam.nl/open_geodata/mid.php?KAARTLAAG=FIETSNETTEN&THEMA=fietsnetten" -o "${MID_FILE}"

generate-gpx-files: download-map-data
	${MAKEFILE_DIR}scripts/generate_gpx_files.sh -i "${INPUT_DIR}" -o "${OUTPUT_DIR}" -f "${BASE_NAME}"
	@echo "Done"

PREV_RELEASE_DIR := ${MAKEFILE_DIR}prev-release
download-previous-release-map-data:
	mkdir -p "${PREV_RELEASE_DIR}"
	gh release download --clobber -p "*.mid" -p "*.mif" -D "${PREV_RELEASE_DIR}"

check-for-new-map-data: download-map-data download-previous-release-map-data
	PREV_MIF_FILE="$$(find ${PREV_RELEASE_DIR} -name "*.mif" -print -quit)" && \
	PREV_MID_FILE="$$(find ${PREV_RELEASE_DIR} -name "*.mid" -print -quit)" && \
	if [ "$$(sha1sum "$$PREV_MID_FILE" | cut -d' ' -f1)" = "$$(sha1sum "${MID_FILE}" | cut -d' ' -f1)" ] && \
	[ "$$(sha1sum "$$PREV_MIF_FILE" | cut -d' ' -f1)" = "$$(sha1sum "${MIF_FILE}" | cut -d' ' -f1)" ]; then \
		echo "Map data unchanged. Exiting" >&2; exit 2; \
	else \
  echo "Map data changed. Regenerating GPX files" >&2; exit 0; \
fi

create-github-release: generate-gpx-files
	gh release create "${DATE}" \
		--title "Amsterdam Cycling Network ${DATE}" \
		--notes "Auto-generated OsmAnd GPX files for the Amsterdam cycling network (fietsnetten)" \
		${INPUT_DIR}/fietsnetten_${DATE}.mid \
		${INPUT_DIR}/fietsnetten_${DATE}.mif \
		${OUTPUT_DIR}/*.gpx

TOS_URL=https://maps.amsterdam.nl/open_geodata/terms.php
TOS_SHA_CHECKSUM_FILE=${MAKEFILE_DIR}.tos.sha1
check-for-tos-changes:
	if [ "$$(cat "${TOS_SHA_CHECKSUM_FILE}" | cut -d' ' -f1)" != "$$(curl -sSfL "${TOS_URL}" | sha1sum | cut -d' ' -f1)" ]; then \
		echo "Map data TOS changed. Needs investigating" >&2; \
		exit 1; \
	fi

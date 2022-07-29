#!/bin/bash
#
#  Copyright (C) 2018-2020 Aclima, Inc.
#  This file is part of Sundstrom
#
#  SPDX-License-Identifier: GPL-2.0-or-later
#  See LICENSES/README.md for more information.
#

#
# copy_image.sh - Script to copy distribution into a target folder
#
# Environment variable parameters:
#
#    - MACHINE: The OE machine name
#    - IMAGE: The OE image name
#    - DISTRO: The OE distro name
#    - VERSION: The OE distro version
#    - SDKMACHINE: The OE native architecture
#    - TCLIBC: The OE toolchain's C library, e.g. "glibc", "musl" or "uclibc"
#
# This script is the entry point of the packaging system. It expects
# environment parameters set by the Makefile in the root directory. The
# parameters are used to calculate paths which are passed on to the other
# scripts.
#
set -o errexit
set -o pipefail
set -o nounset

# Pass -n as second argument to supress newline
log() {
  echo ${2:-} "copy_image.sh: ${1}"
}

log "MACHINE:    $MACHINE"
log "IMAGE:      $IMAGE"
log "DISTRO:     $DISTRO"
log "VERSION:    $VERSION"
log "SDKMACHINE: $SDKMACHINE"
log "TCLIBC:     $TCLIBC"
echo

# Utility functions
function print_size() {
  du --block-size=1M --apparent-size "$1" | cut -f1
}

# Paths
DEPLOY_DIR="build/deploy/${DISTRO}-${TCLIBC}/images/$MACHINE"

# Set up directory structure
TARGET_DIR=target
mkdir -p $TARGET_DIR

# Copy Mender imges to target dir
log "Copying Mender images to ${TARGET_DIR}..."

MENDER_TARGET="${TARGET_DIR}/${DISTRO}-${IMAGE}-${VERSION}-${MACHINE}.mender"
log "    ${MENDER_TARGET} " -n
cp "${DEPLOY_DIR}/${IMAGE}-${MACHINE}.mender" "${MENDER_TARGET}"
echo "($(print_size "${MENDER_TARGET}") MiB)"

IMG_TARGET="${TARGET_DIR}/${DISTRO}-${IMAGE}-${VERSION}-${MACHINE}.img"
log "    ${IMG_TARGET} " -n
cp "${DEPLOY_DIR}/${IMAGE}-${MACHINE}.uefiimg" "${IMG_TARGET}"
echo "($(print_size "${IMG_TARGET}") MiB)"

BZ2_TARGET="${TARGET_DIR}/${DISTRO}-${IMAGE}-${VERSION}-${MACHINE}.img.bz2"
log "    ${BZ2_TARGET} " -n
cp "${DEPLOY_DIR}/${IMAGE}-${MACHINE}.uefiimg.bz2" "${BZ2_TARGET}"
echo "($(print_size "${BZ2_TARGET}") MiB)"

# Compress image
GZ_TARGET="$TARGET_DIR/${DISTRO}-${IMAGE}-${VERSION}-${MACHINE}.img.gz"
log "Compressing image..."
log "    ${GZ_TARGET} " -n
gzip --keep --force "${IMG_TARGET}"
echo "($(print_size "${GZ_TARGET}") MiB)"

# Clean up
log "Success"
log "Built image: $(basename -- ${GZ_TARGET})"
log "See ${TARGET_DIR}/ folder"
echo

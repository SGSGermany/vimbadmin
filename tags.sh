#!/bin/bash
# ViMbAdmin
# A php-fpm container running ViMbAdmin.
#
# Copyright (c) 2022  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

BUILD_INFO=""
if [ $# -gt 0 ] && [[ "$1" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    BUILD_INFO=".${1,,}"
fi

# get version of package
if [ -z "$VIMBADMIN_VERSION" ]; then
    echo "Unable to read ViMbAdmin version from 'container.env': Missing required '\$VIMBADMIN_VERSION' variable" >&2
    exit 1
elif ! [[ "$VIMBADMIN_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)([+~-]|$) ]]; then
    echo "Unable to read ViMbAdmin version from 'container.env': '$VERSION' is no valid version" >&2
    exit 1
fi

VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
VERSION_MINOR="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
VERSION_MAJOR="${BASH_REMATCH[1]}"

# build tags
BUILD_INFO="$(date --utc +'%Y%m%d')$BUILD_INFO"

TAGS=(
    "v$VERSION" "v$VERSION-$BUILD_INFO"
    "v$VERSION_MINOR" "v$VERSION_MINOR-$BUILD_INFO"
    "v$VERSION_MAJOR" "v$VERSION_MAJOR-$BUILD_INFO"
    "latest"
)

printf 'VERSION="%s"\n' "$VERSION"
printf 'TAGS="%s"\n' "${TAGS[*]}"

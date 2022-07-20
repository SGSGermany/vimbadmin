#!/bin/sh
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

if [ -e "/var/www/vimbadmin_version_info" ]; then
    exit
fi

VIMBADMIN_VERSION="$(sed -ne 's/^VERSION=\(.*\)$/\1/p' /usr/src/vimbadmin/version_info)"

# sync ViMbAdmin files
echo "Initializing ViMbAdmin $VIMBADMIN_VERSION..."
rsync -rlptog --delete --chown www-data:www-data \
    "/usr/src/vimbadmin/vimbadmin/" \
    "/var/www/vimbadmin/"

rsync -rlptog --delete --chown www-data:www-data \
    "/usr/src/vimbadmin/public/" \
    "/var/www/html/"

rsync -lptog --chown www-data:www-data \
    "/usr/src/vimbadmin/version_info" \
    "/var/www/vimbadmin_version_info"

# sync custom skin
if [ -n "$(find "/usr/src/vimbadmin/skin" -mindepth 1 -maxdepth 1 -not -empty)" ]; then
    echo "Applying custom skin..."
    rsync -rlptog --chown www-data:www-data \
        "/usr/src/vimbadmin/skin/public/" \
        "/var/www/html/"

    rsync -rlptog --chown www-data:www-data \
        --exclude '*.patch' \
        "/usr/src/vimbadmin/skin/skin/" \
        "/var/www/vimbadmin/application/views/_skins/custom/"

    (
        cd "/usr/src/vimbadmin/skin/skin"
        find . -name '*.patch' -print0 | while IFS= read -r -d '' FILE; do
            FILE="${FILE:2:-6}"
            rsync -rlptog --chown www-data:www-data \
                --exclude '*.patch' \
                "/usr/src/vimbadmin/vimbadmin/application/views/$FILE" \
                "/var/www/vimbadmin/application/views/_skins/custom/$FILE"
            patch -u \
                "/var/www/vimbadmin/application/views/_skins/custom/$FILE" \
                "/usr/src/vimbadmin/skin/skin/$FILE.patch"
        done
    )
fi

# run install script
/usr/lib/vimbadmin/setup/install.sh

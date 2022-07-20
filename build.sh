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

COMPOSER_INSTALL="https://getcomposer.org/installer"
COMPOSER_INSTALL_SIG="https://composer.github.io/installer.sig"

set -eu -o pipefail
export LC_ALL=C

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"
source "$CI_TOOLS_PATH/helper/git.sh.inc"
source "$CI_TOOLS_PATH/helper/patch.sh.inc"
source "$CI_TOOLS_PATH/helper/php.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

pkg_install "$CONTAINER" --virtual .vimbadmin-run-deps \
    gettext \
    patch \
    rsync

php_install_ext "$CONTAINER" \
    pdo_mysql \
    gettext

user_add "$CONTAINER" mysql 65538

cmd buildah config \
    --env COMPOSER_ALLOW_SUPERUSER="1" \
    "$CONTAINER"

cmd buildah run "$CONTAINER" -- \
    php -r 'copy($_SERVER["argv"][1], "/composer-setup.php") || exit(1);' -- \
    "$COMPOSER_INSTALL"

cmd buildah run "$CONTAINER" -- \
    php -r '(hash_file("sha384", "/composer-setup.php") === file_get_contents($_SERVER["argv"][1])) || exit(1);' -- \
    "$COMPOSER_INSTALL_SIG"

cmd buildah run "$CONTAINER" -- \
    php -f /composer-setup.php -- \
        --install-dir "/usr/local/bin" \
        --filename "composer"

echo + "rm -f …/composer-setup.php" >&2
rm -f "$MOUNT/composer-setup.php"

git_clone "$VIMBADMIN_GIT_REPO" "$VIMBADMIN_GIT_REF" \
    "$MOUNT/usr/src/vimbadmin/vimbadmin" "…/usr/src/vimbadmin/vimbadmin"

echo + "VIMBADMIN_HASH=\"\$(git -C …/usr/src/vimbadmin/vimbadmin rev-parse HEAD)\"" >&2
VIMBADMIN_HASH="$(git -C "$MOUNT/usr/src/vimbadmin/vimbadmin" rev-parse HEAD)"

echo + "[ \"\$VIMBADMIN_GIT_COMMIT\" == \"\$VIMBADMIN_HASH\" ]" >&2
if [ "$VIMBADMIN_GIT_COMMIT" != "$VIMBADMIN_HASH" ]; then
    echo "Failed to verify source code integrity of ViMbAdmin $VIMBADMIN_VERSION:" \
        "Expecting Git commit '$VIMBADMIN_GIT_COMMIT', got '$VIMBADMIN_HASH'" >&2
    exit 1
fi

git_ungit "$MOUNT/usr/src/vimbadmin/vimbadmin" "…/usr/src/vimbadmin/vimbadmin"

patch_apply "$CONTAINER" "$BUILD_DIR/patch" "./patch"

cmd buildah run "$CONTAINER" -- \
    composer -d "/usr/src/vimbadmin/vimbadmin" \
        install --no-dev --prefer-dist --optimize-autoloader

echo + "buildah run $(quote "$CONTAINER") --" \
    "rsync -rlptog /usr/src/vimbadmin/vimbadmin/public/{css,images,img,js,favicon.ico} /usr/src/vimbadmin/public" >&2
buildah run "$CONTAINER" -- \
    rsync -rlptog \
        "/usr/src/vimbadmin/vimbadmin/public/css" \
        "/usr/src/vimbadmin/vimbadmin/public/images" \
        "/usr/src/vimbadmin/vimbadmin/public/img" \
        "/usr/src/vimbadmin/vimbadmin/public/js" \
        "/usr/src/vimbadmin/vimbadmin/public/favicon.ico" \
        "/usr/src/vimbadmin/public"

echo + "rm -rf …/usr/src/vimbadmin/vimbadmin/public" >&2
rm -rf "$MOUNT/usr/src/vimbadmin/vimbadmin/public"

echo + "rm -rf …/usr/src/vimbadmin/vimbadmin/application/views/_skins/myskin" >&2
rm -rf "$MOUNT/usr/src/vimbadmin/vimbadmin/application/views/_skins/myskin"

cmd buildah run "$CONTAINER" -- \
    /bin/sh -c "printf '%s=%s\n' \"\$@\" > /usr/src/vimbadmin/version_info" -- \
        VERSION "$VIMBADMIN_VERSION" \
        HASH "$VIMBADMIN_HASH"

cmd buildah run "$CONTAINER" -- \
    composer clear-cache

cleanup "$CONTAINER"

cmd buildah config \
    --volume "/var/www" \
    --volume "/run/mysql" \
    "$CONTAINER"

cmd buildah config \
    --entrypoint '[ "/entrypoint.sh" ]' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="ViMbAdmin" \
    --annotation org.opencontainers.image.description="A php-fpm container running ViMbAdmin." \
    --annotation org.opencontainers.image.version="$VIMBADMIN_VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/vimbadmin" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"

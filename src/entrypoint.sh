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

set -e

[ $# -gt 0 ] || set -- php-fpm "$@"
if [ "$1" == "php-fpm" ]; then
    if [ ! -f "/etc/vimbadmin/config.secret.inc.php" ]; then
        [ -f "/run/secrets/vimbadmin_setup_key" ] \
            && VIMBADMIN_SETUP_KEY="$(cat "/run/secrets/vimbadmin_setup_key")" \
            || VIMBADMIN_SETUP_KEY="$(LC_ALL=C tr -dc '[\x21-\x7E]' < /dev/urandom 2> /dev/null | tr -d "\\\'" | head -c 64 || true)"

        [ -f "/run/secrets/vimbadmin_cookie_key" ] \
            && VIMBADMIN_COOKIE_KEY="$(cat "/run/secrets/vimbadmin_cookie_key")" \
            || VIMBADMIN_COOKIE_KEY="$(LC_ALL=C tr -dc '[\x21-\x7E]' < /dev/urandom 2> /dev/null | tr -d "\\\'" | head -c 64 || true)"

        {
            printf '<?php\n';
            printf "\$config['securitysalt'] = '%s';\n" "$VIMBADMIN_SETUP_KEY";
            printf "\$config['resources']['auth']['oss']['rememberme']['salt'] = '%s';\n" "$VIMBADMIN_COOKIE_KEY";
        } > "/etc/vimbadmin/config.secret.inc.php"
    fi

    if [ ! -f "/etc/vimbadmin/config.password.inc.php" ]; then
        if
            [ -f "/run/secrets/vimbadmin_password_scheme" ] \
            || [ -f "/run/secrets/vimbadmin_password_salt" ] \
            || [ -f "/run/secrets/vimbadmin_password_min_length" ]
        then
            {
                printf '<?php\n';
                [ ! -f "/run/secrets/vimbadmin_password_scheme" ] \
                    || printf "\$config['defaults']['mailbox']['password_scheme'] = '%s';\n" \
                        "$(cat "/run/secrets/vimbadmin_password_scheme")";
                [ ! -f "/run/secrets/vimbadmin_password_salt" ] \
                    || printf "\$config['defaults']['mailbox']['password_salt'] = '%s';\n" \
                        "$(cat "/run/secrets/vimbadmin_password_salt")";
                [ ! -f "/run/secrets/vimbadmin_password_min_length" ] \
                    || printf "\$config['defaults']['mailbox']['min_password_length'] = '%s';\n" \
                        "$(cat "/run/secrets/vimbadmin_password_min_length")";
            } > "/etc/vimbadmin/config.password.inc.php"
        fi
    fi

    if [ ! -f "/etc/vimbadmin/config.database.inc.php" ]; then
        if
            [ -f "/run/secrets/vimbadmin_mysql_database" ] \
            || [ -f "/run/secrets/vimbadmin_mysql_user" ] \
            || [ -f "/run/secrets/vimbadmin_mysql_password" ]
        then
            {
                printf '<?php\n';
                [ ! -f "/run/secrets/vimbadmin_mysql_database" ] \
                    || printf "\$config['resources']['doctrine2']['connection']['options']['dbname'] = '%s';\n" \
                        "$(cat "/run/secrets/vimbadmin_mysql_database")";
                [ ! -f "/run/secrets/vimbadmin_mysql_user" ] \
                    || printf "\$config['resources']['doctrine2']['connection']['options']['user'] = '%s';\n" \
                        "$(cat "/run/secrets/vimbadmin_mysql_user")";
                [ ! -f "/run/secrets/vimbadmin_mysql_password" ] \
                    || printf "\$config['resources']['doctrine2']['connection']['options']['password'] = '%s';\n" \
                        "$(cat "/run/secrets/vimbadmin_mysql_password")";
            } > "/etc/vimbadmin/config.database.inc.php"
        fi
    fi

    if [ ! -f "/etc/vimbadmin/config.transport.inc.php" ]; then
        if
            [ -f "/run/secrets/vimbadmin_transport_user" ] \
            || [ -f "/run/secrets/vimbadmin_transport_password" ]
        then
            {
                printf '<?php\n';
                [ ! -f "/run/secrets/vimbadmin_transport_user" ] \
                    || printf "\$config['resources']['mail']['transport']['username'] = '%s';\n" \
                        "$(cat "/run/secrets/vimbadmin_transport_user")";
                [ ! -f "/run/secrets/vimbadmin_transport_password" ] \
                    || printf "\$config['resources']['mail']['transport']['password'] = '%s';\n" \
                        "$(cat "/run/secrets/vimbadmin_transport_password")";
            } > "/etc/vimbadmin/config.transport.inc.php"
        fi
    fi

    if [ ! -z "$VIMBADMIN_ADMIN_EMAIL" ] && [ -f "/run/secrets/vimbadmin_admin_email" ]; then
        export VIMBADMIN_ADMIN_EMAIL="$(cat "/run/secrets/vimbadmin_admin_email")"
    fi

    # setup ViMbAdmin, if necessary
    /usr/lib/vimbadmin/setup.sh

    exec "$@"
fi

exec "$@"

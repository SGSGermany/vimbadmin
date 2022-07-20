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

doctrine2() {
    php -f "/usr/lib/vimbadmin/doctrine2-cli.php" -- "$@"
}

mysql() {
    php -f "/usr/lib/vimbadmin/mysql-cli.php" -- \
        --user "$VIMBADMIN_MYSQL_USER" \
        --password "$VIMBADMIN_MYSQL_PASSWORD" \
        --database "$VIMBADMIN_MYSQL_DATABASE" \
        "$@"
}

read_secret() {
    local SECRET="/run/secrets/$1"

    [ -e "$SECRET" ] || { echo "Failed to read '$SECRET' secret: No such file or directory" >&2; return 1; }
    [ -f "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Not a file" >&2; return 1; }
    [ -r "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Permission denied" >&2; return 1; }
    cat "$SECRET" || return 1
}

envsubst() {
    local VARIABLES="$(for ARG in "$@"; do
        echo "$ARG" | awk 'match($0, /^[a-zA-Z_][a-zA-Z0-9_]*=/, m) {print sprintf("${%s}", substr($0, RSTART, RLENGTH-1))}'
    done)"

    env -i "$@" \
        sh -c '/usr/bin/envsubst "$1"' 'envsubst' "$VARIABLES"
}

VIMBADMIN_MYSQL_DATABASE_MAIL="$(read_secret "vimbadmin_mysql_database_mail")"
VIMBADMIN_MYSQL_DATABASE="$(read_secret "vimbadmin_mysql_database")"
VIMBADMIN_MYSQL_USER="$(read_secret "vimbadmin_mysql_user")"
VIMBADMIN_MYSQL_PASSWORD="$(read_secret "vimbadmin_mysql_password")"

VIMBADMIN_SUPERADMIN_USER="$(read_secret "vimbadmin_superadmin_user")"
VIMBADMIN_SUPERADMIN_PASSWORD="$(read_secret "vimbadmin_superadmin_password")"

# create ViMbAdmin database
if ! doctrine2 "orm:validate-schema" > /dev/null; then
    echo "Creating tables of ViMbAdmin database ($VIMBADMIN_MYSQL_DATABASE)..."
    doctrine2 "orm:schema-tool:create"
fi

# create mail database
SQL_MAIL_TABLES="SELECT \`TABLE_NAME\`
FROM   \`information_schema\`.\`TABLES\`
WHERE  \`TABLE_SCHEMA\` = '$VIMBADMIN_MYSQL_DATABASE_MAIL'"

if [ -z "$(mysql --execute "$SQL_MAIL_TABLES")" ]; then
    echo "Creating tables of mail database ($VIMBADMIN_MYSQL_DATABASE_MAIL)..."
    envsubst \
        MAIL_DATABASE="$VIMBADMIN_MYSQL_DATABASE_MAIL" \
        VIMBADMIN_DATABASE="$VIMBADMIN_MYSQL_DATABASE" \
        < "/usr/lib/vimbadmin/setup/sql/mail.sql" \
        | mysql --import "-"
fi

SQL_VIMBADMIN_TRIGGERS="SELECT \`TRIGGER_NAME\`
FROM   \`information_schema\`.\`TRIGGERS\`
WHERE  \`TRIGGER_SCHEMA\` = '$VIMBADMIN_MYSQL_DATABASE'
UNION
SELECT \`ROUTINE_NAME\`
FROM   \`information_schema\`.\`ROUTINES\`
WHERE  \`ROUTINE_SCHEMA\` = '$VIMBADMIN_MYSQL_DATABASE'
       AND \`ROUTINE_TYPE\` IN ('PROCEDURE', 'FUNCTION')"

# create ViMbAdmin mail database trigger
if [ -z "$(mysql --execute "$SQL_VIMBADMIN_TRIGGERS")" ]; then
    echo "Creating ViMbAdmin mail database trigger..."
    envsubst \
        MAIL_DATABASE="$VIMBADMIN_MYSQL_DATABASE_MAIL" \
        VIMBADMIN_DATABASE="$VIMBADMIN_MYSQL_DATABASE" \
        < "/usr/lib/vimbadmin/setup/sql/vimbadmin.sql" \
        | mysql --import "-"

    echo "Rebuilding mail database..."
    mysql --execute "CALL REBUILD_DATABASE()"
fi

# run ViMbAdmin's setup routine
SQL_VIMBADMIN_ADMINS="SELECT COUNT(*)
FROM   \`$VIMBADMIN_MYSQL_DATABASE\`.\`admin\`"

if [ -z "$(mysql --execute "$SQL_VIMBADMIN_ADMINS")" ]; then
    echo "Running ViMbAdmin setup routine..."
    php -f "/usr/lib/vimbadmin/setup/lib/vimbadmin-install.php" -- \
        "$VIMBADMIN_SUPERADMIN_USER" \
        "$VIMBADMIN_SUPERADMIN_PASSWORD"

    echo "Created ViMbAdmin super admin '$VIMBADMIN_SUPERADMIN_USER'"
fi

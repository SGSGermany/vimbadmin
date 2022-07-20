<?php
/**
 * ViMbAdmin
 * A php-fpm container running ViMbAdmin.
 *
 * Copyright (c) 2022  SGS Serious Gaming & Simulations GmbH
 *
 * This work is licensed under the terms of the MIT license.
 * For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
 *
 * SPDX-License-Identifier: MIT
 * License-Filename: LICENSE
 */

require_once('Zend/Config.php');
require_once('Zend/Config/Ini.php');

$env = [];
foreach (getenv() as $name => $value) {
    if ((substr_compare($name, 'VIMBADMIN_', 0, 10) === 0) && ($value !== '')) {
        $env[substr($name, 10)] = $value;
    }
}

$config = [];

// load config.user.ini
if (file_exists('/etc/vimbadmin/config.user.ini')) {
    $zendConfigUser = new Zend_Config_Ini('/etc/vimbadmin/config.user.ini', APPLICATION_ENV);
    $config = $zendConfigUser->toArray();
}

// load config.user.inc.php
if (file_exists('/etc/vimbadmin/config.user.inc.php')) {
    require('/etc/vimbadmin/config.user.inc.php');
}

// hide errors and exceptions
$config['resources']['frontController']['params']['displayExceptions'] ??= false;
$config['phpSettings']['display_errors'] ??= false;
$config['phpSettings']['display_startup_errors'] ??= false;

// load ViMbAdmin secrets
$config['securitysalt'] =
    $env['SETUP_KEY']
    ?? $config['securitysalt']
    ?? null;

$config['resources']['auth']['oss']['rememberme']['salt'] =
    $env['COOKIE_KEY']
    ?? $config['resources']['auth']['oss']['rememberme']['salt']
    ?? null;

if (file_exists('/etc/vimbadmin/config.secret.inc.php')) {
    require('/etc/vimbadmin/config.secret.inc.php');
}

// password config
$config['defaults']['mailbox']['password_scheme'] =
    $env['PASSWORD_SCHEME']
    ?? $config['defaults']['mailbox']['password_scheme']
    ?? 'crypt:sha512';

$config['defaults']['mailbox']['password_salt'] =
    $env['PASSWORD_SALT']
    ?? $config['defaults']['mailbox']['password_salt']
    ?? null;

$config['defaults']['mailbox']['min_password_length'] =
    $env['PASSWORD_MIN_LENGTH']
    ?? $config['defaults']['mailbox']['min_password_length']
    ?? 8;

$config['defaults']['mailbox']['dovecot_pw_binary'] =
    $config['defaults']['mailbox']['dovecot_pw_binary']
    ?? null;

if (file_exists('/etc/vimbadmin/config.password.inc.php')) {
    require('/etc/vimbadmin/config.password.inc.php');
}

// database config
$config['resources']['doctrine2']['connection']['options']['driver'] ??= 'pdo_mysql';
$config['resources']['doctrine2']['connection']['options']['host'] ??= 'localhost';
$config['resources']['doctrine2']['connection']['options']['unix_socket'] ??= '/run/mysql/mysql.sock';
$config['resources']['doctrine2']['connection']['options']['dbname'] ??= 'mail';
$config['resources']['doctrine2']['connection']['options']['user'] ??= 'mail';
$config['resources']['doctrine2']['connection']['options']['password'] ??= '';
$config['resources']['doctrine2']['connection']['options']['charset'] ??= 'utf8';

if (isset($env['MYSQL_DATABASE'])) {
    $config['resources']['doctrine2']['connection']['options']['dbname'] = $env['MYSQL_DATABASE'];
}
if (isset($env['MYSQL_USER'])) {
    $config['resources']['doctrine2']['connection']['options']['user'] = $env['MYSQL_USER'];
}
if (isset($env['MYSQL_PASSWORD'])) {
    $config['resources']['doctrine2']['connection']['options']['password'] = $env['MYSQL_PASSWORD'];
}

if (file_exists('/etc/vimbadmin/config.database.inc.php')) {
    require('/etc/vimbadmin/config.database.inc.php');
}

// mail transport config
$config['resources']['mail']['transport']['type'] ??= 'smtp';
$config['resources']['mail']['transport']['host'] ??= 'localhost';

if (file_exists('/etc/vimbadmin/config.transport.inc.php')) {
    require('/etc/vimbadmin/config.transport.inc.php');
}

// mailbox config
$config['defaults']['domain']['transport'] ??= 'virtual';
$config['defaults']['mailbox']['uid'] ??= null;
$config['defaults']['mailbox']['gid'] ??= null;
$config['defaults']['mailbox']['maildir'] ??= null;
$config['defaults']['mailbox']['homedir'] ??= null;

// access restrictions config
if (!is_array($config['vimbadmin_plugins']['AccessPermissions']['type'] ?? null)) {
    $config['vimbadmin_plugins']['AccessPermissions']['type'] = [];
}

$config['vimbadmin_plugins']['AccessPermissions']['disabled'] ??= false;

if (!$config['vimbadmin_plugins']['AccessPermissions']['type']) {
    $config['vimbadmin_plugins']['AccessPermissions']['type'] = [
        'SMTP' => 'Send emails (SMTP)',
        'IMAP' => 'Access mailbox (IMAP)',
        'SIEVE' => 'Manage filters (SIEVE)',
    ];
}

// admin alias config
if (!is_array($config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultAliases'] ?? null)) {
    $config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultAliases'] = [];
}

if (!is_array($config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultMapping'] ?? null)) {
    $config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultMapping'] = [];
}

$config['vimbadmin_plugins']['MailboxAutomaticAliases']['disabled'] ??= false;

if (!$config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultAliases']) {
    $config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultAliases'] = [
        'abuse',
        'administrator',
        'admin',
        'hostmaster',
        'postmaster',
        'root',
        'security',
        'webmaster',
    ];
}

(static function () use (&$config, $env): void {
    $aliasList = $config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultAliases'];
    $aliasGotoMap = $config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultMapping'];

    $config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultAliases'] = [];
    $config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultMapping'] = [];

    foreach ($aliasList as $alias) {
        $aliasGoto =
            $aliasGotoMap[$alias]
            ?? $aliasGotoMap['*']
            ?? $env['ADMIN_EMAIL']
            ?? null;

        if ($aliasGoto) {
            $config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultAliases'][] = $alias;
            $config['vimbadmin_plugins']['MailboxAutomaticAliases']['defaultMapping'][$alias] = $aliasGoto;
        }
    }
})();

// identity config
$config['identity']['orgname'] ??= null;
$config['identity']['name'] ??= 'ViMbAdmin Administrator';
$config['identity']['email'] ??= $env['ADMIN_EMAIL'] ?? 'admin@example.com';

$config['identity']['autobot']['name'] ??= $config['identity']['name'];
$config['identity']['autobot']['email'] ??= $config['identity']['email'];

$config['identity']['mailer']['name'] ??= $config['identity']['name'];
$config['identity']['mailer']['email'] ??= $config['identity']['email'];

$config['server']['email']['name'] ??= $config['identity']['name'];
$config['server']['email']['address'] ??= $config['identity']['email'];

// misc settings
if (!isset($config['resources']['smarty']['skin'])) {
    if (is_dir('/var/www/vimbadmin/application/views/_skins/custom')) {
        $config['resources']['smarty']['skin'] = 'custom';
    }
}

$config['skipVersionCheck'] ??= true;
$config['skipInstallPingback'] ??= true;

$config['mailbox_deletion_fs_enabled'] ??= false;

$config['defaults']['list_size']['disabled'] ??= false;
$config['defaults']['list_size']['multiplier'] ??= 'MB';

$config['defaults']['quota']['multiplier'] ??= 'MB';

$config['server']['pop3']['enabled'] ??= false;

// load ViMbAdmin's default application.ini.dist and merge our custom config
$zendConfig = new Zend_Config_Ini(
    APPLICATION_PATH . '/configs/application.ini.dist',
    APPLICATION_ENV,
    [ 'allowModifications' => true ]
);
$zendConfig->merge(new Zend_Config($config));

return $zendConfig;

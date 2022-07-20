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

define('APPLICATION_PATH', '/var/www/vimbadmin/application');
define('APPLICATION_ENV', 'production');

require_once(APPLICATION_PATH . '/../vendor/autoload.php');

// load configuration
$config = require('/etc/vimbadmin/config.inc.php');

// create application, and bootstrap OSSAutoLoader
require_once('Zend/Application.php');

$application = new Zend_Application(APPLICATION_ENV, $config);
$application->bootstrap('OSSAutoLoader');

// create Doctrine entity manager
require_once('Zend/Registry.php');
require_once('OSS/Resource/Doctrine2.php');

$database = 'default';
$entityManager = null;
if (Zend_Registry::isRegistered('d2em') && isset(Zend_Registry::get('d2em')[$database])) {
    $entityManager = Zend_Registry::get('d2em')[$database];
} else {
    $entityManagerPlugin = new OSS_Resource_Doctrine2($application->getOption('resources')['doctrine2']);
    $application->getBootstrap()->registerPluginResource($entityManagerPlugin);

    $entityManager = $entityManagerPlugin->getDoctrine2($database);
    Zend_Registry::set('d2em', [ $database => $entityManager ]);
}

// run Doctrine cli
$cli = new \Symfony\Component\Console\Application('Doctrine Command Line Interface');
$cli->setCatchExceptions(true);
$cli->setAutoExit(true);

$cliHelperSet = $cli->getHelperSet();
$cliHelperSet->set(new \Doctrine\DBAL\Tools\Console\Helper\ConnectionHelper($entityManager->getConnection()), 'db');
$cliHelperSet->set(new \Doctrine\ORM\Tools\Console\Helper\EntityManagerHelper($entityManager), 'em');

\Doctrine\ORM\Tools\Console\ConsoleRunner::addCommands($cli);

$cli->run();

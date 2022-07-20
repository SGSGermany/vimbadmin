<?php

define('APPLICATION_PATH', '/var/www/vimbadmin/application');
define('APPLICATION_ENV', 'production');

require_once(APPLICATION_PATH . '/../vendor/autoload.php');

// load configuration
$config = require('/etc/vimbadmin/config.inc.php');

// create application, bootstrap, and run
require_once('Zend/Application.php');

$application = new Zend_Application(APPLICATION_ENV, $config);

register_shutdown_function([ 'Zend_Session', 'writeClose' ], true);

$application
    ->bootstrap()
    ->run();

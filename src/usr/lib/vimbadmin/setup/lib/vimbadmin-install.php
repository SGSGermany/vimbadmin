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

$_SERVER = array_merge($_SERVER, [
    'DOCUMENT_ROOT' => '/var/www/html',

    'SERVER_PROTOCOL' => 'HTTP/1.1',
    'SERVER_NAME' => 'localhost',
    'SERVER_ADDR' => '127.0.0.1',
    'SERVER_PORT' => '80',

    'REMOTE_ADDR' => '127.0.0.1',
    'REMOTE_PORT' => '' . random_int(32768, 60999),
    'HTTP_HOST' => 'localhost',
    'HTTP_ACCEPT' => 'text/plain,text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'HTTP_ACCEPT_ENCODING' => '',
    'HTTP_ACCEPT_LANGUAGE' => 'en-US,en;q=0.8',
    'HTTP_USER_AGENT' => '',
]);

function __request(string $requestMethod = 'GET', string $requestUri = '', array $postParams = []) {
    $pathInfo = $queryString = '';
    if (($pos = strpos($requestUri, '?')) !== false) {
        $pathInfo = substr($requestUri, 0, $pos);
        $queryString = substr($requestUri, $pos + 1);
        parse_str($queryString, $queryParams);
        $_GET = array_merge($_GET, $queryParams);
    } else {
        $pathInfo = $requestUri;
    }

    if ($postParams) {
        $_POST = array_merge($_POST, $postParams);
    }

    $_SERVER['REQUEST_SCHEME'] = 'http';
    $_SERVER['REQUEST_METHOD'] = $requestMethod;
    $_SERVER['REQUEST_URI'] = $requestUri;
    $_SERVER['PATH_INFO'] = $pathInfo;
    $_SERVER['QUERY_STRING'] = $queryString;
}

__request();

require_once(APPLICATION_PATH . '/../vendor/autoload.php');

// read SUPERADMIN_USER and SUPERADMIN_PASSWORD arguments
if (!isset($_SERVER['argv'][1])) {
    fwrite(STDERR, "Missing required argument: SUPERADMIN_USER\n");
    exit(1);
}
if (!isset($_SERVER['argv'][2])) {
    fwrite(STDERR, "Missing required argument: SUPERADMIN_PASSWORD\n");
    exit(1);
}

[ $superAdminUser, $superAdminPassword ] = array_splice($_SERVER['argv'], 1, 2);
$_SERVER['argc'] -= 2;

// redirector and json helper should not exit
require_once('Zend/Controller/Action/HelperBroker.php');

$redirector = Zend_Controller_Action_HelperBroker::getStaticHelper('redirector');
$redirector->setExit(false);

$json = Zend_Controller_Action_HelperBroker::getStaticHelper('json');
$json->suppressExit = true;

// load configuration
$config = require('/etc/vimbadmin/config.inc.php');

// create fake request
__request('POST', 'auth/setup', [
    'salt' => $config->securitysalt,
    'username' => $superAdminUser,
    'password' => $superAdminPassword,
]);

// create application, and bootstrap
require_once('Zend/Application.php');

$application = new Zend_Application(APPLICATION_ENV, $config);

register_shutdown_function([ 'Zend_Session', 'writeClose' ], true);

$application->bootstrap();

// create request and response
require_once 'Zend/Controller/Request/HttpTestCase.php';
require_once('Zend/Controller/Response/HttpTestCase.php');

$request = new class extends Zend_Controller_Request_HttpTestCase {
    protected $_method = null;

    public function getMethod() {
        return $this->_method ?? $this->getServer('REQUEST_METHOD');
    }
};

$response = new class extends Zend_Controller_Response_HttpTestCase {
    protected $_renderExceptions = true;
};

// create front controller
require_once('Zend/Controller/Front.php');

$frontController = $application->getBootstrap()->getResource('frontcontroller');
$frontController
    ->setRequest($request)
    ->setResponse($response)
    ->throwExceptions(false)
    ->returnResponse(false);

// run application
$application->run();

// check for success and print response on errors
if (($response->getHttpResponseCode() >= 400) || $response->isException()) {
    echo $response->sendResponse();
    exit(1);
}

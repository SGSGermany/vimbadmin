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

declare(strict_types=1);

// read cli arguments
$database = $user = $password = null;
$query = $import = null;

while ($_SERVER['argc'] > 1) {
    switch (true) {
        case ($_SERVER['argv'][1] === '--database'):
        case ($_SERVER['argv'][1] === '--user'):
        case ($_SERVER['argv'][1] === '--password'):
            if (!isset($_SERVER['argv'][2])) {
                fwrite(STDERR, sprintf("Missing required parameter for option '%s'\n", $_SERVER['argv'][1]));
                exit(1);
            }

            if ($_SERVER['argv'][1] === '--database') {
                $database = $_SERVER['argv'][2];
            } elseif ($_SERVER['argv'][1] === '--user') {
                $user = $_SERVER['argv'][2];
            } elseif ($_SERVER['argv'][1] === '--password') {
                $password = $_SERVER['argv'][2];
            }

            array_splice($_SERVER['argv'], 1, 2);
            $_SERVER['argc'] -= 2;
            break;

        case ($_SERVER['argv'][1] === '--execute'):
        case ($_SERVER['argv'][1] === '--import'):
            if (!isset($_SERVER['argv'][2])) {
                fwrite(STDERR, sprintf("Missing required parameter for option '%s'\n", $_SERVER['argv'][1]));
                exit(1);
            }

            if (($query !== null) || ($import !== null)) {
                fwrite(STDERR, sprintf("Options '--execute' and '--import' are mutually exclusive\n", $_SERVER['argv'][1]));
                exit(1);
            }

            if ($_SERVER['argv'][1] === '--execute') {
                $query = $_SERVER['argv'][2];
            } elseif ($_SERVER['argv'][1] === '--import') {
                $import = $_SERVER['argv'][2];
            }

            array_splice($_SERVER['argv'], 1, 2);
            $_SERVER['argc'] -= 2;
            break;

        default:
            fwrite(STDERR, sprintf("Unknown option: %s\n", $_SERVER['argv'][1]));
            exit(1);
    }
}

if ($database === null) {
    fwrite(STDERR, "Missing required option: --database\n");
    exit(1);
}

if (($query === null) && ($import === null)) {
    exit(0);
}

// connect to database
try {
    $dsn = sprintf('mysql:dbname=%s;host=localhost;unix_socket=/run/mysql/mysql.sock', $database);

    $pdo = new PDO($dsn, $user, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (\PDOException $e) {
    fwrite(STDERR, sprintf("Unable to connect to MySQL database: %s\n", $e->getMessage()));
    exit(1);
}

try {
    $pdo->exec('SET NAMES utf8');
} catch (\PDOException $e) {
    fwrite(STDERR, sprintf("Failed to initialize MySQL database connection: %s\n", $e->getMessage()));
    exit(1);
}

// execute query
if ($query !== null) {
    try {
        $stmt = $pdo->query($query);
        while (($row = $stmt->fetch(PDO::FETCH_NUM)) !== false) {
            if ($row) {
                echo implode("\t", $row) . "\n";
            }
        }
    } catch (\PDOException $e) {
        fwrite(STDERR, sprintf("Failed to execute MySQL query: %s\n", $e->getMessage()));
        exit(1);
    }

    exit(0);
}

// import file
$file = null;
if ($import !== '-') {
    $fileError = null;
    if (!file_exists($_SERVER['argv'][2])) {
        $fileError = 'No such file or directory';
    } elseif (!is_file($_SERVER['argv'][2])) {
        $fileError = 'Not a file';
    } elseif (!is_readable($_SERVER['argv'][2])) {
        $fileError = 'Permission denied';
    }

    if ($fileError !== null) {
        fwrite(STDERR, sprintf("Unable to import SQL file '%s': %s\n", $_SERVER['argv'][2], $fileError));
        exit(1);
    }

    printf("Processing SQL file '%s'...\n", $import);
    $file = fopen($filePath, 'r');
} else {
    printf("Processing SQL queries from standard input...\n");
    $file = fopen('php://stdin', 'r');
}

$query = '';
$delimiter = ';';
$delimiterLength = 1;
while (($line = fgets($file)) !== false) {
    $trim = trim($line);

    if (($trim === '') || (substr_compare($trim, '-- ', 0, 3) === 0)) {
        continue;
    }

    if (substr_compare($trim, 'DELIMITER ', 0, 10) === 0) {
        $delimiter = substr($trim, 10);
        $delimiterLength = strlen($delimiter);
        continue;
    }

    $query .= $line;

    if (substr_compare($trim, $delimiter, -$delimiterLength) === 0) {
        $query = trim(substr(rtrim($query), 0, -$delimiterLength));

        if ($query !== '') {
            try {
                $pdo->exec($query);
            } catch (\PDOException $e) {
                fwrite(STDERR, sprintf("Failed to execute MySQL query: %s\n", $e->getMessage()));
                exit(1);
            }

            $query = '';
        }
    }
}

fclose($file);

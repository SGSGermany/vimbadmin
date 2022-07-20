DROP TABLE IF EXISTS `${MAIL_DATABASE}`.`domain`;
CREATE TABLE `${MAIL_DATABASE}`.`domain` (
    `domain` VARCHAR(255) NOT NULL,
    `transport` VARCHAR(255) NOT NULL DEFAULT 'virtual',
    PRIMARY KEY (`domain`)
);

DROP TABLE IF EXISTS `${MAIL_DATABASE}`.`user`;
CREATE TABLE `${MAIL_DATABASE}`.`user` (
    `user` VARCHAR(255) NOT NULL,
    `password` VARCHAR(255) NOT NULL,
    `mailbox` VARCHAR(255) NOT NULL,
    `access_restriction` VARCHAR(200) NOT NULL DEFAULT 'ALL',
    PRIMARY KEY (`user`),
    INDEX (`mailbox`)
);

DROP TABLE IF EXISTS `${MAIL_DATABASE}`.`user_access`;
CREATE TABLE `${MAIL_DATABASE}`.`user_access` (
    `user` VARCHAR(255) NOT NULL,
    `address` VARCHAR(255) NOT NULL,
    UNIQUE KEY `user_access` (`user`,`address`),
    INDEX (`user`),
    INDEX (`address`)
);

DROP TABLE IF EXISTS `${MAIL_DATABASE}`.`user_foreign_access`;
CREATE TABLE `${MAIL_DATABASE}`.`user_foreign_access` (
    `user` varchar(255) NOT NULL,
    `address` varchar(255) NOT NULL DEFAULT '',
    UNIQUE KEY `user_foreign_access` (`user`,`address`),
    INDEX (`user`),
    INDEX (`address`)
);

DROP TABLE IF EXISTS `${MAIL_DATABASE}`.`mailbox`;
CREATE TABLE `${MAIL_DATABASE}`.`mailbox` (
    `address` VARCHAR(255) NOT NULL,
    `uid` BIGINT NULL,
    `gid` BIGINT NULL,
    `homedir` VARCHAR(255) NULL,
    `maildir` VARCHAR(255) NULL,
    `quota_rule` VARCHAR(255) NULL,
    `quota_rule2` VARCHAR(255) NULL,
    `quota_rule3` VARCHAR(255) NULL,
    PRIMARY KEY (`address`)
);

DROP TABLE IF EXISTS `${MAIL_DATABASE}`.`mailbox_quota`;
CREATE TABLE `${MAIL_DATABASE}`.`mailbox_quota` (
    `address` VARCHAR(255) NOT NULL,
    `bytes` BIGINT NOT NULL DEFAULT 0,
    `messages` INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (`address`)
);

DROP TABLE IF EXISTS `${MAIL_DATABASE}`.`alias`;
CREATE TABLE `${MAIL_DATABASE}`.`alias` (
    `address` VARCHAR(255) NOT NULL,
    `goto` VARCHAR(255) NOT NULL,
    UNIQUE KEY `alias` (`address`,`goto`),
    INDEX (`address`),
    INDEX (`goto`)
);

DROP TABLE IF EXISTS `${MAIL_DATABASE}`.`recipient_access`;
CREATE TABLE `${MAIL_DATABASE}`.`recipient_access` (
    `address` varchar(255) NOT NULL,
    `result` enum('OK','DUNNO','REJECT') NOT NULL,
    `error_message` varchar(255) DEFAULT NULL,
    PRIMARY KEY (`address`)
);

DROP TABLE IF EXISTS `${MAIL_DATABASE}`.`sender_access`;
CREATE TABLE `${MAIL_DATABASE}`.`sender_access` (
    `address` varchar(255) NOT NULL,
    `result` enum('OK','DUNNO','REJECT') NOT NULL,
    `error_message` varchar(255) DEFAULT NULL,
    PRIMARY KEY (`address`)
);

DROP TABLE IF EXISTS `${MAIL_DATABASE}`.`tls_policy`;
CREATE TABLE `${MAIL_DATABASE}`.`tls_policy` (
    `domain` varchar(255) NOT NULL,
    `policy` enum('none', 'may', 'encrypt', 'dane', 'dane-only', 'fingerprint', 'verify', 'secure') NOT NULL,
    `params` varchar(255),
    PRIMARY KEY (`domain`)
);

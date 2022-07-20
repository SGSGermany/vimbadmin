USE `${VIMBADMIN_DATABASE}`;

DROP PROCEDURE IF EXISTS REBUILD_DATABASE;
DROP PROCEDURE IF EXISTS DOMAIN_CREATE;
DROP PROCEDURE IF EXISTS DOMAIN_UPDATE;
DROP PROCEDURE IF EXISTS DOMAIN_DELETE;
DROP PROCEDURE IF EXISTS DOMAIN_REBUILD;
DROP PROCEDURE IF EXISTS USER_CREATE;
DROP PROCEDURE IF EXISTS USER_UPDATE;
DROP PROCEDURE IF EXISTS USER_DELETE;
DROP PROCEDURE IF EXISTS MAILBOX_CREATE;
DROP PROCEDURE IF EXISTS MAILBOX_UPDATE;
DROP PROCEDURE IF EXISTS MAILBOX_DELETE;
DROP PROCEDURE IF EXISTS ALIAS_CREATE;
DROP PROCEDURE IF EXISTS ALIAS_DELETE;
DROP PROCEDURE IF EXISTS ACCESS_CREATE;
DROP PROCEDURE IF EXISTS ACCESS_DELETE;
DROP PROCEDURE IF EXISTS QUOTA_UPDATE;
DROP PROCEDURE IF EXISTS LOG_DEBUG;

DROP FUNCTION IF EXISTS GET_DOMAIN;
DROP FUNCTION IF EXISTS IS_DOMAIN_ACTIVE;
DROP FUNCTION IF EXISTS IS_USER;
DROP FUNCTION IF EXISTS IS_USER_MAILBOX;
DROP FUNCTION IF EXISTS FORMAT_USER_PASSWORD;

DROP TRIGGER IF EXISTS `${VIMBADMIN_DATABASE}`.DOMAIN_INSERT_TRIGGER;
DROP TRIGGER IF EXISTS `${VIMBADMIN_DATABASE}`.DOMAIN_UPDATE_TRIGGER;
DROP TRIGGER IF EXISTS `${VIMBADMIN_DATABASE}`.DOMAIN_DELETE_TRIGGER;
DROP TRIGGER IF EXISTS `${VIMBADMIN_DATABASE}`.MAILBOX_INSERT_TRIGGER;
DROP TRIGGER IF EXISTS `${VIMBADMIN_DATABASE}`.MAILBOX_UPDATE_TRIGGER;
DROP TRIGGER IF EXISTS `${VIMBADMIN_DATABASE}`.MAILBOX_DELETE_TRIGGER;
DROP TRIGGER IF EXISTS `${VIMBADMIN_DATABASE}`.ALIAS_INSERT_TRIGGER;
DROP TRIGGER IF EXISTS `${VIMBADMIN_DATABASE}`.ALIAS_UPDATE_TRIGGER;
DROP TRIGGER IF EXISTS `${VIMBADMIN_DATABASE}`.ALIAS_DELETE_TRIGGER;
DROP TRIGGER IF EXISTS `${MAIL_DATABASE}`.ACCESS_INSERT_TRIGGER;
DROP TRIGGER IF EXISTS `${MAIL_DATABASE}`.ACCESS_UPDATE_TRIGGER;
DROP TRIGGER IF EXISTS `${MAIL_DATABASE}`.ACCESS_DELETE_TRIGGER;
DROP TRIGGER IF EXISTS `${MAIL_DATABASE}`.QUOTA_INSERT_TRIGGER;
DROP TRIGGER IF EXISTS `${MAIL_DATABASE}`.QUOTA_UPDATE_TRIGGER;
DROP TRIGGER IF EXISTS `${MAIL_DATABASE}`.QUOTA_DELETE_TRIGGER;

DELIMITER //

--
-- Rebuild `mail` database procedure
--

//

CREATE PROCEDURE REBUILD_DATABASE()
BEGIN
    DECLARE `active_domains` LONGTEXT;
    DECLARE `active_mailboxes` LONGTEXT;
    DECLARE `active_aliases` LONGTEXT;

    CALL LOG_DEBUG('call', 'procedure', 'REBUILD_DATABASE', '');

    -- Truncate database tables
    TRUNCATE TABLE `${MAIL_DATABASE}`.`alias`;
    TRUNCATE TABLE `${MAIL_DATABASE}`.`mailbox_quota`;
    TRUNCATE TABLE `${MAIL_DATABASE}`.`mailbox`;
    TRUNCATE TABLE `${MAIL_DATABASE}`.`user_access`;
    TRUNCATE TABLE `${MAIL_DATABASE}`.`user`;
    TRUNCATE TABLE `${MAIL_DATABASE}`.`domain`;

    -- Get a list of all active domains
    SELECT GROUP_CONCAT(`${VIMBADMIN_DATABASE}`.`domain`.`id`)
    INTO   `active_domains`
    FROM   `${VIMBADMIN_DATABASE}`.`domain`
    WHERE  `${VIMBADMIN_DATABASE}`.`domain`.`active` = '1';

    -- Get a list of all active mailboxes
    SELECT GROUP_CONCAT(`${VIMBADMIN_DATABASE}`.`mailbox`.`id`)
    INTO   `active_mailboxes`
    FROM   `${VIMBADMIN_DATABASE}`.`mailbox`
    WHERE  `${VIMBADMIN_DATABASE}`.`mailbox`.`active` = '1';

    -- Get a list of all active aliases
    SELECT GROUP_CONCAT(`${VIMBADMIN_DATABASE}`.`alias`.`id`)
    INTO   `active_aliases`
    FROM   `${VIMBADMIN_DATABASE}`.`alias`
    WHERE  `${VIMBADMIN_DATABASE}`.`alias`.`active` = '1';

    -- Temporarily disable triggers
    SET @TRIGGER_DISABLED = 1;

    -- Disable all domains
    UPDATE `${VIMBADMIN_DATABASE}`.`domain`
    SET    `${VIMBADMIN_DATABASE}`.`domain`.`active` = '0';

    -- Disable all mailboxes
    UPDATE `${VIMBADMIN_DATABASE}`.`mailbox`
    SET    `${VIMBADMIN_DATABASE}`.`mailbox`.`active` = '0';

    -- Disable all aliases
    UPDATE `${VIMBADMIN_DATABASE}`.`alias`
    SET    `${VIMBADMIN_DATABASE}`.`alias`.`active` = '0';

    -- Re-enable trigger
    SET @TRIGGER_DISABLED = 0;

    -- Re-enable previously active domains
    UPDATE `${VIMBADMIN_DATABASE}`.`domain`
    SET    `${VIMBADMIN_DATABASE}`.`domain`.`active` = '1'
    WHERE  FIND_IN_SET(`${VIMBADMIN_DATABASE}`.`domain`.`id`, `active_domains`);

    -- Re-enable previously active mailboxes
    UPDATE `${VIMBADMIN_DATABASE}`.`mailbox`
    SET    `${VIMBADMIN_DATABASE}`.`mailbox`.`active` = '1'
    WHERE  FIND_IN_SET(`${VIMBADMIN_DATABASE}`.`mailbox`.`id`, `active_mailboxes`);

    -- Re-enable previously active aliases
    UPDATE `${VIMBADMIN_DATABASE}`.`alias`
    SET    `${VIMBADMIN_DATABASE}`.`alias`.`active` = '1'
    WHERE  FIND_IN_SET(`${VIMBADMIN_DATABASE}`.`alias`.`id`, `active_aliases`);
END;

//

--
-- Domain procedures and functions
--

CREATE PROCEDURE DOMAIN_CREATE(
    IN `domain` VARCHAR(255),
    IN `transport` VARCHAR(255)
)
BEGIN
    CALL LOG_DEBUG('call', 'procedure', 'DOMAIN_CREATE', JSON_ARRAY(`domain`, `transport`));

    -- Create domain
    INSERT INTO `${MAIL_DATABASE}`.`domain`
        (`domain`, `transport`)
    VALUES
        (`domain`, `transport`);
END;

//

CREATE PROCEDURE DOMAIN_UPDATE(
    IN `domain` VARCHAR(255),
    IN `transport` VARCHAR(255)
)
BEGIN
    CALL LOG_DEBUG('call', 'procedure', 'DOMAIN_UPDATE', JSON_ARRAY(`domain`, `transport`));

    -- Update domain
    UPDATE `${MAIL_DATABASE}`.`domain`
    SET    `${MAIL_DATABASE}`.`domain`.`transport` = `transport`
    WHERE  `${MAIL_DATABASE}`.`domain`.`domain` = `domain`;
END;

//

CREATE PROCEDURE DOMAIN_DELETE(
    IN `domain` VARCHAR(255)
)
BEGIN
    CALL LOG_DEBUG('call', 'procedure', 'DOMAIN_DELETE', JSON_ARRAY(`domain`));

    -- Delete aliases of this domain
    DELETE FROM `${MAIL_DATABASE}`.`alias`
    WHERE       `${MAIL_DATABASE}`.`alias`.`address` LIKE CONCAT('%', '@', `domain`);

    -- Delete mailboxes of this domain
    DELETE FROM `${MAIL_DATABASE}`.`mailbox`
    WHERE       `${MAIL_DATABASE}`.`mailbox`.`address` LIKE CONCAT('%', '@', `domain`);

    -- Delete users whose primary mailbox uses this domain
    DELETE FROM `${MAIL_DATABASE}`.`user_access`
    WHERE       `${MAIL_DATABASE}`.`user_access`.`address` LIKE CONCAT('%', '@', `domain`);

    DELETE FROM `${MAIL_DATABASE}`.`user`
    WHERE       `${MAIL_DATABASE}`.`user`.`mailbox` LIKE CONCAT('%', '@', `domain`);

    -- Please note that we purposely don't delete aliases redirecting e-mails
    -- *to* this domain, because we don't validate alias targets in general

    -- Delete domain
    DELETE FROM `${MAIL_DATABASE}`.`domain`
    WHERE       `${MAIL_DATABASE}`.`domain`.`domain` = `domain`;
END;

//

CREATE PROCEDURE DOMAIN_REBUILD(
    IN `domain` VARCHAR(255),
    IN `transport` VARCHAR(255)
)
BEGIN
    DECLARE `active_mailboxes` LONGTEXT;
    DECLARE `active_aliases` LONGTEXT;

    CALL LOG_DEBUG('call', 'procedure', 'DOMAIN_REBUILD', JSON_ARRAY(`domain`, `transport`));

    -- Delete domain leftovers
    CALL DOMAIN_DELETE(`domain`);

    -- Create domain
    CALL DOMAIN_CREATE(`domain`, `transport`);

    -- Get a list of all active mailboxes
    SELECT GROUP_CONCAT(`${VIMBADMIN_DATABASE}`.`mailbox`.`id`)
    INTO   `active_mailboxes`
    FROM   `${VIMBADMIN_DATABASE}`.`mailbox`
    WHERE  `${VIMBADMIN_DATABASE}`.`mailbox`.`username` LIKE CONCAT('%', '@', `domain`)
           AND `${VIMBADMIN_DATABASE}`.`mailbox`.`active` = '1';

    -- Get a list of all active aliases
    SELECT GROUP_CONCAT(`${VIMBADMIN_DATABASE}`.`alias`.`id`)
    INTO   `active_aliases`
    FROM   `${VIMBADMIN_DATABASE}`.`alias`
    WHERE  `${VIMBADMIN_DATABASE}`.`alias`.`address` LIKE CONCAT('%', '@', `domain`)
           AND `${VIMBADMIN_DATABASE}`.`alias`.`active` = '1';

    -- Temporarily disable triggers
    SET @TRIGGER_DISABLED = 1;

    -- Disable all mailboxes
    UPDATE `${VIMBADMIN_DATABASE}`.`mailbox`
    SET    `${VIMBADMIN_DATABASE}`.`mailbox`.`active` = '0'
    WHERE  `${VIMBADMIN_DATABASE}`.`mailbox`.`username` LIKE CONCAT('%', '@', `domain`);

    -- Disable all aliases
    UPDATE `${VIMBADMIN_DATABASE}`.`alias`
    SET    `${VIMBADMIN_DATABASE}`.`alias`.`active` = '0'
    WHERE  `${VIMBADMIN_DATABASE}`.`alias`.`address` LIKE CONCAT('%', '@', `domain`);

    -- Re-enable trigger
    SET @TRIGGER_DISABLED = 0;

    -- Re-enable previously active mailboxes
    UPDATE `${VIMBADMIN_DATABASE}`.`mailbox`
    SET    `${VIMBADMIN_DATABASE}`.`mailbox`.`active` = '1'
    WHERE  FIND_IN_SET(`${VIMBADMIN_DATABASE}`.`mailbox`.`id`, `active_mailboxes`);

    -- Re-enable previously active aliases
    UPDATE `${VIMBADMIN_DATABASE}`.`alias`
    SET    `${VIMBADMIN_DATABASE}`.`alias`.`active` = '1'
    WHERE  FIND_IN_SET(`${VIMBADMIN_DATABASE}`.`alias`.`id`, `active_aliases`);
END;

//

CREATE FUNCTION GET_DOMAIN(
    `id` BIGINT
)
RETURNS VARCHAR(255)
BEGIN
    DECLARE `domain` VARCHAR(255);

    SELECT `${VIMBADMIN_DATABASE}`.`domain`.`domain`
    INTO   `domain`
    FROM   `${VIMBADMIN_DATABASE}`.`domain`
    WHERE  `${VIMBADMIN_DATABASE}`.`domain`.`id` = `id`;

    RETURN `domain`;
END;

//

CREATE FUNCTION IS_DOMAIN_ACTIVE(
    `domain` VARCHAR(255)
)
RETURNS TINYINT
BEGIN
    DECLARE `domain_active` TINYINT DEFAULT '0';

    SELECT `${VIMBADMIN_DATABASE}`.`domain`.`active`
    INTO   `domain_active`
    FROM   `${VIMBADMIN_DATABASE}`.`domain`
    WHERE  `${VIMBADMIN_DATABASE}`.`domain`.`domain` = `domain`;

    RETURN `domain_active`;
END;

//

--
-- User procedures
--

CREATE PROCEDURE USER_CREATE(
    IN `user` VARCHAR(255),
    IN `password` VARCHAR(255),
    IN `mailbox` VARCHAR(255),
    IN `access_restriction` VARCHAR(200)
)
BEGIN
    CALL LOG_DEBUG('call', 'procedure', 'USER_CREATE', JSON_ARRAY(`user`, `password`, `mailbox`, `access_restriction`));

    -- Create user
    INSERT INTO `${MAIL_DATABASE}`.`user`
        (`user`, `password`, `mailbox`, `access_restriction`)
    VALUES
        (`user`, FORMAT_USER_PASSWORD(`password`), `mailbox`, `access_restriction`);

    -- Add user access rule for the primary mailbox
    INSERT INTO `${MAIL_DATABASE}`.`user_access`
        (`user`, `address`)
    VALUES
        (`user`, `mailbox`);

    -- Add foreign access rules for the newly created user
    INSERT INTO `${MAIL_DATABASE}`.`user_access`
        (`user`, `address`)
    SELECT `${MAIL_DATABASE}`.`user_foreign_access`.`user`,
           `${MAIL_DATABASE}`.`user_foreign_access`.`address`
    FROM   `${MAIL_DATABASE}`.`user_foreign_access`
    WHERE  `${MAIL_DATABASE}`.`user_foreign_access`.`user` = `user`;

    -- Add foreign access rules for pre-existing aliases of this mailbox
    INSERT IGNORE INTO `${MAIL_DATABASE}`.`user_access`
        (`user`, `address`)
    SELECT `user`,
           `${MAIL_DATABASE}`.`alias`.`address`
    FROM   `${MAIL_DATABASE}`.`alias`
    WHERE  `${MAIL_DATABASE}`.`alias`.`goto` = `user`;
END;

//

CREATE PROCEDURE USER_UPDATE(
    IN `user` VARCHAR(255),
    IN `password` VARCHAR(255),
    IN `mailbox` VARCHAR(255),
    IN `access_restriction` VARCHAR(200)
)
BEGIN
    DECLARE `old_mailbox` VARCHAR(255);

    CALL LOG_DEBUG('call', 'procedure', 'USER_UPDATE', JSON_ARRAY(`user`, `password`, `mailbox`, `access_restriction`));

    SELECT `${MAIL_DATABASE}`.`user`.`mailbox`
    INTO   `old_mailbox`
    FROM   `${MAIL_DATABASE}`.`user`
    WHERE  `${MAIL_DATABASE}`.`user`.`user` = `user`;

    -- Update user
    UPDATE `${MAIL_DATABASE}`.`user`
    SET    `${MAIL_DATABASE}`.`user`.`password` = FORMAT_USER_PASSWORD(`password`),
           `${MAIL_DATABASE}`.`user`.`mailbox` = `mailbox`,
           `${MAIL_DATABASE}`.`user`.`access_restriction` = `access_restriction`
    WHERE  `${MAIL_DATABASE}`.`user`.`user` = `user`;

    -- Update user access rule for the primary mailbox, if necessary
    IF `old_mailbox` <> `mailbox` THEN
        UPDATE `${MAIL_DATABASE}`.`user_access`
        SET    `${MAIL_DATABASE}`.`user_access`.`address` = `mailbox`
        WHERE  `${MAIL_DATABASE}`.`user_access`.`user` = `user`
               AND `${MAIL_DATABASE}`.`user_access`.`address` = `old_mailbox`;

       -- This is actually unreachable code for ViMbAdmin, because ViMbAdmin
       -- requires an user's primary mailbox to match its user name
    END IF;
END;

//

CREATE PROCEDURE USER_DELETE(
    IN `user` VARCHAR(255)
)
BEGIN
    CALL LOG_DEBUG('call', 'procedure', 'USER_DELETE', JSON_ARRAY(`user`));

    -- Delete user access rules
    DELETE FROM `${MAIL_DATABASE}`.`user_access`
    WHERE       `${MAIL_DATABASE}`.`user_access`.`user` = `user`;

    -- Delete user
    DELETE FROM `${MAIL_DATABASE}`.`user`
    WHERE       `${MAIL_DATABASE}`.`user`.`user` = `user`;
END;

//

CREATE FUNCTION IS_USER(
    `user` VARCHAR(255)
)
RETURNS TINYINT
BEGIN
    DECLARE `is_user` TINYINT DEFAULT '0';

    SELECT LEAST(COUNT(`${MAIL_DATABASE}`.`user`.`user`), 1)
    INTO   `is_user`
    FROM   `${MAIL_DATABASE}`.`user`
    WHERE  `${MAIL_DATABASE}`.`user`.`user` = `user`;

    RETURN `is_user`;
END;

//

CREATE FUNCTION IS_USER_MAILBOX(
    `address` VARCHAR(255)
)
RETURNS TINYINT
BEGIN
    DECLARE `is_mailbox` TINYINT DEFAULT '0';

    SELECT LEAST(COUNT(`${MAIL_DATABASE}`.`user`.`user`), 1)
    INTO   `is_mailbox`
    FROM   `${MAIL_DATABASE}`.`user`
    WHERE  `${MAIL_DATABASE}`.`user`.`mailbox` = `address`;

    RETURN `is_mailbox`;
END;

//

CREATE FUNCTION FORMAT_USER_PASSWORD(
    `password` VARCHAR(255)
)
RETURNS VARCHAR(255)
BEGIN
    IF `password` LIKE '$1$%' THEN
        RETURN CONCAT('{MD5-CRYPT}', `password`);
    ELSEIF `password` LIKE '$2$%' OR `password` LIKE '$2_$%' THEN
        RETURN CONCAT('{BLF-CRYPT}', `password`);
    ELSEIF `password` LIKE '$sha1$%' THEN
        RETURN CONCAT('{SHA1-CRYPT}', `password`);
    ELSEIF `password` LIKE '$5$%' THEN
        RETURN CONCAT('{SHA256-CRYPT}', `password`);
    ELSEIF `password` LIKE '$6$%' THEN
        RETURN CONCAT('{SHA512-CRYPT}', `password`);
    ELSEIF `password` LIKE '$pbkdf2$%' THEN
        RETURN CONCAT('{PBKDF2}', `password`);
    ELSEIF `password` LIKE '$argon2i$%' THEN
        RETURN CONCAT('{ARGON2I}', `password`);
    ELSEIF `password` LIKE '$argon2d$%' THEN
        RETURN CONCAT('{ARGON2D}', `password`);
    ELSE
        RETURN `password`;
    END IF;
END;

//

--
-- Mailbox procedures
--

CREATE PROCEDURE MAILBOX_CREATE(
    IN `address` VARCHAR(255),
    IN `uid` BIGINT,
    IN `gid` BIGINT,
    IN `homedir` VARCHAR(255),
    IN `maildir` VARCHAR(255),
    IN `quota` BIGINT
)
BEGIN
    DECLARE `quota_rule` VARCHAR(255);
    DECLARE `quota_rule2` VARCHAR(255);
    DECLARE `quota_rule3` VARCHAR(255);

    CALL LOG_DEBUG('call', 'procedure', 'MAILBOX_CREATE', JSON_ARRAY(`address`, `uid`, `gid`, `homedir`, `maildir`, `quota`));

    SET `uid` = IF(LENGTH(`uid`), `uid`, NULL);
    SET `gid` = IF(LENGTH(`gid`), `gid`, NULL);
    SET `homedir` = IF(LENGTH(`homedir`), `homedir`, NULL);
    SET `maildir` = IF(LENGTH(`maildir`), `maildir`, NULL);
    SET `quota_rule` = CONCAT('*:bytes=', `quota`);
    SET `quota_rule2` = CONCAT('Trash:bytes=', '+', ROUND(`quota` * 0.075, 0));
    SET `quota_rule3` = CONCAT('Sent:bytes=', '+', ROUND(`quota` * 0.025, 0));

    -- Create mailbox
    INSERT INTO `${MAIL_DATABASE}`.`mailbox`
        (`address`, `uid`, `gid`, `homedir`, `maildir`, `quota_rule`, `quota_rule2`, `quota_rule3`)
    VALUES
        (`address`, `uid`, `gid`, `homedir`, `maildir`, `quota_rule`, `quota_rule2`, `quota_rule3`);

    -- Updating the mailbox's quota is the MDA's job, because ViMbAdmin can't
    -- know whether the mailbox's Maildir exists
END;

//

CREATE PROCEDURE MAILBOX_UPDATE(
    IN `address` VARCHAR(255),
    IN `uid` BIGINT,
    IN `gid` BIGINT,
    IN `homedir` VARCHAR(255),
    IN `maildir` VARCHAR(255),
    IN `quota` BIGINT
)
BEGIN
    DECLARE `quota_rule` VARCHAR(255);
    DECLARE `quota_rule2` VARCHAR(255);
    DECLARE `quota_rule3` VARCHAR(255);

    CALL LOG_DEBUG('call', 'procedure', 'MAILBOX_UPDATE', JSON_ARRAY(`address`, `uid`, `gid`, `homedir`, `maildir`, `quota`));

    SET `uid` = IF(LENGTH(`uid`), `uid`, NULL);
    SET `gid` = IF(LENGTH(`gid`), `gid`, NULL);
    SET `homedir` = IF(LENGTH(`homedir`), `homedir`, NULL);
    SET `maildir` = IF(LENGTH(`maildir`), `maildir`, NULL);
    SET `quota_rule` = CONCAT('*:bytes=', `quota`);
    SET `quota_rule2` = CONCAT('Trash:bytes=', '+', ROUND(`quota` * 0.075, 0));
    SET `quota_rule3` = CONCAT('Sent:bytes=', '+', ROUND(`quota` * 0.025, 0));

    -- Update mailbox
    UPDATE `${MAIL_DATABASE}`.`mailbox`
    SET    `${MAIL_DATABASE}`.`mailbox`.`uid` = `uid`,
           `${MAIL_DATABASE}`.`mailbox`.`gid` = `gid`,
           `${MAIL_DATABASE}`.`mailbox`.`homedir` = `homedir`,
           `${MAIL_DATABASE}`.`mailbox`.`maildir` = `maildir`,
           `${MAIL_DATABASE}`.`mailbox`.`quota_rule` = `quota_rule`,
           `${MAIL_DATABASE}`.`mailbox`.`quota_rule2` = `quota_rule2`,
           `${MAIL_DATABASE}`.`mailbox`.`quota_rule3` = `quota_rule3`
    WHERE  `${MAIL_DATABASE}`.`mailbox`.`address` = `address`;
END;

//

CREATE PROCEDURE MAILBOX_DELETE(
    IN `address` VARCHAR(255)
)
BEGIN
    CALL LOG_DEBUG('call', 'procedure', 'MAILBOX_DELETE', JSON_ARRAY(`address`));

    -- Delete mailbox
    DELETE FROM `${MAIL_DATABASE}`.`mailbox`
    WHERE       `${MAIL_DATABASE}`.`mailbox`.`address` = `address`;

    -- Clearing the mailbox's quota is the MDA's job, because ViMbAdmin can't
    -- know whether the mailbox's Maildir was removed, too
END;

//

--
-- Alias procedures
--

CREATE PROCEDURE ALIAS_CREATE(
    IN `address` VARCHAR(255),
    IN `goto` LONGTEXT
)
BEGIN
    DECLARE `goto_count` INT DEFAULT 0;
    DECLARE `goto_index` INT DEFAULT 0;
    DECLARE `goto_address` VARCHAR(255);

    CALL LOG_DEBUG('call', 'procedure', 'ALIAS_CREATE', JSON_ARRAY(`address`, `goto`));

    SET `goto_count` = CHAR_LENGTH(`goto`) - CHAR_LENGTH(REPLACE(`goto`, ',', '')) + 1;
    WHILE `goto_index` < `goto_count` DO
        -- ViMbAdmin creates aliases with multiple `goto` addresses, thus we
        -- must first split the list of addresses into multiple rows
        SET `goto_address` = SUBSTRING_INDEX(SUBSTRING_INDEX(`goto`, ',', `goto_index` + 1), ',', -1);

        -- Create alias
        INSERT IGNORE INTO `${MAIL_DATABASE}`.`alias`
            (`address`, `goto`)
        VALUES
            (`address`, `goto_address`);

        -- Check whether the `goto` address is a mailbox, and add an user
        -- access rule if it is a mailbox; this check is *not* recursive on
        -- purpose, because we'd have to rebuild all user access rules when
        -- updating any alias otherwise
        IF IS_USER_MAILBOX(`goto_address`) = '1' THEN
            INSERT IGNORE INTO `${MAIL_DATABASE}`.`user_access`
                (`user`, `address`)
            VALUES
                (`goto_address`, `address`);
        END IF;

        SET `goto_index` = `goto_index` + 1;
    END WHILE;
END;

//

CREATE PROCEDURE ALIAS_DELETE(
    IN `address` VARCHAR(255)
)
BEGIN
    CALL LOG_DEBUG('call', 'procedure', 'ALIAS_DELETE', JSON_ARRAY(`address`));

    IF IS_USER_MAILBOX(`address`) <> '1' THEN
        -- Delete any user access rules for this alias
        DELETE FROM `${MAIL_DATABASE}`.`user_access`
        WHERE       `${MAIL_DATABASE}`.`user_access`.`address` = `address`;

        -- Since we're creating an user access rule for an user's primary
        -- mailbox, and since ViMbAdmin creates an `address` -> `address` alias
        -- for every mailbox, we must ensure that we don't accidentally delete
        -- the user access rule of an user's primary mailbox
    END IF;

    -- Delete alias
    DELETE FROM `${MAIL_DATABASE}`.`alias`
    WHERE       `${MAIL_DATABASE}`.`alias`.`address` = `address`;
END;

//

--
-- User foreign access procedures
--

CREATE PROCEDURE ACCESS_CREATE(
    IN `user` VARCHAR(255),
    IN `address` VARCHAR(255)
)
BEGIN
    CALL LOG_DEBUG('call', 'procedure', 'ACCESS_CREATE', JSON_ARRAY(`user`, `address`));

    IF IS_USER(`user`) = '1' THEN
        -- Create user access rule
        INSERT IGNORE INTO `${MAIL_DATABASE}`.`user_access`
            (`user`, `address`)
        VALUES
            (`user`, `address`);

        -- Since foreign user access rules aren't managed by ViMbAdmin, there
        -- can be access rules for non-existing or inactive users; thus we must
        -- check whether the user exists
    END IF;
END;

//

CREATE PROCEDURE ACCESS_DELETE(
    IN `user` VARCHAR(255),
    IN `address` VARCHAR(255)
)
BEGIN
    CALL LOG_DEBUG('call', 'procedure', 'ACCESS_DELETE', JSON_ARRAY(`user`, `address`));

    DELETE FROM `${MAIL_DATABASE}`.`user_access`
    WHERE       `${MAIL_DATABASE}`.`user_access`.`user` = `user`
                AND `${MAIL_DATABASE}`.`user_access`.`address` = `address`;
END;

//

--
-- Quota procedures
--

CREATE PROCEDURE QUOTA_UPDATE(
    IN `address` VARCHAR(255),
    IN `bytes` BIGINT,
    IN `messages` INTEGER
)
BEGIN
    CALL LOG_DEBUG('call', 'procedure', 'QUOTA_UPDATE', JSON_ARRAY(`address`, `bytes`, `messages`));

    UPDATE `${VIMBADMIN_DATABASE}`.`mailbox`
    SET    `${VIMBADMIN_DATABASE}`.`mailbox`.`homedir_size` = `bytes`,
           `${VIMBADMIN_DATABASE}`.`mailbox`.`maildir_size` = `bytes`,
           `${VIMBADMIN_DATABASE}`.`mailbox`.`size_at` = NOW()
    WHERE  `${VIMBADMIN_DATABASE}`.`mailbox`.`username` = `address`;

    -- ViMbAdmin doesn't distinguish between user name and mailbox, thus we can
    -- simply use the mailbox address to identify the matching mail user
END;

//

--
-- Helper procedures
--

CREATE PROCEDURE LOG_DEBUG(
    IN `action` VARCHAR(255),
    IN `type` ENUM('procedure', 'function', 'trigger'),
    IN `context` VARCHAR(255),
    IN `text` LONGTEXT
)
BEGIN
    IF @DEBUG_ENABLED = '1' THEN
        CREATE TEMPORARY TABLE IF NOT EXISTS `debug_log` (
            `id` BIGINT NOT NULL AUTO_INCREMENT,
            `action` VARCHAR(255) DEFAULT NULL,
            `type` ENUM('procedure', 'function', 'trigger') NOT NULL,
            `context` VARCHAR(255) NOT NULL,
            `text` LONGTEXT DEFAULT NULL,
            `date` DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        );

        INSERT INTO `debug_log`
            (`action`, `type`, `context`, `text`)
        VALUES
            (`action`, `type`, `context`, `text`);
    END IF;
END;

//

--
-- `vimbadmin`.`domain` trigger
--

USE `${VIMBADMIN_DATABASE}`

//

CREATE TRIGGER DOMAIN_INSERT_TRIGGER
    AFTER INSERT ON `${VIMBADMIN_DATABASE}`.`domain`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL LOG_DEBUG('call', 'trigger', 'DOMAIN_INSERT_TRIGGER', JSON_ARRAY(NEW.`domain`));

        IF NEW.`active` = '1' THEN
            -- Create new domain
            CALL DOMAIN_CREATE(NEW.`domain`, NEW.`transport`);
        END IF;
    END IF;
END;

//

CREATE TRIGGER DOMAIN_UPDATE_TRIGGER
    AFTER UPDATE ON `${VIMBADMIN_DATABASE}`.`domain`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL LOG_DEBUG('call', 'trigger', 'DOMAIN_UPDATE_TRIGGER', JSON_ARRAY(NEW.`domain`));

        IF NEW.`active` = '1' THEN
            IF OLD.`active` <> '1' THEN
                -- Create domain including pre-existing users, mailboxes and aliases
                CALL DOMAIN_REBUILD(NEW.`domain`, NEW.`transport`);
            ELSE
                -- Update domain
                CALL DOMAIN_UPDATE(NEW.`domain`, NEW.`transport`);
            END IF;
        ELSE
            -- Delete previously active domain, if applicable
            CALL DOMAIN_DELETE(OLD.`domain`);
        END IF;
    END IF;
END;

//

CREATE TRIGGER DOMAIN_DELETE_TRIGGER
    AFTER DELETE ON `${VIMBADMIN_DATABASE}`.`domain`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL LOG_DEBUG('call', 'trigger', 'DOMAIN_DELETE_TRIGGER', JSON_ARRAY(OLD.`domain`));

        -- Delete domain
        CALL DOMAIN_DELETE(OLD.`domain`);

        -- Even though DOMAIN_DELETE() will try to delete all mailboxes and aliases
        -- of this domain, it isn't going to find any, because ViMbAdmin already
        -- deleted all of them earlier
    END IF;
END;

//

--
-- `vimbadmin`.`mailbox` trigger
--

USE `${VIMBADMIN_DATABASE}`

//

CREATE TRIGGER MAILBOX_INSERT_TRIGGER
    AFTER INSERT ON `${VIMBADMIN_DATABASE}`.`mailbox`
FOR EACH ROW
BEGIN
    DECLARE `domain` VARCHAR(255);
    DECLARE `mailbox` VARCHAR(255);

    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL LOG_DEBUG('call', 'trigger', 'MAILBOX_INSERT_TRIGGER', JSON_ARRAY(NEW.`username`));

        SET `domain` = GET_DOMAIN(NEW.`Domain_id`);

        IF IS_DOMAIN_ACTIVE(`domain`) = '1' AND NEW.`active` = '1' THEN
            -- ViMbAdmin doesn't really differentiate between username and mailbox,
            -- but we do, otherwise we couldn't switch to something else later
            SET `mailbox` = CONCAT(NEW.`local_part`, '@', `domain`);

            -- Create user
            CALL USER_CREATE(NEW.`username`, NEW.`password`, `mailbox`, NEW.`access_restriction`);

            -- Create mailbox
            CALL MAILBOX_CREATE(`mailbox`, NEW.`uid`, NEW.`gid`, NEW.`homedir`, NEW.`maildir`, NEW.`quota`);
        END IF;
    END IF;
END;

//

CREATE TRIGGER MAILBOX_UPDATE_TRIGGER
    AFTER UPDATE ON `${VIMBADMIN_DATABASE}`.`mailbox`
FOR EACH ROW
BEGIN
    DECLARE `old_domain` VARCHAR(255);
    DECLARE `old_mailbox` VARCHAR(255);

    DECLARE `new_domain` VARCHAR(255);
    DECLARE `new_mailbox` VARCHAR(255);

    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL LOG_DEBUG('call', 'trigger', 'MAILBOX_UPDATE_TRIGGER', JSON_ARRAY(NEW.`username`));

        SET `old_domain` = GET_DOMAIN(OLD.`Domain_id`);
        SET `old_mailbox` = CONCAT(OLD.`local_part`, '@', `old_domain`);

        SET `new_domain` = GET_DOMAIN(NEW.`Domain_id`);
        SET `new_mailbox` = CONCAT(NEW.`local_part`, '@', `new_domain`);

        IF `old_mailbox` <> `new_mailbox` THEN
            -- Delete old mailbox
            CALL MAILBOX_DELETE(`old_mailbox`);

           -- This actually can't happen with ViMbAdmin, because an user's
           -- primary mailbox always matches its user name in ViMbAdmin
        END IF;

        IF IS_DOMAIN_ACTIVE(`new_domain`) = '1' THEN
            -- Update mailbox
            IF NEW.`active` = '1' THEN
                IF OLD.`active` <> '1' THEN
                    -- Create previously inactive user
                    CALL USER_CREATE(NEW.`username`, NEW.`password`, `new_mailbox`, NEW.`access_restriction`);

                    -- Create previously inactive mailbox
                    CALL MAILBOX_CREATE(`new_mailbox`, NEW.`uid`, NEW.`gid`, NEW.`homedir`, NEW.`maildir`, NEW.`quota`);
                ELSE
                    -- Update user
                    CALL USER_UPDATE(NEW.`username`, NEW.`password`, `new_mailbox`, NEW.`access_restriction`);

                    -- Update mailbox
                    CALL MAILBOX_UPDATE(`new_mailbox`, NEW.`uid`, NEW.`gid`, NEW.`homedir`, NEW.`maildir`, NEW.`quota`);
                END IF;
            ELSE
                -- Delete user
                CALL USER_DELETE(OLD.`username`);

                -- Delete previously active mailbox, if applicable
                CALL MAILBOX_DELETE(`old_mailbox`);
            END IF;
        END IF;
    END IF;
END;

//

CREATE TRIGGER MAILBOX_DELETE_TRIGGER
    AFTER DELETE ON `${VIMBADMIN_DATABASE}`.`mailbox`
FOR EACH ROW
BEGIN
    DECLARE `domain` VARCHAR(255);
    DECLARE `mailbox` VARCHAR(255);

    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL LOG_DEBUG('call', 'trigger', 'MAILBOX_DELETE_TRIGGER', JSON_ARRAY(OLD.`username`));

        SET `domain` = GET_DOMAIN(OLD.`Domain_id`);
        SET `mailbox` = CONCAT(OLD.`local_part`, '@', `domain`);

        -- Delete user
        CALL USER_DELETE(OLD.`username`);

        -- Delete mailbox
        CALL MAILBOX_DELETE(`mailbox`);
    END IF;
END;

//

--
-- `vimbadmin`.`alias` trigger
--

USE `${VIMBADMIN_DATABASE}`

//

CREATE TRIGGER ALIAS_INSERT_TRIGGER
    AFTER INSERT ON `${VIMBADMIN_DATABASE}`.`alias`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL LOG_DEBUG('call', 'trigger', 'ALIAS_INSERT_TRIGGER', JSON_ARRAY(NEW.`address`));

        IF IS_DOMAIN_ACTIVE(GET_DOMAIN(NEW.`Domain_id`)) = '1' AND NEW.`active` = '1' THEN
            -- Create alias
            CALL ALIAS_CREATE(NEW.`address`, NEW.`goto`);
        END IF;
    END IF;
END;

//

CREATE TRIGGER ALIAS_UPDATE_TRIGGER
    AFTER UPDATE ON `${VIMBADMIN_DATABASE}`.`alias`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL LOG_DEBUG('call', 'trigger', 'ALIAS_UPDATE_TRIGGER', JSON_ARRAY(NEW.`address`));

        IF IS_DOMAIN_ACTIVE(GET_DOMAIN(NEW.`Domain_id`)) = '1' THEN
            -- Delete alias
            CALL ALIAS_DELETE(OLD.`address`);

            IF NEW.`active` = '1' THEN
                -- Create alias
                CALL ALIAS_CREATE(NEW.`address`, NEW.`goto`);
            END IF;
        END IF;
    END IF;
END;

//

CREATE TRIGGER ALIAS_DELETE_TRIGGER
    AFTER DELETE ON `${VIMBADMIN_DATABASE}`.`alias`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL LOG_DEBUG('call', 'trigger', 'ALIAS_DELETE_TRIGGER', JSON_ARRAY(OLD.`address`));

        -- Delete alias
        CALL ALIAS_DELETE(OLD.`address`);
    END IF;
END;

//

--
-- `mail`.`user_foreign_access` trigger
--

USE `${MAIL_DATABASE}`

//

CREATE TRIGGER ACCESS_INSERT_TRIGGER
    AFTER INSERT ON `${MAIL_DATABASE}`.`user_foreign_access`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL `${VIMBADMIN_DATABASE}`.LOG_DEBUG('call', 'trigger', 'ACCESS_INSERT_TRIGGER', JSON_ARRAY(NEW.`user`, NEW.`address`));

        CALL `${VIMBADMIN_DATABASE}`.ACCESS_CREATE(NEW.`user`, NEW.`address`);
    END IF;
END;

//

CREATE TRIGGER ACCESS_UPDATE_TRIGGER
    AFTER UPDATE ON `${MAIL_DATABASE}`.`user_foreign_access`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL `${VIMBADMIN_DATABASE}`.LOG_DEBUG('call', 'trigger', 'ACCESS_UPDATE_TRIGGER', JSON_ARRAY(NEW.`user`, OLD.`address`, NEW.`address`));

        CALL `${VIMBADMIN_DATABASE}`.ACCESS_DELETE(OLD.`user`, OLD.`address`);
        CALL `${VIMBADMIN_DATABASE}`.ACCESS_CREATE(NEW.`user`, NEW.`address`);
    END IF;
END;

//

CREATE TRIGGER ACCESS_DELETE_TRIGGER
    AFTER DELETE ON `${MAIL_DATABASE}`.`user_foreign_access`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL `${VIMBADMIN_DATABASE}`.LOG_DEBUG('call', 'trigger', 'ACCESS_DELETE_TRIGGER', JSON_ARRAY(OLD.`user`, OLD.`address`));

        CALL `${VIMBADMIN_DATABASE}`.ACCESS_DELETE(OLD.`user`, OLD.`address`);
    END IF;
END;

//

--
-- `mail`.`mailbox_quota` trigger
--

USE `${MAIL_DATABASE}`

//

CREATE TRIGGER QUOTA_INSERT_TRIGGER
    AFTER INSERT ON `${MAIL_DATABASE}`.`mailbox_quota`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL `${VIMBADMIN_DATABASE}`.LOG_DEBUG('call', 'trigger', 'QUOTA_INSERT_TRIGGER', JSON_ARRAY(NEW.`address`));

        CALL `${VIMBADMIN_DATABASE}`.QUOTA_UPDATE(NEW.`address`, NEW.`bytes`, NEW.`messages`);
    END IF;
END;

//

CREATE TRIGGER QUOTA_UPDATE_TRIGGER
    AFTER UPDATE ON `${MAIL_DATABASE}`.`mailbox_quota`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL `${VIMBADMIN_DATABASE}`.LOG_DEBUG('call', 'trigger', 'QUOTA_UPDATE_TRIGGER', JSON_ARRAY(NEW.`address`));

        CALL `${VIMBADMIN_DATABASE}`.QUOTA_UPDATE(NEW.`address`, NEW.`bytes`, NEW.`messages`);
    END IF;
END;

//

CREATE TRIGGER QUOTA_DELETE_TRIGGER
    AFTER DELETE ON `${MAIL_DATABASE}`.`mailbox_quota`
FOR EACH ROW
BEGIN
    IF @TRIGGER_DISABLED IS NULL OR @TRIGGER_DISABLED <> '1' THEN
        CALL `${VIMBADMIN_DATABASE}`.LOG_DEBUG('call', 'trigger', 'QUOTA_DELETE_TRIGGER', JSON_ARRAY(OLD.`address`));

        CALL `${VIMBADMIN_DATABASE}`.QUOTA_UPDATE(OLD.`address`, NULL, NULL);
    END IF;
END;

//

DELIMITER ;

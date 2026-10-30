CREATE TABLE IF NOT EXISTS `gungame_accounts` (
    `citizenid`   VARCHAR(64)  NOT NULL,
    `account_id`  VARCHAR(32)  NOT NULL,
    `name`        VARCHAR(32)  NOT NULL,
    `icon`        TEXT         NULL,
    `level`       INT          NOT NULL DEFAULT 1,
    `total_xp`    INT          NOT NULL DEFAULT 0,
    `total_kills` INT          NOT NULL DEFAULT 0,
    `total_wins`  INT          NOT NULL DEFAULT 0,
    `total_losses` INT         NOT NULL DEFAULT 0,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    UNIQUE KEY `uniq_account_id` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gungame_weekly` (
    `citizenid` VARCHAR(64) NOT NULL,
    `xp`        INT NOT NULL DEFAULT 0,
    `wins`      INT NOT NULL DEFAULT 0,
    `kills`     INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`),
    CONSTRAINT `fk_weekly_account` FOREIGN KEY (`citizenid`)
        REFERENCES `gungame_accounts` (`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gungame_meta` (
    `key`   VARCHAR(64) NOT NULL,
    `value` TEXT NULL,
    PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gungame_friends` (
    `citizenid`        VARCHAR(64) NOT NULL,
    `friend_citizenid` VARCHAR(64) NOT NULL,
    `created_at`       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `friend_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gungame_friend_requests` (
    `id`        INT AUTO_INCREMENT,
    `from_cid`  VARCHAR(64) NOT NULL,
    `to_cid`    VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_request` (`from_cid`, `to_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

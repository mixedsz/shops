-- ============================================================
-- FLAKE SHOPS - ANALYTICS DATABASE SCHEMA (FIXED)
-- Run this in your database to fix all analytics errors
-- ============================================================

-- Shop visits tracking
CREATE TABLE IF NOT EXISTS `shop_visits` (
    `id`                INT(11) NOT NULL AUTO_INCREMENT,
    `shop_name`         VARCHAR(100) NOT NULL,
    `player_identifier` VARCHAR(100) NOT NULL,
    `player_name`       VARCHAR(100) NOT NULL,
    `made_purchase`     TINYINT(1) DEFAULT 0,
    `total_spent`       INT(11) DEFAULT 0,
    `visit_date`        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_shop_name` (`shop_name`),
    INDEX `idx_player_identifier` (`player_identifier`),
    INDEX `idx_visit_date` (`visit_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Individual purchase records
CREATE TABLE IF NOT EXISTS `shop_purchases` (
    `id`                INT(11) NOT NULL AUTO_INCREMENT,
    `shop_name`         VARCHAR(100) NOT NULL,
    `player_identifier` VARCHAR(100) NOT NULL,
    `player_name`       VARCHAR(100) NOT NULL,
    `item_name`         VARCHAR(100) NOT NULL,
    `item_label`        VARCHAR(255) NOT NULL,
    `quantity`          INT(11) NOT NULL DEFAULT 1,
    `price_per_item`    INT(11) NOT NULL DEFAULT 0,
    `total_cost`        INT(11) NOT NULL DEFAULT 0,
    `currency_type`     VARCHAR(50) NOT NULL DEFAULT 'money',
    `purchase_date`     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_shop_name` (`shop_name`),
    INDEX `idx_player_identifier` (`player_identifier`),
    INDEX `idx_purchase_date` (`purchase_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Popular items aggregate (upserted on each purchase)
CREATE TABLE IF NOT EXISTS `shop_popular_items` (
    `id`            INT(11) NOT NULL AUTO_INCREMENT,
    `shop_name`     VARCHAR(100) NOT NULL,
    `item_name`     VARCHAR(100) NOT NULL,
    `item_label`    VARCHAR(255) NOT NULL,
    `total_sold`    INT(11) NOT NULL DEFAULT 0,
    `total_revenue` INT(11) NOT NULL DEFAULT 0,
    `last_sold`     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_shop_item` (`shop_name`, `item_name`),
    INDEX `idx_shop_name` (`shop_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Daily revenue aggregate
CREATE TABLE IF NOT EXISTS `shop_daily_revenue` (
    `id`                  INT(11) NOT NULL AUTO_INCREMENT,
    `shop_name`           VARCHAR(100) NOT NULL,
    `date`                DATE NOT NULL,
    `total_revenue`       INT(11) NOT NULL DEFAULT 0,
    `total_transactions`  INT(11) NOT NULL DEFAULT 0,
    `unique_customers`    INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_shop_date` (`shop_name`, `date`),
    INDEX `idx_shop_name` (`shop_name`),
    INDEX `idx_date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- If your tables already exist with missing columns, run
-- the ALTER statements below to patch them instead:
-- ============================================================

-- Patch shop_visits if it exists but is missing visit_date
ALTER TABLE `shop_visits`
    ADD COLUMN IF NOT EXISTS `visit_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS `made_purchase` TINYINT(1) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `total_spent` INT(11) DEFAULT 0;

-- Patch shop_purchases if it exists but is missing price_per_item
ALTER TABLE `shop_purchases`
    ADD COLUMN IF NOT EXISTS `price_per_item` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `purchase_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Patch shop_popular_items if it exists but is missing last_sold
ALTER TABLE `shop_popular_items`
    ADD COLUMN IF NOT EXISTS `last_sold` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- Patch shop_daily_revenue if it exists but is missing unique_customers
ALTER TABLE `shop_daily_revenue`
    ADD COLUMN IF NOT EXISTS `unique_customers` INT(11) NOT NULL DEFAULT 0;
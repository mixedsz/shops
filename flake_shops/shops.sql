CREATE TABLE IF NOT EXISTS `shops` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_name` VARCHAR(100) NOT NULL UNIQUE,
    `shop_data` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Example shop data structure (stored as JSON in shop_data column):
-- {
--     "Items": [
--         {"label": "Water", "item": "water", "price": 5}
--     ],
--     "Pos": [
--         {"x": 25.7, "y": -1347.3, "z": 29.5}
--     ],
--     "Currency": ["money", "bank"],
--     "UsePickup": false,
--     "UsePed": true,
--     "ShopPed": {
--         "model": "mp_m_shopkeep_01",
--         "heading": 0.0,
--         "scenario": "WORLD_HUMAN_STAND_IMPATIENT"
--     },
--     "ShopLogo": "twentyfourseven.png",
--     "Blip": {
--         "sprite": 52,
--         "display": 4,
--         "scale": 0.7,
--         "colour": 2,
--         "shortRange": true,
--         "name": "Shop"
--     }
-- }


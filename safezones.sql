CREATE TABLE IF NOT EXISTS `safezones` ( 
    `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
    `points` VARCHAR(255) NOT NULL, 
    `data` LONGTEXT NOT NULL,
    PRIMARY KEY (`id`)
);

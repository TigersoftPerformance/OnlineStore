-- SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
-- SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
-- SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

CREATE SCHEMA IF NOT EXISTS `TP` DEFAULT CHARACTER SET utf8 ;
USE `TP` ;

-- -----------------------------------------------------
-- Table `TP`.`BCRacingCoilovers`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`BCRacingCoilovers` ;

CREATE TABLE IF NOT EXISTS `TP`.`BCRacingCoilovers` (
  `idBCRacingCoilovers` INT(11) NOT NULL AUTO_INCREMENT,
  `make` VARCHAR(30) NULL DEFAULT NULL,
  `model` VARCHAR(50) NULL DEFAULT NULL,
  `model_code` VARCHAR(50) NULL DEFAULT NULL,
  `year` VARCHAR(15) NULL DEFAULT NULL,
  `item_no` VARCHAR(10) NULL DEFAULT NULL,
  `VS` CHAR(1) NULL DEFAULT NULL,
  `VT` CHAR(1) NULL DEFAULT NULL,
  `VL` CHAR(1) NULL DEFAULT NULL,
  `VN` CHAR(1) NULL DEFAULT NULL,
  `VH` CHAR(1) NULL DEFAULT NULL,
  `VA` CHAR(1) NULL DEFAULT NULL,
  `VM` CHAR(1) NULL DEFAULT NULL,
  `RS` CHAR(1) NULL DEFAULT NULL,
  `RA` CHAR(1) NULL DEFAULT NULL,
  `RH` CHAR(1) NULL DEFAULT NULL,
  `RN` CHAR(1) NULL DEFAULT NULL,
  `MA` CHAR(1) NULL DEFAULT NULL,
  `MH` CHAR(1) NULL DEFAULT NULL,
  `SA` CHAR(1) NULL DEFAULT NULL,
  `ER` CHAR(1) NULL DEFAULT NULL,
  UNIQUE INDEX `idBCRacingCoilovers` (`idBCRacingCoilovers` ASC))
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`BMCAirFilters`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`BMCAirFilters` ;

CREATE TABLE IF NOT EXISTS `TP`.`BMCAirFilters` (
  `part_id` INT(11) NOT NULL AUTO_INCREMENT,
  `part` VARCHAR(32) NOT NULL,
  `name` TEXT NOT NULL COMMENT '	',
  `buy_price` FLOAT NOT NULL COMMENT '	',
  `RRP` FLOAT NOT NULL,
  `type` TEXT NULL DEFAULT NULL,
  `description` TEXT NULL DEFAULT NULL,
  `dimname1` VARCHAR(45) NULL DEFAULT NULL,
  `dimvalue1` VARCHAR(45) NULL DEFAULT NULL,
  `dimname2` VARCHAR(45) NULL DEFAULT NULL,
  `dimvalue2` VARCHAR(45) NULL DEFAULT NULL,
  `dimname3` VARCHAR(45) NULL DEFAULT NULL,
  `dimvalue3` VARCHAR(45) NULL DEFAULT NULL,
  `image` TEXT NULL DEFAULT NULL,
  `diagram` TEXT NULL DEFAULT NULL,
  `active` CHAR(1) NULL DEFAULT NULL,
  `comments` LONGTEXT NULL DEFAULT NULL,
  PRIMARY KEY (`part_id`),
  UNIQUE INDEX `part_id_UNIQUE` (`part_id` ASC))
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`BMCCars`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`BMCCars` ;

CREATE TABLE IF NOT EXISTS `TP`.`BMCCars` (
  `idBMCCars` INT(11) NOT NULL AUTO_INCREMENT,
  `make` TEXT NOT NULL,
  `variant` TEXT NOT NULL,
  `hp` INT(11) NULL DEFAULT NULL,
  `year` VARCHAR(16) NULL DEFAULT NULL,
  `part_id` INT(11) NOT NULL,
  `active` CHAR(1) NULL DEFAULT NULL,
  `comments` LONGTEXT NULL DEFAULT NULL,
  PRIMARY KEY (`idBMCCars`),
  UNIQUE INDEX `idBMCCars_UNIQUE` (`idBMCCars` ASC))
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`BMCmods`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`BMCmods` ;

CREATE TABLE IF NOT EXISTS `TP`.`BMCmods` (
  `idBMCmods` INT(11) NOT NULL AUTO_INCREMENT,
  `make` TEXT NULL DEFAULT NULL,
  `marca` INT(11) NULL DEFAULT NULL,
  `model` TEXT NULL DEFAULT NULL,
  `modid` VARCHAR(30) NULL DEFAULT NULL,
  PRIMARY KEY (`idBMCmods`))
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`CarFilters`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`CarFilters` ;

CREATE TABLE IF NOT EXISTS `TP`.`CarFilters` (
  `idCarFilters` INT(11) NOT NULL AUTO_INCREMENT,
  `carID` INT(11) NULL DEFAULT NULL,
  `CR` INT(11) NULL DEFAULT NULL,
  `CDA` INT(11) NULL DEFAULT NULL,
  `CRF` INT(11) NULL DEFAULT NULL,
  `OTA` INT(11) NULL DEFAULT NULL,
  `SPK` INT(11) NULL DEFAULT NULL,
  PRIMARY KEY (`idCarFilters`))
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`Cars`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`Cars` ;

CREATE TABLE IF NOT EXISTS `TP`.`Cars` (
  `idCars` INT(11) NOT NULL AUTO_INCREMENT,
  `make` TEXT NOT NULL,
  `model` TEXT NOT NULL,
  `model_code` TEXT NULL DEFAULT NULL,
  `variant` TEXT NULL DEFAULT NULL,
  `fuel_type` TEXT NOT NULL,
  `start_date` DATE NOT NULL,
  `end_date` DATE NOT NULL,
  `capacity` FLOAT NOT NULL,
  `cylinders` INT(11) NOT NULL,
  `original_bhp` INT(11) NULL DEFAULT NULL,
  `original_kw` INT(11) NULL DEFAULT NULL,
  `original_nm` INT(11) NULL DEFAULT NULL,
  `superchips_tune` INT(11) NULL DEFAULT NULL,
  `superchips_stage2` INT(11) NULL DEFAULT NULL,
  `superchips_stage3` INT(11) NULL DEFAULT NULL,
  `superchips_stage4` INT(11) NULL DEFAULT NULL,
  `bmc_airfilter` INT(11) NULL DEFAULT NULL,
  `bc_racing_coilovers` INT(11) NULL DEFAULT NULL,
  `active` CHAR(1) NULL DEFAULT NULL,
  `comments` LONGTEXT NULL DEFAULT NULL,
  PRIMARY KEY (`idCars`),
  UNIQUE INDEX `idCars_UNIQUE` (`idCars` ASC))
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`CarsNew`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`CarsNew` ;


-- -----------------------------------------------------
-- Table `TP`.`Categories`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`Categories` ;

CREATE TABLE IF NOT EXISTS `TP`.`Categories` (
  `longname` VARCHAR(120) NOT NULL,
  `shortname` VARCHAR(50) NOT NULL,
  `partid` VARCHAR(25) NULL,
  `idCars` INT(11) NULL,
  `image` TEXT NOT NULL,
  `description` TEXT NOT NULL,
  `metatags_title` TEXT NULL DEFAULT NULL,
  `metatags_keywords` TEXT NULL DEFAULT NULL,
  `metatags_description` TEXT NULL DEFAULT NULL,
  `active` CHAR(1) NULL DEFAULT NULL,
  `comments` LONGTEXT NULL DEFAULT NULL,
  PRIMARY KEY (`shortname`))
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`FIWebsite`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`FI` ;
DROP TABLE IF EXISTS `TP`.`FIDESC` ;
DROP TABLE IF EXISTS `TP`.`FIWebsite` ;

CREATE TABLE IF NOT EXISTS `TP`.`FIWebsite` (
  `partid` VARCHAR(16) NULL DEFAULT NULL,
  `name` VARCHAR(50) NULL DEFAULT NULL,
  `category` VARCHAR(50) NULL DEFAULT NULL,
  `price` DECIMAL(13,4) NULL DEFAULT '0',
  `overview` TEXT NULL DEFAULT NULL,
  `images` TEXT NULL DEFAULT NULL,
  `videos` TEXT NULL DEFAULT NULL,
  `description` TEXT NULL DEFAULT NULL,
  `active` CHAR(1) NULL DEFAULT NULL,
  `comments` LONGTEXT NULL DEFAULT NULL,
  PRIMARY KEY (`partid`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `TP`.`FIProducts`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`FIProducts` ;

CREATE TABLE IF NOT EXISTS `TP`.`FIProducts` (
  `partid` VARCHAR(16) NULL DEFAULT NULL,
  `name` VARCHAR(50) NULL DEFAULT NULL,
  `category` VARCHAR(50) NULL DEFAULT NULL,
  `rrprice` DECIMAL(13,4) NULL DEFAULT '0',
  `tpprice` DECIMAL(13,4) NULL DEFAULT '0',
  `tpcost` DECIMAL(13,4) NULL DEFAULT '0',
  `image` TEXT NULL DEFAULT NULL,
  `description` LONGTEXT NULL DEFAULT NULL,
  `manufacturer` VARCHAR(50) NULL DEFAULT NULL,
  `sortorder` INT NULL DEFAULT '0',
  `active` CHAR(1) NULL DEFAULT NULL,
  `comments` LONGTEXT NULL DEFAULT NULL,
  PRIMARY KEY (`partid`) )
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`ModelCodes`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`ModelCodes` ;

CREATE TABLE IF NOT EXISTS `TP`.`ModelCodes` (
  `idModelCodes` INT(11) NOT NULL AUTO_INCREMENT,
  `make` TEXT NULL DEFAULT NULL,
  `model` TEXT NULL DEFAULT NULL,
  `model_code` TEXT NULL DEFAULT NULL,
  `start_date` VARCHAR(5) NULL DEFAULT NULL,
  `end_date` VARCHAR(5) NULL DEFAULT NULL,
  `nickname` TEXT NULL DEFAULT NULL,
  `active` CHAR(1) NULL DEFAULT NULL,
  `comments` LONGTEXT NULL DEFAULT NULL,
  PRIMARY KEY (`idModelCodes`),
  UNIQUE INDEX `idModelCodes_UNIQUE` (`idModelCodes` ASC))
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`QuantumCars`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`QuantumCars` ;

CREATE TABLE IF NOT EXISTS `TP`.`QuantumCars` (
  `idQuantumCars` INT(11) NOT NULL AUTO_INCREMENT,
  `make` VARCHAR(30) NULL DEFAULT NULL,
  `model` VARCHAR(50) NULL DEFAULT NULL,
  `variant` VARCHAR(50) NULL DEFAULT NULL,
  `original_bhp` INT(15) NULL DEFAULT NULL,
  `tuned_bhp` INT(15) NULL DEFAULT NULL,
  `bhp_increase` VARCHAR(15) NULL DEFAULT NULL,
  `original_nm` INT(15) NULL DEFAULT NULL,
  `tuned_nm` INT(15) NULL DEFAULT NULL,
  `nm_increase` VARCHAR(15) NULL DEFAULT NULL,
  `image` VARCHAR(60) NULL DEFAULT NULL,
  UNIQUE INDEX `idQuantumCars` (`idQuantumCars` ASC))
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `TP`.`SuperchipsMakes`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`SuperchipsMakes` ;

CREATE TABLE IF NOT EXISTS `TP`.`SuperchipsMakes` (
  `make_num` INT(11) NOT NULL,
  `make` TEXT NOT NULL,
  `active` CHAR(1) NULL DEFAULT NULL,
  `comments` LONGTEXT NULL DEFAULT NULL,
  PRIMARY KEY (`make_num`),
  UNIQUE INDEX `make_num_UNIQUE` (`make_num` ASC))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`SuperchipsWebsite`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`SuperchipsWebsite` ;

CREATE TABLE IF NOT EXISTS `TP`.`SuperchipsWebsite` (
  `variant_id` INT(11) NOT NULL,
  `make` TEXT NOT NULL,
  `model` TEXT NOT NULL,
  `year` TEXT NULL DEFAULT NULL,
  `engine_type` TEXT NOT NULL,
  `capacity` INT(11) NOT NULL,
  `cylinders` INT(11) NOT NULL,
  `original_bhp` INT(11) NOT NULL,
  `original_nm` INT(11) NOT NULL,
  `gain_bhp` INT(11) NOT NULL,
  `gain_nm` INT(11) NOT NULL,
  `uk_price` INT(11) NOT NULL,
  `bluefin` CHAR(1) NOT NULL,
  `epc` CHAR(1) NOT NULL,
  `tune_type` CHAR(1) NULL DEFAULT NULL,
  `dyno_graph` TEXT NULL DEFAULT NULL,
  `road_test` TEXT NULL DEFAULT NULL,
  `warning` TEXT NULL DEFAULT NULL,
  `related_media` TEXT NULL DEFAULT NULL,
  `active` CHAR(1) NULL DEFAULT NULL,
  `comments` LONGTEXT NULL DEFAULT NULL,
  `mark` CHAR(1) NOT NULL,
  PRIMARY KEY (`variant_id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `TP`.`ZenCartStoreEntries`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`ZenCartStoreEntries` ;

CREATE TABLE IF NOT EXISTS `TP`.`ZenCartStoreEntries` (
  `v_products_model` VARCHAR(32) NOT NULL,
  `v_products_type` INT DEFAULT '1' NOT NULL,
  `v_products_image` TEXT NULL DEFAULT NULL,
  `v_products_name_1` TEXT NOT NULL,
  `v_products_description_1` LONGTEXT NULL DEFAULT NULL,
  `v_products_url_1` TEXT NULL DEFAULT NULL,
  `v_specials_price` FLOAT NULL DEFAULT NULL,
  `v_specials_date_avail` DATE NULL DEFAULT NULL,
  `v_specials_expires_date` DATE NULL DEFAULT NULL,
  `v_products_price` FLOAT NOT NULL,
  `v_products_weight` FLOAT NULL DEFAULT '0',
  `v_products_is_call` INT NULL DEFAULT '0',
  `v_products_sort_order` INT NULL DEFAULT '0',
  `v_products_quantity_order_min` FLOAT NULL DEFAULT '1',
  `v_products_quantity_order_units` FLOAT NULL DEFAULT '1',
  `v_products_priced_by_attribute` INT NULL DEFAULT '0',
  `v_products_is_always_free_shipping` INT NULL DEFAULT '0',
  `v_date_avail` DATE NULL DEFAULT '2014-07-01 00:00:00',
  `v_date_added` DATE NULL DEFAULT '2014-07-01 00:00:00',
  `v_products_quantity` FLOAT NULL DEFAULT '100',
  `v_manufacturers_name` TEXT NOT NULL,
  `v_categories_name_1` TEXT NOT NULL,
  `v_tax_class_title` TEXT NULL,
  `v_status` INT NULL DEFAULT '1',
  `v_metatags_products_name_status` INT NULL DEFAULT '1',
  `v_metatags_title_status` INT NULL DEFAULT '1',
  `v_metatags_model_status` INT NULL DEFAULT '1',
  `v_metatags_price_status` INT NULL DEFAULT '0',
  `v_metatags_title_tagline_status` INT NULL DEFAULT '1',
  `v_metatags_title_1` TEXT NOT NULL,
  `v_metatags_keywords_1` TEXT NOT NULL,
  `v_metatags_description_1` LONGTEXT NOT NULL,
  PRIMARY KEY (`v_products_model`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- SET SQL_MODE=@OLD_SQL_MODE;
-- SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
-- SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- -----------------------------------------------------
-- Table `TP`.`BMCAirProducts`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `TP`.`BMCAirProducts` ;

CREATE TABLE IF NOT EXISTS `TP`.`BMCAirProducts` (
  `part_id` INT(11) NOT NULL AUTO_INCREMENT,
  `cat` TEXT NULL DEFAULT NULL,
  `part` VARCHAR(32) NOT NULL,
  `name` TEXT NOT NULL COMMENT ' ',
  `buy_price` FLOAT NOT NULL COMMENT '  ',
  `RRP` FLOAT NOT NULL,
  `type` TEXT NULL DEFAULT NULL,
  `description` TEXT NULL DEFAULT NULL,
  `dimname1` VARCHAR(45) NULL DEFAULT NULL,
  `dimvalue1` VARCHAR(45) NULL DEFAULT NULL,
  `dimname2` VARCHAR(45) NULL DEFAULT NULL,
  `dimvalue2` VARCHAR(45) NULL DEFAULT NULL,
  `dimname3` VARCHAR(45) NULL DEFAULT NULL,
  `dimvalue3` VARCHAR(45) NULL DEFAULT NULL,
  `image` TEXT NULL DEFAULT NULL,
  `diagram` TEXT NULL DEFAULT NULL,
  `active` CHAR(1) NULL DEFAULT NULL,
  `comments` LONGTEXT NULL DEFAULT NULL,
  PRIMARY KEY (`part_id`),
  UNIQUE INDEX `part_id_UNIQUE` (`part_id` ASC))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

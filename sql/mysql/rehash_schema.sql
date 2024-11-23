-- MySQL dump 10.13  Distrib 8.0.31, for Linux (x86_64)
--
-- Host: 127.0.0.1    Database: soylentnews
-- ------------------------------------------------------
-- Server version	8.0.31-0ubuntu0.22.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `abusers`
--

DROP TABLE IF EXISTS `abusers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `abusers` (
  `abuser_id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL,
  `ipid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `pagename` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `reason` varchar(120) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `querystring` varchar(200) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`abuser_id`),
  KEY `uid` (`uid`),
  KEY `ipid` (`ipid`),
  KEY `subnetid` (`subnetid`),
  KEY `reason` (`reason`),
  KEY `ts` (`ts`)
) ENGINE=InnoDB AUTO_INCREMENT=93281 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog`
--

DROP TABLE IF EXISTS `accesslog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `host_addr` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `dat` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `uid` mediumint unsigned NOT NULL,
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `query_string` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `user_agent` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `skid` smallint unsigned NOT NULL DEFAULT '0',
  `bytes` mediumint unsigned NOT NULL DEFAULT '0',
  `duration` float NOT NULL DEFAULT '0',
  `pagemark` bigint unsigned NOT NULL DEFAULT '0',
  `local_addr` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `static` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `secure` tinyint NOT NULL DEFAULT '0',
  `referer` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `status` smallint unsigned NOT NULL DEFAULT '200',
  PRIMARY KEY (`id`),
  KEY `host_addr_part` (`host_addr`),
  KEY `op_part` (`op`,`skid`),
  KEY `ts` (`ts`)
) ENGINE=InnoDB AUTO_INCREMENT=259836157 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog_admin`
--

DROP TABLE IF EXISTS `accesslog_admin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog_admin` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `host_addr` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `dat` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `uid` mediumint unsigned NOT NULL,
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `query_string` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `user_agent` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `skid` smallint unsigned NOT NULL DEFAULT '0',
  `bytes` mediumint unsigned NOT NULL DEFAULT '0',
  `form` mediumblob NOT NULL,
  `secure` tinyint NOT NULL DEFAULT '0',
  `status` smallint unsigned NOT NULL DEFAULT '200',
  PRIMARY KEY (`id`),
  KEY `host_addr` (`host_addr`),
  KEY `ts` (`ts`)
) ENGINE=InnoDB AUTO_INCREMENT=3300637 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog_artcom`
--

DROP TABLE IF EXISTS `accesslog_artcom`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog_artcom` (
  `uid` mediumint unsigned NOT NULL,
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `c` smallint unsigned NOT NULL DEFAULT '0',
  KEY `uid` (`uid`),
  KEY `ts` (`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog_build_uidip`
--

DROP TABLE IF EXISTS `accesslog_build_uidip`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog_build_uidip` (
  `uidip` varchar(32) NOT NULL,
  `op` varchar(254) NOT NULL,
  PRIMARY KEY (`uidip`,`op`),
  KEY `op` (`op`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog_build_unique_uid`
--

DROP TABLE IF EXISTS `accesslog_build_unique_uid`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog_build_unique_uid` (
  `uid` mediumint unsigned NOT NULL,
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog_temp`
--

DROP TABLE IF EXISTS `accesslog_temp`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog_temp` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `host_addr` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `dat` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `uid` mediumint unsigned NOT NULL,
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `query_string` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `user_agent` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `skid` smallint unsigned NOT NULL DEFAULT '0',
  `bytes` mediumint unsigned NOT NULL DEFAULT '0',
  `duration` float NOT NULL DEFAULT '0',
  `pagemark` bigint unsigned NOT NULL DEFAULT '0',
  `local_addr` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `static` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `secure` tinyint NOT NULL DEFAULT '0',
  `referer` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `status` smallint unsigned NOT NULL DEFAULT '200',
  PRIMARY KEY (`id`),
  KEY `host_addr_part` (`host_addr`),
  KEY `op_part` (`op`,`skid`),
  KEY `uid` (`uid`),
  KEY `skid_op` (`skid`,`op`),
  KEY `op_uid_skid` (`op`,`uid`,`skid`),
  KEY `referer` (`referer`(4)),
  KEY `ts` (`ts`),
  KEY `pagemark` (`pagemark`)
) ENGINE=InnoDB AUTO_INCREMENT=259735417 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog_temp_errors`
--

DROP TABLE IF EXISTS `accesslog_temp_errors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog_temp_errors` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `host_addr` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `dat` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `uid` mediumint unsigned NOT NULL,
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `query_string` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `user_agent` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `skid` smallint unsigned NOT NULL DEFAULT '0',
  `bytes` mediumint unsigned NOT NULL DEFAULT '0',
  `duration` float NOT NULL DEFAULT '0',
  `pagemark` bigint unsigned NOT NULL DEFAULT '0',
  `local_addr` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `static` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `secure` tinyint NOT NULL DEFAULT '0',
  `referer` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `status` smallint unsigned NOT NULL DEFAULT '200',
  PRIMARY KEY (`id`),
  KEY `host_addr_part` (`host_addr`),
  KEY `op_part` (`op`,`skid`),
  KEY `ts` (`ts`),
  KEY `status_op_skid` (`status`,`op`,`skid`)
) ENGINE=InnoDB AUTO_INCREMENT=259735417 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog_temp_host_addr`
--

DROP TABLE IF EXISTS `accesslog_temp_host_addr`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog_temp_host_addr` (
  `host_addr` char(39) NOT NULL,
  `anon` enum('no','yes') NOT NULL DEFAULT 'yes',
  PRIMARY KEY (`host_addr`,`anon`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog_temp_other`
--

DROP TABLE IF EXISTS `accesslog_temp_other`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog_temp_other` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `host_addr` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `dat` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `uid` mediumint unsigned NOT NULL,
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `query_string` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `user_agent` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `skid` smallint unsigned NOT NULL DEFAULT '0',
  `bytes` mediumint unsigned NOT NULL DEFAULT '0',
  `duration` float NOT NULL DEFAULT '0',
  `pagemark` bigint unsigned NOT NULL DEFAULT '0',
  `local_addr` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `static` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `secure` tinyint NOT NULL DEFAULT '0',
  `referer` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `status` smallint unsigned NOT NULL DEFAULT '200',
  PRIMARY KEY (`id`),
  KEY `host_addr_part` (`host_addr`),
  KEY `op_part` (`op`,`skid`),
  KEY `ts` (`ts`),
  KEY `skid` (`skid`)
) ENGINE=InnoDB AUTO_INCREMENT=259735417 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog_temp_rss`
--

DROP TABLE IF EXISTS `accesslog_temp_rss`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog_temp_rss` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `host_addr` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `dat` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `uid` mediumint unsigned NOT NULL,
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `query_string` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `user_agent` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `skid` smallint unsigned NOT NULL DEFAULT '0',
  `bytes` mediumint unsigned NOT NULL DEFAULT '0',
  `duration` float NOT NULL DEFAULT '0',
  `pagemark` bigint unsigned NOT NULL DEFAULT '0',
  `local_addr` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `static` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `secure` tinyint NOT NULL DEFAULT '0',
  `referer` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `status` smallint unsigned NOT NULL DEFAULT '200',
  PRIMARY KEY (`id`),
  KEY `host_addr_part` (`host_addr`),
  KEY `op_part` (`op`,`skid`),
  KEY `ts` (`ts`),
  KEY `skid` (`skid`)
) ENGINE=InnoDB AUTO_INCREMENT=259735417 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accesslog_temp_subscriber`
--

DROP TABLE IF EXISTS `accesslog_temp_subscriber`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accesslog_temp_subscriber` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `host_addr` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(39) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `dat` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `uid` mediumint unsigned NOT NULL,
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `query_string` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `user_agent` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `skid` smallint unsigned NOT NULL DEFAULT '0',
  `bytes` mediumint unsigned NOT NULL DEFAULT '0',
  `duration` float NOT NULL DEFAULT '0',
  `pagemark` bigint unsigned NOT NULL DEFAULT '0',
  `local_addr` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `static` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `secure` tinyint NOT NULL DEFAULT '0',
  `referer` varchar(254) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `status` smallint unsigned NOT NULL DEFAULT '200',
  PRIMARY KEY (`id`),
  KEY `host_addr_part` (`host_addr`),
  KEY `op_part` (`op`,`skid`),
  KEY `skid` (`skid`)
) ENGINE=InnoDB AUTO_INCREMENT=259735417 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `achievements`
--

DROP TABLE IF EXISTS `achievements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `achievements` (
  `aid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `description` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `repeatable` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `increment` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`aid`),
  UNIQUE KEY `achievement` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ajax_ops`
--

DROP TABLE IF EXISTS `ajax_ops`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ajax_ops` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `op` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `class` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subroutine` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `reskey_name` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `reskey_type` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `op` (`op`)
) ENGINE=InnoDB AUTO_INCREMENT=58 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `al2`
--

DROP TABLE IF EXISTS `al2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `al2` (
  `srcid` bigint unsigned NOT NULL DEFAULT '0',
  `value` int unsigned NOT NULL DEFAULT '0',
  `updatecount` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`srcid`),
  KEY `value` (`value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `al2_log`
--

DROP TABLE IF EXISTS `al2_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `al2_log` (
  `al2lid` int unsigned NOT NULL AUTO_INCREMENT,
  `srcid` bigint unsigned NOT NULL DEFAULT '0',
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `adminuid` mediumint unsigned NOT NULL DEFAULT '0',
  `al2tid` tinyint unsigned NOT NULL DEFAULT '0',
  `val` enum('set','clear') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`al2lid`),
  KEY `ts` (`ts`),
  KEY `srcid_ts` (`srcid`,`ts`),
  KEY `al2tid_val_srcid` (`al2tid`,`val`,`srcid`)
) ENGINE=InnoDB AUTO_INCREMENT=1487 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `al2_log_comments`
--

DROP TABLE IF EXISTS `al2_log_comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `al2_log_comments` (
  `al2lid` int unsigned NOT NULL DEFAULT '0',
  `comment` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`al2lid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `al2_types`
--

DROP TABLE IF EXISTS `al2_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `al2_types` (
  `al2tid` tinyint unsigned NOT NULL AUTO_INCREMENT,
  `bitpos` tinyint unsigned DEFAULT NULL,
  `name` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `title` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`al2tid`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `bitpos` (`bitpos`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `authors_cache`
--

DROP TABLE IF EXISTS `authors_cache`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `authors_cache` (
  `uid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `nickname` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `fakeemail` varchar(75) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `homepage` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `storycount` mediumint NOT NULL,
  `bio` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `author` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB AUTO_INCREMENT=6667 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `auto_poll`
--

DROP TABLE IF EXISTS `auto_poll`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auto_poll` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `primaryskid` smallint unsigned DEFAULT NULL,
  `qid` mediumint unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `backup_blocks`
--

DROP TABLE IF EXISTS `backup_blocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `backup_blocks` (
  `bid` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `block` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  PRIMARY KEY (`bid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `badpasswords`
--

DROP TABLE IF EXISTS `badpasswords`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `badpasswords` (
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `ip` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnet` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `password` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `realemail` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  KEY `uid` (`uid`),
  KEY `ip` (`ip`),
  KEY `subnet` (`subnet`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bitpay_log`
--

DROP TABLE IF EXISTS `bitpay_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bitpay_log` (
  `logid` bigint unsigned NOT NULL AUTO_INCREMENT,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `uid` mediumint unsigned DEFAULT NULL,
  `invoice_id` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `payment_net` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `payment_status` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `raw_transaction` text CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `remote_address` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`logid`)
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `blobs`
--

DROP TABLE IF EXISTS `blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blobs` (
  `id` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `content_type` varchar(80) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `filename` varchar(80) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `seclev` mediumint unsigned NOT NULL DEFAULT '0',
  `reference_count` mediumint unsigned NOT NULL DEFAULT '1',
  `data` longblob NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `blocks`
--

DROP TABLE IF EXISTS `blocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blocks` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `bid` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `block` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `seclev` mediumint unsigned NOT NULL DEFAULT '0',
  `type` enum('static','portald') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'static',
  `description` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `skin` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `ordernum` tinyint DEFAULT '0',
  `title` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `portal` tinyint NOT NULL DEFAULT '0',
  `url` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `rdf` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `retrieve` tinyint NOT NULL DEFAULT '0',
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `rss_template` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `items` smallint NOT NULL DEFAULT '0',
  `autosubmit` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `rss_cookie` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `all_skins` tinyint NOT NULL DEFAULT '0',
  `shill` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `shill_uid` mediumint unsigned NOT NULL DEFAULT '0',
  `default_block` tinyint unsigned NOT NULL DEFAULT '0',
  `hidden` tinyint unsigned NOT NULL DEFAULT '0',
  `always_on` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `bid` (`bid`),
  KEY `type` (`type`),
  KEY `skin` (`skin`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `classes`
--

DROP TABLE IF EXISTS `classes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `classes` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `class` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `db_type` enum('writer','reader','log','search') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'writer',
  `fallback` enum('writer','reader','log','search') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `class_key` (`class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `clout_types`
--

DROP TABLE IF EXISTS `clout_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `clout_types` (
  `clid` smallint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `class` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`clid`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `code_param`
--

DROP TABLE IF EXISTS `code_param`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `code_param` (
  `param_id` smallint unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(24) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `code` tinyint NOT NULL DEFAULT '0',
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`param_id`),
  UNIQUE KEY `code_key` (`type`,`code`)
) ENGINE=InnoDB AUTO_INCREMENT=65 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comment_log`
--

DROP TABLE IF EXISTS `comment_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comment_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `cid` int unsigned NOT NULL,
  `logtext` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  PRIMARY KEY (`id`),
  KEY `ts` (`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comment_promote_log`
--

DROP TABLE IF EXISTS `comment_promote_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comment_promote_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `cid` int unsigned NOT NULL DEFAULT '0',
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  PRIMARY KEY (`id`),
  KEY `cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comment_text`
--

DROP TABLE IF EXISTS `comment_text`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comment_text` (
  `cid` int unsigned NOT NULL,
  `comment` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `commentmodes`
--

DROP TABLE IF EXISTS `commentmodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `commentmodes` (
  `mode` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `description` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`mode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comments`
--

DROP TABLE IF EXISTS `comments_audit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comments_audit` (
  `logid` int unsigned NOT NULL AUTO_INCREMENT,
  `cid` int unsigned NOT NULL,
  `date` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `mod_uid` mediumint unsigned NOT NULL,
  `mod_reason` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `spam_flag` tinyint(1) NOT NULL,
  PRIMARY KEY (`logid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

DROP TABLE IF EXISTS `comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comments` (
  `sid` mediumint unsigned NOT NULL,
  `cid` int unsigned NOT NULL AUTO_INCREMENT,
  `pid` int unsigned NOT NULL DEFAULT '0',
  `opid` int unsigned NOT NULL DEFAULT '0',
  `children` int unsigned NOT NULL DEFAULT '0',
  `date` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `ipid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subject` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `subject_orig` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `uid` mediumint unsigned NOT NULL,
  `points` tinyint NOT NULL DEFAULT '0',
  `pointsorig` tinyint NOT NULL DEFAULT '0',
  `pointsmax` tinyint NOT NULL DEFAULT '0',
  `lastmod` mediumint unsigned NOT NULL DEFAULT '0',
  `reason` tinyint unsigned NOT NULL DEFAULT '0',
  `signature` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `karma_bonus` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `subscriber_bonus` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `len` smallint unsigned NOT NULL DEFAULT '0',
  `karma` smallint NOT NULL DEFAULT '0',
  `karma_abs` smallint unsigned NOT NULL DEFAULT '0',
  `tweak_orig` tinyint NOT NULL DEFAULT '0',
  `tweak` tinyint NOT NULL DEFAULT '0',
  `badge_id` tinyint NOT NULL DEFAULT '0',
  `spam_flag` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`cid`),
  KEY `display` (`sid`,`points`,`uid`),
  KEY `byname` (`uid`,`points`),
  KEY `ipid` (`ipid`),
  KEY `subnetid` (`subnetid`),
  KEY `theusual` (`sid`,`uid`,`points`,`cid`),
  KEY `countreplies` (`pid`,`sid`),
  KEY `uid_date` (`uid`,`date`),
  KEY `date_sid` (`date`,`sid`),
  KEY `opid` (`opid`)
) ENGINE=InnoDB AUTO_INCREMENT=1310463 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `content_filters`
--

DROP TABLE IF EXISTS `content_filters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `content_filters` (
  `filter_id` tinyint unsigned NOT NULL AUTO_INCREMENT,
  `form` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `regex` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `modifier` varchar(5) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `field` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `ratio` float(6,4) NOT NULL DEFAULT '0.0000',
  `minimum_match` mediumint NOT NULL DEFAULT '0',
  `minimum_length` mediumint NOT NULL DEFAULT '0',
  `err_message` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '',
  PRIMARY KEY (`filter_id`),
  KEY `form` (`form`),
  KEY `regex` (`regex`),
  KEY `field_key` (`field`)
) ENGINE=InnoDB AUTO_INCREMENT=236 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `css`
--

DROP TABLE IF EXISTS `css`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `css` (
  `csid` int NOT NULL AUTO_INCREMENT,
  `rel` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'stylesheet',
  `type` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'text/css',
  `media` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'screen, projection',
  `file` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `title` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `skin` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `page` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `admin` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `theme` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `ctid` tinyint NOT NULL DEFAULT '0',
  `ordernum` int DEFAULT '0',
  `ie_cond` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `lowbandwidth` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `layout` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  PRIMARY KEY (`csid`),
  KEY `ctid` (`ctid`),
  KEY `page_skin` (`page`,`skin`),
  KEY `skin_page` (`skin`,`page`),
  KEY `layout` (`layout`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `css_type`
--

DROP TABLE IF EXISTS `css_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `css_type` (
  `ctid` tinyint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `ordernum` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ctid`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dateformats`
--

DROP TABLE IF EXISTS `dateformats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dateformats` (
  `id` tinyint unsigned NOT NULL DEFAULT '0',
  `format` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `description` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dbs`
--

DROP TABLE IF EXISTS `dbs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dbs` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `virtual_user` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `isalive` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `type` enum('writer','reader','log','search','log_slave','querylog') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'reader',
  `weight` tinyint unsigned NOT NULL DEFAULT '1',
  `weight_adjust` float unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dbs_readerstatus`
--

DROP TABLE IF EXISTS `dbs_readerstatus`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dbs_readerstatus` (
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `dbid` mediumint unsigned NOT NULL,
  `was_alive` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `was_reachable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `was_running` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `slave_lag_secs` float DEFAULT '0',
  `query_bog_secs` float DEFAULT '0',
  `bog_rsqid` mediumint unsigned DEFAULT NULL,
  `had_weight` tinyint unsigned DEFAULT '1',
  `had_weight_adjust` float unsigned DEFAULT '1',
  KEY `ts_dbid` (`ts`,`dbid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dbs_readerstatus_queries`
--

DROP TABLE IF EXISTS `dbs_readerstatus_queries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dbs_readerstatus_queries` (
  `rsqid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `text` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`rsqid`),
  KEY `text` (`text`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `discussion_kinds`
--

DROP TABLE IF EXISTS `discussion_kinds`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `discussion_kinds` (
  `dkid` tinyint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`dkid`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `discussions`
--

DROP TABLE IF EXISTS `discussions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `discussions` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `dkid` tinyint unsigned NOT NULL DEFAULT '1',
  `stoid` mediumint unsigned NOT NULL DEFAULT '0',
  `sid` char(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `title` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `url` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `topic` int unsigned NOT NULL,
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `type` enum('open','recycle','archived') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'open',
  `uid` mediumint unsigned NOT NULL,
  `commentcount` smallint unsigned NOT NULL DEFAULT '0',
  `flags` enum('ok','delete','dirty') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'ok',
  `primaryskid` smallint unsigned DEFAULT NULL,
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `approved` tinyint unsigned NOT NULL DEFAULT '0',
  `commentstatus` enum('disabled','enabled','friends_only','friends_fof_only','no_foe','no_foe_eof','logged_in') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'enabled',
  `archivable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `legacy` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  PRIMARY KEY (`id`),
  KEY `stoid` (`stoid`),
  KEY `sid` (`sid`),
  KEY `topic` (`topic`),
  KEY `primaryskid` (`primaryskid`,`ts`),
  KEY `type` (`type`,`uid`,`ts`)
) ENGINE=InnoDB AUTO_INCREMENT=55882 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dst`
--

DROP TABLE IF EXISTS `dst`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dst` (
  `region` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `selectable` tinyint NOT NULL DEFAULT '0',
  `start_hour` tinyint NOT NULL,
  `start_wnum` tinyint NOT NULL,
  `start_wday` tinyint NOT NULL,
  `start_month` tinyint NOT NULL,
  `end_hour` tinyint NOT NULL,
  `end_wnum` tinyint NOT NULL,
  `end_wday` tinyint NOT NULL,
  `end_month` tinyint NOT NULL,
  PRIMARY KEY (`region`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dynamic_blocks`
--

DROP TABLE IF EXISTS `dynamic_blocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dynamic_blocks` (
  `type_id` tinyint unsigned NOT NULL DEFAULT '0',
  `type` enum('portal','admin','user') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'user',
  `private` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  PRIMARY KEY (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dynamic_user_blocks`
--

DROP TABLE IF EXISTS `dynamic_user_blocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dynamic_user_blocks` (
  `bid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `portal_id` mediumint unsigned NOT NULL DEFAULT '0',
  `type_id` tinyint unsigned NOT NULL DEFAULT '0',
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `title` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `url` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `name` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `description` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `block` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `seclev` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_update` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`bid`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `idx_uid_name` (`uid`,`name`),
  KEY `idx_typeid` (`type_id`),
  KEY `idx_portalid` (`portal_id`)
) ENGINE=InnoDB AUTO_INCREMENT=94553 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `file_queue`
--

DROP TABLE IF EXISTS `file_queue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `file_queue` (
  `fqid` int unsigned NOT NULL AUTO_INCREMENT,
  `stoid` mediumint unsigned DEFAULT NULL,
  `fhid` mediumint unsigned DEFAULT NULL,
  `file` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `action` enum('upload','thumbnails','sprite') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `blobid` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`fqid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose`
--

DROP TABLE IF EXISTS `firehose`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `globjid` int unsigned NOT NULL DEFAULT '0',
  `discussion` mediumint unsigned NOT NULL DEFAULT '0',
  `type` enum('submission','journal','bookmark','feed','story','vendor','misc','comment','discussion','project','tagname') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'submission',
  `createtime` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `popularity` float NOT NULL DEFAULT '0',
  `editorpop` float NOT NULL DEFAULT '0',
  `neediness` float NOT NULL DEFAULT '0',
  `activity` float NOT NULL DEFAULT '0',
  `accepted` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `rejected` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `public` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `attention_needed` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `is_spam` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `primaryskid` smallint DEFAULT '0',
  `tid` smallint DEFAULT '0',
  `srcid` int unsigned NOT NULL DEFAULT '0',
  `url_id` int unsigned NOT NULL DEFAULT '0',
  `toptags` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `email` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `emaildomain` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `name` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `dept` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `ipid` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `category` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `nexuslist` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `signoffs` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `stoid` mediumint unsigned DEFAULT '0',
  `body_length` mediumint unsigned NOT NULL DEFAULT '0',
  `word_count` mediumint unsigned NOT NULL DEFAULT '0',
  `srcname` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `thumb` mediumint unsigned DEFAULT NULL,
  `mediatype` enum('text','none','video','image','audio') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'none',
  `offmainpage` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `sprite` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `sprite_info` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `preview` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  PRIMARY KEY (`id`),
  UNIQUE KEY `globjid` (`globjid`),
  KEY `createtime` (`createtime`),
  KEY `popularity` (`popularity`),
  KEY `neediness` (`neediness`),
  KEY `url_id` (`url_id`),
  KEY `uid` (`uid`),
  KEY `last_update` (`last_update`),
  KEY `type_srcid` (`type`,`srcid`)
) ENGINE=InnoDB AUTO_INCREMENT=97 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_history`
--

DROP TABLE IF EXISTS `firehose_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_history` (
  `globjid` int unsigned NOT NULL DEFAULT '0',
  `secsin` int unsigned NOT NULL DEFAULT '0',
  `userpop` float NOT NULL DEFAULT '0',
  `editorpop` float NOT NULL DEFAULT '0',
  UNIQUE KEY `globjid_secsin` (`globjid`,`secsin`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_ogaspt`
--

DROP TABLE IF EXISTS `firehose_ogaspt`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_ogaspt` (
  `globjid` int unsigned NOT NULL DEFAULT '0',
  `pubtime` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`globjid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_section`
--

DROP TABLE IF EXISTS `firehose_section`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_section` (
  `fsid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `section_name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'unnamed',
  `section_filter` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `skid` smallint unsigned NOT NULL DEFAULT '0',
  `display` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `view_id` mediumint unsigned NOT NULL DEFAULT '0',
  `section_color` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `ordernum` tinyint DEFAULT '0',
  PRIMARY KEY (`fsid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_section_settings`
--

DROP TABLE IF EXISTS `firehose_section_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_section_settings` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `fsid` mediumint unsigned NOT NULL,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `section_name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'unnamed',
  `section_filter` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `display` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `view_id` mediumint unsigned NOT NULL DEFAULT '0',
  `section_color` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uid_fsid` (`uid`,`fsid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_setting_log`
--

DROP TABLE IF EXISTS `firehose_setting_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_setting_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_skin_volume`
--

DROP TABLE IF EXISTS `firehose_skin_volume`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_skin_volume` (
  `skid` smallint unsigned NOT NULL,
  `story_vol` mediumint unsigned NOT NULL DEFAULT '0',
  `other_vol` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`skid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_tab`
--

DROP TABLE IF EXISTS `firehose_tab`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_tab` (
  `tabid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `tabname` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'unnamed',
  `filter` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `orderby` enum('popularity','createtime','editorpop','activity') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'createtime',
  `orderdir` enum('ASC','DESC') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'DESC',
  `color` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `mode` enum('full','fulltitle') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'fulltitle',
  PRIMARY KEY (`tabid`),
  UNIQUE KEY `uid_tabname` (`uid`,`tabname`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_text`
--

DROP TABLE IF EXISTS `firehose_text`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_text` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(80) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `introtext` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `bodytext` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `media` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=97 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_topics_rendered`
--

DROP TABLE IF EXISTS `firehose_topics_rendered`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_topics_rendered` (
  `id` mediumint unsigned NOT NULL,
  `tid` smallint unsigned NOT NULL,
  UNIQUE KEY `id_tid` (`id`,`tid`),
  KEY `tid_id` (`tid`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_update_log`
--

DROP TABLE IF EXISTS `firehose_update_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_update_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `new_count` smallint unsigned NOT NULL DEFAULT '0',
  `update_count` smallint unsigned NOT NULL DEFAULT '0',
  `total_num` smallint unsigned NOT NULL DEFAULT '0',
  `more_num` smallint unsigned NOT NULL DEFAULT '0',
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `duration` float NOT NULL DEFAULT '0',
  `bytes` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_view`
--

DROP TABLE IF EXISTS `firehose_view`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_view` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `viewname` varchar(24) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'unnamed',
  `viewtitle` varchar(24) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'untitled',
  `useparentfilter` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `tab_display` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `options_edit` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `admin_maxitems` tinyint NOT NULL DEFAULT '-1',
  `maxitems` tinyint NOT NULL DEFAULT '-1',
  `seclev` mediumint unsigned NOT NULL DEFAULT '0',
  `filter` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `orderby` enum('popularity','createtime','editorpop','activity','neediness','') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'createtime',
  `orderdir` enum('ASC','DESC','') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'DESC',
  `color` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `duration` enum('7','-1','') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `mode` enum('full','fulltitle','mixed','') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `pause` enum('1','0','') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `searchbutton` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `datafilter` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `admin_unsigned` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `usermode` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `use_exclusions` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `editable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  `shortcut` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `short_url` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `link_icon` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `placeholder` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `addable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `removable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `firehose_view_settings`
--

DROP TABLE IF EXISTS `firehose_view_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firehose_view_settings` (
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `id` mediumint unsigned NOT NULL,
  `color` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `orderby` enum('popularity','createtime','editorpop','activity','neediness','') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'createtime',
  `orderdir` enum('ASC','DESC','') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'DESC',
  `mode` enum('full','fulltitle','mixed','') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `datafilter` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `admin_unsigned` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'no',
  `usermode` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  PRIMARY KEY (`uid`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `formkeys`
--

DROP TABLE IF EXISTS `formkeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `formkeys` (
  `formkey` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `formname` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `id` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `idcount` mediumint unsigned NOT NULL DEFAULT '0',
  `uid` mediumint unsigned NOT NULL,
  `ipid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` tinyint NOT NULL DEFAULT '0',
  `last_ts` int unsigned NOT NULL DEFAULT '0',
  `ts` int unsigned NOT NULL DEFAULT '0',
  `submit_ts` int unsigned NOT NULL DEFAULT '0',
  `content_length` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`formkey`),
  KEY `formname` (`formname`),
  KEY `uid` (`uid`),
  KEY `ipid` (`ipid`),
  KEY `subnetid` (`subnetid`),
  KEY `idcount` (`idcount`),
  KEY `ts` (`ts`),
  KEY `last_ts` (`ts`),
  KEY `submit_ts` (`submit_ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `globj_adminnotes`
--

DROP TABLE IF EXISTS `globj_adminnotes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `globj_adminnotes` (
  `globjid` int unsigned NOT NULL AUTO_INCREMENT,
  `adminnote` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`globjid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `globj_types`
--

DROP TABLE IF EXISTS `globj_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `globj_types` (
  `gtid` smallint unsigned NOT NULL AUTO_INCREMENT,
  `maintable` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`gtid`),
  UNIQUE KEY `maintable` (`maintable`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `globj_urls`
--

DROP TABLE IF EXISTS `globj_urls`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `globj_urls` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `globjid` int unsigned NOT NULL DEFAULT '0',
  `url_id` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `globjid_url_id` (`globjid`,`url_id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `globjs`
--

DROP TABLE IF EXISTS `globjs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `globjs` (
  `globjid` int unsigned NOT NULL AUTO_INCREMENT,
  `gtid` smallint unsigned NOT NULL,
  `target_id` int unsigned NOT NULL,
  PRIMARY KEY (`globjid`),
  UNIQUE KEY `target` (`gtid`,`target_id`)
) ENGINE=InnoDB AUTO_INCREMENT=132 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `globjs_viewed`
--

DROP TABLE IF EXISTS `globjs_viewed`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `globjs_viewed` (
  `gvid` int unsigned NOT NULL AUTO_INCREMENT,
  `globjid` int unsigned NOT NULL,
  `uid` mediumint unsigned NOT NULL,
  `viewed_at` datetime NOT NULL,
  PRIMARY KEY (`gvid`),
  UNIQUE KEY `globjid_uid` (`globjid`,`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `globjs_viewed_archived`
--

DROP TABLE IF EXISTS `globjs_viewed_archived`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `globjs_viewed_archived` (
  `gvid` int unsigned NOT NULL,
  `globjid` int unsigned NOT NULL,
  `uid` mediumint unsigned NOT NULL,
  `viewed_at` datetime NOT NULL,
  PRIMARY KEY (`gvid`),
  UNIQUE KEY `globjid_uid` (`globjid`,`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hooks`
--

DROP TABLE IF EXISTS `hooks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hooks` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `param` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `class` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subroutine` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `hook_param` (`param`,`class`,`subroutine`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `humanconf`
--

DROP TABLE IF EXISTS `humanconf`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `humanconf` (
  `hcid` int unsigned NOT NULL AUTO_INCREMENT,
  `hcpid` int unsigned NOT NULL,
  `formkey` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `tries_left` smallint unsigned NOT NULL DEFAULT '3',
  PRIMARY KEY (`hcid`),
  UNIQUE KEY `formkey` (`formkey`),
  KEY `hcpid` (`hcpid`)
) ENGINE=InnoDB AUTO_INCREMENT=76 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `humanconf_pool`
--

DROP TABLE IF EXISTS `humanconf_pool`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `humanconf_pool` (
  `hcpid` int unsigned NOT NULL AUTO_INCREMENT,
  `hcqid` smallint unsigned NOT NULL,
  `answer` char(8) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `lastused` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL,
  `inuse` tinyint NOT NULL DEFAULT '0',
  `filename_img` varchar(63) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `filename_mp3` varchar(63) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `html` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`hcpid`),
  KEY `answer` (`answer`),
  KEY `lastused` (`lastused`)
) ENGINE=InnoDB AUTO_INCREMENT=8001 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `humanconf_questions`
--

DROP TABLE IF EXISTS `humanconf_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `humanconf_questions` (
  `hcqid` smallint unsigned NOT NULL AUTO_INCREMENT,
  `filedir` char(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `urlprefix` char(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `question` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`hcqid`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `journal_themes`
--

DROP TABLE IF EXISTS `journal_themes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `journal_themes` (
  `id` tinyint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `journal_transfer`
--

DROP TABLE IF EXISTS `journal_transfer`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `journal_transfer` (
  `id` mediumint unsigned NOT NULL,
  `subid` mediumint unsigned NOT NULL DEFAULT '0',
  `stoid` mediumint unsigned NOT NULL DEFAULT '0',
  `updated` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `stoid_updated` (`stoid`,`updated`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `journals`
--

DROP TABLE IF EXISTS `journals`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `journals` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL,
  `date` datetime NOT NULL,
  `description` varchar(80) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `posttype` tinyint NOT NULL DEFAULT '2',
  `discussion` mediumint unsigned DEFAULT NULL,
  `tid` smallint unsigned NOT NULL,
  `promotetype` enum('publicize','publish','post') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'publish',
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `srcid_32` bigint unsigned NOT NULL DEFAULT '0',
  `srcid_24` bigint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `uid_date_id` (`uid`,`date`,`id`),
  KEY `IDandUID` (`id`,`uid`),
  KEY `tid` (`tid`),
  KEY `srcid_32` (`srcid_32`),
  KEY `srcid_24` (`srcid_24`)
) ENGINE=InnoDB AUTO_INCREMENT=14766 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `journals_text`
--

DROP TABLE IF EXISTS `journals_text`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `journals_text` (
  `id` mediumint unsigned NOT NULL,
  `article` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `introtext` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `menus`
--

DROP TABLE IF EXISTS `menus`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `menus` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `menu` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `label` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `sel_label` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `seclev` mediumint unsigned NOT NULL,
  `showanon` tinyint NOT NULL DEFAULT '0',
  `menuorder` mediumint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `page_labels_un` (`menu`,`label`),
  KEY `page_labels` (`menu`,`label`)
) ENGINE=InnoDB AUTO_INCREMENT=50 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_codes`
--

DROP TABLE IF EXISTS `message_codes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_codes` (
  `code` int NOT NULL,
  `type` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `seclev` int NOT NULL DEFAULT '1',
  `modes` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `send` enum('now','defer','collective') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'now',
  `subscribe` tinyint(1) NOT NULL DEFAULT '0',
  `acl` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `delivery_bvalue` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_deliverymodes`
--

DROP TABLE IF EXISTS `message_deliverymodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_deliverymodes` (
  `code` smallint NOT NULL DEFAULT '0',
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `bitvalue` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_drop`
--

DROP TABLE IF EXISTS `message_drop`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_drop` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user` mediumint unsigned NOT NULL,
  `fuser` mediumint unsigned NOT NULL,
  `code` int NOT NULL DEFAULT '-1',
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `altto` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `send` enum('now','defer','collective') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'now',
  `message` mediumblob NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1234105 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_log`
--

DROP TABLE IF EXISTS `message_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_log` (
  `id` int NOT NULL,
  `user` mediumint unsigned NOT NULL,
  `fuser` mediumint unsigned NOT NULL,
  `code` int NOT NULL DEFAULT '-1',
  `mode` int NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_web`
--

DROP TABLE IF EXISTS `message_web`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_web` (
  `id` int NOT NULL,
  `user` mediumint unsigned NOT NULL,
  `fuser` mediumint unsigned NOT NULL,
  `code` int NOT NULL DEFAULT '-1',
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `readed` tinyint(1) NOT NULL DEFAULT '0',
  `date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`id`),
  KEY `fuser` (`fuser`),
  KEY `user` (`user`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_web_text`
--

DROP TABLE IF EXISTS `message_web_text`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_web_text` (
  `id` int NOT NULL,
  `subject` blob NOT NULL,
  `message` blob NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `misc_user_opts`
--

DROP TABLE IF EXISTS `misc_user_opts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `misc_user_opts` (
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `optorder` mediumint DEFAULT NULL,
  `seclev` mediumint unsigned NOT NULL,
  `default_val` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `vals_regex` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `short_desc` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `long_desc` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `opts_html` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `moderatorlog`
--

DROP TABLE IF EXISTS `moderatorlog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `moderatorlog` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `ipid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `uid` mediumint unsigned NOT NULL,
  `val` tinyint NOT NULL DEFAULT '0',
  `sid` mediumint unsigned NOT NULL DEFAULT '0',
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `cid` int unsigned NOT NULL,
  `cuid` mediumint unsigned NOT NULL,
  `reason` tinyint unsigned DEFAULT '0',
  `active` tinyint NOT NULL DEFAULT '1',
  `spent` tinyint NOT NULL DEFAULT '1',
  `points_orig` tinyint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `sid` (`sid`,`cid`),
  KEY `sid_2` (`sid`,`uid`,`cid`),
  KEY `cid` (`cid`),
  KEY `ipid` (`ipid`),
  KEY `subnetid` (`subnetid`),
  KEY `uid` (`uid`),
  KEY `cuid` (`cuid`),
  KEY `ts_uid_sid` (`ts`,`uid`,`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=933720 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `modreasons`
--

DROP TABLE IF EXISTS `modreasons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `modreasons` (
  `id` tinyint unsigned NOT NULL,
  `name` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `m2able` tinyint NOT NULL DEFAULT '1',
  `listable` tinyint NOT NULL DEFAULT '1',
  `val` tinyint NOT NULL DEFAULT '0',
  `karma` tinyint NOT NULL DEFAULT '0',
  `fairfrac` float NOT NULL DEFAULT '0.5',
  `unfairname` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `ordered` tinyint unsigned NOT NULL DEFAULT '50',
  `needs_prior_mod` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `open_proxies`
--

DROP TABLE IF EXISTS `open_proxies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `open_proxies` (
  `ip` varchar(15) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `port` smallint unsigned NOT NULL DEFAULT '0',
  `dur` float DEFAULT NULL,
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `xff` varchar(40) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `ipid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`ip`),
  KEY `ts` (`ts`),
  KEY `ipid` (`ipid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pagemark`
--

DROP TABLE IF EXISTS `pagemark`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pagemark` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `pagemark` bigint unsigned NOT NULL DEFAULT '0',
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `dom` float NOT NULL DEFAULT '0',
  `js` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `pagemark` (`pagemark`),
  KEY `ts` (`ts`)
) ENGINE=InnoDB AUTO_INCREMENT=30158 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `paypal_log`
--

DROP TABLE IF EXISTS `paypal_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `paypal_log` (
  `logid` bigint unsigned NOT NULL AUTO_INCREMENT,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `uid` mediumint unsigned DEFAULT NULL,
  `transaction_id` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `parent_transaction_id` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `transaction_type` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `email` varchar(450) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `name` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `payment_gross` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `payment_status` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `raw_transaction` text CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `remote_address` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`logid`)
) ENGINE=InnoDB AUTO_INCREMENT=2041 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `people`
--

DROP TABLE IF EXISTS `people`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `people` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL,
  `person` mediumint unsigned NOT NULL,
  `type` enum('friend','foe') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `perceive` enum('fan','freak') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `fof` mediumint unsigned NOT NULL DEFAULT '0',
  `eof` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `degree_of_separation` (`uid`,`person`),
  KEY `person` (`person`)
) ENGINE=InnoDB AUTO_INCREMENT=8283 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pollanswers`
--

DROP TABLE IF EXISTS `pollanswers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pollanswers` (
  `qid` mediumint unsigned NOT NULL,
  `aid` mediumint NOT NULL,
  `answer` char(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `votes` mediumint DEFAULT NULL,
  PRIMARY KEY (`qid`,`aid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pollquestions`
--

DROP TABLE IF EXISTS `pollquestions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pollquestions` (
  `qid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `question` char(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `voters` mediumint DEFAULT NULL,
  `topic` smallint unsigned NOT NULL,
  `discussion` mediumint unsigned DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  `uid` mediumint unsigned NOT NULL,
  `primaryskid` smallint unsigned DEFAULT NULL,
  `autopoll` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `flags` enum('ok','delete','dirty') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'ok',
  `polltype` enum('nodisplay','section','story') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'section',
  PRIMARY KEY (`qid`),
  KEY `uid` (`uid`),
  KEY `discussion` (`discussion`)
) ENGINE=InnoDB AUTO_INCREMENT=164 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pollvoters`
--

DROP TABLE IF EXISTS `pollvoters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pollvoters` (
  `qid` mediumint NOT NULL,
  `id` char(35) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `time` datetime DEFAULT NULL,
  `uid` mediumint unsigned NOT NULL,
  KEY `qid` (`qid`,`id`,`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `preview`
--

DROP TABLE IF EXISTS `preview`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `preview` (
  `preview_id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL,
  `src_fhid` mediumint unsigned NOT NULL DEFAULT '0',
  `preview_fhid` mediumint unsigned NOT NULL DEFAULT '0',
  `title` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `introtext` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `bodytext` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `active` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'yes',
  PRIMARY KEY (`preview_id`),
  KEY `uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `preview_param`
--

DROP TABLE IF EXISTS `preview_param`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `preview_param` (
  `param_id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `preview_id` mediumint unsigned NOT NULL,
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`param_id`),
  UNIQUE KEY `submission_key` (`preview_id`,`name`)
) ENGINE=InnoDB AUTO_INCREMENT=47 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `projects`
--

DROP TABLE IF EXISTS `projects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `projects` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `unixname` varchar(24) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `textname` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `url_id` int unsigned NOT NULL DEFAULT '0',
  `createtime` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `srcname` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '0',
  `description` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unixname` (`unixname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `querylog`
--

DROP TABLE IF EXISTS `querylog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `querylog` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `type` enum('SELECT','INSERT','UPDATE','DELETE','REPLACE') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'SELECT',
  `thetables` varchar(40) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `package` varchar(24) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `line` mediumint unsigned NOT NULL DEFAULT '0',
  `package1` varchar(24) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `line1` mediumint unsigned NOT NULL DEFAULT '0',
  `duration` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `caller` (`package`,`line`),
  KEY `ts` (`ts`),
  KEY `type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `related_links`
--

DROP TABLE IF EXISTS `related_links`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `related_links` (
  `id` smallint unsigned NOT NULL AUTO_INCREMENT,
  `keyword` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `name` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `link` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `keyword` (`keyword`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `related_stories`
--

DROP TABLE IF EXISTS `related_stories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `related_stories` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `stoid` mediumint unsigned DEFAULT '0',
  `rel_stoid` mediumint unsigned DEFAULT '0',
  `rel_sid` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `title` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `url` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `cid` int unsigned NOT NULL DEFAULT '0',
  `ordernum` smallint unsigned NOT NULL DEFAULT '0',
  `fhid` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `stoid` (`stoid`)
) ENGINE=InnoDB AUTO_INCREMENT=81587 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `remarks`
--

DROP TABLE IF EXISTS `remarks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `remarks` (
  `rid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL,
  `stoid` mediumint unsigned NOT NULL,
  `priority` smallint unsigned NOT NULL DEFAULT '0',
  `time` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `type` enum('system','user') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'user',
  `remark` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`rid`),
  KEY `uid` (`uid`),
  KEY `stoid` (`stoid`),
  KEY `time` (`time`),
  KEY `priority` (`priority`)
) ENGINE=InnoDB AUTO_INCREMENT=42518 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reskey_failures`
--

DROP TABLE IF EXISTS `reskey_failures`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reskey_failures` (
  `rkid` int NOT NULL,
  `failure` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`rkid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reskey_hourlysalt`
--

DROP TABLE IF EXISTS `reskey_hourlysalt`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reskey_hourlysalt` (
  `ts` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `salt` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  UNIQUE KEY `ts` (`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reskey_resource_checks`
--

DROP TABLE IF EXISTS `reskey_resource_checks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reskey_resource_checks` (
  `rkrcid` smallint unsigned NOT NULL AUTO_INCREMENT,
  `rkrid` smallint unsigned NOT NULL,
  `type` enum('create','touch','use','all') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `class` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `ordernum` smallint unsigned DEFAULT '0',
  PRIMARY KEY (`rkrcid`),
  UNIQUE KEY `rkrid_name` (`rkrid`,`type`,`class`)
) ENGINE=InnoDB AUTO_INCREMENT=151 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reskey_resources`
--

DROP TABLE IF EXISTS `reskey_resources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reskey_resources` (
  `rkrid` smallint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `static` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  PRIMARY KEY (`rkrid`)
) ENGINE=InnoDB AUTO_INCREMENT=201 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reskey_sessions`
--

DROP TABLE IF EXISTS `reskey_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reskey_sessions` (
  `sessid` int unsigned NOT NULL AUTO_INCREMENT,
  `reskey` char(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `name` varchar(48) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  PRIMARY KEY (`sessid`),
  UNIQUE KEY `reskey_name` (`reskey`,`name`),
  KEY `reskey` (`reskey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reskey_vars`
--

DROP TABLE IF EXISTS `reskey_vars`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reskey_vars` (
  `rkrid` smallint unsigned NOT NULL,
  `name` varchar(48) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `description` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  UNIQUE KEY `name_rkrid` (`name`,`rkrid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reskeys`
--

DROP TABLE IF EXISTS `reskeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reskeys` (
  `rkid` int NOT NULL AUTO_INCREMENT,
  `reskey` char(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `rkrid` smallint unsigned NOT NULL,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `srcid_ip` bigint unsigned NOT NULL DEFAULT '0',
  `failures` tinyint NOT NULL DEFAULT '0',
  `touches` tinyint NOT NULL DEFAULT '0',
  `is_alive` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `create_ts` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_ts` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `submit_ts` datetime DEFAULT NULL,
  PRIMARY KEY (`rkid`),
  UNIQUE KEY `reskey` (`reskey`),
  KEY `rkrid` (`rkrid`),
  KEY `uid` (`uid`),
  KEY `srcid_ip` (`srcid_ip`),
  KEY `create_ts` (`create_ts`),
  KEY `last_ts` (`last_ts`),
  KEY `submit_ts` (`submit_ts`)
) ENGINE=InnoDB AUTO_INCREMENT=18547001 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rss_raw`
--

DROP TABLE IF EXISTS `rss_raw`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `rss_raw` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `link_signature` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `title_signature` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `description_signature` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `link` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `title` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `description` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `subid` mediumint unsigned DEFAULT NULL,
  `bid` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `processed` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uber_signature` (`link_signature`,`title_signature`,`description_signature`),
  KEY `processed` (`processed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sessions` (
  `session` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned DEFAULT NULL,
  `lasttime` datetime DEFAULT NULL,
  `lasttitle` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `last_subid` mediumint unsigned DEFAULT NULL,
  `last_sid` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `last_fhid` mediumint unsigned DEFAULT NULL,
  `last_action` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`session`),
  UNIQUE KEY `uid` (`uid`)
) ENGINE=InnoDB AUTO_INCREMENT=3966843 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `shill_ids`
--

DROP TABLE IF EXISTS `shill_ids`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `shill_ids` (
  `shill_id` tinyint unsigned NOT NULL DEFAULT '0',
  `user` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`shill_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `signoff`
--

DROP TABLE IF EXISTS `signoff`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `signoff` (
  `soid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `stoid` mediumint unsigned NOT NULL DEFAULT '0',
  `uid` mediumint unsigned NOT NULL,
  `signoff_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `signoff_type` varchar(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`soid`),
  KEY `stoid` (`stoid`)
) ENGINE=InnoDB AUTO_INCREMENT=96867 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `site_info`
--

DROP TABLE IF EXISTS `site_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `site_info` (
  `param_id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `value` varchar(200) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `description` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`param_id`),
  UNIQUE KEY `site_keys` (`name`,`value`)
) ENGINE=InnoDB AUTO_INCREMENT=92 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `skin_colors`
--

DROP TABLE IF EXISTS `skin_colors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `skin_colors` (
  `skid` smallint unsigned NOT NULL,
  `name` varchar(24) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `skincolor` char(12) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  UNIQUE KEY `skid_name` (`skid`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `skins`
--

DROP TABLE IF EXISTS `skins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `skins` (
  `skid` smallint unsigned NOT NULL AUTO_INCREMENT,
  `nexus` int unsigned NOT NULL,
  `artcount_min` mediumint unsigned NOT NULL DEFAULT '10',
  `artcount_max` mediumint unsigned NOT NULL DEFAULT '30',
  `older_stories_max` mediumint unsigned NOT NULL DEFAULT '0',
  `name` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `othername` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `title` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `issue` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `submittable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `searchable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `storypickable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `skinindex` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `url` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `hostname` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `cookiedomain` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `index_handler` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'index.pl',
  `max_rewrite_secs` mediumint unsigned NOT NULL DEFAULT '3600',
  `last_rewrite` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `ac_uid` mediumint unsigned NOT NULL DEFAULT '0',
  `require_acl` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `theme` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  PRIMARY KEY (`skid`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `slashd_errnotes`
--

DROP TABLE IF EXISTS `slashd_errnotes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `slashd_errnotes` (
  `ts` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `taskname` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'SLASHD',
  `line` mediumint unsigned NOT NULL DEFAULT '0',
  `errnote` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `moreinfo` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  KEY `ts` (`ts`),
  KEY `taskname_ts` (`taskname`,`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `slashd_status`
--

DROP TABLE IF EXISTS `slashd_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `slashd_status` (
  `task` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `hostname` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `next_begin` datetime DEFAULT NULL,
  `in_progress` tinyint NOT NULL DEFAULT '0',
  `last_completed` datetime DEFAULT NULL,
  `summary` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `duration` float(10,2) DEFAULT NULL,
  PRIMARY KEY (`task`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `soap_methods`
--

DROP TABLE IF EXISTS `soap_methods`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `soap_methods` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `class` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `method` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `seclev` mediumint NOT NULL DEFAULT '1000',
  `subscriber_only` tinyint NOT NULL DEFAULT '0',
  `formkeys` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `soap_method` (`class`,`method`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `spamarmors`
--

DROP TABLE IF EXISTS `spamarmors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `spamarmors` (
  `armor_id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(40) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `code` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `active` mediumint DEFAULT '1',
  PRIMARY KEY (`armor_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sphinx_counter`
--

DROP TABLE IF EXISTS `sphinx_counter`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sphinx_counter` (
  `src` smallint unsigned NOT NULL,
  `completion` int unsigned DEFAULT NULL,
  `last_seen` datetime NOT NULL,
  `started` datetime NOT NULL,
  `elapsed` int unsigned DEFAULT NULL,
  UNIQUE KEY `src_completion` (`src`,`completion`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sphinx_counter_archived`
--

DROP TABLE IF EXISTS `sphinx_counter_archived`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sphinx_counter_archived` (
  `src` smallint unsigned NOT NULL,
  `completion` int unsigned NOT NULL,
  `last_seen` datetime NOT NULL,
  `started` datetime NOT NULL,
  `elapsed` int unsigned DEFAULT NULL,
  UNIQUE KEY `src_completion` (`src`,`completion`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sphinx_index`
--

DROP TABLE IF EXISTS `sphinx_index`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sphinx_index` (
  `src` smallint unsigned NOT NULL,
  `name` varchar(48) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `asynch` tinyint unsigned NOT NULL DEFAULT '1',
  `laststart` datetime NOT NULL DEFAULT '2000-01-01 00:00:00',
  `frequency` int unsigned NOT NULL DEFAULT '86400',
  PRIMARY KEY (`src`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sphinx_search`
--

DROP TABLE IF EXISTS `sphinx_search`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sphinx_search` (
  `globjid` int NOT NULL,
  `weight` int NOT NULL,
  `query` varchar(3072) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `_sph_count` int NOT NULL,
  KEY `query` (`query`(1024))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `static_files`
--

DROP TABLE IF EXISTS `static_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `static_files` (
  `sfid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `stoid` mediumint unsigned NOT NULL,
  `fhid` mediumint unsigned NOT NULL,
  `filetype` enum('file','image','audio') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'file',
  `name` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `width` smallint unsigned NOT NULL DEFAULT '0',
  `height` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`sfid`),
  KEY `stoid` (`stoid`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stats_daily`
--

DROP TABLE IF EXISTS `stats_daily`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stats_daily` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `skid` smallint unsigned NOT NULL DEFAULT '0',
  `day` date NOT NULL,
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `day_key_pair` (`day`,`name`,`skid`),
  UNIQUE KEY `skid_day_name` (`skid`,`day`,`name`),
  KEY `name_day` (`name`,`day`)
) ENGINE=InnoDB AUTO_INCREMENT=11181335 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stats_graphs_index`
--

DROP TABLE IF EXISTS `stats_graphs_index`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stats_graphs_index` (
  `day` date NOT NULL,
  `md5` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `id` blob
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stories`
--

DROP TABLE IF EXISTS `stories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stories` (
  `stoid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `sid` char(16) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `uid` mediumint unsigned NOT NULL,
  `dept` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `time` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `hits` mediumint unsigned NOT NULL DEFAULT '0',
  `discussion` mediumint unsigned DEFAULT NULL,
  `primaryskid` smallint unsigned DEFAULT NULL,
  `tid` int unsigned DEFAULT NULL,
  `submitter` mediumint unsigned NOT NULL,
  `commentcount` smallint unsigned NOT NULL DEFAULT '0',
  `hitparade` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '0,0,0,0,0,0,0',
  `is_archived` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `in_trash` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `day_published` date NOT NULL DEFAULT '1970-01-01',
  `qid` mediumint unsigned DEFAULT NULL,
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `body_length` mediumint unsigned NOT NULL DEFAULT '0',
  `word_count` mediumint unsigned NOT NULL DEFAULT '0',
  `archive_last_update` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `notes` text COLLATE utf8mb3_unicode_ci,
  PRIMARY KEY (`stoid`),
  UNIQUE KEY `sid` (`sid`),
  KEY `uid` (`uid`),
  KEY `is_archived` (`is_archived`),
  KEY `time` (`time`),
  KEY `submitter` (`submitter`),
  KEY `day_published` (`day_published`),
  KEY `skidtid` (`primaryskid`,`tid`),
  KEY `discussion_stoid` (`discussion`,`stoid`),
  KEY `slowass` (`in_trash`,`time`)
) ENGINE=InnoDB AUTO_INCREMENT=8108516 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `story_dirty`
--

DROP TABLE IF EXISTS `story_dirty`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `story_dirty` (
  `stoid` mediumint unsigned NOT NULL,
  PRIMARY KEY (`stoid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `story_files`
--

DROP TABLE IF EXISTS `story_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `story_files` (
  `id` int NOT NULL AUTO_INCREMENT,
  `stoid` mediumint unsigned NOT NULL DEFAULT '0',
  `description` varchar(80) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `file_id` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `isimage` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  PRIMARY KEY (`id`),
  KEY `stoid` (`stoid`),
  KEY `file_id` (`file_id`)
) ENGINE=InnoDB AUTO_INCREMENT=157 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `story_param`
--

DROP TABLE IF EXISTS `story_param`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `story_param` (
  `param_id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `stoid` mediumint unsigned NOT NULL,
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`param_id`),
  UNIQUE KEY `story_key` (`stoid`,`name`)
) ENGINE=InnoDB AUTO_INCREMENT=206230 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `story_render_dirty`
--

DROP TABLE IF EXISTS `story_render_dirty`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `story_render_dirty` (
  `stoid` mediumint unsigned NOT NULL,
  PRIMARY KEY (`stoid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `story_text`
--

DROP TABLE IF EXISTS `story_text`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `story_text` (
  `stoid` mediumint unsigned NOT NULL,
  `title` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `introtext` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `bodytext` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `relatedtext` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `rendered` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  PRIMARY KEY (`stoid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `story_topics_chosen`
--

DROP TABLE IF EXISTS `story_topics_chosen`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `story_topics_chosen` (
  `stoid` mediumint unsigned NOT NULL,
  `tid` int unsigned NOT NULL,
  `weight` float NOT NULL DEFAULT '1',
  UNIQUE KEY `story_topic` (`stoid`,`tid`),
  KEY `tid_stoid` (`tid`,`stoid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `story_topics_rendered`
--

DROP TABLE IF EXISTS `story_topics_rendered`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `story_topics_rendered` (
  `stoid` mediumint unsigned NOT NULL,
  `tid` int unsigned NOT NULL,
  UNIQUE KEY `story_topic` (`stoid`,`tid`),
  KEY `tid_stoid` (`tid`,`stoid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `string_param`
--

DROP TABLE IF EXISTS `string_param`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `string_param` (
  `param_id` smallint unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `code` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `name` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`param_id`),
  UNIQUE KEY `code_key` (`type`,`code`)
) ENGINE=InnoDB AUTO_INCREMENT=331 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stripe_log`
--

DROP TABLE IF EXISTS `stripe_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stripe_log` (
  `logid` bigint unsigned NOT NULL AUTO_INCREMENT,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `event_id` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `remote_address` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `raw_transaction` text CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`logid`)
) ENGINE=InnoDB AUTO_INCREMENT=518 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `submission_param`
--

DROP TABLE IF EXISTS `submission_param`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `submission_param` (
  `param_id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `subid` mediumint unsigned NOT NULL,
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`param_id`),
  UNIQUE KEY `submission_key` (`subid`,`name`)
) ENGINE=InnoDB AUTO_INCREMENT=83134 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `submissions`
--

DROP TABLE IF EXISTS `submissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `submissions` (
  `subid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `email` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `emaildomain` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `name` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `time` datetime NOT NULL,
  `subj` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `story` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `tid` int unsigned NOT NULL,
  `note` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT '',
  `primaryskid` smallint unsigned DEFAULT NULL,
  `comment` text COLLATE utf8mb3_unicode_ci,
  `uid` mediumint unsigned NOT NULL,
  `ipid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnetid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `del` tinyint NOT NULL DEFAULT '0',
  `weight` float NOT NULL DEFAULT '0',
  `signature` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `mediatype` enum('text','none','video','image','audio') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'none',
  `dept` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`subid`),
  UNIQUE KEY `signature` (`signature`),
  KEY `emaildomain` (`emaildomain`),
  KEY `del` (`del`),
  KEY `uid` (`uid`),
  KEY `ipid` (`ipid`),
  KEY `subnetid` (`subnetid`),
  KEY `primaryskid_tid` (`primaryskid`,`tid`),
  KEY `tid` (`tid`),
  KEY `time_emaildomain` (`time`,`emaildomain`)
) ENGINE=InnoDB AUTO_INCREMENT=59897 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `submissions_notes`
--

DROP TABLE IF EXISTS `submissions_notes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `submissions_notes` (
  `noid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `submatch` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `subnote` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `time` datetime DEFAULT NULL,
  PRIMARY KEY (`noid`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscribe_payments`
--

DROP TABLE IF EXISTS `subscribe_payments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subscribe_payments` (
  `spid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL,
  `email` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `payment_gross` decimal(10,2) NOT NULL,
  `payment_net` decimal(10,2) NOT NULL,
  `pages` mediumint unsigned DEFAULT NULL,
  `transaction_id` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `method` varchar(6) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `submethod` varchar(3) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `memo` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `data` blob,
  `payment_type` varchar(10) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `puid` mediumint unsigned DEFAULT NULL,
  `raw_transaction` text CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `days` mediumint unsigned DEFAULT NULL,
  PRIMARY KEY (`spid`),
  UNIQUE KEY `transaction_id` (`transaction_id`),
  KEY `uid` (`uid`),
  KEY `ts` (`ts`),
  KEY `puid` (`puid`)
) ENGINE=InnoDB AUTO_INCREMENT=1923 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tag_params`
--

DROP TABLE IF EXISTS `tag_params`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tag_params` (
  `tagid` int unsigned NOT NULL,
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  UNIQUE KEY `tag_name` (`tagid`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tagboxes`
--

DROP TABLE IF EXISTS `tagboxes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tagboxes` (
  `tbid` smallint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `weight` float unsigned NOT NULL DEFAULT '1',
  `last_run_completed` datetime DEFAULT NULL,
  `last_tagid_logged` int unsigned NOT NULL,
  `last_tdid_logged` int unsigned NOT NULL,
  `last_tuid_logged` int unsigned NOT NULL,
  PRIMARY KEY (`tbid`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tagboxlog_feeder`
--

DROP TABLE IF EXISTS `tagboxlog_feeder`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tagboxlog_feeder` (
  `tfid` int unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime NOT NULL,
  `tbid` smallint unsigned NOT NULL,
  `affected_id` int unsigned NOT NULL,
  `importance` float unsigned NOT NULL DEFAULT '1',
  `claimed` datetime DEFAULT NULL,
  `tagid` int unsigned DEFAULT NULL,
  `tdid` int unsigned DEFAULT NULL,
  `tuid` int unsigned DEFAULT NULL,
  PRIMARY KEY (`tfid`),
  KEY `tbid_tagid` (`tbid`,`tagid`),
  KEY `tbid_tdid` (`tbid`,`tdid`),
  KEY `tbid_tuid` (`tbid`,`tuid`),
  KEY `tbid_affectedid` (`tbid`,`affected_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tagcommand_adminlog`
--

DROP TABLE IF EXISTS `tagcommand_adminlog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tagcommand_adminlog` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `cmdtype` varchar(6) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `tagnameid` int unsigned NOT NULL,
  `globjid` int unsigned DEFAULT NULL,
  `adminuid` mediumint unsigned NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `created_at` (`created_at`),
  KEY `tagnameid_globjid` (`tagnameid`,`globjid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tagcommand_adminlog_sfnet`
--

DROP TABLE IF EXISTS `tagcommand_adminlog_sfnet`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tagcommand_adminlog_sfnet` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `cmdtype` varchar(6) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `tagnameid` int unsigned NOT NULL,
  `globjid` int unsigned DEFAULT NULL,
  `sfnetadminuid` mediumint unsigned NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `created_at` (`created_at`),
  KEY `tagnameid_globjid` (`tagnameid`,`globjid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tagname_cache`
--

DROP TABLE IF EXISTS `tagname_cache`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tagname_cache` (
  `tagnameid` int unsigned NOT NULL,
  `tagname` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `weight` float unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`tagnameid`),
  UNIQUE KEY `tagname` (`tagname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tagname_params`
--

DROP TABLE IF EXISTS `tagname_params`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tagname_params` (
  `tagnameid` int unsigned NOT NULL,
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  UNIQUE KEY `tagname_name` (`tagnameid`,`name`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tagnames`
--

DROP TABLE IF EXISTS `tagnames`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tagnames` (
  `tagnameid` int unsigned NOT NULL AUTO_INCREMENT,
  `tagname` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`tagnameid`),
  UNIQUE KEY `tagname` (`tagname`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tagnames_similarity_rendered`
--

DROP TABLE IF EXISTS `tagnames_similarity_rendered`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tagnames_similarity_rendered` (
  `clid` smallint unsigned NOT NULL DEFAULT '0',
  `syn_tnid` int unsigned NOT NULL DEFAULT '0',
  `similarity` enum('1','-1') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '1',
  `pref_tnid` int unsigned NOT NULL DEFAULT '0',
  UNIQUE KEY `clid_syn_sim` (`clid`,`syn_tnid`,`similarity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tagnames_synonyms_chosen`
--

DROP TABLE IF EXISTS `tagnames_synonyms_chosen`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tagnames_synonyms_chosen` (
  `clid` smallint unsigned NOT NULL DEFAULT '0',
  `pref_tnid` int unsigned NOT NULL DEFAULT '0',
  `syn_tnid` int unsigned NOT NULL DEFAULT '0',
  UNIQUE KEY `clid_pref_syn` (`clid`,`pref_tnid`,`syn_tnid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tags`
--

DROP TABLE IF EXISTS `tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags` (
  `tagid` int unsigned NOT NULL AUTO_INCREMENT,
  `tagnameid` int unsigned NOT NULL,
  `globjid` int unsigned NOT NULL,
  `uid` mediumint unsigned NOT NULL,
  `created_at` datetime NOT NULL,
  `inactivated` datetime DEFAULT NULL,
  `private` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  PRIMARY KEY (`tagid`),
  KEY `tagnameid` (`tagnameid`),
  KEY `globjid_tagnameid` (`globjid`,`tagnameid`),
  KEY `uid_globjid_tagnameid_inactivated` (`uid`,`globjid`,`tagnameid`,`inactivated`),
  KEY `uid_tagnameid_globjid_inactivated` (`uid`,`tagnameid`,`globjid`,`inactivated`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=101 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tags_dayofweek`
--

DROP TABLE IF EXISTS `tags_dayofweek`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags_dayofweek` (
  `day` tinyint unsigned NOT NULL DEFAULT '0',
  `proportion` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tags_deactivated`
--

DROP TABLE IF EXISTS `tags_deactivated`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags_deactivated` (
  `tdid` int unsigned NOT NULL AUTO_INCREMENT,
  `tagid` int unsigned NOT NULL,
  PRIMARY KEY (`tdid`),
  KEY `tagid` (`tagid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tags_hourofday`
--

DROP TABLE IF EXISTS `tags_hourofday`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags_hourofday` (
  `hour` tinyint unsigned NOT NULL DEFAULT '0',
  `proportion` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`hour`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tags_peerweight`
--

DROP TABLE IF EXISTS `tags_peerweight`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags_peerweight` (
  `tpwid` int unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `clid` smallint unsigned NOT NULL,
  `gen` smallint unsigned NOT NULL DEFAULT '0',
  `weight` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`tpwid`),
  UNIQUE KEY `uid_clid` (`uid`,`clid`),
  KEY `clid_gen_uid` (`clid`,`gen`,`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tags_searched`
--

DROP TABLE IF EXISTS `tags_searched`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags_searched` (
  `tseid` int unsigned NOT NULL AUTO_INCREMENT,
  `tagnameid` int unsigned NOT NULL,
  `searched_at` datetime NOT NULL,
  `uid` mediumint unsigned DEFAULT NULL,
  PRIMARY KEY (`tseid`),
  KEY `tagnameid` (`tagnameid`),
  KEY `searched_at` (`searched_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tags_udc`
--

DROP TABLE IF EXISTS `tags_udc`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags_udc` (
  `hourtime` datetime NOT NULL,
  `udc` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`hourtime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tags_userchange`
--

DROP TABLE IF EXISTS `tags_userchange`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags_userchange` (
  `tuid` int unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime NOT NULL,
  `uid` mediumint unsigned NOT NULL,
  `user_key` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `value_old` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `value_new` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  PRIMARY KEY (`tuid`),
  KEY `uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `templates`
--

DROP TABLE IF EXISTS `templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `templates` (
  `tpid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `page` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'misc',
  `skin` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'default',
  `lang` char(5) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'en_US',
  `template` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `seclev` mediumint unsigned NOT NULL,
  `description` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `title` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`tpid`),
  UNIQUE KEY `true_template` (`name`,`page`,`skin`,`lang`)
) ENGINE=InnoDB AUTO_INCREMENT=421 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topic_nexus`
--

DROP TABLE IF EXISTS `topic_nexus`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topic_nexus` (
  `tid` int unsigned NOT NULL,
  `current_qid` mediumint unsigned DEFAULT NULL,
  PRIMARY KEY (`tid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topic_nexus_dirty`
--

DROP TABLE IF EXISTS `topic_nexus_dirty`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topic_nexus_dirty` (
  `tid` int unsigned NOT NULL,
  PRIMARY KEY (`tid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topic_nexus_extras`
--

DROP TABLE IF EXISTS `topic_nexus_extras`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topic_nexus_extras` (
  `extras_id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `tid` int unsigned NOT NULL,
  `extras_keyword` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `extras_textname` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `type` enum('text','list') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'text',
  `content_type` enum('story','comment') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'story',
  `required` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `ordering` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`extras_id`),
  UNIQUE KEY `tid_keyword` (`tid`,`extras_keyword`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topic_param`
--

DROP TABLE IF EXISTS `topic_param`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topic_param` (
  `param_id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `tid` int unsigned NOT NULL,
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`param_id`),
  UNIQUE KEY `topic_key` (`tid`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topic_parents`
--

DROP TABLE IF EXISTS `topic_parents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topic_parents` (
  `tid` int unsigned NOT NULL,
  `parent_tid` int unsigned NOT NULL,
  `min_weight` float NOT NULL DEFAULT '10',
  UNIQUE KEY `child_and_parent` (`tid`,`parent_tid`),
  KEY `parent_tid` (`parent_tid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topics`
--

DROP TABLE IF EXISTS `topics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topics` (
  `tid` int unsigned NOT NULL AUTO_INCREMENT,
  `keyword` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `textname` varchar(80) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `series` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `image` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `width` smallint unsigned NOT NULL DEFAULT '0',
  `height` smallint unsigned NOT NULL DEFAULT '0',
  `submittable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `searchable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `storypickable` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'yes',
  `usesprite` enum('no','yes') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  PRIMARY KEY (`tid`),
  UNIQUE KEY `keyword` (`keyword`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `twitter_log`
--

DROP TABLE IF EXISTS `twitter_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `twitter_log` (
  `sid` char(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`sid`,`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tzcodes`
--

DROP TABLE IF EXISTS `tzcodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tzcodes` (
  `tz` char(4) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `off_set` mediumint NOT NULL,
  `description` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `dst_region` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `dst_tz` char(4) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `dst_off_set` mediumint DEFAULT NULL,
  PRIMARY KEY (`tz`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `uncommonstorywords`
--

DROP TABLE IF EXISTS `uncommonstorywords`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `uncommonstorywords` (
  `word` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`word`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `urls`
--

DROP TABLE IF EXISTS `urls`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `urls` (
  `url_id` int unsigned NOT NULL AUTO_INCREMENT,
  `url_digest` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `url` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `is_success` tinyint DEFAULT NULL,
  `createtime` datetime DEFAULT NULL,
  `last_attempt` datetime DEFAULT NULL,
  `last_success` datetime DEFAULT NULL,
  `believed_fresh_until` datetime DEFAULT NULL,
  `status_code` smallint DEFAULT NULL,
  `reason_phrase` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `content_type` varchar(60) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `initialtitle` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `validatedtitle` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `tags_top` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `popularity` float NOT NULL DEFAULT '0',
  `anon_bookmarks` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`url_id`),
  UNIQUE KEY `url_digest` (`url_digest`),
  KEY `bfu` (`believed_fresh_until`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user_achievement_streaks`
--

DROP TABLE IF EXISTS `user_achievement_streaks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_achievement_streaks` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `aid` mediumint unsigned NOT NULL DEFAULT '0',
  `streak` mediumint unsigned NOT NULL DEFAULT '0',
  `last_hit` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`id`),
  UNIQUE KEY `achievement` (`uid`,`aid`)
) ENGINE=InnoDB AUTO_INCREMENT=4405 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user_achievements`
--

DROP TABLE IF EXISTS `user_achievements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_achievements` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `aid` mediumint unsigned NOT NULL DEFAULT '0',
  `exponent` smallint unsigned NOT NULL DEFAULT '0',
  `createtime` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`id`),
  UNIQUE KEY `achievement` (`uid`,`aid`),
  KEY `aid_exponent` (`aid`,`exponent`)
) ENGINE=InnoDB AUTO_INCREMENT=13094 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `uid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `nickname` varchar(35) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `realemail` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `fakeemail` varchar(75) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `homepage` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `passwd` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `sig` varchar(200) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `seclev` mediumint unsigned NOT NULL DEFAULT '0',
  `matchname` varchar(35) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `newpasswd` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `newpasswd_ts` datetime DEFAULT NULL,
  `journal_last_entry_date` datetime DEFAULT NULL,
  `author` tinyint NOT NULL DEFAULT '0',
  `shill_id` tinyint unsigned NOT NULL DEFAULT '0',
  `willing_to_vote` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`),
  KEY `login` (`nickname`,`uid`,`passwd`),
  KEY `chk4user` (`realemail`,`nickname`),
  KEY `chk4matchname` (`matchname`),
  KEY `author_lookup` (`author`),
  KEY `seclev` (`seclev`)
) ENGINE=InnoDB AUTO_INCREMENT=30461 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_acl`
--

DROP TABLE IF EXISTS `users_acl`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_acl` (
  `id` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL,
  `acl` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uid_key` (`uid`,`acl`),
  KEY `uid` (`uid`),
  KEY `acl` (`acl`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_clout`
--

DROP TABLE IF EXISTS `users_clout`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_clout` (
  `clout_id` int unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL,
  `clid` smallint unsigned NOT NULL,
  `clout` float unsigned DEFAULT NULL,
  PRIMARY KEY (`clout_id`),
  UNIQUE KEY `uid_clid` (`uid`,`clid`),
  KEY `clid` (`clid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_comments`
--

DROP TABLE IF EXISTS `users_comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_comments` (
  `uid` mediumint unsigned NOT NULL,
  `posttype` mediumint NOT NULL DEFAULT '1',
  `defaultpoints` tinyint NOT NULL DEFAULT '1',
  `highlightthresh` tinyint NOT NULL DEFAULT '4',
  `maxcommentsize` smallint unsigned NOT NULL DEFAULT '4096',
  `hardthresh` tinyint NOT NULL DEFAULT '0',
  `clbig` smallint unsigned NOT NULL DEFAULT '0',
  `clsmall` smallint unsigned NOT NULL DEFAULT '0',
  `reparent` tinyint NOT NULL DEFAULT '1',
  `nosigs` tinyint NOT NULL DEFAULT '0',
  `commentlimit` smallint unsigned NOT NULL DEFAULT '100',
  `commentspill` smallint unsigned NOT NULL DEFAULT '50',
  `commentsort` tinyint NOT NULL DEFAULT '0',
  `noscores` tinyint NOT NULL DEFAULT '0',
  `threshold` tinyint NOT NULL DEFAULT '0',
  `highnew` tinyint NOT NULL DEFAULT '1',
  `dimread` tinyint NOT NULL DEFAULT '1',
  `mode` enum('flat','nocomment','threadtos','threadtng') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'threadtos',
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_comments_read_log`
--

DROP TABLE IF EXISTS `users_comments_read_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_comments_read_log` (
  `uid` mediumint unsigned NOT NULL,
  `discussion_id` mediumint unsigned NOT NULL,
  `cid_now` int unsigned NOT NULL,
  `cid_new` int unsigned NOT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`discussion_id`,`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_hits`
--

DROP TABLE IF EXISTS `users_hits`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_hits` (
  `uid` mediumint unsigned NOT NULL,
  `lastclick` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `hits` int NOT NULL DEFAULT '0',
  `hits_bought` int NOT NULL DEFAULT '0',
  `hits_bought_today` smallint unsigned NOT NULL DEFAULT '0',
  `hits_paidfor` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_index`
--

DROP TABLE IF EXISTS `users_index`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_index` (
  `uid` mediumint unsigned NOT NULL,
  `story_never_topic` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `story_never_author` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `story_never_nexus` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `story_always_topic` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `story_always_author` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `story_always_nexus` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `story_full_brief_nexus` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `story_brief_always_nexus` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `story_full_best_nexus` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `story_brief_best_nexus` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `slashboxes` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `maxstories` tinyint unsigned NOT NULL DEFAULT '30',
  `noboxes` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_info`
--

DROP TABLE IF EXISTS `users_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_info` (
  `uid` mediumint unsigned NOT NULL,
  `totalmods` mediumint NOT NULL DEFAULT '0',
  `realname` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `bio` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `points` smallint NOT NULL DEFAULT '0',
  `tokens` mediumint NOT NULL DEFAULT '0',
  `lastgranted` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `m2info` varchar(64) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `karma` mediumint NOT NULL DEFAULT '0',
  `maillist` tinyint NOT NULL DEFAULT '0',
  `totalcomments` mediumint unsigned DEFAULT '0',
  `lastm2` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `m2_mods_saved` varchar(120) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `lastaccess` date NOT NULL DEFAULT '1970-01-01',
  `lastaccess_ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `m2fair` mediumint unsigned NOT NULL DEFAULT '0',
  `up_fair` mediumint unsigned NOT NULL DEFAULT '0',
  `down_fair` mediumint unsigned NOT NULL DEFAULT '0',
  `m2unfair` mediumint unsigned NOT NULL DEFAULT '0',
  `up_unfair` mediumint unsigned NOT NULL DEFAULT '0',
  `down_unfair` mediumint unsigned NOT NULL DEFAULT '0',
  `m2fairvotes` mediumint unsigned NOT NULL DEFAULT '0',
  `m2voted_up_fair` mediumint unsigned NOT NULL DEFAULT '0',
  `m2voted_down_fair` mediumint unsigned NOT NULL DEFAULT '0',
  `m2unfairvotes` mediumint unsigned NOT NULL DEFAULT '0',
  `m2voted_up_unfair` mediumint unsigned NOT NULL DEFAULT '0',
  `m2voted_down_unfair` mediumint unsigned NOT NULL DEFAULT '0',
  `m2voted_lonedissent` mediumint unsigned NOT NULL DEFAULT '0',
  `m2voted_majority` mediumint unsigned NOT NULL DEFAULT '0',
  `upmods` mediumint unsigned NOT NULL DEFAULT '0',
  `downmods` mediumint unsigned NOT NULL DEFAULT '0',
  `stirred` mediumint unsigned NOT NULL DEFAULT '0',
  `session_login` tinyint NOT NULL DEFAULT '0',
  `cookie_location` enum('classbid','subnetid','ipid','none') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'classbid',
  `registered` tinyint unsigned NOT NULL DEFAULT '1',
  `reg_id` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `expiry_days` smallint unsigned NOT NULL DEFAULT '1',
  `expiry_comm` smallint unsigned NOT NULL DEFAULT '1',
  `user_expiry_days` smallint unsigned NOT NULL DEFAULT '1',
  `user_expiry_comm` smallint unsigned NOT NULL DEFAULT '1',
  `initdomain` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `created_ipid` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `created_at` datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
  `tag_clout` float unsigned NOT NULL DEFAULT '1',
  `people` mediumblob,
  `people_status` enum('ok','dirty') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'ok',
  `skin` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `subscriber_until` date NOT NULL DEFAULT '1970-01-01',
  `hide_subscription` tinyint unsigned NOT NULL DEFAULT '0',
  `mod_banned` date DEFAULT '1000-01-01',
  PRIMARY KEY (`uid`),
  KEY `initdomain` (`initdomain`),
  KEY `created_ipid` (`created_ipid`),
  KEY `tokens` (`tokens`),
  KEY `people_status` (`people_status`),
  KEY `age` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_logtokens`
--

DROP TABLE IF EXISTS `users_logtokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_logtokens` (
  `lid` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL DEFAULT '0',
  `locationid` char(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `temp` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `public` enum('yes','no') CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'no',
  `expires` datetime NOT NULL DEFAULT '2000-01-01 00:00:00',
  `value` char(22) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`lid`),
  UNIQUE KEY `uid_locationid_temp_public` (`uid`,`locationid`,`temp`,`public`),
  KEY `locationid` (`locationid`),
  KEY `temp` (`temp`),
  KEY `public` (`public`)
) ENGINE=InnoDB AUTO_INCREMENT=168774 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_messages`
--

DROP TABLE IF EXISTS `users_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_messages` (
  `id` int NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL,
  `code` int NOT NULL,
  `mode` tinyint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code_key` (`uid`,`code`)
) ENGINE=InnoDB AUTO_INCREMENT=242734 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_openid`
--

DROP TABLE IF EXISTS `users_openid`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_openid` (
  `openid_id` int unsigned NOT NULL AUTO_INCREMENT,
  `openid_url` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `uid` mediumint unsigned NOT NULL,
  PRIMARY KEY (`openid_id`),
  UNIQUE KEY `openid_url` (`openid_url`),
  KEY `uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_openid_reskeys`
--

DROP TABLE IF EXISTS `users_openid_reskeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_openid_reskeys` (
  `oprid` int unsigned NOT NULL AUTO_INCREMENT,
  `openid_url` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `reskey` char(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`oprid`),
  KEY `openid_url` (`openid_url`),
  KEY `reskey` (`reskey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_param`
--

DROP TABLE IF EXISTS `users_param`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_param` (
  `param_id` int unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint unsigned NOT NULL,
  `name` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`param_id`),
  UNIQUE KEY `uid_key` (`uid`,`name`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=12218729 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users_prefs`
--

DROP TABLE IF EXISTS `users_prefs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_prefs` (
  `uid` mediumint unsigned NOT NULL,
  `willing` tinyint NOT NULL DEFAULT '1',
  `dfid` tinyint unsigned NOT NULL DEFAULT '0',
  `tzcode` char(4) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'EST',
  `noicons` tinyint NOT NULL DEFAULT '0',
  `light` tinyint NOT NULL DEFAULT '0',
  `mylinks` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `lang` char(5) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'en_US',
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `vars`
--

DROP TABLE IF EXISTS `vars`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vars` (
  `name` varchar(48) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `value` mediumtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci,
  `description` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xsite_auth_log`
--

DROP TABLE IF EXISTS `xsite_auth_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xsite_auth_log` (
  `site` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `ts` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `nonce` varchar(30) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  UNIQUE KEY `site` (`site`,`ts`,`nonce`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2023-06-08  3:33:03

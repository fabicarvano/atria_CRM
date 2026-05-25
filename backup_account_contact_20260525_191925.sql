/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.11.14-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: atria_crm
-- ------------------------------------------------------
-- Server version	10.11.14-MariaDB-0+deb12u2

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `account_contact`
--

DROP TABLE IF EXISTS `account_contact`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `account_contact` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `account_id` varchar(17) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contact_id` varchar(17) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_inactive` tinyint(1) DEFAULT 0,
  `deleted` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQ_ACCOUNT_ID_CONTACT_ID` (`account_id`,`contact_id`),
  KEY `IDX_ACCOUNT_ID` (`account_id`),
  KEY `IDX_CONTACT_ID` (`contact_id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `account_contact`
--

LOCK TABLES `account_contact` WRITE;
/*!40000 ALTER TABLE `account_contact` DISABLE KEYS */;
INSERT INTO `account_contact` VALUES
(1,'6a07eb5a25c8ae31e','6a0b09fb2e9a2b09e',NULL,0,0),
(2,'6a07eb5a25c8ae31e','6a0b0a14cd58d4744',NULL,0,0),
(3,'6a07eb5a164a9276c','6a0e8c68a52c32aca','Diretor de ICT (Tecnologia da Informação e Comunicações)',0,0),
(4,'6a07eb5a3c89b0b3e','6a0e8e447573fd57d','Head Of Department',0,0),
(5,'6a0d35fa687be71e7','6a10e01e058c1904a','Gerente de Operação de TI e Telecom',0,0),
(6,'6a0d35fa687be71e7','6a10e27b6a7a2a802','IT Service Manager',0,0),
(7,'6a07eb5a164a9276c','6a10e2d28d4292835','Diretor de tecnologia',1,0),
(8,'6a1494510a0c8c5c7','6a10e2d28d4292835','Diretor de tecnologia',0,0);
/*!40000 ALTER TABLE `account_contact` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-05-25 19:19:25

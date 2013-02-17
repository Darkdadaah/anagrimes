-- MySQL dump 10.13  Distrib 5.1.66, for debian-linux-gnu (x86_64)
--
-- Host: sql-user-d    Database: u_darkdadaah
-- ------------------------------------------------------
-- Server version	5.1.66

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `articles`
--

DROP TABLE IF EXISTS `articles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `articles` (
  `art_id` int(11) NOT NULL AUTO_INCREMENT,
  `titre` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  `r_titre` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  `titre_plat` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  `r_titre_plat` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  `transcrit_plat` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  `r_transcrit_plat` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  `anagramme_id` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  PRIMARY KEY (`art_id`),
  KEY `index_articles_titre` (`titre`(10)),
  KEY `index_articles_r_titre` (`r_titre`(10)),
  KEY `index_articles_titre_plat` (`titre_plat`(10)),
  KEY `index_articles_r_titre_plat` (`r_titre_plat`(10)),
  KEY `index_articles_transcrit_plat` (`transcrit_plat`(10)),
  KEY `index_articles_r_transcrit_plat` (`r_transcrit_plat`(10)),
  KEY `index_articles_anagramme` (`anagramme_id`(10))
) ENGINE=InnoDB AUTO_INCREMENT=2359261 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compte_brwikisource`
--

DROP TABLE IF EXISTS `compte_brwikisource`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compte_brwikisource` (
  `mot` text,
  `count` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compte_brwikisource_2`
--

DROP TABLE IF EXISTS `compte_brwikisource_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compte_brwikisource_2` (
  `mot` text,
  `count` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compte_enwikisource`
--

DROP TABLE IF EXISTS `compte_enwikisource`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compte_enwikisource` (
  `mot` text,
  `count` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compte_enwikisource_2`
--

DROP TABLE IF EXISTS `compte_enwikisource_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compte_enwikisource_2` (
  `mot` text,
  `count` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compte_frwiki`
--

DROP TABLE IF EXISTS `compte_frwiki`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compte_frwiki` (
  `mot` text,
  `count` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compte_frwikisource`
--

DROP TABLE IF EXISTS `compte_frwikisource`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compte_frwikisource` (
  `mot` text,
  `count` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compte_frwikisource_2`
--

DROP TABLE IF EXISTS `compte_frwikisource_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compte_frwikisource_2` (
  `mot` text,
  `count` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compte_frwiktionary`
--

DROP TABLE IF EXISTS `compte_frwiktionary`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compte_frwiktionary` (
  `mot` text,
  `count` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `inconnus_brwikisource`
--

DROP TABLE IF EXISTS `inconnus_brwikisource`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `inconnus_brwikisource` (
  `mot` text,
  `article` text,
  `nombre` int(11) DEFAULT NULL,
  `quality` int(11) DEFAULT '0',
  KEY `index_inc_frw_mot` (`mot`(10))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `inconnus_brwikisource_2`
--

DROP TABLE IF EXISTS `inconnus_brwikisource_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `inconnus_brwikisource_2` (
  `mot` text,
  `article` text,
  `nombre` int(11) DEFAULT NULL,
  `quality` int(11) DEFAULT '0',
  KEY `index_inc_frw_mot` (`mot`(10))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `inconnus_enwikisource`
--

DROP TABLE IF EXISTS `inconnus_enwikisource`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `inconnus_enwikisource` (
  `mot` text,
  `article` text,
  `nombre` int(11) DEFAULT NULL,
  `quality` int(11) DEFAULT '0',
  KEY `index_inc_frw_mot` (`mot`(10))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `inconnus_enwikisource_2`
--

DROP TABLE IF EXISTS `inconnus_enwikisource_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `inconnus_enwikisource_2` (
  `mot` text,
  `article` text,
  `nombre` int(11) DEFAULT NULL,
  `quality` int(11) DEFAULT '0',
  KEY `index_inc_frw_mot` (`mot`(10))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `inconnus_frwiki`
--

DROP TABLE IF EXISTS `inconnus_frwiki`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `inconnus_frwiki` (
  `mot` text,
  `article` text,
  `nombre` int(11) DEFAULT NULL,
  `quality` int(11) DEFAULT '0',
  KEY `index_inc_frw_mot` (`mot`(10))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `inconnus_frwikisource`
--

DROP TABLE IF EXISTS `inconnus_frwikisource`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `inconnus_frwikisource` (
  `mot` text,
  `article` text,
  `nombre` int(11) DEFAULT NULL,
  `quality` int(11) DEFAULT '0',
  KEY `index_inc_frw_mot` (`mot`(10))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `inconnus_frwikisource_2`
--

DROP TABLE IF EXISTS `inconnus_frwikisource_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `inconnus_frwikisource_2` (
  `mot` text,
  `article` text,
  `nombre` int(11) DEFAULT NULL,
  `quality` int(11) DEFAULT '0',
  KEY `index_inc_frw_mot` (`mot`(10))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `inconnus_frwiktionary`
--

DROP TABLE IF EXISTS `inconnus_frwiktionary`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `inconnus_frwiktionary` (
  `mot` text,
  `article` text,
  `nombre` int(11) DEFAULT NULL,
  KEY `index_inc_frw_mot` (`mot`(10))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `langues`
--

DROP TABLE IF EXISTS `langues`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `langues` (
  `langue` char(10) NOT NULL,
  `num` int(11) DEFAULT NULL,
  `num_min` int(11) DEFAULT NULL,
  PRIMARY KEY (`langue`),
  KEY `langues_num` (`num`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `log`
--

DROP TABLE IF EXISTS `log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `log` (
  `action` text,
  `num` int(11) DEFAULT NULL,
  `latest_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `init_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mots`
--

DROP TABLE IF EXISTS `mots`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mots` (
  `mots_id` int(11) NOT NULL AUTO_INCREMENT,
  `titre` text COLLATE latin1_general_cs,
  `langue` text COLLATE latin1_general_cs NOT NULL,
  `type` text COLLATE latin1_general_cs NOT NULL,
  `pron` text COLLATE latin1_general_cs,
  `pron_simple` text COLLATE latin1_general_cs,
  `r_pron_simple` text COLLATE latin1_general_cs,
  `num` int(11) DEFAULT NULL,
  `flex` tinyint(1) DEFAULT '0',
  `loc` tinyint(1) DEFAULT '0',
  `gent` tinyint(1) DEFAULT '0',
  `rand` int(11) DEFAULT NULL,
  `rime_pauvre` text COLLATE latin1_general_cs,
  `rime_suffisante` text COLLATE latin1_general_cs,
  `rime_riche` text COLLATE latin1_general_cs,
  `rime_voyelle` text COLLATE latin1_general_cs,
  `syllabes` int(11) DEFAULT NULL,
  PRIMARY KEY (`mots_id`),
  KEY `index_mots_titre` (`titre`(10)),
  KEY `index_mots_pron_simple` (`pron_simple`(10)),
  KEY `index_mots_r_pron_simple` (`r_pron_simple`(10)),
  KEY `index_mots_loc` (`loc`),
  KEY `index_mots_langue` (`langue`(3)),
  KEY `index_mots_type` (`type`(3)),
  KEY `index_mots_flex` (`flex`),
  KEY `index_mots_gent` (`gent`),
  KEY `index_mots_titre_langue` (`titre`(10),`langue`(3),`type`(3)),
  KEY `mots_rand` (`rand`),
  KEY `index_mots_rime_riche` (`rime_riche`(3)),
  KEY `index_mots_rime_suffisante` (`rime_suffisante`(2)),
  KEY `index_mots_rime_pauvre` (`rime_pauvre`(2)),
  KEY `index_mots_rime_voyelle` (`rime_voyelle`(1))
) ENGINE=InnoDB AUTO_INCREMENT=2555866 DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `transcrits`
--

DROP TABLE IF EXISTS `transcrits`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `transcrits` (
  `tr_id` int(11) NOT NULL AUTO_INCREMENT,
  `titre` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  `transcrit` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  `transcrit_plat` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  `r_transcrit_plat` text CHARACTER SET latin1 COLLATE latin1_general_cs,
  PRIMARY KEY (`tr_id`),
  KEY `r_transcrit_index` (`r_transcrit_plat`(10)),
  KEY `transcrit_plat_index` (`transcrit_plat`(10))
) ENGINE=InnoDB AUTO_INCREMENT=6315 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-02-17 22:53:43

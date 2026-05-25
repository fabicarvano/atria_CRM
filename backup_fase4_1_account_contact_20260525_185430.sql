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
(7,'6a07eb5a164a9276c','6a10e2d28d4292835','Diretor de tecnologia',0,0),
(8,'6a1494510a0c8c5c7','6a10e2d28d4292835','Diretor de tecnologia',0,0);
/*!40000 ALTER TABLE `account_contact` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact`
--

DROP TABLE IF EXISTS `contact`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `contact` (
  `id` varchar(17) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `deleted` tinyint(1) DEFAULT 0,
  `salutation_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `do_not_call` tinyint(1) NOT NULL DEFAULT 0,
  `address_street` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_state` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_country` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_postal_code` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  `middle_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `stream_updated_at` datetime DEFAULT NULL,
  `account_id` varchar(17) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `account_id_anterior` varchar(17) DEFAULT NULL,
  `status_validacao_empresa` varchar(255) DEFAULT NULL,
  `campaign_id` varchar(17) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_by_id` varchar(17) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `modified_by_id` varchar(17) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `assigned_user_id` varchar(17) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `linkedin_url` varchar(512) DEFAULT NULL,
  `company_linkedin` varchar(512) DEFAULT NULL,
  `company_website` varchar(255) DEFAULT NULL,
  `company_name_atual` varchar(255) DEFAULT NULL,
  `email_corporativo` varchar(255) DEFAULT NULL,
  `fonte_email` varchar(100) DEFAULT NULL,
  `data_enriquecimento_email` datetime DEFAULT NULL,
  `cargo` varchar(255) DEFAULT NULL,
  `picture_url` varchar(2048) DEFAULT NULL,
  `linkedin_photo_url` varchar(2048) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `linkedin_last_sync` datetime DEFAULT NULL,
  `nivel_hierarquico` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `enriquecida_linkedin` tinyint(1) NOT NULL DEFAULT 0,
  `data_enriquecimento_linkedin` datetime DEFAULT NULL,
  `fonte_enriquecimento` varchar(100) DEFAULT NULL,
  `headline` varchar(512) DEFAULT NULL,
  `is_premium` tinyint(1) NOT NULL DEFAULT 0,
  `is_creator` tinyint(1) NOT NULL DEFAULT 0,
  `is_influencer` tinyint(1) NOT NULL DEFAULT 0,
  `location_linkedin` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQ_CREATED_AT_ID` (`created_at`,`id`),
  KEY `IDX_CREATED_AT` (`created_at`,`deleted`),
  KEY `IDX_FIRST_NAME` (`first_name`,`deleted`),
  KEY `IDX_NAME` (`first_name`,`last_name`),
  KEY `IDX_ASSIGNED_USER` (`assigned_user_id`,`deleted`),
  KEY `IDX_ACCOUNT_ID` (`account_id`),
  KEY `IDX_CAMPAIGN_ID` (`campaign_id`),
  KEY `IDX_CREATED_BY_ID` (`created_by_id`),
  KEY `IDX_MODIFIED_BY_ID` (`modified_by_id`),
  KEY `IDX_ASSIGNED_USER_ID` (`assigned_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `contact`
--

LOCK TABLES `contact` WRITE;
/*!40000 ALTER TABLE `contact` DISABLE KEYS */;
INSERT INTO `contact` VALUES
('6a0b09fb2e9a2b09e',0,'Mr.','teste','1',NULL,0,NULL,NULL,NULL,NULL,NULL,'2026-05-18 12:45:47','2026-05-18 12:45:47',NULL,'2026-05-18 12:45:47','6a07eb5a25c8ae31e',NULL,NULL,NULL,'6a07b9805de933235',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,0,0,0,NULL),
('6a0b0a14cd58d4744',0,'Mrs.','tetando 3','1',NULL,0,NULL,NULL,NULL,NULL,NULL,'2026-05-18 12:46:12','2026-05-18 12:46:12',NULL,'2026-05-18 12:46:12','6a07eb5a25c8ae31e',NULL,NULL,NULL,'6a07b9805de933235',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,0,0,0,NULL),
('6a0e8c68a52c32aca',0,NULL,'Eduardo','Oliveira','',0,NULL,NULL,NULL,NULL,NULL,'2026-05-21 04:39:04','2026-05-22 18:58:53',NULL,'2026-05-21 04:39:04','6a07eb5a164a9276c',NULL,NULL,NULL,'6a0ccc0619b0aa0d2','6a0ccc0619b0aa0d2',NULL,'https://www.linkedin.com/in/ACwAAErKusEBRXESfZgqY4sWV5yDFVCQVUn3Gbc',NULL,NULL,NULL,NULL,NULL,NULL,'Diretor de ICT (Tecnologia da Informação e Comunicações)',NULL,NULL,NULL,'VP / Diretor',0,NULL,NULL,NULL,0,0,0,NULL),
('6a0e8e447573fd57d',0,NULL,'Eder','Oliveira','Experiencia na gestão da área de TI, desde a operação dos serviços gerenciados de TI bem como na Gestão de Projetos de TI tanto no modo Waterfall quanto Agile.   Principais experiencias :  1. Arquitetura Corporativa  2. Gestão de Projetos Ageis & Cascata  3. Merge & Acquisitions  4. Experiencia em Projetos Globais.  5. Sistemas ERP & ITGC Compliance  6. Gestão Budgetária,  7. Segurança cibernética  8. Automação Industrial (ICS, SCADAs, etc).  9. Gestão de pessoas,  10. Consolidação de TI  11. Managed Services em ambientes hybridos (Cloud, On-Premises)  12. Advanced Analytics, AI, ML 13. Six Sigma (Black Belt)',0,NULL,NULL,NULL,NULL,NULL,'2026-05-21 04:47:00','2026-05-23 03:22:33',NULL,'2026-05-21 04:47:00','6a07eb5a3c89b0b3e',NULL,NULL,NULL,'6a0ccc0619b0aa0d2','6a07b9805de933235',NULL,'https://www.linkedin.com/in/ACwAAAPEAVUByAcXX4qu50WWxovrVkP3pH2b11A',NULL,NULL,NULL,NULL,NULL,NULL,'Head Of Department','https://media.licdn.com/dms/image/v2/C4E03AQHXGoeQIdpomA/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1635026612376?e=1781136000&v=beta&t=Lml7DtO-j2WUenkqWSIMFxdukbzivJ9Y4ivRxBdTTEM','https://media.licdn.com/dms/image/v2/C4E03AQHXGoeQIdpomA/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1635026612376?e=1781136000&v=beta&t=Lml7DtO-j2WUenkqWSIMFxdukbzivJ9Y4ivRxBdTTEM','2026-05-23 03:22:33','Gerente / Coordenador',1,'2026-05-23 03:22:33','apify_linkedin_profile','IT Manager at Auren Energia',0,0,0,'São Paulo, São Paulo'),
('6a10e01e058c1904a',0,NULL,'Marcelo','Dieguez','• Atuação em TI e Telecom em Utilities (CEMIG - Companhia Energética de Minas Gerais) e em empresas de serviços (Empresa de Infovias / CEMIGTelecom / ISPs).   • Experiência em O&M de Infraestrutura de TI e Telecom buscando continua melhoria nos processos, estreitando relacionamento com stakeholders, zelando pela excelência de ações em prazo, custo, qualidade e cumprimento de SLAs.  • Liderança de equipes de TI e Telecom (técnicos, analistas e engenheiros) promovendo o engajamento e desenvolvimento profissional.  • Busca de soluções tecnológicas para implementação, expansão e melhoria de processos de TI e Telecom.  Formação •  Especialização em Gestão de Negócios - FDC - 2021. •  MBA em Gestão Estratégica de Projetos - UNA-BH - 2009. •  Graduação em Engenharia Eletrônica e de Telecomunicação - PUC-MG - 2005.  Hobbies •  Atleta amador de ciclismo com participação em competições no Brasil e exterior. •  Homebrewer/Mestre Cervejeiro - UNI-BH - Especialização em Tecnologia Cervejeira – 2017.',0,NULL,NULL,NULL,NULL,NULL,'2026-05-22 23:00:46','2026-05-22 23:11:46',NULL,'2026-05-22 23:00:46','6a0d35fa687be71e7',NULL,NULL,NULL,'6a0ccc0619b0aa0d2','6a0ccc0619b0aa0d2',NULL,'https://www.linkedin.com/in/ACwAABkd-UUB_IAmM3yh8wj6tg0l0IGM0MgWqYY',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'https://media.licdn.com/dms/image/v2/D4D03AQEzeakay_FL4A/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1709688737816?e=1781136000&v=beta&t=UiWlW3MRz6GwZhKpOnR4DfsFKHz9wbMtzSbPkdd_eb8',NULL,NULL,0,NULL,NULL,NULL,0,0,0,NULL),
('6a10e27b6a7a2a802',0,NULL,'José Luiz Pereira','Silva','Atua com Tecnologia da Informação e Telecomunicações. Experiência em projetos de adoção de melhores práticas de Gerenciamento de Serviços de TI e Governança de TI e se especializou em gerenciamento de serviços com ITIL e CobIT.   Especializações: ITG, ITSM',0,NULL,NULL,NULL,NULL,NULL,'2026-05-22 23:10:51','2026-05-22 23:10:51',NULL,'2026-05-22 23:10:51','6a0d35fa687be71e7',NULL,NULL,NULL,'6a0ccc0619b0aa0d2','6a0ccc0619b0aa0d2',NULL,'https://www.linkedin.com/in/ACwAAAUbriYB6VcIwU30tP2CO5NqgwfRWFfYCYI',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'https://media.licdn.com/dms/image/v2/C4D03AQHXLMd2PyIDxg/profile-displayphoto-shrink_400_400/profile-displayphoto-shrink_400_400/0/1517232986279?e=1781136000&v=beta&t=LpTsym7WiGZfqEZmJRhLvK-9NXxYeIbcRPQwm2a68AY',NULL,NULL,0,NULL,NULL,NULL,0,0,0,NULL),
('6a10e2d28d4292835',0,NULL,'Thiago','Diniz Batista','Education and Career Path Graduated in Computer Science from the Federal University of Uberlândia, with specializations from renowned institutions such as FGV, FIA, and StartSe, I have built a 30-year career in Information Technology. My experience includes leading digital transformation initiatives, developing new businesses, and building high-performance teams. My journey is marked by consistent results, including process optimization and significant reductions in operational costs.  Current Position I currently serve as the Managing Director of the Algar Group, leading a team of 450 employees across Back-office areas such as Accounting, Tax, Finance, Procurement, Legal, HR, and Corporate IT.  Key Achievements in the Last 5 Years Over the past five years, I have led technological and organizational transformation projects, including the migration of strategic systems such as SAP/S4 Hana, infrastructure modernization with a transition to the cloud, intelligent automation with RPA and AI, compliance and security through LGPD implementation, as well as mergers and acquisitions (M&A) projects that have driven business growth and competitiveness.  Highlight of Results Through a robust digital transformation strategy, including talent development, organizational restructuring, and process adaptation, we achieved a 30% reduction in operational costs by combining efficiency and innovation.  Advisory Board Role in a Startup I serve as an advisory board member for a startup focused on RPA, Hyperautomation, and Artificial Intelligence, contributing with strategies that drive innovation and scalability in the sector.',0,NULL,NULL,NULL,NULL,NULL,'2026-05-22 23:12:18','2026-05-25 18:26:25',NULL,'2026-05-22 23:12:18','6a1494510a0c8c5c7','6a07eb5a164a9276c','empresa_divergente_corrigida',NULL,'6a0ccc0619b0aa0d2','6a07b9805de933235',NULL,'https://www.linkedin.com/in/ACwAAACSFQkBmi7NhCpmhI4QCqRhDkDyQOwzQtI','https://linkedin.com/company/algar-oficial','algartelecom.com.br','Algar','thiago@algartelecom.com.br','apify_linkedin_profile','2026-05-25 18:26:25',NULL,NULL,'https://media.licdn.com/dms/image/v2/D4D03AQGwteBRfHW7Jw/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1686774604051?e=1781136000&v=beta&t=9sarph4At5OMUDnQ-n4KEZf4JkitFfxxBXazbSHsuPk','2026-05-25 18:26:25','VP / Diretor',1,'2026-05-25 18:26:25','apify_linkedin_profile','CEO | CIO | Advisor | Mentor',0,1,0,'Uberlândia, Minas Gerais');
/*!40000 ALTER TABLE `contact` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_company_history`
--

DROP TABLE IF EXISTS `contact_company_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `contact_company_history` (
  `id` varchar(17) NOT NULL,
  `contact_id` varchar(17) DEFAULT NULL,
  `account_id_anterior` varchar(17) DEFAULT NULL,
  `account_id_novo` varchar(17) DEFAULT NULL,
  `empresa_anterior` varchar(255) DEFAULT NULL,
  `empresa_atual` varchar(255) DEFAULT NULL,
  `linkedin_empresa_anterior` varchar(512) DEFAULT NULL,
  `linkedin_empresa_atual` varchar(512) DEFAULT NULL,
  `company_website` varchar(255) DEFAULT NULL,
  `cargo` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `motivo` varchar(100) DEFAULT NULL,
  `fonte` varchar(100) DEFAULT NULL,
  `raw_json` mediumtext DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `created_by_id` varchar(17) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `IDX_CONTACT_COMPANY_HISTORY_CONTACT` (`contact_id`),
  KEY `IDX_CONTACT_COMPANY_HISTORY_ACCOUNT_ANTERIOR` (`account_id_anterior`),
  KEY `IDX_CONTACT_COMPANY_HISTORY_ACCOUNT_NOVO` (`account_id_novo`),
  KEY `IDX_CONTACT_COMPANY_HISTORY_CREATED_AT` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `contact_company_history`
--

LOCK TABLES `contact_company_history` WRITE;
/*!40000 ALTER TABLE `contact_company_history` DISABLE KEYS */;
INSERT INTO `contact_company_history` VALUES
('7ae306a6964976868','6a10e2d28d4292835','6a07eb5a164a9276c','6a1494510a0c8c5c7','Algar Telecom','Algar','https://www.linkedin.com/company/algar-telecom','https://linkedin.com/company/algar-oficial','algartelecom.com.br','Diretor de tecnologia','thiago@algartelecom.com.br','conta_criada_automaticamente','apify_linkedin_profile','{\"linkedinUrl\":\"https://www.linkedin.com/in/ACwAAACSFQkBmi7NhCpmhI4QCqRhDkDyQOwzQtI\",\"firstName\":\"Thiago\",\"lastName\":\"Diniz Batista\",\"fullName\":\"Thiago Diniz Batista\",\"headline\":\"CEO | CIO | Advisor | Mentor\",\"email\":\"thiago@algartelecom.com.br\",\"mobileNumber\":null,\"jobTitle\":\"Diretor de tecnologia\",\"jobStartedOn\":\"09-2025\",\"jobLocation\":null,\"jobStillWorking\":true,\"companyName\":\"Algar\",\"companyIndustry\":\"Telecommunications\",\"companyWebsite\":\"algartelecom.com.br\",\"companyLinkedin\":\"linkedin.com/company/algar-oficial\",\"companyFoundedIn\":null,\"companySize\":\"1001-5000\",\"currentJobDuration\":\"4 mos\",\"currentJobDurationInYrs\":0.33,\"topSkillsByEndorsements\":null,\"addressCountryOnly\":\"Brazil\",\"addressWithCountry\":\"Uberlândia, Minas Gerais Brazil\",\"addressWithoutCountry\":\"Uberlândia, Minas Gerais\",\"profilePic\":\"https://media.licdn.com/dms/image/v2/D4D03AQGwteBRfHW7Jw/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1686774604051?e=1781136000&v=beta&t=9sarph4At5OMUDnQ-n4KEZf4JkitFfxxBXazbSHsuPk\",\"profilePicHighQuality\":\"https://media.licdn.com/dms/image/v2/D4D03AQGwteBRfHW7Jw/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1686774604051?e=1781136000&v=beta&t=9sarph4At5OMUDnQ-n4KEZf4JkitFfxxBXazbSHsuPk\",\"backgroundPic\":\"https://media.licdn.com/dms/image/v2/D4D16AQF9fqljk3CrGw/profile-displaybackgroundimage-shrink_200_800/B4DZl3QG1FGgAY-/0/1758642336117?e=1781136000&v=beta&t=0cQnUXJTKDKGG3u53s56zKzyfT6BptEgKB532E0ToBc\",\"linkedinId\":null,\"isPremium\":false,\"isVerified\":false,\"isJobSeeker\":null,\"isRetired\":false,\"isCreator\":true,\"isInfluencer\":false,\"isCurrentlyEmployed\":true,\"about\":\"Education and Career Path\\nGraduated in Computer Science from the Federal University of Uberlândia, with specializations from renowned institutions such as FGV, FIA, and StartSe, I have built a 30-year career in Information Technology. My experience includes leading digital transformation initiatives, developing new businesses, and building high-performance teams. My journey is marked by consistent results, including process optimization and significant reductions in operational costs.\\n\\nCurrent Position\\nI currently serve as the Managing Director of the Algar Group, leading a team of 450 employees across Back-office areas such as Accounting, Tax, Finance, Procurement, Legal, HR, and Corporate IT.\\n\\nKey Achievements in the Last 5 Years\\nOver the past five years, I have led technological and organizational transformation projects, including the migration of strategic systems such as SAP/S4 Hana, infrastructure modernization with a transition to the cloud, intelligent automation with RPA and AI, compliance and security through LGPD implementation, as well as mergers and acquisitions (M&A) projects that have driven business growth and competitiveness.\\n\\nHighlight of Results\\nThrough a robust digital transformation strategy, including talent development, organizational restructuring, and process adaptation, we achieved a 30% reduction in operational costs by combining efficiency and innovation.\\n\\nAdvisory Board Role in a Startup\\nI serve as an advisory board member for a startup focused on RPA, Hyperautomation, and Artificial Intelligence, contributing with strategies that drive innovation and scalability in the sector.\",\"publicIdentifier\":\"ACwAAACSFQkBmi7NhCpmhI4QCqRhDkDyQOwzQtI\",\"linkedinPublicUrl\":\"https://www.linkedin.com/in/thiagodinizbatista\",\"openConnection\":null,\"urn\":\"ACoAAACSFQkBlEj7fEAr73kxv_LEcashnomdyZc\",\"totalRecommendationsReceived\":0,\"totalRecommendationsGiven\":0,\"birthday\":null,\"associatedHashtag\":[],\"firstRoleYear\":1995,\"totalExperienceYears\":31.3,\"experiencesCount\":10,\"experiences\":[{\"companyId\":\"469057\",\"companyUrn\":\"urn:li:fsd_company:469057\",\"companyLink1\":\"https://www.linkedin.com/company/algar-oficial/\",\"companyName\":\"Algar\",\"companySize\":\"1001-5000\",\"companyWebsite\":\"algartelecom.com.br\",\"companyIndustry\":\"Telecommunications\",\"logo\":\"https://media.licdn.com/dms/image/v2/D4D0BAQEq1L7mnu40sA/company-logo_200_200/B4DZdUohkUH4AI-/0/1749471599632/algar_telecom_logo?e=1781136000&v=beta&t=KmOOydMjWpItKn2wSQKPyc-tRrOmgTIvKLuV4kzCrEE\",\"title\":\"Diretor de tecnologia\",\"jobDescription\":null,\"jobStartedOn\":\"09-2025\",\"jobEndedOn\":null,\"jobLocation\":\"Уберландия, MG\",\"jobStillWorking\":true,\"jobLocationCountry\":null,\"employmentType\":null},{\"companyId\":\"74045468\",\"companyUrn\":\"urn:li:fsd_company:74045468\",\"companyLink1\":\"https://www.linkedin.com/company/csc-algar/\",\"companyName\":\"Csc Algar\",\"companySize\":\"201-500\",\"companyWebsite\":null,\"companyIndustry\":\"Information Technology And Services\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4D0BAQFgTDt25CWa6Q/company-logo_400_400/company-logo_400_400/0/1630536534314?e=1781136000&v=beta&t=K24khZlrIzoQvygQuJaeYhbBwTnivCmyDzhfhTVRTMY\",\"title\":\"Managing Director\",\"jobDescription\":null,\"jobStartedOn\":\"11-2017\",\"jobEndedOn\":\"05-2026\",\"jobLocation\":\"Uberlândia, Minas Gerais, Brasil\",\"jobStillWorking\":false,\"jobLocationCountry\":null,\"employmentType\":null},{\"companyId\":\"83056622\",\"companyUrn\":\"urn:li:fsd_company:83056622\",\"companyLink1\":\"https://www.linkedin.com/company/vibritech/\",\"companyName\":\"Vibri\",\"companySize\":\"1-10\",\"companyWebsite\":\"vibritech.com\",\"companyIndustry\":\"Internet\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4D0BAQEqnEnqdojU1Q/company-logo_400_400/company-logo_400_400/0/1660614058408/vibritech_logo?e=1781136000&v=beta&t=R6W3CjJ7x3pOaHMhHcx2F9q3SaRj3UVKhms2AunRD00\",\"title\":\"Advisor\",\"jobDescription\":null,\"jobStartedOn\":\"12-2024\",\"jobEndedOn\":\"09-2025\",\"jobLocation\":\"Localidade São Paulo, Brasil\",\"jobStillWorking\":false,\"jobLocationCountry\":null,\"employmentType\":null},{\"companyId\":\"1407682\",\"companyUrn\":\"urn:li:fsd_company:1407682\",\"companyLink1\":\"https://www.linkedin.com/company/zupinnovation/\",\"companyName\":\"Zup Innovation\",\"companySize\":\"1001-5000\",\"companyWebsite\":\"zupinnovation.com\",\"companyIndustry\":\"Information Technology And Services\",\"logo\":\"https://media.licdn.com/dms/image/v2/D4E0BAQEPrNNXCXG9_g/img-crop_100/B4EZfA_oolHcAY-/0/1751289597787?e=1781136000&v=beta&t=1cm9j0PWsT9uMpVEFK3_Jyam76U0m1m9-EZSZxFsksQ\",\"title\":\"Director of Services and Operations\",\"jobDescription\":null,\"jobStartedOn\":\"08-2014\",\"jobEndedOn\":\"10-2017\",\"jobLocation\":\"Uberlândia Area, Brazil\",\"jobStillWorking\":false,\"jobLocationCountry\":null,\"employmentType\":null},{\"companyId\":\"333329\",\"companyUrn\":\"urn:li:fsd_company:333329\",\"companyLink1\":\"https://www.linkedin.com/company/itau/\",\"companyName\":\"Itaú Unibanco\",\"companySize\":\"10001+\",\"companyWebsite\":\"itau.com.br\",\"companyIndustry\":\"Banking\",\"logo\":\"https://media.licdn.com/dms/image/v2/D4D0BAQGmyPiGIU-69w/company-logo_100_100/B4DZZFc2k4GgAQ-/0/1744921914031/itau_logo?e=1781136000&v=beta&t=9YEt4CP1KPpEB5fqIzRiVvaIgnBcd6PgAHvWT9pxaYo\",\"title\":\"Executive IT Manager\",\"jobDescription\":null,\"jobStartedOn\":\"08-2011\",\"jobEndedOn\":\"07-2014\",\"jobLocation\":\"São Paulo, Brasil\",\"jobStillWorking\":false,\"jobLocationCountry\":null,\"employmentType\":null},{\"companyId\":\"4310\",\"companyUrn\":\"urn:li:fsd_company:4310\",\"companyLink1\":\"https://www.linkedin.com/company/transunion/\",\"companyName\":\"Transunion\",\"companySize\":\"10001+\",\"companyWebsite\":\"transunion.com\",\"companyIndustry\":\"Information Technology And Services\",\"logo\":\"https://media.licdn.com/dms/image/v2/D4D0BAQEk0GcygRhErQ/company-logo_400_400/company-logo_400_400/0/1688367018553/transunion_logo?e=1781136000&v=beta&t=gnM6VG92zx68r2MsyT_DvNWGBZ61RkMxz5oE_UBnx3M\",\"title\":\"Director of Services and Operations\",\"jobDescription\":null,\"jobStartedOn\":\"12-2009\",\"jobEndedOn\":\"07-2011\",\"jobLocation\":\"São Paulo, Brasil\",\"jobStillWorking\":false,\"jobLocationCountry\":null,\"employmentType\":null},{\"companyId\":\"2793\",\"companyUrn\":\"urn:li:fsd_company:2793\",\"companyLink1\":\"https://www.linkedin.com/company/borland/\",\"companyName\":\"Borland Software\",\"companySize\":\"1001-5000\",\"companyWebsite\":\"borland.com\",\"companyIndustry\":\"Computer Software\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4E0BAQGY2gcVHSCVwg/company-logo_400_400/company-logo_400_400/0/1631306599988?e=1781136000&v=beta&t=29j_MPrcv90oTEgMGfUbyNXarlRvt07s5fCcvWis8O0\",\"title\":\"Director of Services and Operations\",\"jobDescription\":null,\"jobStartedOn\":\"08-2000\",\"jobEndedOn\":\"11-2009\",\"jobLocation\":\"São Paulo, Brasil\",\"jobStillWorking\":false,\"jobLocationCountry\":null,\"employmentType\":null},{\"companyId\":null,\"companyUrn\":null,\"companyLink1\":null,\"companyName\":null,\"companySize\":null,\"companyWebsite\":null,\"companyIndustry\":null,\"logo\":null,\"title\":\"Founder\",\"jobDescription\":null,\"jobStartedOn\":\"1997\",\"jobEndedOn\":\"2000\",\"jobLocation\":\"Uberlândia, Minas Gerais, Brasil\",\"jobStillWorking\":false,\"jobLocationCountry\":null,\"employmentType\":null},{\"companyId\":\"22226\",\"companyUrn\":\"urn:li:fsd_company:22226\",\"companyLink1\":\"https://www.linkedin.com/company/cemig/\",\"companyName\":\"Cemig\",\"companySize\":\"5001-10000\",\"companyWebsite\":\"cemig.com.br\",\"companyIndustry\":\"Utilities\",\"logo\":\"https://media.licdn.com/dms/image/v2/D4D0BAQEOdamlZM-r4A/company-logo_400_400/company-logo_400_400/0/1733168468455/cemig_logo?e=1781136000&v=beta&t=uVoNcUJRyrbvCBJGK1yJ9r0MB-JY_xRdvdspLRfsm_Q\",\"title\":\"Intern\",\"jobDescription\":null,\"jobStartedOn\":\"01-1997\",\"jobEndedOn\":\"08-1997\",\"jobLocation\":\"Uberlândia Area, Brazil\",\"jobStillWorking\":false,\"jobLocationCountry\":null,\"employmentType\":null},{\"companyId\":\"11685072\",\"companyUrn\":\"urn:li:fsd_company:11685072\",\"companyLink1\":\"https://www.linkedin.com/school/universidadefederaldeuberlandia/\",\"companyName\":null,\"companySize\":null,\"companyWebsite\":null,\"companyIndustry\":null,\"logo\":\"https://media.licdn.com/dms/image/v2/D4D0BAQHrts4e7cWyGA/company-logo_100_100/B4DZvTKxwOIAAQ-/0/1768774377025/universidadefederaldeuberlandia_logo?e=1781136000&v=beta&t=0BjItxtwYudVmYcyejhO3BTYjXxkqtKK_TePDZyycoc\",\"title\":\"Researcher\",\"jobDescription\":null,\"jobStartedOn\":\"01-1995\",\"jobEndedOn\":\"01-1997\",\"jobLocation\":\"Uberlândia Area, Brazil\",\"jobStillWorking\":false,\"jobLocationCountry\":null,\"employmentType\":null}],\"updates\":[],\"skills\":[{\"title\":\"Visão Sistêmica\"},{\"title\":\"Pensamento sistêmico\"},{\"title\":\"Alto desempenho\"},{\"title\":\"Estratégia empresarial\"},{\"title\":\"Mudança de cultura\"},{\"title\":\"Inovação empresarial\"},{\"title\":\"Cultura organizacional\"},{\"title\":\"Melhoria de processos\"},{\"title\":\"Tecnologia da informação\"},{\"title\":\"Transformação digital\"},{\"title\":\"Transformação empresarial\"},{\"title\":\"Liderança de equipe\"},{\"title\":\"Trabalho em equipe\"},{\"title\":\"Big data\"},{\"title\":\"Inteligência artificial\"},{\"title\":\"Aplicativos móveis\"},{\"title\":\"Serviços web\"},{\"title\":\"SAP ERP\"},{\"title\":\"Gestão de fornecedores\"},{\"title\":\"Práticas de engenharia de software\"}],\"creatorWebsite\":[],\"profilePicAllDimensions\":[],\"educations\":[{\"companyId\":\"481634\",\"companyUrn\":\"urn:li:fsd_company:481634\",\"companyLink1\":\"https://www.linkedin.com/school/mit-professional-education/\",\"logo\":\"https://media.licdn.com/dms/image/v2/D4E0BAQFZLjfg1Jhpfw/company-logo_400_400/company-logo_400_400/0/1720625381085/mit_professional_education_logo?e=1781136000&v=beta&t=DiGzdXXWyNBO7vVhFe2oTZEnufxlOiEJtg2QFQ8GqR4\",\"title\":\"MIT Professional Education\",\"subtitle\":\"IA Generativa na Era da Transformação Digital , Tecnologia da Informação\",\"description\":null,\"grade\":null,\"period\":{\"startedOn\":null,\"endedOn\":null}},{\"companyId\":\"8175\",\"companyUrn\":\"urn:li:fsd_company:8175\",\"companyLink1\":\"https://www.linkedin.com/school/fgv/\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4D0BAQFtDwxOTmj18Q/company-logo_400_400/company-logo_400_400/0/1657633907178/fgv_logo?e=1781136000&v=beta&t=Xw-bLH3pZS7NDmMTkUFuyC5cKWcSJxrwku2-JOwgRS4\",\"title\":\"Fundação Getulio Vargas\",\"subtitle\":\"C-level Program - CEO, Business Administration\",\"description\":null,\"grade\":null,\"period\":{\"startedOn\":null,\"endedOn\":null}},{\"companyId\":\"69250271\",\"companyUrn\":\"urn:li:fsd_company:69250271\",\"companyLink1\":\"https://www.linkedin.com/school/startse-university/\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4D0BAQGojR1VA_dZBQ/company-logo_400_400/company-logo_400_400/0/1630478614674/startse_university_logo?e=1781136000&v=beta&t=NW0Gm0xMIySdGWV19Ud72JAMUdUAgFtGdAslNEmciz8\",\"title\":\"StartSe University\",\"subtitle\":\"Xponential Business Administration, Digital Transformation\",\"description\":null,\"grade\":null,\"period\":{\"startedOn\":null,\"endedOn\":null}},{\"companyId\":\"416522\",\"companyUrn\":\"urn:li:fsd_company:416522\",\"companyLink1\":\"https://www.linkedin.com/school/fiabusinessschool/\",\"logo\":\"https://media.licdn.com/dms/image/v2/D4D0BAQHHDRKid8YkYA/company-logo_200_200/B4DZoRN636IkAI-/0/1761225453831/fiabusinessschool_logo?e=1781136000&v=beta&t=OY1iajDRXejr4I5NEPbcURBYwDn59FgNDxLenv5iQWU\",\"title\":\"FIA Business School\",\"subtitle\":\"Graduate Program in New Technologies, Digital Transformation, and Agility, Information Technology\",\"description\":null,\"grade\":null,\"period\":{\"startedOn\":null,\"endedOn\":null}},{\"companyId\":\"8175\",\"companyUrn\":\"urn:li:fsd_company:8175\",\"companyLink1\":\"https://www.linkedin.com/school/fgv/\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4D0BAQFtDwxOTmj18Q/company-logo_400_400/company-logo_400_400/0/1657633907178/fgv_logo?e=1781136000&v=beta&t=Xw-bLH3pZS7NDmMTkUFuyC5cKWcSJxrwku2-JOwgRS4\",\"title\":null,\"subtitle\":\"MBA, Project Management\",\"description\":null,\"grade\":null,\"period\":{\"startedOn\":null,\"endedOn\":null}},{\"companyId\":\"15090749\",\"companyUrn\":\"urn:li:fsd_company:15090749\",\"companyLink1\":\"https://www.linkedin.com/school/ufuoficial/\",\"logo\":\"https://media.licdn.com/dms/image/v2/D4D0BAQHd0dpD-8bfrg/company-logo_200_200/B4DZuUcD8SIkAI-/0/1767721943656/ufuoficial_logo?e=1781136000&v=beta&t=z45eQ2d7MwIKbH3wmLD_-9pmL0TzpYxBa_LwICFdwuc\",\"title\":\"Universidade Federal de Uberlândia\",\"subtitle\":\"Bachelor, Computer Science\",\"description\":null,\"grade\":null,\"period\":{\"startedOn\":null,\"endedOn\":null}}],\"licenseAndCertificates\":[{\"companyId\":\"69250271\",\"companyUrn\":\"urn:li:fsd_company:69250271\",\"companyLink1\":\"https://www.linkedin.com/school/startse-university/\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4D0BAQGojR1VA_dZBQ/company-logo_400_400/company-logo_400_400/0/1630478614674/startse_university_logo?e=1781136000&v=beta&t=NW0Gm0xMIySdGWV19Ud72JAMUdUAgFtGdAslNEmciz8\",\"title\":\"IA para Negócios\",\"subtitle\":\"StartSe University\",\"issued\":\"Issued Jul 2025\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"companyId\":\"69250271\",\"companyUrn\":\"urn:li:fsd_company:69250271\",\"companyLink1\":\"https://www.linkedin.com/school/startse-university/\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4D0BAQGojR1VA_dZBQ/company-logo_400_400/company-logo_400_400/0/1630478614674/startse_university_logo?e=1781136000&v=beta&t=NW0Gm0xMIySdGWV19Ud72JAMUdUAgFtGdAslNEmciz8\",\"title\":\"MultiAgentes\",\"subtitle\":\"StartSe University\",\"issued\":\"Issued Jul 2025\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"companyId\":\"68562773\",\"companyUrn\":\"urn:li:fsd_company:68562773\",\"companyLink1\":\"https://www.linkedin.com/school/board-academy-br/\",\"logo\":\"https://media.licdn.com/dms/image/v2/D4D0BAQHZv0b0lQHFuQ/company-logo_200_200/B4DZrZypZ3GsAM-/0/1764590524626/board_academy_br_logo?e=1781136000&v=beta&t=Xntbdumr9v2p65Jd1pIxJI9qElNWQ4HhSCoqLpUTkYw\",\"title\":\"LEAN GOVERNANCE\",\"subtitle\":\"Board Academy Br\",\"issued\":\"Issued Apr 2024\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"companyId\":\"69250271\",\"companyUrn\":\"urn:li:fsd_company:69250271\",\"companyLink1\":\"https://www.linkedin.com/school/startse-university/\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4D0BAQGojR1VA_dZBQ/company-logo_400_400/company-logo_400_400/0/1630478614674/startse_university_logo?e=1781136000&v=beta&t=NW0Gm0xMIySdGWV19Ud72JAMUdUAgFtGdAslNEmciz8\",\"title\":\"AI for Leaders\",\"subtitle\":\"StartSe University\",\"issued\":\"Issued Jul 2023\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"companyId\":\"69250271\",\"companyUrn\":\"urn:li:fsd_company:69250271\",\"companyLink1\":\"https://www.linkedin.com/school/startse-university/\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4D0BAQGojR1VA_dZBQ/company-logo_400_400/company-logo_400_400/0/1630478614674/startse_university_logo?e=1781136000&v=beta&t=NW0Gm0xMIySdGWV19Ud72JAMUdUAgFtGdAslNEmciz8\",\"title\":\"LEx - Liderança Exponencial\",\"subtitle\":\"StartSe University\",\"issued\":\"Issued Jun 2023\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"companyId\":\"24063\",\"companyUrn\":\"urn:li:fsd_company:24063\",\"companyLink1\":\"https://www.linkedin.com/school/exin/\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4E0BAQFi8TgZbeVOXw/company-logo_400_400/company-logo_400_400/0/1656919652964/exin_logo?e=1781136000&v=beta&t=2GPNdkxvwgSxGh7Dpv0uWVJmcMMem391Lgy4s3N0QMU\",\"title\":\"ISFS - Information Security Foundation\",\"subtitle\":\"EXIN\",\"issued\":\"Issued May 2021\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"companyId\":\"24063\",\"companyUrn\":\"urn:li:fsd_company:24063\",\"companyLink1\":\"https://www.linkedin.com/school/exin/\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4E0BAQFi8TgZbeVOXw/company-logo_400_400/company-logo_400_400/0/1656919652964/exin_logo?e=1781136000&v=beta&t=2GPNdkxvwgSxGh7Dpv0uWVJmcMMem391Lgy4s3N0QMU\",\"title\":\"PDPF - Privacy and Data Protection Foundation\",\"subtitle\":\"EXIN\",\"issued\":\"Issued Apr 2021\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"title\":\"Scrum Master\",\"subtitle\":null,\"issued\":\"Issued Dec 2008\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"title\":\"Starteam - Software Configuration Management\",\"subtitle\":\"Borland Latin America\",\"issued\":\"Issued Sep 2005\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"title\":\"CaliberRM - Requeriment Management\",\"subtitle\":\"Borland Latin America\",\"issued\":\"Issued Apr 2005\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"title\":\"Delphi 6.0\",\"subtitle\":\"Borland Latin America\",\"issued\":\"Issued Sep 1999\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]},{\"title\":\"Project Management Professional\",\"subtitle\":\"Project Management Institute\",\"issued\":\"Issued Jun 2013\",\"breakdown\":false,\"subComponents\":[{\"description\":[]}]}],\"honorsAndAwards\":[],\"languages\":[{\"name\":\"English\",\"proficiency\":null},{\"name\":\"Portuguese\",\"proficiency\":\"NATIVE_OR_BILINGUAL\"},{\"name\":\"Spanish\",\"proficiency\":null}],\"volunteerAndAwards\":[{\"companyId\":\"1026194\",\"companyUrn\":\"urn:li:fsd_company:1026194\",\"companyLink1\":\"https://www.linkedin.com/company/instituto-algar/\",\"logo\":\"https://media.licdn.com/dms/image/v2/C4D0BAQEi1QnzBpya9g/company-logo_400_400/company-logo_400_400/0/1630553413239?e=1781136000&v=beta&t=1PoLICNcyru_xct9boavxdOxWf0rKbtutTl8RrzREvo\",\"title\":\"Mentor\",\"subtitle\":\"Instituto Algar\",\"caption\":\"Jul 2023 - Present · 2 yrs 6 mos\",\"breakdown\":false,\"subComponenets\":[{\"description\":[]}]},{\"companyId\":\"766002\",\"companyUrn\":\"urn:li:fsd_company:766002\",\"companyLink1\":\"https://www.linkedin.com/company/grupo-algar/\",\"logo\":\"https://media.licdn.com/dms/image/v2/D4D0BAQElDh3t6rJObQ/company-logo_200_200/B4DZx8l7EMIUAI-/0/1771616843627/grupo_algar_logo?e=1781136000&v=beta&t=HzZnZ7kp_jdviY5maqSrxylZ3_VIzb85hWDoBGUaRV8\",\"title\":\"Mentor de negócios\",\"subtitle\":\"Grupo Algar\",\"caption\":\"Jul 2023 - Present · 2 yrs 6 mos\",\"breakdown\":false,\"subComponenets\":[{\"description\":[]}]}],\"verifications\":[],\"promos\":[],\"highlights\":[],\"projects\":[],\"publications\":[],\"patents\":[],\"courses\":[],\"testScores\":[],\"organizations\":[],\"volunteerCauses\":[],\"interests\":[],\"recommendationsReceived\":[],\"recommendations\":[],\"peopleAlsoViewed\":[]}','2026-05-25 18:26:25','6a07b9805de933235');
/*!40000 ALTER TABLE `contact_company_history` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-05-25 18:54:31

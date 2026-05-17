<?php
return [
  'database' => [
    'host' => 'localhost',
    'port' => '',
    'charset' => NULL,
    'dbname' => 'atria_crm',
    'user' => 'atria',
    'password' => 'XP3U2DHo55ETz6DllQjfqlza',
    'platform' => 'Mysql'
  ],
  'smtpPassword' => NULL,
  'logger' => [
    'path' => 'data/logs/espo.log',
    'level' => 'WARNING',
    'rotation' => true,
    'maxFileNumber' => 30,
    'printTrace' => false,
    'databaseHandler' => false,
    'sql' => false,
    'sqlFailed' => false
  ],
  'restrictedMode' => false,
  'cleanupAppLog' => true,
  'cleanupAppLogPeriod' => '30 days',
  'webSocketMessager' => 'ZeroMQ',
  'clientSecurityHeadersDisabled' => false,
  'clientCspDisabled' => false,
  'clientCspScriptSourceList' => [
    0 => 'https://maps.googleapis.com'
  ],
  'adminUpgradeDisabled' => false,
  'isInstalled' => true,
  'microtimeInternal' => 1778891153.726027,
  'cryptKey' => '6a078fb3eed313333e9c4abbc60d77cb',
  'hashSecretKey' => 'd8289b5e9c203f6b84fe1af9a61459b5',
  'defaultPermissions' => [
    'user' => 33,
    'group' => 33
  ],
  'actualDatabaseType' => 'mariadb',
  'actualDatabaseVersion' => '10.11.14',
  'instanceId' => '4dc8ffd0-0c1e-4c06-8b93-7634c6fb19f0'
];

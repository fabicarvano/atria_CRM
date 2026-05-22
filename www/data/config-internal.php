<?php
return [
  'database' => [
    'host' => 'localhost',
    'port' => '',
    'charset' => 'utf8mb4',
    'dbname' => 'atria_crm',
    'user' => 'atria',
    'password' => 'XP3U2DHo55ETz6DllQjfqlza'
  ],
  'smtpPassword' => '',
  'adminPassword' => 'ET4Hryxu3W9yANbB',
  'installed' => true,
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
  'microtimeInternal' => 1779336513.666584,
  'cryptKey' => '311346da5b08a52c7166c1f9ed5ad801',
  'actualDatabaseType' => 'mariadb',
  'actualDatabaseVersion' => '10.11.14',
  'instanceId' => '510cd16e-255a-4ea3-b0bb-2448a86ee9d4',
  'apiSecretKeys' => (object) []
];

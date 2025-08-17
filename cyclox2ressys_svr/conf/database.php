<?php
defined('BASEPATH') OR exit('No direct script access allowed');

$active_group = 'default';
$query_builder = TRUE;

$db['default'] = array(
	'dsn'	=> '',
	'hostname' => getenv('DB_HOSTNAME') ? getenv('DB_HOSTNAME') : '127.0.0.1',
	'username' => getenv('DB_USERNAME') ? getenv('DB_USERNAME') : 'db_user',
	'password' => getenv('DB_PASSWORD') ? getenv('DB_PASSWORD') : 'dbpass',
	'database' => getenv('DB_DATABASE') ? getenv('DB_DATABASE') : 'cyclox2',
	'dbdriver' => 'mysqli',
	'dbprefix' => '',
	'pconnect' => FALSE,
	'db_debug' => (ENVIRONMENT !== 'production'),
	'cache_on' => FALSE,
	'cachedir' => '',
	'char_set' => 'utf8',
	'dbcollat' => 'utf8_general_ci',
	'swap_pre' => '',
	'encrypt' => FALSE,
	'compress' => FALSE,
	'stricton' => FALSE,
	'failover' => array(),
	'save_queries' => TRUE
);

<?php
/**
 * ローカル検証専用のメール設定。tools/run_local_cake.sh が app/Config/email.php としてマウントする。
 * すべての設定を Debug トランスポートにし、ローカル実行からは実際のメールを送らない
 * （core.php の mail_reports=1 により、バッチ失敗時に MailReporter が送信しようとするため）。
 */
class EmailConfig {

	public $default = array(
		'transport' => 'Debug',
		'from' => 'local-debug@localhost',
		'log' => true,
	);

	public $sys_reporter = array(
		'transport' => 'Debug',
		'from' => 'local-debug@localhost',
		'log' => true,
	);

	public $smtp = array(
		'transport' => 'Debug',
		'from' => 'local-debug@localhost',
		'log' => true,
	);

	public $fast = array(
		'transport' => 'Debug',
		'from' => 'local-debug@localhost',
		'log' => true,
	);
}

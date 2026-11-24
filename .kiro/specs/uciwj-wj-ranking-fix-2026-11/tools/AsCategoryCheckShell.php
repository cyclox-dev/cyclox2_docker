<?php
/**
 * ローカル検証専用: ResultParamCalcComponent::asCategory() の判定結果を出力する。
 * DB は書き換えない。cyclox2web にはコミットせず、使い捨てコンテナに
 * app/Console/Command/AsCategoryCheckShell.php としてマウントして使う。
 *
 * > cd app && Console/cake as_category_check
 *
 * 出力: label <TAB> racer_code <TAB> races_category_code <TAB> at_date <TAB> as_category
 * 検証ケースは design.md「AsCategoryCheckShell の検証ケース」に対応する。
 */
App::uses('AppShell', 'Console/Command');
App::uses('ComponentCollection', 'Controller');
App::uses('ResultParamCalcComponent', 'Controller/Component');

class AsCategoryCheckShell extends AppShell
{
	public $uses = array();

	public function main()
	{
		$calc = new ResultParamCalcComponent(new ComponentCollection());

		// label, racer_code(false=未登録の新規選手), races_category_code, at_date
		$cases = array(
			array('target-MDX', 'XTK-178-0059', 'UCIWJ', '2026-11-15'),
			array('target-MDX', 'CXK-156-0033', 'UCIWJ', '2026-11-15'),
			array('target-KNS', 'CXK-156-0033', 'UCIWJ', '2026-11-22'),
			array('target-KNS', 'XTK-178-0059', 'UCIWJ', '2026-11-22'),
			array('target-KNS', 'KNS-201-0043', 'UCIWJ', '2026-11-22'),
			array('target-KNS', 'KNS-234-0063', 'UCIWJ', '2026-11-22'),
			array('no-WJ-holder', false, 'UCIWJ', '2026-11-22'),
			array('existing-UCI', 'CCH-000-0154', 'UCIME', '2026-11-22'),
			array('existing-UCI', 'CCM-000-0317', 'UCIME+U', '2026-11-15'),
			array('existing-UCI', 'CCM-000-7117', 'UCIWE', '2026-11-22'),
			array('existing-UCI', 'CCM-156-0031', 'UCIMJ', '2026-11-22'),
			array('other', 'TKI-156-0172', 'WJ', '2026-11-22'),
			array('other', 'CCM-201-0019', 'CL1', '2026-11-22'),
		);

		foreach ($cases as $c) {
			list($label, $racer, $rc, $date) = $c;
			$ret = $calc->asCategory($racer, $rc, $date);
			$this->out(implode("\t", array($label, $racer === false ? '(none)' : $racer, $rc, $date, var_export($ret, true))));
		}
	}
}

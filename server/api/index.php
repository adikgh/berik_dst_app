<?php
// Раздача мобильді программасының API-і (Flutter: iOS + Android).
// Орны: dist.pf.c/api/index.php. Сұрау: /api/?a=<әрекет>, жауап JSON.
// Кіру: a=login (phone, password) → token. Қалған сұрауларда: Authorization: Bearer <token>.
// Тіл: X-Lang тақырыбы (kz, ru, en, uz, ky). Базаға жаңа кесте керек емес.

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
ini_set('display_errors', '0');
set_exception_handler(function ($e) {
	error_log('dst api: '.$e->getMessage());
	if (ob_get_level()) ob_end_clean();
	http_response_code(500);
	echo json_encode(['ok' => false, 'error' => 'server'], JSON_UNESCAPED_UNICODE);
});

// Сайттың өз cookie-лері API-ге араласпасын: тек тіл қалады
$api_lang = preg_replace('/[^a-z]/', '', strtolower((string)@$_SERVER['HTTP_X_LANG']));
$_COOKIE = [];
if ($api_lang !== '') $_COOKIE['lang'] = $api_lang;
unset($_GET['lang'], $_GET['company']);

ob_start();
include __DIR__.'/../config/core.php';
ob_end_clean();
require_once __DIR__.'/../orders/hist.php';

const API_TTL = 3600 * 24 * 180; // токен 6 ай жарамды (сайттағы cookie сияқты)
$api_raw = json_decode((string)file_get_contents('php://input'), true); // программа JSON жібереді
$api_in = is_array($api_raw) ? $api_raw : $_POST;
$a = (string)@$_GET['a'];

function out($data, $code = 200) {
	http_response_code($code);
	echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
	exit();
}
function fail($err, $code = 400) { out(['ok' => false, 'error' => $err], $code); }
function in_s($k) { global $api_in; return trim((string)@$api_in[$k]); }
function in_i($k) { global $api_in; return (int)@$api_in[$k]; }
function esc($s) { return mysqli_real_escape_string(db::$connect, (string)$s); }

// Токен: user_id.мерзімі.қолтаңба. Қолтаңбаға құпиясөз кіреді, құпиясөз ауысса токен өзі жарамсыз болады.
function api_key() {
	$sec = is_file(__DIR__.'/../config/secret.php') ? (include __DIR__.'/../config/secret.php') : [];
	$k = is_array($sec) ? (string)@$sec['api_key'] : '';
	return $k !== '' ? $k : hash('sha256', 'berik_dst_api|'.db::$name.'|'.db::$pass);
}
function api_sign($uid, $exp, $pass) { return hash_hmac('sha256', $uid.'|'.$exp.'|'.$pass, api_key()); }
function api_token($u) { $exp = time() + API_TTL; return $u['id'].'.'.$exp.'.'.api_sign($u['id'], $exp, $u['password']); }

// Раздачаға кіре алатын лауазымдар: 1 Директор, 2 Админ, 3 Раздача
function api_staff_ok($uid) {
	$s = fun::user_staffw($uid);
	return ($s && in_array((int)$s['positions_id'], [1, 2, 3])) ? $s : null;
}

// ---------- кіру ----------
if ($a == 'login') {
	$phone = substr(preg_replace('/\D/', '', in_s('phone')), -10);
	$pass = in_s('password');
	if (strlen($phone) != 10 || $pass === '') fail('wrong');
	$u = mysqli_fetch_assoc(db::query("select * from user where phone = '".esc($phone)."' and `right` = 1 limit 1"));
	if (!$u || (string)$u['password'] !== $pass) fail('wrong');
	if (!api_staff_ok($u['id'])) fail('no_access', 403);
	out(['ok' => true, 'token' => api_token($u)]);
}

// ---------- токенді тексеру ----------
$hdr = (string)(@$_SERVER['HTTP_AUTHORIZATION'] ?: @$_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?: @$_SERVER['HTTP_X_TOKEN']);
$tok = trim(preg_replace('/^Bearer\s+/i', '', $hdr));
$tp = explode('.', $tok);
if (count($tp) != 3 || (int)$tp[1] < time()) fail('auth', 401);
$user = mysqli_fetch_assoc(db::query("select * from user where id = '".(int)$tp[0]."' and `right` = 1 limit 1"));
if (!$user || !hash_equals(api_sign((int)$tp[0], (int)$tp[1], (string)$user['password']), $tp[2])) fail('auth', 401);
$user_right = api_staff_ok($user['id']);
if (!$user_right) fail('no_access', 403);
$user_id = (int)$user['id'];
$company = (int)($user_right['company_id'] ?: 1);
$company_d = mysqli_fetch_assoc(db::query("select * from `company` where id = '$company'"));
$branch = (int)@$user_right['branch_id'];

// Компания төлемі біткен болса
if (@$company_d['ins_dt'] != null && @$company_d['end_dt'] != null) {
	$left = intval((strtotime($company_d['end_dt']) - strtotime(date('d.m.Y'))) / 86400);
	if ($left <= 0) fail('company_expired', 402);
}

function st_names() {
	return [1 => t::w('Жаңа', 'Новый'), 8 => t::w('Дайындалуда', 'Готовится'), 2 => t::w('Дайын', 'Готов'), 11 => t::w('Курьер тағайындалды', 'Курьер назначен'), 3 => t::w('Жолда', 'В пути'), 9 => t::w('Столда', 'На столе'), 4 => t::w('Аяқталды', 'Завершён'), 5 => t::w('Бас тарту', 'Отказ'), 6 => t::w('Алғанда бас тарту', 'Отказ при получении'), 10 => t::w('Сыртта бас тарту', 'Отказ вне')];
}
function st_colors() {
	static $c = null;
	if ($c === null) { $c = []; $q = db::query("select id, clr from retail_orders_status"); while ($r = mysqli_fetch_assoc($q)) $c[(int)$r['id']] = (string)$r['clr']; }
	return $c;
}
function pm_names() {
	return ['transfer' => t::w('Аударым', 'Перевод'), 'qr' => 'Kaspi QR', 'cash' => t::w('Қолма-қол', 'Наличные'), 'red' => 'Red', 'mix' => t::w('Аралас', 'Смешанная'), 'mixed' => t::w('Аралас', 'Смешанная'), 'unpaid' => t::w('Төленбеген', 'Не оплачен')];
}
function type_names() { return [1 => t::w('Жеткізу', 'Доставка'), 2 => t::w('Өзімен', 'Собой'), 3 => t::w('Сервис', 'Сервис'), 4 => t::w('Кафе', 'Кафе')]; }
function user_name($id) { static $c = []; $id = (int)$id; if (!$id) return ''; if (!isset($c[$id])) { $u = fun::user($id); $c[$id] = $u ? trim((string)$u['name']) : ''; } return $c[$id]; }
function branch_row($id) { static $c = []; $id = (int)$id; if (!$id) return null; if (!array_key_exists($id, $c)) { $b = fun::branch($id); $c[$id] = $b ?: null; } return $c[$id]; }

// Бір тапсырыстың JSON түрі (сайттағы карточкадағы барлық дерек)
function order_json($o, $full = false) {
	$st = (int)$o['order_status']; $ot = (int)$o['order_type'];
	$b = branch_row($o['branch_id']);
	$items = []; $q = db::query("select * from retail_orders_products where order_id = '".(int)$o['id']."' order by ins_dt asc");
	while ($p = mysqli_fetch_assoc($q)) {
		$pd = product::product($p['product_id']);
		$items[] = ['name' => (string)@$pd['name_ru'], 'qty' => (float)$p['quantity'], 'price' => (float)$p['price'], 'sum' => (float)$p['quantity'] * (float)$p['price']];
	}
	$pm = pm_names();
	$pre = (string)@$o['prepay_method'] !== '' ? (int)$o['pay_prepay'] : (int)$o['pay_qr'];
	$ph = substr(preg_replace('/\D/', '', (string)$o['phone']), -10);
	$r = [
		'id' => (int)$o['id'],
		'number' => (string)@$b['code'].$o['number'],
		'type' => $ot,
		'type_name' => @type_names()[$ot] ?: '',
		'status' => $st,
		'status_name' => @st_names()[$st] ?: '',
		'status_color' => @st_colors()[$st] ?: '#10a96a',
		'time' => date('H:i', strtotime($o['ins_dt'])),
		'created' => (string)$o['ins_dt'],
		'preorder' => (string)$o['preorder_dt'],
		'courier_id' => (int)$o['сourier_id'],
		'courier_name' => user_name($o['сourier_id']),
		'courier_can_change' => $ot == 1 && in_array($st, [1, 8, 2, 11]),
		'can_give' => in_array($st, [1, 8, 2]) && in_array($ot, [2, 3]),
		'can_table' => in_array($st, [1, 8, 2]) && $ot == 4,
		'items' => $items,
		'delivery' => (int)$o['pay_delivery'],
		'total' => (int)$o['total'],
		'prepay' => $pre,
		'prepay_method' => (string)(@$pm[$o['prepay_method']] ?: ''),
		'pay_cash' => (int)$o['pay_cash'],
		'payment_method' => (string)(@$pm[$o['payment_method']] ?: $o['payment_method']),
		'refuse_reason' => trim((string)@$o['refuse_reason']),
		'kept_sum' => (int)@$o['kept_sum'],
		'address' => (string)$o['address'],
		'floor_apt' => trim((string)@$o['floor_apt']),
		'operator' => user_name($o['user_id']),
		'phone' => strlen($ph) == 10 ? $ph : '',
	];
	if ($full) {
		$r['branch'] = (string)@$b['name'];
		$r['additional'] = trim(strip_tags((string)$o['additional']));
		$r['comment'] = trim(strip_tags((string)$o['comment']));
		$r['updated'] = (string)@$o['upd_dt'];
		$r['history'] = order_timeline($o);
		$r['changes'] = order_changes((int)$o['id']);
	}
	return $r;
}

// Статус уақыт сызығы: orders/hist.php-тағы dist_hist_html логикасы, тек дерек түрінде
function order_timeline($o) {
	$oid = (int)$o['id']; $last = [];
	$lg = db::query("select new_value sid, max(ins_dt) dt from retail_orders_log where order_id = '$oid' and field = 'status' group by new_value");
	while ($l = mysqli_fetch_assoc($lg)) $last[(int)$l['sid']] = $l['dt'];
	$nm = st_names(); $cur = (int)$o['order_status']; $rows = []; $first = true;
	$sts = db::query("select * from retail_orders_status order by number asc");
	while ($s = mysqli_fetch_assoc($sts)) {
		$sid = (int)$s['id']; $dt = @$last[$sid];
		if ($first) $dt = $o['ins_dt'];
		$first = false;
		if ($sid == 7 && !$dt && $cur != $sid) continue;
		if (!in_array((string)$o['order_type'], explode(',', (string)@$s['types'])) && !$dt && $cur != $sid) continue;
		$rows[] = ['name' => @$nm[$sid] ?: trim((string)$s['name_ru']), 'color' => $s['clr'] ?: '#9aa0a6', 'dt' => $dt ? (string)$dt : '', 'on' => (bool)($dt || $cur == $sid), 'current' => $cur == $sid];
	}
	$ci = -1; foreach ($rows as $k => $r) if ($r['current']) $ci = $k;
	if ($ci >= 0) foreach ($rows as $k => $r) if ($k > $ci) { $rows[$k]['on'] = false; $rows[$k]['dt'] = ''; }
	$last_on = -1; foreach ($rows as $k => $r) if ($r['on']) $last_on = $k;
	$final = in_array($cur, [4, 5, 6, 10]);
	foreach ($rows as $k => $r) $rows[$k]['skip'] = !$r['on'] && ($k < $last_on || $final);
	return $rows;
}

// Өзгерістер тізімі: HTML-ін алып, әр жолды мәтінге айналдырамыз (логика hist.php-та бір жерде қалады)
function order_changes($oid) {
	$res = dist_changes_html($oid); $out = [];
	if ($res[0] === '') return $out;
	$dom = new DOMDocument();
	@$dom->loadHTML('<?xml encoding="utf-8"?><div>'.$res[0].'</div>');
	$xp = new DOMXPath($dom);
	foreach ($xp->query("//div[@class='oh_cl']") as $cl) {
		$f = $xp->query(".//span[@class='oh_cl_f']", $cl)->item(0);
		$m = $xp->query(".//small", $cl)->item(0);
		$v = $xp->query(".//div[@class='oh_cl_v']", $cl)->item(0);
		$parts = [];
		if ($v) foreach ($v->childNodes as $n) { $t = trim(preg_replace('/\s+/u', ' ', $n->textContent)); if ($t !== '') $parts[] = ['t' => $t, 'k' => $n->nodeName == 's' ? 'old' : ($n->nodeName == 'b' ? 'new' : 'txt')]; }
		$out[] = ['field' => $f ? trim($f->textContent) : '', 'meta' => $m ? trim($m->textContent) : '', 'parts' => $parts];
	}
	return $out;
}

function own_order($id) {
	global $company;
	return mysqli_fetch_assoc(db::query("select * from retail_orders where id = '".(int)$id."' and company_id = '".(int)$company."' limit 1"));
}
function log_status($oid, $old, $new) {
	global $user_id, $datetime;
	if ((int)$old == (int)$new) return;
	db::query("INSERT INTO `retail_orders_log` (order_id, field, old_value, new_value, user_id, ins_dt) VALUES ('".(int)$oid."', 'status', '".(int)$old."', '".(int)$new."', '".(int)$user_id."', '$datetime')");
}

// Тізімдер: orders/index.php-тағы сұраулар
function list_where($sort, $staff) {
	global $start_cdate, $end_cdate, $company;
	$w = "ins_dt BETWEEN '$start_cdate' and '$end_cdate' and `paid` = 1 and company_id = '".(int)$company."'";
	$cr = $staff ? " and `сourier_id` = '".(int)$staff."'" : " and `сourier_id` is not null";
	$m = [
		'new' => ["$w and `order_type` = 1 and `сourier_id` is null and `order_status` in (1, 8, 2)", 'asc'],
		'road' => ["$w and `order_type` = 1 and `order_status` in (11, 3)$cr", 'desc'],
		'history' => ["$w and `order_type` = 1 and `order_status` = 4$cr", 'desc'],
		'myself' => ["$w and `order_type` = 2 and `order_status` in (1, 8, 2)", 'desc'],
		'myself_yes' => ["$w and `order_type` = 2 and `order_status` = 4", 'desc'],
		'service' => ["$w and `order_type` = 3 and `order_status` in (1, 8, 2)", 'desc'],
		'service_yes' => ["$w and `order_type` = 3 and `order_status` = 4", 'desc'],
		'coffee' => ["$w and `order_type` = 4", 'desc'],
		'none' => ["$w and `order_status` in (5, 6, 10)", 'desc'],
	];
	return @$m[$sort];
}

switch ($a) {

	// Профиль, компания және қосулы бөлімдер
	case 'me':
		$pos = [1 => t::w('Директор', 'Директор'), 2 => t::w('Админ', 'Админ'), 3 => t::w('Раздача', 'Раздача')];
		$types = [];
		$tq = db::query("select nms from retail_orders_type order by number asc");
		while ($t = mysqli_fetch_assoc($tq)) if (in_array($t['nms'], ['delivery', 'yourself', 'service', 'coffee']) && !empty($company_d[$t['nms']])) $types[] = $t['nms'];
		out(['ok' => true,
			'user' => ['id' => $user_id, 'name' => trim($user['name'].' '.$user['surname']), 'phone' => (string)$user['phone'], 'img' => $user['img'] ? '/assets/uploads/users/'.$user['img'] : '', 'position' => (string)@$pos[(int)$user_right['positions_id']]],
			'company' => ['id' => $company, 'name' => (string)@$company_d['name'], 'city' => trim((string)@$company_d['city']) ?: 'shymkent'],
			'types' => $types,
			'whatsapp' => (string)@$site['whatsapp'],
			'lang' => t::$lang,
		]);

	// Тапсырыстар тізімі: sort = new | road | history | myself | myself_yes | service | service_yes | coffee | none
	case 'orders':
		$sort = (string)@$_GET['sort'] ?: 'new';
		$lw = list_where($sort, (int)@$_GET['staff']);
		if (!$lw) fail('sort');
		$q = db::query("select * from retail_orders where {$lw[0]} order by number {$lw[1]}");
		$list = []; while ($o = mysqli_fetch_assoc($q)) $list[] = order_json($o);
		out(['ok' => true, 'sort' => $sort, 'orders' => $list]);

	// Бір тапсырыс: толық мәлімет, статус тарихы, өзгерістер
	case 'order':
		$o = own_order(@$_GET['id']);
		if (!$o) fail('not_found', 404);
		out(['ok' => true, 'order' => order_json($o, true)]);

	// Жаңа тапсырыс бар ма: программа әр 15 секундта сұрайды, саны өссе дыбыс шығады
	case 'poll':
		$cnt = [];
		foreach (['new' => 'delivery', 'myself' => 'yourself', 'service' => 'service', 'coffee' => 'coffee'] as $s => $tp) {
			if (empty($company_d[$tp])) continue;
			$lw = list_where($s, 0);
			$cnt[$s] = (int)mysqli_fetch_assoc(db::query("select count(*) c from retail_orders where {$lw[0]}".($s == 'coffee' ? " and order_status in (1, 8, 2)" : '')))['c'];
		}
		$mx = (int)mysqli_fetch_assoc(db::query("select max(id) m from retail_orders where ins_dt BETWEEN '$start_cdate' and '$end_cdate' and `paid` = 1 and company_id = '$company'"))['m'];
		out(['ok' => true, 'counts' => $cnt, 'last_id' => $mx]);

	// Курьерлер тізімі
	case 'couriers':
		$list = [];
		$q = db::query("select * from company_staff where positions_id = 6 and company_id = '$company' order by ins_dt desc");
		while ($s = mysqli_fetch_assoc($q)) { $u = fun::user($s['user_id']); if (!$u) continue; $list[] = ['id' => (int)$u['id'], 'staff_id' => (int)$s['id'], 'name' => trim($u['name'].' '.$u['surname']), 'phone' => (string)$u['phone'], 'img' => $u['img'] ? '/assets/uploads/users/'.$u['img'] : '']; }
		out(['ok' => true, 'couriers' => $list]);

	// Курьер тағайындау / алып тастау (courier_id = 0)
	case 'assign':
		$o = own_order(in_i('order_id'));
		if (!$o || (int)$o['order_type'] != 1) fail('not_found', 404);
		$cur = (int)$o['order_status'];
		if (!in_array($cur, [1, 8, 2, 11])) fail('locked', 409);
		$cid = in_i('courier_id');
		if ($cid) {
			if (!mysqli_num_rows(db::query("select id from company_staff where user_id = '$cid' and positions_id = 6 and company_id = '$company'"))) fail('courier');
			db::query("UPDATE `retail_orders` SET сourier_id = '$cid', order_status = 11 WHERE id = '".(int)$o['id']."'");
			$new = 11;
		} else {
			db::query("UPDATE `retail_orders` SET сourier_id = null, order_status = 2 WHERE id = '".(int)$o['id']."'");
			$new = 2;
		}
		log_status($o['id'], $cur, $new);
		out(['ok' => true]);

	// Өзімен / Сервис: клиент алды → Аяқталды (4)
	case 'give':
		$o = own_order(in_i('id'));
		if (!$o) fail('not_found', 404);
		$cur = (int)$o['order_status'];
		if (!in_array($cur, [1, 8, 2]) || !in_array((int)$o['order_type'], [2, 3])) fail('locked', 409);
		db::query("UPDATE `retail_orders` SET `order_status` = 4, upd_dt = '$datetime' WHERE id = '".(int)$o['id']."'");
		log_status($o['id'], $cur, 4);
		out(['ok' => true]);

	// Кафе: клиентке берілді → Столда (9)
	case 'table':
		$o = own_order(in_i('id'));
		if (!$o || (int)$o['order_type'] != 4) fail('not_found', 404);
		$cur = (int)$o['order_status'];
		if (!in_array($cur, [1, 8, 2])) fail('locked', 409);
		db::query("UPDATE `retail_orders` SET order_status = 9, upd_dt = '$datetime' WHERE id = '".(int)$o['id']."'");
		log_status($o['id'], $cur, 9);
		out(['ok' => true]);

	// Курьер қосу (users/get.php?add_user сияқты)
	case 'courier_add':
		$name = trim(strip_tags(in_s('name')));
		$phone = substr(preg_replace('/\D/', '', in_s('phone')), -10);
		if (strlen($phone) != 10) fail('phone');
		$u = mysqli_fetch_assoc(db::query("SELECT * FROM `user` WHERE phone = '$phone' limit 1"));
		if (!$u) {
			db::query("INSERT INTO `user`(`name`, `phone`, `password`, `right`) VALUES ('".esc($name)."', '$phone', '123456', 1)");
			$u = mysqli_fetch_assoc(db::query("SELECT * FROM `user` WHERE phone = '$phone' limit 1"));
		}
		if (!$u) fail('error', 500);
		$uid = (int)$u['id'];
		if (mysqli_num_rows(db::query("SELECT id FROM `company_staff` WHERE user_id = '$uid' and company_id = '$company'"))) out(['ok' => true, 'exists' => true]);
		if (!$u['right'] || !$u['password']) db::query("UPDATE `user` SET `right` = 1, `password` = IFNULL(`password`, '123456') WHERE id = '$uid'");
		db::query("INSERT INTO `company_staff`(`user_id`, `positions_id`, `company_id`) VALUES ('$uid', 6, '$company')");
		out(['ok' => true]);

	// Курьерді өзгерту: аты, нөмірі
	case 'courier_edit':
		$id = in_i('id');
		$name = trim(strip_tags(in_s('name')));
		$phone = substr(preg_replace('/\D/', '', in_s('phone')), -10);
		if (!mysqli_num_rows(db::query("SELECT id FROM `company_staff` WHERE user_id = '$id' and positions_id = 6 and company_id = '$company'"))) fail('not_found', 404);
		if ($phone && strlen($phone) != 10) fail('phone');
		if ($phone && mysqli_num_rows(db::query("SELECT id FROM `user` WHERE phone = '$phone' and id != '$id'"))) fail('phone_busy');
		if ($name !== '') db::query("UPDATE `user` SET `name` = '".esc($name)."' WHERE id = '$id'");
		if ($phone) db::query("UPDATE `user` SET `phone` = '$phone' WHERE id = '$id'");
		out(['ok' => true]);

	// Курьерді тізімнен өшіру (тек осы компаниядағы курьер жазбасы)
	case 'courier_del':
		$sid = in_i('staff_id');
		db::query("DELETE FROM `company_staff` WHERE id = '$sid' and positions_id = 6 and company_id = '$company'");
		out(['ok' => true]);

	// Құпиясөзді өзгерту: жаңа токен қайтарады
	case 'password':
		$p = in_s('password');
		if (mb_strlen($p) < 4) fail('short');
		db::query("UPDATE `user` SET `password` = '".esc(strip_tags($p))."' WHERE id = '$user_id'");
		$user['password'] = strip_tags($p);
		out(['ok' => true, 'token' => api_token($user)]);

	default:
		fail('action', 404);
}

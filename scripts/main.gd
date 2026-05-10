extends Control

# ============================================================
# Corporate Coffee — career-ladder tycoon
# Stage 1: Office Coffee Juffrouw (timing minigame, defection)
# Stage 2: Café Owner
# Stage 3: Chain CEO
# Stage 4: Corporate CEO  (win at $10M)
# ============================================================

# --- progression ---
var stage: int = 1
var money: float = 0.0
var rep: float = 0.5
var won: bool = false

# --- universal metrics (cups counted as floats, displayed as ints) ---
var session_start_msec: int = 0
var current_rate: float = 0.0
var money_last_tick: float = 0.0
var customers_served: float = 0.0
var total_perfect: float = 0.0
var total_good: float = 0.0
var total_mediocre: float = 0.0
var total_burnt: float = 0.0

# --- stage 1 (office) ---
var beans: int = 10
var milk: int = 0
var has_steamer: bool = false
var quality: float = 0.7  # 0..1, drives spawn rate
const OFFICE_SIZE: int = 8
var defected: int = 0  # colleagues who brought their own pod machine

# --- stage 2 (café) ---
var baristas: int = 0
var cafe_price_mult: float = 1.0
var current_supplier: int = 0
var machine_clean: float = 0.9
var machine_calibration: float = 0.9
var machine_pressure: float = 0.9
const MACHINE_DRIFT_CLEAN: float = 0.012
const MACHINE_DRIFT_CALIB: float = 0.006

const SUPPLIERS: Array[Dictionary] = [
	{"name": "Local Roaster", "cost": 0.0, "quality": 1.0, "tag": "🏘️"},
	{"name": "Brazil",        "cost": 1.0, "quality": 1.25, "tag": "🇧🇷"},
	{"name": "Ethiopia",      "cost": 4.0, "quality": 1.8, "tag": "🇪🇹"},
	{"name": "Vietnam",       "cost": 0.0, "quality": 0.7, "tag": "🇻🇳"},
]

# --- stage 3 (chain) ---
var locations: Array[Dictionary] = []
const PROMO_DRAIN_BASE: float = 0.015     # per second, no manager
const PROMO_DRAIN_MANAGED: float = 0.008  # per second, with manager
const MANAGER_SALARY: float = 5.0         # $/sec ongoing

# --- stage 4 (corporate) ---
var stock_price: float = 100.0
var marketing_level: int = 0
var corporate_staff: int = 8
var staff_salary: float = 25.0  # $/head/s base
var morale: float = 0.7
var bulk_tier: int = 0
var cartel_active: bool = false
var antitrust_risk: float = 0.0
var strike_seconds: int = 0
var layoff_cooldown: int = 0

const BULK_TIERS: Array[Dictionary] = [
	{"name": "no contracts",    "cost": 0.0,         "discount": 1.00},
	{"name": "1k contracts",    "cost": 100_000.0,   "discount": 0.85},
	{"name": "10k contracts",   "cost": 500_000.0,   "discount": 0.65},
	{"name": "100k contracts",  "cost": 2_000_000.0, "discount": 0.40},
]

# --- constants ---
const STAGE_NAMES: Array[String] = [
	"",
	"Office Coffee Juffrouw",
	"Café Owner",
	"Chain CEO",
	"Corporate CEO",
]
const STAGE_GOALS: Array[float] = [0.0, 200.0, 2000.0, 100000.0, 10000000.0]
const STAGE_BG: Array[Color] = [
	Color.WHITE,
	Color(0.97, 0.93, 0.85),
	Color(0.85, 0.92, 0.85),
	Color(0.82, 0.88, 0.95),
	Color(0.18, 0.22, 0.32),
]
const STAGE_FG: Array[Color] = [
	Color.BLACK,
	Color(0.15, 0.10, 0.05),
	Color(0.10, 0.20, 0.10),
	Color(0.10, 0.15, 0.30),
	Color(0.95, 0.95, 0.95),
]

# stage 1 drinks — sweet_min/max define the brewing minigame's perfect zone
const DRINK_ESPRESSO: Dictionary = {
	"name": "Espresso", "emoji": "☕", "price": 2, "tip": 2,
	"beans": 1, "milk": 0, "needs_steamer": false,
	"sweet_min": 0.55, "sweet_max": 0.78,
}
const DRINK_CAPPUCCINO: Dictionary = {
	"name": "Cappuccino", "emoji": "🍼", "price": 4, "tip": 3,
	"beans": 1, "milk": 1, "needs_steamer": true,
	"sweet_min": 0.60, "sweet_max": 0.76,
}
const DRINK_LATTE: Dictionary = {
	"name": "Latte", "emoji": "🥛", "price": 5, "tip": 4,
	"beans": 1, "milk": 2, "needs_steamer": true,
	"sweet_min": 0.66, "sweet_max": 0.80,
}

# --- ui (built once) ---
var bg: ColorRect
var hud_label: Label
var notif_label: Label
var stage_view: Control
var spawn_timer: Timer
var revenue_timer: Timer

# --- ui (rebuilt per stage) ---
var beans_label: Label
var milk_label: Label
var quality_label: Label
var office_label: Label
var queue_box: HBoxContainer
var queue: Array[Dictionary] = []  # [{drink, button, brewing}]

var s2_status: Label
var supplier_buttons: Array[Button] = []
var machine_clean_bar: ProgressBar
var machine_calib_bar: ProgressBar
var machine_press_bar: ProgressBar
var s3_list: VBoxContainer
var s3_rows: Array[Dictionary] = []  # [{info: Label, cut: Button}]
var s3_status: Label
var s4_status: Label
var cartel_button: Button
var bulk_button: Button
var metrics_timer: Timer
var dev_skip_button: Button


func _ready() -> void:
	randomize()
	session_start_msec = Time.get_ticks_msec()
	_build_root_ui()
	_enter_stage(1)


# ============================================================
#  ROOT UI
# ============================================================
func _build_root_ui() -> void:
	bg = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	hud_label = Label.new()
	hud_label.position = Vector2(20, 8)
	hud_label.size = Vector2(740, 50)
	hud_label.add_theme_font_size_override("font_size", 14)
	add_child(hud_label)

	dev_skip_button = Button.new()
	dev_skip_button.text = "⏭ skip stage (dev)"
	dev_skip_button.position = Vector2(770, 8)
	dev_skip_button.size = Vector2(170, 28)
	dev_skip_button.pressed.connect(_dev_skip_stage)
	add_child(dev_skip_button)

	notif_label = Label.new()
	notif_label.position = Vector2(20, 60)
	notif_label.size = Vector2(920, 22)
	notif_label.modulate = Color(0.35, 0.55, 0.35)
	add_child(notif_label)

	stage_view = Control.new()
	stage_view.anchor_right = 1.0
	stage_view.anchor_bottom = 1.0
	stage_view.offset_top = 90.0
	add_child(stage_view)

	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_on_spawn)
	add_child(spawn_timer)

	revenue_timer = Timer.new()
	revenue_timer.wait_time = 1.0
	revenue_timer.timeout.connect(_on_revenue_tick)
	add_child(revenue_timer)

	metrics_timer = Timer.new()
	metrics_timer.wait_time = 1.0
	metrics_timer.autostart = true
	metrics_timer.timeout.connect(_on_metrics_tick)
	add_child(metrics_timer)


func _enter_stage(s: int) -> void:
	stage = s
	bg.color = STAGE_BG[s]
	var fg: Color = STAGE_FG[s]
	hud_label.modulate = fg
	notif_label.modulate = fg.lerp(Color(0.3, 0.7, 0.3), 0.5)

	for c in stage_view.get_children():
		c.queue_free()
	queue.clear()
	beans_label = null
	milk_label = null
	quality_label = null
	office_label = null
	queue_box = null
	s2_status = null
	supplier_buttons.clear()
	machine_clean_bar = null
	machine_calib_bar = null
	machine_press_bar = null
	s3_list = null
	s3_rows.clear()
	s3_status = null
	s4_status = null
	cartel_button = null
	bulk_button = null
	spawn_timer.stop()
	revenue_timer.stop()

	match s:
		1: _setup_stage_1()
		2: _setup_stage_2()
		3: _setup_stage_3()
		4: _setup_stage_4()

	_refresh_hud()
	_notify("Welcome to Stage %d — %s" % [s, STAGE_NAMES[s]])


func _refresh_hud() -> void:
	var elapsed_s: int = (Time.get_ticks_msec() - session_start_msec) / 1000
	var mm: int = elapsed_s / 60
	var ss: int = elapsed_s % 60
	var rate_sign: String = "↗" if current_rate >= 0.0 else "↘"
	hud_label.text = "💰 $%s   ⭐ Rep %d%%   🪜 Stage %d/4 · %s   🎯 next: $%s\n⏱ %d:%02d   %s $%+.2f/s   🧑 served: %d   ✨ perfect: %d / 🔥 burnt: %d" % [
		_fmt_money(money), int(rep * 100.0), stage, STAGE_NAMES[stage], _fmt_money(STAGE_GOALS[stage]),
		mm, ss, rate_sign, current_rate,
		int(customers_served), int(total_perfect), int(total_burnt),
	]


func _on_metrics_tick() -> void:
	current_rate = money - money_last_tick
	money_last_tick = money
	_refresh_hud()


func _record_cups(count: float, perfect_rate: float, burnt_rate: float) -> void:
	if count <= 0.0:
		return
	customers_served += count
	total_perfect += count * perfect_rate
	total_burnt += count * burnt_rate
	# the rest are split between good/mediocre — not separately tracked in late stages
	total_good += count * (1.0 - perfect_rate - burnt_rate) * 0.7
	total_mediocre += count * (1.0 - perfect_rate - burnt_rate) * 0.3


func _dev_skip_stage() -> void:
	if stage >= 4:
		money += 1_000_000.0
		_notify("[dev] +$1M for stage 4 testing.")
		_refresh_stage_4_ui()
		_refresh_hud()
		return
	# fast-forward: bump money to comfortably enter the next stage
	money = maxf(money, STAGE_GOALS[stage] + 100.0)
	_enter_stage(stage + 1)


func _notify(msg: String) -> void:
	notif_label.text = msg


func _fmt_money(amount: float) -> String:
	if amount >= 1_000_000.0:
		return "%.2fM" % (amount / 1_000_000.0)
	if amount >= 1_000.0:
		return "%.1fk" % (amount / 1_000.0)
	return "%.2f" % amount


# ============================================================
#  STAGE 1 — Office Coffee Juffrouw
# ============================================================
func _setup_stage_1() -> void:
	_stage_title("☕  Office Coffee Juffrouw — brew well or they'll bring their own machines")

	beans_label = _make_stage_label(Vector2(20, 50))
	milk_label = _make_stage_label(Vector2(180, 50))
	quality_label = _make_stage_label(Vector2(340, 50))
	office_label = _make_stage_label(Vector2(540, 50))

	var qh: Label = Label.new()
	qh.text = "Colleagues — click to start brewing, click again on the green zone for a perfect cup:"
	qh.position = Vector2(20, 92)
	qh.size = Vector2(920, 28)
	qh.modulate = STAGE_FG[1]
	stage_view.add_child(qh)

	queue_box = HBoxContainer.new()
	queue_box.position = Vector2(20, 124)
	queue_box.size = Vector2(920, 110)
	queue_box.add_theme_constant_override("separation", 8)
	stage_view.add_child(queue_box)

	_make_stage_button("Buy beans (10) — $5", Vector2(20, 260), _buy_beans)
	_make_stage_button("Buy milk (10) — $3", Vector2(260, 260), _buy_milk)
	_make_stage_button("Steamer — $30", Vector2(500, 260), _buy_steamer)
	_make_stage_button("Faster spawns — $40", Vector2(740, 260), _buy_machine)
	_make_stage_button("PROMOTE → Café Owner", Vector2(20, 330), _try_promote)

	spawn_timer.wait_time = 3.0
	spawn_timer.start()
	_update_s1_labels()


func _update_s1_labels() -> void:
	if beans_label != null:
		beans_label.text = "🫘 Beans: %d" % beans
	if milk_label != null:
		milk_label.text = "🥛 Milk: %d" % milk
	if quality_label != null:
		quality_label.text = "✨ Quality: %d%%" % int(quality * 100.0)
	if office_label != null:
		office_label.text = "🏢 Loyal: %d/%d" % [OFFICE_SIZE - defected, OFFICE_SIZE]


func _spawn_colleague() -> void:
	if queue_box == null:
		return
	var active: int = OFFICE_SIZE - defected
	if active <= 0:
		_notify("Everyone brought their own pod machine. You need to promote out of here.")
		return
	if queue.size() >= mini(active, 4):
		return
	# spawn chance scales with quality
	if randf() > 0.35 + quality * 0.65:
		return
	var pool: Array[Dictionary] = [DRINK_ESPRESSO]
	if has_steamer:
		pool.append(DRINK_CAPPUCCINO)
		pool.append(DRINK_LATTE)
	var drink: Dictionary = pool.pick_random()

	var btn: Button = Button.new()
	btn.text = "🧑\n%s\nclick" % String(drink["emoji"])
	btn.custom_minimum_size = Vector2(86, 96)
	var entry: Dictionary = {"drink": drink, "button": btn, "brewing": false}
	btn.pressed.connect(_start_brew.bind(entry))
	queue_box.add_child(btn)
	queue.append(entry)


func _start_brew(entry: Dictionary) -> void:
	if bool(entry.get("brewing", false)):
		return
	var drink: Dictionary = entry["drink"]
	var btn: Button = entry["button"]
	var need_beans: int = int(drink["beans"])
	var need_milk: int = int(drink["milk"])
	if beans < need_beans:
		_notify("Out of beans — buy more.")
		return
	if need_milk > 0 and milk < need_milk:
		_notify("Out of milk!")
		return
	beans -= need_beans
	milk -= need_milk
	_update_s1_labels()
	_refresh_hud()

	var bar: BrewBar = BrewBar.new()
	bar.label_text = "🧑 %s\nclick green!" % String(drink["emoji"])
	bar.sweet_min = float(drink["sweet_min"])
	bar.sweet_max = float(drink["sweet_max"])
	bar.evaluated.connect(_brew_finished.bind(entry, bar))
	var idx: int = btn.get_index()
	queue_box.add_child(bar)
	queue_box.move_child(bar, idx)
	btn.queue_free()
	entry["button"] = bar
	entry["brewing"] = true


func _brew_finished(grade: String, entry: Dictionary, bar: BrewBar) -> void:
	var drink: Dictionary = entry["drink"]
	var base_price: int = int(drink["price"])
	var max_tip: int = int(drink["tip"])
	var revenue: float = 0.0
	var q_delta: float = 0.0
	var defect_chance: float = 0.0
	var msg: String = ""
	match grade:
		"perfect":
			revenue = float(base_price) + float(max_tip) * 1.4
			q_delta = 0.05
			total_perfect += 1.0
			msg = "✨ Perfect %s — $%d (incl. tip)" % [String(drink["name"]), int(revenue)]
		"good":
			revenue = float(base_price) + float(max_tip) * 0.6
			q_delta = 0.01
			total_good += 1.0
			msg = "👍 Decent %s — $%d" % [String(drink["name"]), int(revenue)]
		"mediocre":
			revenue = float(base_price) * 0.5
			q_delta = -0.04
			defect_chance = 0.10
			total_mediocre += 1.0
			msg = "😐 Meh %s — $%d (no tip)" % [String(drink["name"]), int(revenue)]
		_:  # "burnt"
			revenue = 0.0
			q_delta = -0.08
			defect_chance = 0.30
			total_burnt += 1.0
			msg = "🔥 Burnt the %s — refund." % String(drink["name"])
	money += revenue
	customers_served += 1.0
	quality = clampf(quality + q_delta, 0.0, 1.0)
	rep = quality
	if defect_chance > 0.0 and randf() < defect_chance and defected < OFFICE_SIZE:
		defected += 1
		msg += "  💔 colleague brought their own pod machine."
	queue.erase(entry)
	bar.queue_free()
	_notify(msg)
	_update_s1_labels()
	_refresh_hud()


func _buy_beans() -> void:
	if money < 5.0:
		_notify("Not enough money for beans.")
		return
	money -= 5.0
	beans += 10
	_update_s1_labels()
	_refresh_hud()


func _buy_milk() -> void:
	if money < 3.0:
		_notify("Not enough money for milk.")
		return
	money -= 3.0
	milk += 10
	_update_s1_labels()
	_refresh_hud()


func _buy_steamer() -> void:
	if has_steamer:
		_notify("You already have a steamer.")
		return
	if money < 30.0:
		_notify("Need $30 for the steamer.")
		return
	money -= 30.0
	has_steamer = true
	_notify("Steamer unlocked — cappuccinos and lattes coming up.")
	_refresh_hud()


func _buy_machine() -> void:
	if money < 40.0:
		_notify("Need $40 for a faster machine.")
		return
	if spawn_timer.wait_time <= 1.0:
		_notify("Machine is already maxed out.")
		return
	money -= 40.0
	spawn_timer.wait_time = maxf(spawn_timer.wait_time - 0.5, 1.0)
	_notify("Faster machine — colleagues come more often.")
	_refresh_hud()


# ============================================================
#  STAGE 2 — Café Owner
# ============================================================
func _setup_stage_2() -> void:
	_stage_title("☕  Café Owner — supplies and equipment matter now")

	_make_stage_button("Hire barista", Vector2(20, 50), _hire_barista)
	_make_stage_button("Raise prices +10%", Vector2(260, 50), _raise_prices)
	_make_stage_button("PROMOTE → Chain CEO", Vector2(500, 50), _try_promote)

	s2_status = Label.new()
	s2_status.position = Vector2(20, 110)
	s2_status.size = Vector2(920, 50)
	s2_status.modulate = STAGE_FG[2]
	s2_status.add_theme_font_size_override("font_size", 14)
	stage_view.add_child(s2_status)

	# --- suppliers ---
	var sup_h: Label = Label.new()
	sup_h.text = "🌍  BEAN SUPPLIERS — pick one (cost & quality affect revenue)"
	sup_h.position = Vector2(20, 165)
	sup_h.size = Vector2(920, 24)
	sup_h.modulate = STAGE_FG[2]
	sup_h.add_theme_font_size_override("font_size", 14)
	stage_view.add_child(sup_h)

	supplier_buttons.clear()
	for i in range(SUPPLIERS.size()):
		var col: int = i % 2
		var row: int = i / 2
		var b: Button = _make_stage_button(
			"",
			Vector2(20 + col * 460, 195 + row * 38),
			_choose_supplier.bind(i),
			Vector2(440, 32),
		)
		supplier_buttons.append(b)

	# --- machine ---
	var mh: Label = Label.new()
	mh.text = "🛠️  ESPRESSO MACHINE — gauges drift each second, keep them healthy"
	mh.position = Vector2(20, 285)
	mh.size = Vector2(920, 24)
	mh.modulate = STAGE_FG[2]
	mh.add_theme_font_size_override("font_size", 14)
	stage_view.add_child(mh)

	machine_clean_bar = _make_gauge(Vector2(20, 318), "Cleanliness")
	machine_calib_bar = _make_gauge(Vector2(20, 354), "Calibration")
	machine_press_bar = _make_gauge(Vector2(20, 390), "Pressure")

	_make_stage_button("Clean", Vector2(670, 314), _clean_machine, Vector2(120, 32))
	_make_stage_button("Calibrate", Vector2(670, 350), _calibrate_machine, Vector2(120, 32))
	_make_stage_button("Tune", Vector2(670, 386), _tune_machine, Vector2(120, 32))

	revenue_timer.wait_time = 1.0
	revenue_timer.start()
	_refresh_stage_2_ui()


func _hire_barista() -> void:
	var cost: float = 50.0 + float(baristas) * 50.0
	if money < cost:
		_notify("Need $%d to hire next barista." % int(cost))
		return
	money -= cost
	baristas += 1
	_refresh_stage_2_ui()
	_refresh_hud()


func _raise_prices() -> void:
	cafe_price_mult += 0.1
	rep = maxf(rep - 0.05, 0.0)
	_notify("Prices up 10%, rep took a small hit.")
	_refresh_stage_2_ui()
	_refresh_hud()


func _choose_supplier(idx: int) -> void:
	current_supplier = idx
	_notify("Now sourcing from %s." % String(SUPPLIERS[idx]["name"]))
	_refresh_stage_2_ui()


func _clean_machine() -> void:
	machine_clean = 1.0
	_notify("Machine wiped down — clean.")
	_refresh_stage_2_ui()


func _calibrate_machine() -> void:
	machine_calibration = 1.0
	_notify("Calibrated — pulls dialed in.")
	_refresh_stage_2_ui()


func _tune_machine() -> void:
	machine_pressure = 1.0
	_notify("Pressure tuned to 9 bar.")
	_refresh_stage_2_ui()


func _stage_2_machine_health() -> float:
	return (machine_clean + machine_calibration + machine_pressure) / 3.0


func _stage_2_revenue_per_sec() -> float:
	var sup: Dictionary = SUPPLIERS[current_supplier]
	var multiplier: float = 0.3 + 0.7 * _stage_2_machine_health()
	var gross: float = float(baristas) * 5.0 * cafe_price_mult * float(sup["quality"]) * multiplier
	return gross - float(sup["cost"])


func _refresh_stage_2_ui() -> void:
	# supplier buttons
	for i in range(SUPPLIERS.size()):
		if i >= supplier_buttons.size():
			continue
		var sup: Dictionary = SUPPLIERS[i]
		var marker: String = "▶  " if i == current_supplier else "    "
		var cost_str: String = "free" if float(sup["cost"]) == 0.0 else "$%.1f/s" % float(sup["cost"])
		supplier_buttons[i].text = "%s%s %s — %s, ×%.2f quality" % [
			marker, String(sup["tag"]), String(sup["name"]), cost_str, float(sup["quality"]),
		]
	# gauges
	if machine_clean_bar != null:
		machine_clean_bar.value = machine_clean
	if machine_calib_bar != null:
		machine_calib_bar.value = machine_calibration
	if machine_press_bar != null:
		machine_press_bar.value = machine_pressure
	# stats line
	if s2_status != null:
		var sup: Dictionary = SUPPLIERS[current_supplier]
		var net: float = _stage_2_revenue_per_sec()
		var next_cost: int = int(50.0 + float(baristas) * 50.0)
		s2_status.text = "Baristas: %d  ·  Price: %.1fx  ·  Supplier: %s  ·  Machine health: %d%%  ·  Net: $%+.2f/s  ·  Next barista: $%d" % [
			baristas, cafe_price_mult, String(sup["name"]),
			int(_stage_2_machine_health() * 100.0), net, next_cost,
		]


# ============================================================
#  STAGE 3 — Chain CEO
# ============================================================
func _setup_stage_3() -> void:
	_stage_title("🏢  Chain CEO — visit locations to keep promo meters topped up")

	var blurb: Label = Label.new()
	blurb.text = "Each branch has a promo meter that drains. Revenue = base × manager × promo. Visit a branch to push promo back to 100%. Managers slow the drain (but cost $5/s)."
	blurb.position = Vector2(20, 40)
	blurb.size = Vector2(920, 28)
	blurb.modulate = STAGE_FG[3]
	blurb.add_theme_font_size_override("font_size", 12)
	stage_view.add_child(blurb)

	_make_stage_button("Open new location", Vector2(20, 78), _buy_location)
	_make_stage_button("Hire next manager — $200", Vector2(260, 78), _hire_manager)
	_make_stage_button("PROMOTE → Corporate CEO", Vector2(500, 78), _try_promote)

	s3_list = VBoxContainer.new()
	s3_list.position = Vector2(20, 140)
	s3_list.size = Vector2(920, 280)
	s3_list.add_theme_constant_override("separation", 4)
	stage_view.add_child(s3_list)

	s3_status = Label.new()
	s3_status.position = Vector2(20, 430)
	s3_status.size = Vector2(920, 28)
	s3_status.modulate = STAGE_FG[3]
	s3_status.add_theme_font_size_override("font_size", 14)
	stage_view.add_child(s3_status)

	revenue_timer.wait_time = 1.0
	revenue_timer.start()
	_refresh_stage_3_ui()


func _buy_location() -> void:
	var cost: float = 500.0 * pow(1.6, float(locations.size()))
	if money < cost:
		_notify("Need $%s for location #%d." % [_fmt_money(cost), locations.size() + 1])
		return
	money -= cost
	var base_rev: float = 25.0 * pow(1.25, float(locations.size()))
	locations.append({
		"name": "Branch #%d" % (locations.size() + 1),
		"base_revenue": base_rev,
		"manager": false,
		"promotion": 1.0,
	})
	_refresh_stage_3_ui()
	_refresh_hud()


func _hire_manager() -> void:
	for loc in locations:
		if not bool(loc.get("manager", false)):
			if money < 200.0:
				_notify("Need $200 for next manager.")
				return
			money -= 200.0
			loc["manager"] = true
			_refresh_stage_3_ui()
			_refresh_hud()
			return
	_notify("All locations have managers.")


func _visit_location(idx: int) -> void:
	if idx < 0 or idx >= locations.size():
		return
	var loc: Dictionary = locations[idx]
	loc["promotion"] = 1.0
	_notify("Visited %s — promo back to 100%%." % String(loc.get("name", "?")))
	_refresh_stage_3_ui()
	_refresh_hud()


func _location_gross_revenue(loc: Dictionary) -> float:
	var base: float = float(loc.get("base_revenue", 0.0))
	var mgr_mult: float = 2.0 if bool(loc.get("manager", false)) else 1.0
	var promo: float = float(loc.get("promotion", 0.0))
	return base * mgr_mult * promo


func _location_net_revenue(loc: Dictionary) -> float:
	var gross: float = _location_gross_revenue(loc)
	var mgr_cost: float = MANAGER_SALARY if bool(loc.get("manager", false)) else 0.0
	return gross - mgr_cost


func _format_location_row(loc: Dictionary) -> String:
	var net: float = _location_net_revenue(loc)
	var mgr_str: String = "👔" if bool(loc.get("manager", false)) else "·  "
	return "%s  %s   $%+5.1f/s net" % [
		mgr_str, String(loc.get("name", "?")), net,
	]


func _add_s3_row(idx: int) -> void:
	if s3_list == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info: Label = Label.new()
	info.size = Vector2(280, 28)
	info.custom_minimum_size = Vector2(280, 28)
	info.modulate = STAGE_FG[3]
	info.add_theme_font_size_override("font_size", 13)
	row.add_child(info)

	var bar: ProgressBar = ProgressBar.new()
	bar.size = Vector2(380, 24)
	bar.custom_minimum_size = Vector2(380, 24)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = true
	row.add_child(bar)

	var visit_btn: Button = Button.new()
	visit_btn.text = "Visit & promote"
	visit_btn.size = Vector2(160, 26)
	visit_btn.custom_minimum_size = Vector2(160, 26)
	visit_btn.pressed.connect(_visit_location.bind(idx))
	row.add_child(visit_btn)

	s3_list.add_child(row)
	s3_rows.append({"info": info, "promo": bar, "visit": visit_btn})


func _refresh_stage_3_ui() -> void:
	while s3_rows.size() < locations.size():
		_add_s3_row(s3_rows.size())
	for i in range(locations.size()):
		if i >= s3_rows.size():
			continue
		var row: Dictionary = s3_rows[i]
		var loc: Dictionary = locations[i]
		(row["info"] as Label).text = _format_location_row(loc)
		(row["promo"] as ProgressBar).value = float(loc.get("promotion", 0.0))
	if s3_status != null:
		var total_net: float = 0.0
		var mgrs: int = 0
		for loc in locations:
			total_net += _location_net_revenue(loc)
			if bool(loc.get("manager", false)):
				mgrs += 1
		var next_cost: float = 500.0 * pow(1.6, float(locations.size()))
		s3_status.text = "📊  %d locations · %d managers · NET $%+.1f/s   ·   next location: $%s" % [
			locations.size(), mgrs, total_net, _fmt_money(next_cost),
		]


# ============================================================
#  STAGE 4 — Corporate CEO
# ============================================================
func _setup_stage_4() -> void:
	_stage_title("💼  Corporate CEO — payroll, suppliers, cartels. Reach $10M to IPO.")

	var blurb: Label = Label.new()
	blurb.text = "Holding company. Manage staff, negotiate wages, get bulk discounts, optionally form a cartel (risky)."
	blurb.position = Vector2(20, 36)
	blurb.size = Vector2(920, 22)
	blurb.modulate = STAGE_FG[4]
	blurb.add_theme_font_size_override("font_size", 12)
	stage_view.add_child(blurb)

	# Row 1 — capital actions
	_make_stage_button("Marketing — $1k", Vector2(20, 66), _buy_marketing, Vector2(220, 42))
	_make_stage_button("Buyback — $5k", Vector2(250, 66), _buy_stock, Vector2(220, 42))
	cartel_button = _make_stage_button("Form cartel", Vector2(480, 66), _toggle_cartel, Vector2(220, 42))
	_make_stage_button("Layoff round", Vector2(710, 66), _layoff_round, Vector2(220, 42))

	# Row 2 — HR & sourcing
	_make_stage_button("Hire 5 corp — $1k", Vector2(20, 116), _hire_corporate, Vector2(220, 42))
	_make_stage_button("Raise wages +10%", Vector2(250, 116), _raise_wages, Vector2(220, 42))
	_make_stage_button("Cut wages −10%", Vector2(480, 116), _cut_wages, Vector2(220, 42))
	bulk_button = _make_stage_button("Bulk", Vector2(710, 116), _buy_bulk_tier, Vector2(220, 42))

	s4_status = Label.new()
	s4_status.position = Vector2(20, 175)
	s4_status.size = Vector2(920, 280)
	s4_status.modulate = STAGE_FG[4]
	s4_status.add_theme_font_size_override("font_size", 14)
	stage_view.add_child(s4_status)

	revenue_timer.wait_time = 1.0
	revenue_timer.start()
	_refresh_stage_4_ui()


func _buy_marketing() -> void:
	if money < 1000.0:
		_notify("Need $1000.")
		return
	money -= 1000.0
	marketing_level += 1
	_refresh_stage_4_ui()
	_refresh_hud()


func _buy_stock() -> void:
	if money < 5000.0:
		_notify("Need $5000.")
		return
	money -= 5000.0
	stock_price += 5.0
	_refresh_stage_4_ui()
	_refresh_hud()


func _hire_corporate() -> void:
	if money < 1000.0:
		_notify("Need $1000 to hire 5 corporate staff.")
		return
	money -= 1000.0
	corporate_staff += 5
	morale = clampf(morale + 0.05, 0.0, 1.0)
	_notify("+5 corporate staff hired.")
	_refresh_stage_4_ui()
	_refresh_hud()


func _raise_wages() -> void:
	staff_salary *= 1.10
	morale = clampf(morale + 0.10, 0.0, 1.0)
	_notify("Wages raised 10%. Morale up.")
	_refresh_stage_4_ui()
	_refresh_hud()


func _cut_wages() -> void:
	staff_salary = maxf(staff_salary * 0.90, 5.0)
	morale = clampf(morale - 0.15, 0.0, 1.0)
	if morale < 0.30 and randf() < 0.5 and strike_seconds == 0:
		strike_seconds = 30
		_notify("⚠  STRIKE — staff walked out. No income for 30s.")
	else:
		_notify("Wages cut 10%. Morale dropped.")
	_refresh_stage_4_ui()
	_refresh_hud()


func _layoff_round() -> void:
	if corporate_staff <= 2:
		_notify("Staff already minimal — can't lay off more.")
		return
	if layoff_cooldown > 0:
		_notify("Last layoff impact still settling — wait %ds." % layoff_cooldown)
		return
	var cut_count: int = maxi(int(float(corporate_staff) * 0.30), 1)
	var severance: float = float(cut_count) * staff_salary * 5.0
	if money < severance:
		_notify("Need $%s for severance." % _fmt_money(severance))
		return
	money -= severance
	corporate_staff -= cut_count
	morale = clampf(morale - 0.20, 0.0, 1.0)
	layoff_cooldown = 60
	_notify("Laid off %d. Severance $%s. Morale −20." % [cut_count, _fmt_money(severance)])
	_refresh_stage_4_ui()
	_refresh_hud()


func _toggle_cartel() -> void:
	cartel_active = not cartel_active
	if cartel_active:
		_notify("⚠  Cartel formed — revenue ×2, antitrust risk rising.")
	else:
		_notify("Cartel dissolved. Risk decays.")
	_refresh_stage_4_ui()


func _buy_bulk_tier() -> void:
	var next_tier: int = bulk_tier + 1
	if next_tier >= BULK_TIERS.size():
		_notify("Already at the top bulk tier.")
		return
	var cost: float = float(BULK_TIERS[next_tier]["cost"])
	if money < cost:
		_notify("Need $%s for %s." % [_fmt_money(cost), String(BULK_TIERS[next_tier]["name"])])
		return
	money -= cost
	bulk_tier = next_tier
	_notify("Upgraded to %s — supplier overhead × %.2f." % [
		String(BULK_TIERS[bulk_tier]["name"]), float(BULK_TIERS[bulk_tier]["discount"]),
	])
	_refresh_stage_4_ui()
	_refresh_hud()


func _stage_4_payroll() -> float:
	# low morale increases cost (overtime, replacements)
	var morale_factor: float = 1.0 + maxf(0.0, 0.7 - morale) * 0.6
	return float(corporate_staff) * staff_salary * morale_factor


func _stage_4_supplier_overhead() -> float:
	# overhead scales with chain size, reduced by bulk tier
	var base: float = 50.0 + float(locations.size()) * 30.0
	return base * float(BULK_TIERS[bulk_tier]["discount"])


func _stage_4_gross_revenue() -> float:
	if strike_seconds > 0:
		return 0.0
	var marketing_boost: float = 1.0 + float(marketing_level) * 0.15
	var cartel_mult: float = 2.0 if cartel_active else 1.0
	return stock_price * 100.0 * marketing_boost * cartel_mult


func _stage_4_net_revenue() -> float:
	return _stage_4_gross_revenue() - _stage_4_payroll() - _stage_4_supplier_overhead()


func _refresh_stage_4_ui() -> void:
	if cartel_button != null:
		cartel_button.text = "Break cartel" if cartel_active else "Form cartel"
	if bulk_button != null:
		var nt: int = bulk_tier + 1
		if nt < BULK_TIERS.size():
			bulk_button.text = "Buy %s — $%s" % [
				String(BULK_TIERS[nt]["name"]),
				_fmt_money(float(BULK_TIERS[nt]["cost"])),
			]
			bulk_button.disabled = false
		else:
			bulk_button.text = "Bulk maxed (×0.40)"
			bulk_button.disabled = true
	if s4_status == null:
		return
	var lines: Array[String] = []
	lines.append("📈  Stock $%.2f   Marketing lv %d   Gross $%s/s   Net $%+s/s" % [
		stock_price, marketing_level,
		_fmt_money(_stage_4_gross_revenue()),
		_fmt_money(_stage_4_net_revenue()),
	])
	lines.append("👥  Staff: %d heads   Salary: $%.1f/head/s   Morale: %d%%   Payroll: $%s/s" % [
		corporate_staff, staff_salary, int(morale * 100.0), _fmt_money(_stage_4_payroll()),
	])
	lines.append("📦  Bulk: %s (×%.2f)   Supplier overhead: $%s/s" % [
		String(BULK_TIERS[bulk_tier]["name"]),
		float(BULK_TIERS[bulk_tier]["discount"]),
		_fmt_money(_stage_4_supplier_overhead()),
	])
	if cartel_active:
		lines.append("⚖  Cartel ACTIVE — antitrust risk: %d%%" % int(antitrust_risk * 100.0))
	else:
		lines.append("⚖  Cartel: off (risk decaying: %d%%)" % int(antitrust_risk * 100.0))
	if strike_seconds > 0:
		lines.append("🚨  STRIKE — %ds remaining (no revenue, payroll & overhead still due)" % strike_seconds)
	if layoff_cooldown > 0:
		lines.append("⏳  Layoff impact decaying — %ds" % layoff_cooldown)
	lines.append("")
	lines.append("🎯  Goal: $10M to IPO")
	if won:
		lines.append("")
		lines.append("🏆  Corporate Coffee Inc. is public. You won.")
	s4_status.text = "\n".join(lines)


# ============================================================
#  TIMERS — shared across stages
# ============================================================
func _on_spawn() -> void:
	if stage == 1:
		_spawn_colleague()


func _on_revenue_tick() -> void:
	match stage:
		2:
			machine_clean = clampf(machine_clean - MACHINE_DRIFT_CLEAN, 0.0, 1.0)
			machine_calibration = clampf(machine_calibration - MACHINE_DRIFT_CALIB, 0.0, 1.0)
			machine_pressure = clampf(machine_pressure + randf_range(-0.04, 0.015), 0.0, 1.0)
			money += _stage_2_revenue_per_sec()
			# baristas serve ~1 cup/s each; quality follows machine health
			var s2_health: float = _stage_2_machine_health()
			_record_cups(
				float(baristas),
				0.45 + 0.30 * s2_health,   # perfect rate: 45–75%
				maxf(0.02, 0.15 - 0.10 * s2_health),  # burnt rate: 5–15%
			)
			_refresh_stage_2_ui()
		3:
			var total_net: float = 0.0
			var total_gross: float = 0.0
			for loc in locations:
				var managed: bool = bool(loc.get("manager", false))
				var drain: float = PROMO_DRAIN_MANAGED if managed else PROMO_DRAIN_BASE
				loc["promotion"] = clampf(float(loc.get("promotion", 0.0)) - drain, 0.0, 1.0)
				total_net += _location_net_revenue(loc)
				total_gross += _location_gross_revenue(loc)
			money += total_net
			# cups derived from gross at ~$5/cup; chains run smoothly
			_record_cups(total_gross / 5.0, 0.55, 0.05)
			_refresh_stage_3_ui()
		4:
			if strike_seconds > 0:
				strike_seconds -= 1
			if layoff_cooldown > 0:
				layoff_cooldown -= 1
			var drift: float = randf_range(-2.0, 2.0) + float(marketing_level) * 0.6
			if cartel_active:
				drift += 1.2
			stock_price = maxf(stock_price + drift, 1.0)
			# antitrust risk dynamics
			if cartel_active:
				antitrust_risk = clampf(antitrust_risk + 0.006, 0.0, 1.0)
				if randf() < antitrust_risk * 0.025:
					var fine: float = 1_000_000.0 + stock_price * 100.0
					money -= fine
					cartel_active = false
					antitrust_risk = 0.0
					_notify("⚖  ANTITRUST FINE — $%s. Cartel busted." % _fmt_money(fine))
			else:
				antitrust_risk = clampf(antitrust_risk - 0.012, 0.0, 1.0)
			# slow morale recovery
			morale = clampf(morale + 0.005, 0.0, 1.0)
			money += _stage_4_net_revenue()
			# corporate scale: cups derived from gross at ~$8/cup blended
			var s4_perfect_rate: float = 0.45 + 0.10 * morale  # morale tilts perfect rate
			_record_cups(_stage_4_gross_revenue() / 8.0, s4_perfect_rate, 0.05)
			_check_win()
			_refresh_stage_4_ui()
	_refresh_hud()


# ============================================================
#  PROMOTION
# ============================================================
func _try_promote() -> void:
	var goal: float = STAGE_GOALS[stage]
	if money < goal:
		_notify("Need $%s to promote (you have $%s)." % [_fmt_money(goal), _fmt_money(money)])
		return
	if stage < 4:
		_enter_stage(stage + 1)


func _check_win() -> void:
	if won:
		return
	if money >= 10_000_000.0:
		won = true
		_notify("🏆  YOU WON — Corporate Coffee Inc. is a household name.")
		revenue_timer.stop()


# ============================================================
#  UI HELPERS
# ============================================================
func _stage_title(text: String) -> void:
	var l: Label = Label.new()
	l.text = text
	l.position = Vector2(20, 0)
	l.size = Vector2(920, 36)
	l.modulate = STAGE_FG[stage]
	l.add_theme_font_size_override("font_size", 22)
	stage_view.add_child(l)


func _make_stage_label(pos: Vector2) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = Vector2(200, 28)
	l.modulate = STAGE_FG[stage]
	stage_view.add_child(l)
	return l


func _make_stage_button(text: String, pos: Vector2, handler: Callable, button_size: Vector2 = Vector2(220, 48)) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.position = pos
	b.size = button_size
	b.pressed.connect(handler)
	stage_view.add_child(b)
	return b


func _make_gauge(pos: Vector2, label: String) -> ProgressBar:
	var l: Label = Label.new()
	l.text = label
	l.position = pos
	l.size = Vector2(120, 28)
	l.modulate = STAGE_FG[stage]
	stage_view.add_child(l)
	var p: ProgressBar = ProgressBar.new()
	p.position = pos + Vector2(130, 4)
	p.size = Vector2(480, 20)
	p.min_value = 0.0
	p.max_value = 1.0
	p.show_percentage = true
	stage_view.add_child(p)
	return p


# ============================================================
#  BREW MINIGAME WIDGET
# ============================================================
class BrewBar extends Control:
	signal evaluated(grade: String)

	var progress: float = 0.0
	var speed: float = 0.85  # ~1.18s to fill
	var sweet_min: float = 0.6
	var sweet_max: float = 0.8
	var locked: bool = false
	var label_text: String = ""
	var _label: Label

	func _ready() -> void:
		custom_minimum_size = Vector2(150, 96)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_label = Label.new()
		_label.text = label_text
		_label.position = Vector2(8, 6)
		_label.size = Vector2(140, 56)
		_label.add_theme_color_override("font_color", Color(0.15, 0.08, 0.05))
		_label.add_theme_font_size_override("font_size", 12)
		add_child(_label)

	func _process(delta: float) -> void:
		if locked:
			return
		progress += delta * speed
		if progress >= 1.0:
			progress = 1.0
			locked = true
			evaluated.emit("burnt")
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if locked:
			return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_lock_in()

	func _lock_in() -> void:
		if locked:
			return
		locked = true
		var grade: String
		if progress >= sweet_min and progress <= sweet_max:
			grade = "perfect"
		elif progress >= sweet_min - 0.10 and progress <= sweet_max + 0.10:
			grade = "good"
		else:
			grade = "mediocre"
		evaluated.emit(grade)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		# bar area sits at the bottom 28px
		var bar_top: float = h - 32.0
		var bar_h: float = 24.0
		var bar_w: float = w - 8.0
		var bar_x: float = 4.0
		# border
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.30, 0.20, 0.10), false, 2.0)
		# bar bg
		draw_rect(Rect2(Vector2(bar_x, bar_top), Vector2(bar_w, bar_h)), Color(0.92, 0.86, 0.74))
		# sweet zone
		var sx: float = bar_x + sweet_min * bar_w
		var sw: float = (sweet_max - sweet_min) * bar_w
		draw_rect(Rect2(Vector2(sx, bar_top), Vector2(sw, bar_h)), Color(0.45, 0.85, 0.45, 0.85))
		# progress fill
		draw_rect(Rect2(Vector2(bar_x, bar_top), Vector2(progress * bar_w, bar_h)), Color(0.55, 0.35, 0.18, 0.35))
		# indicator
		var ix: float = bar_x + progress * bar_w
		draw_line(Vector2(ix, bar_top - 2), Vector2(ix, bar_top + bar_h + 2), Color(0.15, 0.08, 0.05), 3.0)

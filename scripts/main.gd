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

# --- chart histories (universal, populated each metrics tick) ---
var quality_history: Array[float] = []
var machine_clean_history: Array[float] = []
var machine_calib_history: Array[float] = []
var machine_press_history: Array[float] = []
var avg_promo_history: Array[float] = []

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
const MAX_TRAINING: int = 3
const TRAINING_DRAIN_MULT: float = 0.70   # each level multiplies drain by this
const TRAINING_COSTS: Array[float] = [300.0, 600.0, 1200.0]  # cost for level 1, 2, 3

# --- stage 4 (corporate) ---
var stock_price: float = 100.0
var marketing_level: int = 0
var corporate_staff: int = 8
var staff_salary: float = 25.0  # $/head/s base
var morale: float = 0.7
var arabica_tier: int = 0
var robusta_tier: int = 0
var milk_tier: int = 0
var cartel_active: bool = false
var antitrust_risk: float = 0.0
var strike_seconds: int = 0
var layoff_cooldown: int = 0
var shares_owned: int = 0
var stock_history: Array[float] = []
var arabica_price: float = 100.0
var robusta_price: float = 80.0
var milk_price: float = 50.0
var arabica_history: Array[float] = []
var robusta_history: Array[float] = []
var milk_history: Array[float] = []
const BUYBACK_BLOCK_SHARES: int = 100
const BUYBACK_REVENUE_PER_SHARE: float = 0.5
const HISTORY_LEN: int = 32
const SPARK_CHARS: Array[String] = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

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
const STAGE_GOALS: Array[float] = [0.0, 200.0, 2000.0, 100000.0, 100000000.0]
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
var hud_panel: Panel
var hud_label: RichTextLabel
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
var arabica_lock_btn: Button
var robusta_lock_btn: Button
var milk_lock_btn: Button
var buyback_button: Button
var stock_chart_title: Label
var stock_chart: Control
var arabica_chart_title: Label
var arabica_chart: Control
var robusta_chart_title: Label
var robusta_chart: Control
var milk_chart_title: Label
var milk_chart: Control
var s1_quality_chart_title: Label
var s1_quality_chart: Control
var s2_machine_chart_title: Label
var s2_machine_chart: Control
var s3_promo_chart_title: Label
var s3_promo_chart: Control
var metrics_timer: Timer
var dev_skip_button: Button

# --- audio (synthesized at startup) ---
const SR: int = 22050
var sfx_brew_start: AudioStreamPlayer
var sfx_perfect: AudioStreamPlayer
var sfx_good: AudioStreamPlayer
var sfx_mediocre: AudioStreamPlayer
var sfx_burnt: AudioStreamPlayer
var sfx_defect: AudioStreamPlayer
var s2_audio_timer: Timer


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

	hud_panel = Panel.new()
	hud_panel.position = Vector2(8, 4)
	hud_panel.size = Vector2(944, 56)
	var hud_sb: StyleBoxFlat = StyleBoxFlat.new()
	hud_sb.bg_color = Color(0.10, 0.11, 0.14, 0.92)
	hud_sb.corner_radius_top_left = 8
	hud_sb.corner_radius_top_right = 8
	hud_sb.corner_radius_bottom_left = 8
	hud_sb.corner_radius_bottom_right = 8
	hud_sb.border_color = Color(1.0, 1.0, 1.0, 0.10)
	hud_sb.border_width_left = 1
	hud_sb.border_width_right = 1
	hud_sb.border_width_top = 1
	hud_sb.border_width_bottom = 1
	hud_panel.add_theme_stylebox_override("panel", hud_sb)
	add_child(hud_panel)

	hud_label = RichTextLabel.new()
	hud_label.bbcode_enabled = true
	hud_label.fit_content = true
	hud_label.scroll_active = false
	hud_label.position = Vector2(20, 10)
	hud_label.size = Vector2(740, 50)
	hud_label.add_theme_font_size_override("normal_font_size", 14)
	hud_label.add_theme_font_size_override("bold_font_size", 14)
	add_child(hud_label)

	dev_skip_button = Button.new()
	dev_skip_button.text = "⏭ skip stage"
	dev_skip_button.position = Vector2(778, 16)
	dev_skip_button.size = Vector2(160, 32)
	dev_skip_button.pressed.connect(_dev_skip_stage)
	add_child(dev_skip_button)

	notif_label = Label.new()
	notif_label.position = Vector2(20, 64)
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

	# audio
	sfx_brew_start = _make_sfx(_synth_tone(700.0, 0.08, 0.45))
	sfx_perfect = _make_sfx(_synth_chime(880.0, 1320.0, 0.45, 0.55))
	sfx_good = _make_sfx(_synth_tone(660.0, 0.15, 0.45))
	sfx_mediocre = _make_sfx(_synth_tone(440.0, 0.20, 0.40))
	sfx_burnt = _make_sfx(_synth_buzz(180.0, 0.50, 0.50))
	sfx_defect = _make_sfx(_synth_descend(440.0, 220.0, 0.60, 0.45))

	s2_audio_timer = Timer.new()
	s2_audio_timer.timeout.connect(_on_s2_audio_tick)
	add_child(s2_audio_timer)


func _enter_stage(s: int) -> void:
	stage = s
	bg.color = STAGE_BG[s]
	var fg: Color = STAGE_FG[s]
	# hud_label uses BBCode colors, no per-stage tinting
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
	arabica_lock_btn = null
	robusta_lock_btn = null
	milk_lock_btn = null
	buyback_button = null
	stock_chart_title = null
	stock_chart = null
	arabica_chart_title = null
	arabica_chart = null
	robusta_chart_title = null
	robusta_chart = null
	milk_chart_title = null
	milk_chart = null
	s1_quality_chart_title = null
	s1_quality_chart = null
	s2_machine_chart_title = null
	s2_machine_chart = null
	s3_promo_chart_title = null
	s3_promo_chart = null
	spawn_timer.stop()
	revenue_timer.stop()
	if s2_audio_timer != null:
		s2_audio_timer.stop()

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
	var rate_color: String = "#7fdcff" if current_rate >= 0.0 else "#ff8c70"
	var rate_sign: String = "↗" if current_rate >= 0.0 else "↘"
	# Two-line dashboard with colored metric chips
	hud_label.text = (
		"[b][color=#f0c040]💰 $%s[/color][/b]"
		+ "   [color=#7fdc8a]⭐ Rep %d%%[/color]"
		+ "   [color=%s]%s $%+.2f/s[/color]"
		+ "   [color=#b8b8c0]⏱ %d:%02d[/color]"
		+ "   [color=#d8c8a0]🧑 %d served[/color]"
		+ "\n[color=#9fc7e8]🪜 Stage %d/4 · %s[/color]"
		+ "   [color=#f0a050]🎯 next: $%s[/color]"
		+ "   [color=#f0c040]✨ %d perfect[/color]"
		+ "   [color=#ff7060]🔥 %d burnt[/color]"
	) % [
		_fmt_money(money),
		int(rep * 100.0),
		rate_color, rate_sign, current_rate,
		mm, ss,
		int(customers_served),
		stage, STAGE_NAMES[stage],
		_fmt_money(STAGE_GOALS[stage]),
		int(total_perfect), int(total_burnt),
	]


func _on_metrics_tick() -> void:
	current_rate = money - money_last_tick
	money_last_tick = money
	_append_histories()
	match stage:
		1: _update_stage_1_charts()
		2: _refresh_stage_2_ui()
		3: _refresh_stage_3_ui()
		4: _refresh_stage_4_ui()
	_refresh_hud()


func _append_histories() -> void:
	quality_history.append(quality)
	if quality_history.size() > HISTORY_LEN:
		quality_history.pop_front()

	machine_clean_history.append(machine_clean)
	machine_calib_history.append(machine_calibration)
	machine_press_history.append(machine_pressure)
	if machine_clean_history.size() > HISTORY_LEN:
		machine_clean_history.pop_front()
	if machine_calib_history.size() > HISTORY_LEN:
		machine_calib_history.pop_front()
	if machine_press_history.size() > HISTORY_LEN:
		machine_press_history.pop_front()

	var sum_promo: float = 0.0
	for loc in locations:
		sum_promo += float(loc.get("promotion", 0.0))
	var avg: float = 0.0
	if locations.size() > 0:
		avg = sum_promo / float(locations.size())
	avg_promo_history.append(avg)
	if avg_promo_history.size() > HISTORY_LEN:
		avg_promo_history.pop_front()

	stock_history.append(stock_price)
	arabica_history.append(arabica_price)
	robusta_history.append(robusta_price)
	milk_history.append(milk_price)
	if stock_history.size() > HISTORY_LEN:
		stock_history.pop_front()
	if arabica_history.size() > HISTORY_LEN:
		arabica_history.pop_front()
	if robusta_history.size() > HISTORY_LEN:
		robusta_history.pop_front()
	if milk_history.size() > HISTORY_LEN:
		milk_history.pop_front()


func _update_stage_1_charts() -> void:
	if s1_quality_chart != null:
		s1_quality_chart.set_values(quality_history)


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

	# Quality trend chart (right of Promote)
	var s1_color: Color = Color(0.55, 0.75, 0.45)
	var s1_panel: Dictionary = _make_chart_panel(Vector2(260, 308), Vector2(380, 72), s1_color)
	s1_quality_chart_title = s1_panel["title"]
	s1_quality_chart = s1_panel["chart"]
	s1_quality_chart_title.text = "✨ Quality trend (last %ds)" % HISTORY_LEN
	(s1_quality_chart as LineChart).set_range(0.0, 1.0)

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
	if sfx_brew_start != null:
		sfx_brew_start.play()

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
			if sfx_perfect != null:
				sfx_perfect.play()
		"good":
			revenue = float(base_price) + float(max_tip) * 0.6
			q_delta = 0.01
			total_good += 1.0
			msg = "👍 Decent %s — $%d" % [String(drink["name"]), int(revenue)]
			if sfx_good != null:
				sfx_good.play()
		"mediocre":
			revenue = float(base_price) * 0.5
			q_delta = -0.04
			defect_chance = 0.10
			total_mediocre += 1.0
			msg = "😐 Meh %s — $%d (no tip)" % [String(drink["name"]), int(revenue)]
			if sfx_mediocre != null:
				sfx_mediocre.play()
		_:  # "burnt"
			revenue = 0.0
			q_delta = -0.08
			defect_chance = 0.30
			total_burnt += 1.0
			msg = "🔥 Burnt the %s — refund." % String(drink["name"])
			if sfx_burnt != null:
				sfx_burnt.play()
	money += revenue
	customers_served += 1.0
	quality = clampf(quality + q_delta, 0.0, 1.0)
	rep = quality
	if defect_chance > 0.0 and randf() < defect_chance and defected < OFFICE_SIZE:
		defected += 1
		msg += "  💔 colleague brought their own pod machine."
		if sfx_defect != null:
			sfx_defect.play()
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
	_make_stage_button("Raise prices +1%", Vector2(260, 50), _raise_prices)
	_make_stage_button("PROMOTE → Chain CEO", Vector2(500, 50), _try_promote)

	s2_status = Label.new()
	s2_status.position = Vector2(20, 110)
	s2_status.size = Vector2(920, 70)
	s2_status.modulate = STAGE_FG[2]
	s2_status.add_theme_font_size_override("font_size", 13)
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

	# Multi-line machine trend chart (right of buttons)
	var s2_color: Color = Color(0.4, 0.55, 0.4)
	var s2_panel: Dictionary = _make_chart_panel(Vector2(810, 308), Vector2(130, 110), s2_color)
	s2_machine_chart_title = s2_panel["title"]
	s2_machine_chart = s2_panel["chart"]
	s2_machine_chart_title.text = "🛠️ Machine trends"
	(s2_machine_chart as LineChart).set_range(0.0, 1.0)

	revenue_timer.wait_time = 1.0
	revenue_timer.start()
	_retune_s2_audio()
	_refresh_stage_2_ui()


func _retune_s2_audio() -> void:
	if s2_audio_timer == null:
		return
	if baristas <= 0:
		s2_audio_timer.stop()
		return
	# 1 brew/sec/barista; clamp to a reasonable range
	s2_audio_timer.wait_time = clampf(1.0 / float(baristas), 0.12, 2.0)
	if s2_audio_timer.is_stopped():
		s2_audio_timer.start()


func _on_s2_audio_tick() -> void:
	if stage != 2 or baristas <= 0:
		return
	var health: float = _stage_2_machine_health()
	var perfect_p: float = 0.45 + 0.30 * health
	var burnt_p: float = maxf(0.02, 0.15 - 0.10 * health)
	var roll: float = randf()
	var sfx: AudioStreamPlayer
	if roll < perfect_p:
		sfx = sfx_perfect
	elif roll > 1.0 - burnt_p:
		sfx = sfx_burnt
	else:
		sfx = sfx_good
	if sfx == null:
		return
	# softer as the café gets busier — 1/sqrt(baristas) in linear gain
	var gain: float = 1.0 / sqrt(maxf(float(baristas), 1.0))
	sfx.volume_db = linear_to_db(clampf(gain, 0.05, 1.0))
	sfx.play()


func _hire_barista() -> void:
	var cost: float = 50.0 + float(baristas) * 50.0
	if money < cost:
		_notify("Need $%d to hire next barista." % int(cost))
		return
	money -= cost
	baristas += 1
	_retune_s2_audio()
	_refresh_stage_2_ui()
	_refresh_hud()


func _raise_prices() -> void:
	cafe_price_mult += 0.01
	rep = maxf(rep - 0.01, 0.0)
	_notify("Prices +1%. Rep −1%.")
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


func _stage_2_rep_multiplier() -> float:
	# rep damage hits revenue hard: at full rep ×1.0, at zero rep ×0.30
	return 0.30 + 0.70 * rep


func _stage_2_revenue_per_sec() -> float:
	var sup: Dictionary = SUPPLIERS[current_supplier]
	var machine_mult: float = 0.30 + 0.70 * _stage_2_machine_health()
	var rep_mult: float = _stage_2_rep_multiplier()
	var gross: float = (
		float(baristas) * 5.0
		* cafe_price_mult
		* float(sup["quality"])
		* machine_mult
		* rep_mult
	)
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
	# machine trend chart
	if s2_machine_chart != null:
		(s2_machine_chart as LineChart).set_series([
			{"values": machine_clean_history, "color": Color(0.30, 0.70, 0.95)},
			{"values": machine_calib_history, "color": Color(0.95, 0.65, 0.30)},
			{"values": machine_press_history, "color": Color(0.50, 0.85, 0.45)},
		])
	# stats panel — three lines so each multiplier is legible
	if s2_status != null:
		var sup: Dictionary = SUPPLIERS[current_supplier]
		var rep_mult: float = _stage_2_rep_multiplier()
		var machine_mult: float = 0.30 + 0.70 * _stage_2_machine_health()
		var ideal_gross: float = float(baristas) * 5.0 * cafe_price_mult * float(sup["quality"])
		var realised_gross: float = ideal_gross * machine_mult * rep_mult
		var net: float = realised_gross - float(sup["cost"])
		var next_cost: int = int(50.0 + float(baristas) * 50.0)
		var rep_lost: float = ideal_gross - ideal_gross * rep_mult
		s2_status.text = "👥 Baristas: %d   💲 Price: %.2fx   📦 %s ×%.2f   📈 Ideal: $%.1f/s\n✨ Rep: %d%% (×%.2f, costing $%.1f/s)   🛠️ Machine: %d%% (×%.2f)\n💰 Realised gross $%.1f − supplier $%.1f = NET $%+.1f/s   ·   Next barista: $%d" % [
			baristas, cafe_price_mult, String(sup["name"]), float(sup["quality"]), ideal_gross,
			int(rep * 100.0), rep_mult, rep_lost,
			int(_stage_2_machine_health() * 100.0), machine_mult,
			realised_gross, float(sup["cost"]), net, next_cost,
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

	# Average promo trend chart (right of buttons)
	var s3_color: Color = Color(0.3, 0.5, 0.85)
	var s3_panel: Dictionary = _make_chart_panel(Vector2(730, 70), Vector2(200, 60), s3_color)
	s3_promo_chart_title = s3_panel["title"]
	s3_promo_chart = s3_panel["chart"]
	s3_promo_chart_title.text = "Avg promo (all branches)"
	(s3_promo_chart as LineChart).set_range(0.0, 1.0)

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
		"training": 0,
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


func _train_manager(idx: int) -> void:
	if idx < 0 or idx >= locations.size():
		return
	var loc: Dictionary = locations[idx]
	if not bool(loc.get("manager", false)):
		_notify("%s has no manager to train." % String(loc.get("name", "?")))
		return
	var current: int = int(loc.get("training", 0))
	if current >= MAX_TRAINING:
		_notify("%s manager already maxed out." % String(loc.get("name", "?")))
		return
	var cost: float = TRAINING_COSTS[current]
	if money < cost:
		_notify("Need $%s to train next level." % _fmt_money(cost))
		return
	money -= cost
	loc["training"] = current + 1
	_notify("%s manager trained to level %d — drain × %.2f." % [
		String(loc.get("name", "?")), current + 1, pow(TRAINING_DRAIN_MULT, float(current + 1)),
	])
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
	var has_mgr: bool = bool(loc.get("manager", false))
	var training: int = int(loc.get("training", 0))
	var mgr_str: String
	if has_mgr:
		mgr_str = "👔" + "★".repeat(training) if training > 0 else "👔"
	else:
		mgr_str = "·  "
	return "%s  %s   $%+5.1f/s net" % [
		mgr_str, String(loc.get("name", "?")), net,
	]


func _add_s3_row(idx: int) -> void:
	if s3_list == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info: Label = Label.new()
	info.size = Vector2(240, 28)
	info.custom_minimum_size = Vector2(240, 28)
	info.modulate = STAGE_FG[3]
	info.add_theme_font_size_override("font_size", 13)
	row.add_child(info)

	var bar: ProgressBar = ProgressBar.new()
	bar.size = Vector2(330, 24)
	bar.custom_minimum_size = Vector2(330, 24)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = true
	row.add_child(bar)

	var visit_btn: Button = Button.new()
	visit_btn.text = "Visit"
	visit_btn.size = Vector2(110, 26)
	visit_btn.custom_minimum_size = Vector2(110, 26)
	visit_btn.pressed.connect(_visit_location.bind(idx))
	row.add_child(visit_btn)

	var train_btn: Button = Button.new()
	train_btn.text = "Train"
	train_btn.size = Vector2(150, 26)
	train_btn.custom_minimum_size = Vector2(150, 26)
	train_btn.pressed.connect(_train_manager.bind(idx))
	row.add_child(train_btn)

	s3_list.add_child(row)
	s3_rows.append({"info": info, "promo": bar, "visit": visit_btn, "train": train_btn})


func _refresh_stage_3_ui() -> void:
	while s3_rows.size() < locations.size():
		_add_s3_row(s3_rows.size())
	if s3_promo_chart != null:
		s3_promo_chart.set_values(avg_promo_history)
	for i in range(locations.size()):
		if i >= s3_rows.size():
			continue
		var row: Dictionary = s3_rows[i]
		var loc: Dictionary = locations[i]
		(row["info"] as Label).text = _format_location_row(loc)
		(row["promo"] as ProgressBar).value = float(loc.get("promotion", 0.0))
		var train_btn: Button = row["train"]
		var has_mgr: bool = bool(loc.get("manager", false))
		var training: int = int(loc.get("training", 0))
		if not has_mgr:
			train_btn.text = "Train (no mgr)"
			train_btn.disabled = true
		elif training >= MAX_TRAINING:
			train_btn.text = "★★★ maxed"
			train_btn.disabled = true
		else:
			train_btn.text = "Train L%d $%s" % [training + 1, _fmt_money(TRAINING_COSTS[training])]
			train_btn.disabled = false
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
	buyback_button = _make_stage_button("Buy 100 sh", Vector2(250, 66), _buy_stock, Vector2(220, 42))
	cartel_button = _make_stage_button("Form cartel", Vector2(480, 66), _toggle_cartel, Vector2(220, 42))
	_make_stage_button("Layoff round", Vector2(710, 66), _layoff_round, Vector2(220, 42))

	# Row 2 — HR + back to chain
	_make_stage_button("Hire 5 corp — $1k", Vector2(20, 116), _hire_corporate, Vector2(220, 42))
	_make_stage_button("Raise wages +10%", Vector2(250, 116), _raise_wages, Vector2(220, 42))
	_make_stage_button("Cut wages −10%", Vector2(480, 116), _cut_wages, Vector2(220, 42))
	_make_stage_button("← Back to Chain", Vector2(710, 116), _back_to_chain, Vector2(220, 42))

	# charts
	var stock_color: Color = Color(0.45, 0.85, 0.55)
	var ar_color: Color = Color(0.95, 0.78, 0.45)
	var ro_color: Color = Color(0.85, 0.65, 0.40)
	var mi_color: Color = Color(0.80, 0.92, 0.95)
	var stock_panel: Dictionary = _make_chart_panel(Vector2(20, 168), Vector2(430, 100), stock_color)
	stock_chart_title = stock_panel["title"]
	stock_chart = stock_panel["chart"]
	var ar_panel: Dictionary = _make_chart_panel(Vector2(470, 168), Vector2(150, 100), ar_color)
	arabica_chart_title = ar_panel["title"]
	arabica_chart = ar_panel["chart"]
	var ro_panel: Dictionary = _make_chart_panel(Vector2(630, 168), Vector2(150, 100), ro_color)
	robusta_chart_title = ro_panel["title"]
	robusta_chart = ro_panel["chart"]
	var mi_panel: Dictionary = _make_chart_panel(Vector2(790, 168), Vector2(150, 100), mi_color)
	milk_chart_title = mi_panel["title"]
	milk_chart = mi_panel["chart"]

	# Lock-contract buttons under each commodity chart
	arabica_lock_btn = _make_stage_button("Lock arabica", Vector2(470, 274), _lock_arabica, Vector2(150, 28))
	robusta_lock_btn = _make_stage_button("Lock robusta", Vector2(630, 274), _lock_robusta, Vector2(150, 28))
	milk_lock_btn = _make_stage_button("Lock milk", Vector2(790, 274), _lock_milk, Vector2(150, 28))

	s4_status = Label.new()
	s4_status.position = Vector2(20, 312)
	s4_status.size = Vector2(920, 138)
	s4_status.modulate = STAGE_FG[4]
	s4_status.add_theme_font_size_override("font_size", 13)
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
	var cost: float = float(BUYBACK_BLOCK_SHARES) * stock_price
	if money < cost:
		_notify("Need $%s for %d shares at $%.2f." % [_fmt_money(cost), BUYBACK_BLOCK_SHARES, stock_price])
		return
	money -= cost
	var bought_at: float = stock_price
	shares_owned += BUYBACK_BLOCK_SHARES
	stock_price = clampf(stock_price + 1.5, 10.0, 100000.0)
	_notify("Bought %d shares @ $%.2f. Total %d → +$%.1f/s passive." % [
		BUYBACK_BLOCK_SHARES, bought_at, shares_owned,
		float(shares_owned) * BUYBACK_REVENUE_PER_SHARE,
	])
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


func _lock_arabica() -> void:
	_lock_commodity("arabica")


func _lock_robusta() -> void:
	_lock_commodity("robusta")


func _lock_milk() -> void:
	_lock_commodity("milk")


func _lock_commodity(name: String) -> void:
	var current_tier: int = 0
	var current_price: float = 100.0
	match name:
		"arabica":
			current_tier = arabica_tier
			current_price = arabica_price
		"robusta":
			current_tier = robusta_tier
			current_price = robusta_price
		"milk":
			current_tier = milk_tier
			current_price = milk_price
		_:
			return
	var next_tier: int = current_tier + 1
	if next_tier >= BULK_TIERS.size():
		_notify("%s contract already maxed." % name.capitalize())
		return
	var cost: float = float(BULK_TIERS[next_tier]["cost"]) * (current_price / 100.0)
	if money < cost:
		_notify("Need $%s for %s tier %d (price $%.0f)." % [_fmt_money(cost), name.capitalize(), next_tier, current_price])
		return
	money -= cost
	match name:
		"arabica": arabica_tier = next_tier
		"robusta": robusta_tier = next_tier
		"milk":    milk_tier = next_tier
	var discount: float = float(BULK_TIERS[next_tier]["discount"])
	_notify("Locked %s tier %d at $%.0f — leg now ×%.2f." % [
		name.capitalize(), next_tier, current_price, discount,
	])
	_refresh_stage_4_ui()
	_refresh_hud()


func _commodity_lock_cost(tier: int, current_price: float) -> float:
	if tier <= 0 or tier >= BULK_TIERS.size():
		return 0.0
	return float(BULK_TIERS[tier]["cost"]) * (current_price / 100.0)


func _make_sparkline(values: Array, max_chars: int = 28) -> String:
	if values.is_empty():
		return "—"
	var start: int = maxi(0, values.size() - max_chars)
	var slice: Array = values.slice(start, values.size())
	var lo: float = INF
	var hi: float = -INF
	for v in slice:
		var fv: float = float(v)
		if fv < lo:
			lo = fv
		if fv > hi:
			hi = fv
	var rng: float = hi - lo if hi > lo else 1.0
	var s: String = ""
	for v in slice:
		var n: float = clampf((float(v) - lo) / rng, 0.0, 0.999)
		s += SPARK_CHARS[int(n * 8.0)]
	return s


func _required_staff() -> int:
	var base: int = 8 + int(float(locations.size()) * 1.5)
	if cartel_active:
		base += 3
	base += marketing_level * 2
	return maxi(base, 4)


func _utilization() -> float:
	var req: float = float(_required_staff())
	return float(corporate_staff) / maxf(req, 1.0)


func _utilization_mult() -> float:
	var u: float = _utilization()
	if u >= 1.0:
		return 1.0
	return u  # linear penalty when understaffed


func _stage_4_payroll() -> float:
	# low morale increases cost (overtime, replacements)
	var morale_factor: float = 1.0 + maxf(0.0, 0.7 - morale) * 0.6
	return float(corporate_staff) * staff_salary * morale_factor


func _stage_4_supplier_overhead() -> float:
	# overhead scales with chain size; reduction = average of three commodity tier discounts
	var base: float = 50.0 + float(locations.size()) * 30.0
	var arab_d: float = float(BULK_TIERS[arabica_tier]["discount"])
	var robu_d: float = float(BULK_TIERS[robusta_tier]["discount"])
	var milk_d: float = float(BULK_TIERS[milk_tier]["discount"])
	var combined: float = (arab_d + robu_d + milk_d) / 3.0
	return base * combined


func _stage_4_gross_revenue() -> float:
	if strike_seconds > 0:
		return 0.0
	var marketing_boost: float = 1.0 + float(marketing_level) * 0.15
	var cartel_mult: float = 2.0 if cartel_active else 1.0
	var util_mult: float = _utilization_mult()
	var stock_baseline: float = stock_price * 100.0 * marketing_boost * cartel_mult * util_mult
	var shares_revenue: float = float(shares_owned) * BUYBACK_REVENUE_PER_SHARE
	return stock_baseline + shares_revenue


func _stage_4_net_revenue() -> float:
	return _stage_4_gross_revenue() - _stage_4_payroll() - _stage_4_supplier_overhead()


func _refresh_stage_4_ui() -> void:
	# buttons
	if cartel_button != null:
		cartel_button.text = "Break cartel" if cartel_active else "Form cartel"
	if buyback_button != null:
		var bb_cost: float = float(BUYBACK_BLOCK_SHARES) * stock_price
		buyback_button.text = "Buy 100 sh — $%s" % _fmt_money(bb_cost)
	_update_lock_button(arabica_lock_btn, arabica_tier, arabica_price, "arabica")
	_update_lock_button(robusta_lock_btn, robusta_tier, robusta_price, "robusta")
	_update_lock_button(milk_lock_btn, milk_tier, milk_price, "milk")

	# chart titles + data
	var stock_change: float = 0.0
	if stock_history.size() >= 2:
		stock_change = stock_history[stock_history.size() - 1] - stock_history[stock_history.size() - 2]
	var stock_arrow: String = "▲" if stock_change > 0.05 else ("▼" if stock_change < -0.05 else "▬")
	if stock_chart_title != null:
		stock_chart_title.text = "📈 STOCK $%.2f %s%.1f   shares %d → +$%.1f/s" % [
			stock_price, stock_arrow, abs(stock_change),
			shares_owned, float(shares_owned) * BUYBACK_REVENUE_PER_SHARE,
		]
	if stock_chart != null:
		stock_chart.set_values(stock_history)
	if arabica_chart_title != null:
		arabica_chart_title.text = "ARABICA $%.0f" % arabica_price
	if arabica_chart != null:
		arabica_chart.set_values(arabica_history)
	if robusta_chart_title != null:
		robusta_chart_title.text = "ROBUSTA $%.0f" % robusta_price
	if robusta_chart != null:
		robusta_chart.set_values(robusta_history)
	if milk_chart_title != null:
		milk_chart_title.text = "MILK $%.0f" % milk_price
	if milk_chart != null:
		milk_chart.set_values(milk_history)

	if s4_status == null:
		return

	# Status text — HR + ops + cartel + net (tickers are in charts above)
	var lines: Array[String] = []
	var req: int = _required_staff()
	var util: float = _utilization()
	var util_str: String
	if util < 0.85:
		util_str = "⚠ UNDERSTAFFED %d%% — gross ×%.2f" % [int(util * 100.0), util]
	elif util > 1.4:
		util_str = "⚠ overstaffed %d%% — paying idle heads" % int(util * 100.0)
	else:
		util_str = "✓ %d%% util" % int(util * 100.0)
	lines.append("👥 HR    Heads %d / need %d   %s" % [corporate_staff, req, util_str])
	lines.append("        Salary $%.1f/h/s   Morale %d%%   Payroll $%s/s" % [
		staff_salary, int(morale * 100.0), _fmt_money(_stage_4_payroll()),
	])
	lines.append("🏭 OPS   Contracts: arab T%d ×%.2f · rob T%d ×%.2f · milk T%d ×%.2f → supplier $%s/s   Marketing lv %d" % [
		arabica_tier, float(BULK_TIERS[arabica_tier]["discount"]),
		robusta_tier, float(BULK_TIERS[robusta_tier]["discount"]),
		milk_tier, float(BULK_TIERS[milk_tier]["discount"]),
		_fmt_money(_stage_4_supplier_overhead()), marketing_level,
	])
	if cartel_active:
		lines.append("⚖ CARTEL ACTIVE — antitrust risk %d%% (rising)" % int(antitrust_risk * 100.0))
	else:
		lines.append("⚖ Cartel off — risk decaying (%d%%)" % int(antitrust_risk * 100.0))
	if strike_seconds > 0:
		lines.append("🚨 STRIKE — %ds remaining (gross = 0, costs continue)" % strike_seconds)
	if layoff_cooldown > 0:
		lines.append("⏳ Layoff cooldown — %ds" % layoff_cooldown)
	lines.append("")
	lines.append("💰 NET   gross $%s − payroll $%s − supplier $%s = $%+s/s" % [
		_fmt_money(_stage_4_gross_revenue()),
		_fmt_money(_stage_4_payroll()),
		_fmt_money(_stage_4_supplier_overhead()),
		_fmt_money(_stage_4_net_revenue()),
	])
	lines.append("🎯 Goal: $100M to IPO")
	if won:
		lines.append("")
		lines.append("🏆 Corporate Coffee Inc. is public. You won.")
	s4_status.text = "\n".join(lines)


func _update_lock_button(btn: Button, current_tier: int, current_price: float, label_name: String) -> void:
	if btn == null:
		return
	var next_tier: int = current_tier + 1
	if next_tier >= BULK_TIERS.size():
		btn.text = "%s maxed" % label_name.capitalize()
		btn.disabled = true
		return
	var cost: float = _commodity_lock_cost(next_tier, current_price)
	btn.text = "Lock %s T%d — $%s" % [label_name, next_tier, _fmt_money(cost)]
	btn.disabled = false


func _make_chart_panel(pos: Vector2, sz: Vector2, color: Color) -> Dictionary:
	var title: Label = Label.new()
	title.position = pos
	title.size = Vector2(sz.x, 18)
	title.modulate = color
	title.add_theme_font_size_override("font_size", 11)
	stage_view.add_child(title)
	var chart: LineChart = LineChart.new()
	chart.position = pos + Vector2(0, 22)
	chart.size = Vector2(sz.x, sz.y - 22)
	chart.line_color = color
	chart.fill_color = Color(color.r, color.g, color.b, 0.22)
	chart.bg_color = Color(0.0, 0.0, 0.0, 0.18)
	chart.border_color = Color(color.r, color.g, color.b, 0.45)
	stage_view.add_child(chart)
	return {"title": title, "chart": chart}


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
			# rep slowly recovers per cup served, gated by machine health
			rep = clampf(rep + float(baristas) * 0.0003 * s2_health, 0.0, 1.0)
			_refresh_stage_2_ui()
		3:
			var total_net: float = 0.0
			var total_gross: float = 0.0
			for loc in locations:
				var managed: bool = bool(loc.get("manager", false))
				var base_drain: float = PROMO_DRAIN_MANAGED if managed else PROMO_DRAIN_BASE
				var training: int = int(loc.get("training", 0))
				var drain: float = base_drain * pow(TRAINING_DRAIN_MULT, float(training))
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
			var drift: float = randf_range(-3.0, 3.0) + float(marketing_level) * 0.4
			if cartel_active:
				drift += 1.0
			stock_price = clampf(stock_price + drift, 10.0, 100000.0)
			arabica_price = clampf(arabica_price + randf_range(-4.0, 4.0), 30.0, 200.0)
			robusta_price = clampf(robusta_price + randf_range(-3.0, 3.0), 20.0, 150.0)
			milk_price = clampf(milk_price + randf_range(-2.0, 2.0), 20.0, 100.0)
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


func _back_to_chain() -> void:
	# Step from Corporate back to Chain to open more locations.
	# All Corporate state (stock, staff, cartel, contracts, shares) persists.
	if stage == 4:
		_notify("Back to Chain CEO — Corporate state preserved.")
		_enter_stage(3)


func _check_win() -> void:
	if won:
		return
	if money >= 100_000_000.0:
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


func _make_sfx(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p


func _put_sample(data: PackedByteArray, idx: int, sample: float) -> void:
	var s16: int = clampi(int(sample * 32767.0), -32768, 32767)
	if s16 < 0:
		s16 += 65536
	data[idx * 2] = s16 & 0xFF
	data[idx * 2 + 1] = (s16 >> 8) & 0xFF


func _wrap_stream(data: PackedByteArray) -> AudioStreamWAV:
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	s.data = data
	return s


func _synth_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SR))
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t: float = float(i) / float(SR)
		var env: float = minf(t * 30.0, 1.0) * exp(-t * 4.0)
		_put_sample(data, i, sin(t * freq * TAU) * env * volume)
	return _wrap_stream(data)


func _synth_chime(f1: float, f2: float, duration: float, volume: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SR))
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t: float = float(i) / float(SR)
		var env: float = minf(t * 30.0, 1.0) * exp(-t * 2.5)
		var s: float = (sin(t * f1 * TAU) + sin(t * f2 * TAU)) * 0.5
		_put_sample(data, i, s * env * volume)
	return _wrap_stream(data)


func _synth_buzz(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SR))
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t: float = float(i) / float(SR)
		var env: float = minf(t * 20.0, 1.0) * exp(-t * 2.0)
		var sq: float = 1.0 if sin(t * freq * TAU) > 0.0 else -1.0
		var noise: float = randf_range(-0.35, 0.35)
		_put_sample(data, i, (sq * 0.6 + noise) * env * volume)
	return _wrap_stream(data)


func _synth_descend(f_start: float, f_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SR))
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SR)
		var alpha: float = t / duration
		var freq: float = lerp(f_start, f_end, alpha)
		phase += freq * TAU / float(SR)
		var env: float = minf(t * 20.0, 1.0) * exp(-t * 2.0)
		_put_sample(data, i, sin(phase) * env * volume)
	return _wrap_stream(data)


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
	var speed: float = 1.30  # ~0.77s to fill — tighter, harder to nail
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


# ============================================================
#  LINE CHART WIDGET
# ============================================================
class LineChart extends Control:
	var values: Array = []      # single-series fallback
	var series: Array = []      # [{values: Array, color: Color}, ...]
	var line_color: Color = Color.BLACK
	var fill_color: Color = Color(0.0, 0.0, 0.0, 0.15)
	var bg_color: Color = Color(1.0, 1.0, 1.0, 0.06)
	var border_color: Color = Color(1.0, 1.0, 1.0, 0.3)
	var min_y: float = 0.0
	var max_y: float = 1.0
	var auto_scale: bool = true

	func set_range(lo: float, hi: float) -> void:
		min_y = lo
		max_y = hi
		auto_scale = false
		queue_redraw()

	func set_values(v: Array) -> void:
		values = v.duplicate()
		series = []
		_autoscale_from(values)
		queue_redraw()

	func set_series(s: Array) -> void:
		series = []
		var combined: Array = []
		for entry in s:
			var entry_vals: Array = entry.get("values", [])
			series.append({"values": entry_vals.duplicate(), "color": entry.get("color", line_color)})
			for x in entry_vals:
				combined.append(x)
		values = []
		_autoscale_from(combined)
		queue_redraw()

	func _autoscale_from(combined: Array) -> void:
		if not auto_scale or combined.is_empty():
			return
		var lo: float = INF
		var hi: float = -INF
		for x in combined:
			var f: float = float(x)
			if f < lo:
				lo = f
			if f > hi:
				hi = f
		if hi - lo < 0.01:
			hi = lo + 1.0
		var pad: float = (hi - lo) * 0.1
		min_y = lo - pad
		max_y = hi + pad

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), bg_color)
		draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 1.0)
		if not series.is_empty():
			for entry in series:
				_draw_line(entry["values"], entry["color"], false)
		elif values.size() >= 2:
			_draw_line(values, line_color, true)

	func _draw_line(vals: Array, color: Color, with_fill: bool) -> void:
		if vals.size() < 2:
			return
		var w: float = size.x
		var h: float = size.y
		var rng: float = max_y - min_y
		if rng < 0.01:
			rng = 1.0
		var n: int = vals.size()
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(n):
			var x: float = float(i) / float(n - 1) * (w - 4.0) + 2.0
			var y: float = h - 2.0 - (float(vals[i]) - min_y) / rng * (h - 4.0)
			pts.append(Vector2(x, y))
		if with_fill:
			var fill_pts: PackedVector2Array = PackedVector2Array()
			fill_pts.append(Vector2(2.0, h - 2.0))
			for p in pts:
				fill_pts.append(p)
			fill_pts.append(Vector2(w - 2.0, h - 2.0))
			draw_colored_polygon(fill_pts, fill_color)
		for i in range(n - 1):
			draw_line(pts[i], pts[i + 1], color, 2.0)

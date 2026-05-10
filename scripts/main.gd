extends Control

# ============================================================
# Corporate Coffee — career-ladder tycoon
# Stage 1: Office Coffee Juffrouw
# Stage 2: Café Owner
# Stage 3: Chain CEO
# Stage 4: Corporate CEO  (win at $10M)
# ============================================================

# --- progression ---
var stage: int = 1
var money: float = 0.0
var rep: float = 0.5  # 0..1
var customers_served: int = 0
var won: bool = false

# --- stage 1 (office) ---
var beans: int = 10
var milk: int = 0
var has_steamer: bool = false

# --- stage 2 (café) ---
var baristas: int = 0
var cafe_price_mult: float = 1.0

# --- stage 3 (chain) ---
var locations: Array[Dictionary] = []

# --- stage 4 (corporate) ---
var stock_price: float = 100.0
var marketing_level: int = 0

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

# stage 1 drinks
const DRINK_ESPRESSO: Dictionary = {
	"name": "Espresso", "emoji": "☕", "price": 2, "tip": 2,
	"beans": 1, "milk": 0, "needs_steamer": false,
}
const DRINK_CAPPUCCINO: Dictionary = {
	"name": "Cappuccino", "emoji": "🍼", "price": 4, "tip": 3,
	"beans": 1, "milk": 1, "needs_steamer": true,
}
const DRINK_LATTE: Dictionary = {
	"name": "Latte", "emoji": "🥛", "price": 5, "tip": 4,
	"beans": 1, "milk": 2, "needs_steamer": true,
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
var rep_label: Label
var queue_box: HBoxContainer
var queue: Array[Dictionary] = []  # [{drink, button}]

var s2_status: Label
var s3_status: Label
var s4_status: Label


func _ready() -> void:
	randomize()
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
	hud_label.position = Vector2(20, 12)
	hud_label.size = Vector2(920, 32)
	hud_label.add_theme_font_size_override("font_size", 16)
	add_child(hud_label)

	notif_label = Label.new()
	notif_label.position = Vector2(20, 44)
	notif_label.size = Vector2(920, 24)
	notif_label.modulate = Color(0.35, 0.55, 0.35)
	add_child(notif_label)

	stage_view = Control.new()
	stage_view.anchor_right = 1.0
	stage_view.anchor_bottom = 1.0
	stage_view.offset_top = 78.0
	add_child(stage_view)

	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_on_spawn)
	add_child(spawn_timer)

	revenue_timer = Timer.new()
	revenue_timer.wait_time = 1.0
	revenue_timer.timeout.connect(_on_revenue_tick)
	add_child(revenue_timer)


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
	rep_label = null
	queue_box = null
	s2_status = null
	s3_status = null
	s4_status = null
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
	hud_label.text = "💰 $%s   ⭐ %d%%   🪜 Stage %d/4 · %s   🎯 next: $%s" % [
		_fmt_money(money), int(rep * 100.0), stage, STAGE_NAMES[stage], _fmt_money(STAGE_GOALS[stage]),
	]


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
	_stage_title("☕  Office Coffee Juffrouw — make coffee for colleagues")

	beans_label = _make_stage_label(Vector2(20, 50))
	milk_label = _make_stage_label(Vector2(220, 50))
	rep_label = _make_stage_label(Vector2(420, 50))

	var qh: Label = Label.new()
	qh.text = "Colleagues (click to serve their order):"
	qh.position = Vector2(20, 100)
	qh.size = Vector2(500, 28)
	stage_view.add_child(qh)

	queue_box = HBoxContainer.new()
	queue_box.position = Vector2(20, 132)
	queue_box.size = Vector2(920, 110)
	queue_box.add_theme_constant_override("separation", 8)
	stage_view.add_child(queue_box)

	_make_stage_button("Buy beans (10) — $5", Vector2(20, 270), _buy_beans)
	_make_stage_button("Buy milk (10) — $3", Vector2(260, 270), _buy_milk)
	_make_stage_button("Steamer — $30", Vector2(500, 270), _buy_steamer)
	_make_stage_button("Faster spawns — $40", Vector2(740, 270), _buy_machine)
	_make_stage_button("PROMOTE → Café Owner", Vector2(20, 340), _try_promote)

	spawn_timer.wait_time = 3.0
	spawn_timer.start()
	_update_s1_labels()


func _update_s1_labels() -> void:
	if beans_label != null:
		beans_label.text = "🫘 Beans: %d" % beans
	if milk_label != null:
		milk_label.text = "🥛 Milk: %d" % milk
	if rep_label != null:
		rep_label.text = "⭐ Rep: %d%%" % int(rep * 100.0)


func _spawn_colleague() -> void:
	if queue_box == null or queue.size() >= 6:
		return
	var pool: Array[Dictionary] = [DRINK_ESPRESSO]
	if has_steamer:
		pool.append(DRINK_CAPPUCCINO)
		pool.append(DRINK_LATTE)
	var drink: Dictionary = pool.pick_random()

	var btn: Button = Button.new()
	btn.text = "🧑\n%s\n$%d" % [String(drink["emoji"]), int(drink["price"])]
	btn.custom_minimum_size = Vector2(86, 96)
	var entry: Dictionary = {"drink": drink, "button": btn}
	btn.pressed.connect(_serve_colleague.bind(entry))
	queue_box.add_child(btn)
	queue.append(entry)


func _serve_colleague(entry: Dictionary) -> void:
	var drink: Dictionary = entry["drink"]
	var btn: Button = entry["button"]
	var need_beans: int = int(drink["beans"])
	var need_milk: int = int(drink["milk"])
	if beans < need_beans:
		_notify("Out of beans! Buy more.")
		return
	if need_milk > 0 and milk < need_milk:
		_notify("Out of milk!")
		return
	beans -= need_beans
	milk -= need_milk
	var tip: int = randi_range(0, int(drink["tip"]))
	var revenue: float = float(drink["price"]) + float(tip)
	money += revenue
	customers_served += 1
	rep = clampf(rep + 0.01, 0.0, 1.0)
	queue.erase(entry)
	btn.queue_free()
	_notify("Served %s · earned $%d (tip $%d)" % [String(drink["name"]), int(drink["price"]), tip])
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
	_stage_title("☕  Café Owner — your own place, your own staff")

	var blurb: Label = Label.new()
	blurb.text = "Hire baristas. Each barista earns ~$5/sec, scaled by your price multiplier."
	blurb.position = Vector2(20, 50)
	blurb.size = Vector2(920, 28)
	blurb.modulate = STAGE_FG[2]
	stage_view.add_child(blurb)

	_make_stage_button("Hire barista", Vector2(20, 110), _hire_barista)
	_make_stage_button("Raise prices +10%", Vector2(260, 110), _raise_prices)
	_make_stage_button("PROMOTE → Chain CEO", Vector2(500, 110), _try_promote)

	s2_status = Label.new()
	s2_status.position = Vector2(20, 200)
	s2_status.size = Vector2(920, 200)
	s2_status.modulate = STAGE_FG[2]
	s2_status.add_theme_font_size_override("font_size", 16)
	stage_view.add_child(s2_status)

	revenue_timer.wait_time = 1.0
	revenue_timer.start()
	_update_s2_status()


func _hire_barista() -> void:
	var cost: float = 50.0 + float(baristas) * 50.0
	if money < cost:
		_notify("Need $%d to hire next barista." % int(cost))
		return
	money -= cost
	baristas += 1
	_update_s2_status()
	_refresh_hud()


func _raise_prices() -> void:
	cafe_price_mult += 0.1
	rep = maxf(rep - 0.05, 0.0)
	_notify("Prices up 10%, rep took a small hit.")
	_update_s2_status()
	_refresh_hud()


func _update_s2_status() -> void:
	if s2_status == null:
		return
	var rev_per_sec: float = float(baristas) * 5.0 * cafe_price_mult
	var next_cost: int = int(50.0 + float(baristas) * 50.0)
	s2_status.text = "Baristas: %d\nPrice multiplier: %.1fx\nRevenue: $%.2f / sec\n\nNext barista: $%d" % [
		baristas, cafe_price_mult, rev_per_sec, next_cost,
	]


# ============================================================
#  STAGE 3 — Chain CEO
# ============================================================
func _setup_stage_3() -> void:
	_stage_title("🏢  Chain CEO — open locations across the city")

	var blurb: Label = Label.new()
	blurb.text = "Each location generates revenue. Hire managers (👔) to double their output."
	blurb.position = Vector2(20, 50)
	blurb.size = Vector2(920, 28)
	blurb.modulate = STAGE_FG[3]
	stage_view.add_child(blurb)

	_make_stage_button("Open new location", Vector2(20, 100), _buy_location)
	_make_stage_button("Hire next manager — $200", Vector2(260, 100), _hire_manager)
	_make_stage_button("PROMOTE → Corporate CEO", Vector2(500, 100), _try_promote)

	s3_status = Label.new()
	s3_status.position = Vector2(20, 170)
	s3_status.size = Vector2(920, 320)
	s3_status.modulate = STAGE_FG[3]
	s3_status.add_theme_font_size_override("font_size", 14)
	stage_view.add_child(s3_status)

	revenue_timer.wait_time = 1.0
	revenue_timer.start()
	_update_s3_status()


func _buy_location() -> void:
	var cost: float = 500.0 * pow(1.6, float(locations.size()))
	if money < cost:
		_notify("Need $%s for location #%d." % [_fmt_money(cost), locations.size() + 1])
		return
	money -= cost
	var rev: float = 25.0 * pow(1.25, float(locations.size()))
	locations.append({
		"name": "Branch #%d" % (locations.size() + 1),
		"revenue": rev,
		"manager": false,
	})
	_update_s3_status()
	_refresh_hud()


func _hire_manager() -> void:
	for loc in locations:
		if not bool(loc.get("manager", false)):
			if money < 200.0:
				_notify("Need $200 for next manager.")
				return
			money -= 200.0
			loc["manager"] = true
			_update_s3_status()
			_refresh_hud()
			return
	_notify("All locations have managers.")


func _update_s3_status() -> void:
	if s3_status == null:
		return
	var lines: Array[String] = []
	var total: float = 0.0
	for loc in locations:
		var has_mgr: bool = bool(loc.get("manager", false))
		var mult: float = 2.0 if has_mgr else 1.0
		var rev: float = float(loc.get("revenue", 0.0)) * mult
		total += rev
		lines.append("• %s — $%.1f/s %s" % [String(loc.get("name", "?")), rev, "👔" if has_mgr else ""])
	if lines.is_empty():
		lines.append("(no locations yet — buy one to start earning)")
	var next_cost: float = 500.0 * pow(1.6, float(locations.size()))
	lines.append("")
	lines.append("Total: $%.1f/s    Next location: $%s" % [total, _fmt_money(next_cost)])
	s3_status.text = "\n".join(lines)


# ============================================================
#  STAGE 4 — Corporate CEO
# ============================================================
func _setup_stage_4() -> void:
	_stage_title("💼  Corporate CEO — reach $10M to take Corporate Coffee public")

	var blurb: Label = Label.new()
	blurb.text = "Stock price drifts each second. Marketing tilts the drift positive. Buyback boosts price."
	blurb.position = Vector2(20, 50)
	blurb.size = Vector2(920, 28)
	blurb.modulate = STAGE_FG[4]
	stage_view.add_child(blurb)

	_make_stage_button("Marketing campaign — $1k", Vector2(20, 100), _buy_marketing)
	_make_stage_button("Stock buyback — $5k", Vector2(260, 100), _buy_stock)

	s4_status = Label.new()
	s4_status.position = Vector2(20, 180)
	s4_status.size = Vector2(920, 280)
	s4_status.modulate = STAGE_FG[4]
	s4_status.add_theme_font_size_override("font_size", 16)
	stage_view.add_child(s4_status)

	revenue_timer.wait_time = 1.0
	revenue_timer.start()
	_update_s4_status()


func _buy_marketing() -> void:
	if money < 1000.0:
		_notify("Need $1000.")
		return
	money -= 1000.0
	marketing_level += 1
	_refresh_hud()
	_update_s4_status()


func _buy_stock() -> void:
	if money < 5000.0:
		_notify("Need $5000.")
		return
	money -= 5000.0
	stock_price += 5.0
	_refresh_hud()
	_update_s4_status()


func _update_s4_status() -> void:
	if s4_status == null:
		return
	var rev_per_sec: float = stock_price * 100.0
	s4_status.text = "Stock price:     $%.2f\nMarketing level: %d\nRevenue:         $%s / sec\n\nGoal: $10M" % [
		stock_price, marketing_level, _fmt_money(rev_per_sec),
	]
	if won:
		s4_status.text += "\n\n🏆  Corporate Coffee Inc. — IPO complete. You won."


# ============================================================
#  TIMERS — shared across stages
# ============================================================
func _on_spawn() -> void:
	if stage == 1:
		_spawn_colleague()


func _on_revenue_tick() -> void:
	match stage:
		2:
			money += float(baristas) * 5.0 * cafe_price_mult
			_update_s2_status()
		3:
			var total: float = 0.0
			for loc in locations:
				var mult: float = 2.0 if bool(loc.get("manager", false)) else 1.0
				total += float(loc.get("revenue", 0.0)) * mult
			money += total
			_update_s3_status()
		4:
			var drift: float = randf_range(-2.0, 2.0) + float(marketing_level) * 0.6
			stock_price = maxf(stock_price + drift, 1.0)
			money += stock_price * 100.0
			_check_win()
			_update_s4_status()
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


func _make_stage_button(text: String, pos: Vector2, handler: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(220, 48)
	b.pressed.connect(handler)
	stage_view.add_child(b)
	return b

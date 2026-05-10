extends Control

# --- game state ---
var money: int = 50
var stock: int = 5
var price: int = 10
var helpers: int = 0
var queue: Array = []

const RESTOCK_COST: int = 5
const HIRE_COST: int = 50
const MAX_QUEUE: int = 8

# --- ui refs ---
var money_label: Label
var stock_label: Label
var price_label: Label
var helpers_label: Label
var queue_box: HBoxContainer
var spawn_timer: Timer
var helper_timer: Timer


func _ready() -> void:
	# background
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.95, 0.92, 0.85)
	add_child(bg)

	# title
	var title := Label.new()
	title.text = "MarchyParchy — Paper Shop"
	title.add_theme_font_size_override("font_size", 28)
	title.position = Vector2(20, 16)
	title.size = Vector2(900, 40)
	add_child(title)

	# stats
	money_label = _make_label(Vector2(20, 70))
	stock_label = _make_label(Vector2(20, 102))
	price_label = _make_label(Vector2(20, 134))
	helpers_label = _make_label(Vector2(20, 166))

	# queue header
	var qheader := Label.new()
	qheader.text = "Customers (click to serve):"
	qheader.position = Vector2(20, 220)
	qheader.size = Vector2(400, 28)
	add_child(qheader)

	# queue
	queue_box = HBoxContainer.new()
	queue_box.position = Vector2(20, 252)
	queue_box.size = Vector2(900, 80)
	queue_box.add_theme_constant_override("separation", 10)
	add_child(queue_box)

	# buttons
	_make_button("Restock +1 ($%d)" % RESTOCK_COST, Vector2(20, 380), _on_restock)
	_make_button("Hire helper ($%d)" % HIRE_COST, Vector2(260, 380), _on_hire)
	_make_button("Raise price +$1", Vector2(500, 380), _on_raise_price)

	# timers
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 3.0
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn)
	add_child(spawn_timer)

	helper_timer = Timer.new()
	helper_timer.wait_time = 2.0
	helper_timer.autostart = true
	helper_timer.timeout.connect(_on_helper_tick)
	add_child(helper_timer)

	_refresh()


func _make_label(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(300, 28)
	add_child(l)
	return l


func _make_button(label: String, pos: Vector2, handler: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.position = pos
	b.size = Vector2(220, 48)
	b.pressed.connect(handler)
	add_child(b)


func _refresh() -> void:
	money_label.text = "Money: $%d" % money
	stock_label.text = "Stock: %d" % stock
	price_label.text = "Price: $%d" % price
	helpers_label.text = "Helpers: %d" % helpers


# --- spawning ---
func _on_spawn() -> void:
	if queue.size() >= MAX_QUEUE:
		return
	# higher price scares some customers off
	if price > 10 and randf() < float(price - 10) * 0.1:
		return
	_add_customer()


func _add_customer() -> void:
	var btn := Button.new()
	btn.text = "🧑\n$%d" % price
	btn.custom_minimum_size = Vector2(72, 72)
	btn.pressed.connect(_serve_customer.bind(btn))
	queue_box.add_child(btn)
	queue.append(btn)


# --- serving ---
func _serve_customer(btn: Button) -> void:
	if stock <= 0:
		btn.text = "❌\nout"
		btn.disabled = true
		return
	stock -= 1
	money += price
	queue.erase(btn)
	btn.queue_free()
	_refresh()


func _on_helper_tick() -> void:
	if helpers <= 0 or queue.is_empty() or stock <= 0:
		return
	var to_serve := min(helpers, queue.size())
	for i in range(to_serve):
		if stock <= 0 or queue.is_empty():
			break
		var btn: Button = queue[0]
		queue.pop_front()
		stock -= 1
		money += price
		btn.queue_free()
	_refresh()


# --- buttons ---
func _on_restock() -> void:
	if money < RESTOCK_COST:
		return
	money -= RESTOCK_COST
	stock += 1
	_refresh()


func _on_hire() -> void:
	if money < HIRE_COST:
		return
	money -= HIRE_COST
	helpers += 1
	_refresh()


func _on_raise_price() -> void:
	price += 1
	_refresh()

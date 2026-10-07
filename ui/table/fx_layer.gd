class_name FxLayer
extends Control
## Short visual effects drawn over the table: cards flying to a pool, bursts of
## sparks, floating damage numbers, beams and banners. Purely cosmetic; it never
## touches the game state.
##
## Effects are queued (enqueue) so a burst of events, like a round end, plays one
## after another instead of all at once. busy() says whether anything is still
## queued, so bots can wait for the table to catch up.

signal idle

## A backlog longer than this many seconds plays faster, so the table never lags far
## behind the game.
const MAX_BACKLOG: float = 4.0

## Cosmetic randomness only; the rules have their own seeded generator.
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _cursor: float = 0.0
## [{at: float, run: Callable}], in time order.
var _queue: Array[Dictionary] = []
var _was_busy: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40


## Queue `run` to start after everything already queued; the next effect starts
## `duration` seconds later (0 = together with the next one).
func enqueue(run: Callable, duration: float) -> void:
	var backlog: float = _cursor - _clock
	var pace: float = 0.5 if backlog > MAX_BACKLOG else 1.0
	var at: float = maxf(_cursor, _clock)
	_queue.append({"at": at, "run": run})
	_cursor = at + duration * pace


func busy() -> bool:
	return not _queue.is_empty() or _cursor > _clock


## Plays everything still queued right away (e.g. when the match ends).
func flush() -> void:
	var items: Array[Dictionary] = _queue.duplicate()
	_queue.clear()
	_cursor = _clock
	for item: Dictionary in items:
		(item["run"] as Callable).call()
	_was_busy = false
	idle.emit()


func _process(delta: float) -> void:
	_clock += delta
	while not _queue.is_empty() and _queue[0]["at"] <= _clock:
		var item: Dictionary = _queue.pop_front()
		(item["run"] as Callable).call()
	var now_busy: bool = busy()
	if _was_busy and not now_busy:
		idle.emit()
	_was_busy = now_busy


# --- Effects (each starts immediately; use enqueue to sequence them) --------------------

## A card flies from `from` to `to` (centres), growing then settling, and bursts on
## arrival in its colour (then calls `on_arrive`, if given).
func fly_card(card: CardData, face_down: bool, from: Vector2, to: Vector2, seconds: float = 0.45,
		on_arrive: Callable = Callable()) -> void:
	var view := CardView.make(card, true, face_down)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	view.position = from - CardView.MINI_SIZE / 2.0
	view.pivot_offset = CardView.MINI_SIZE / 2.0
	view.scale = Vector2.ONE * 0.8
	view.rotation = _rng.randf_range(-0.4, 0.4)
	var mid: Vector2 = from.lerp(to, 0.5) + Vector2(0, -60)
	var tween := view.create_tween()
	tween.tween_method(func(t: float) -> void:
		var a: Vector2 = from.lerp(mid, t)
		var b: Vector2 = mid.lerp(to, t)
		view.position = a.lerp(b, t) - CardView.MINI_SIZE / 2.0, 0.0, 1.0, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(view, "scale", Vector2.ONE * 1.5, seconds * 0.5)
	tween.parallel().tween_property(view, "rotation", 0.0, seconds)
	tween.chain().tween_property(view, "scale", Vector2.ONE * 1.1, seconds * 0.3)
	var color: Color = UiStyle.card_color(card) if card != null and not face_down else UiStyle.CARD_BACK_COLOR
	tween.chain().tween_callback(func() -> void:
		burst(to, color.lightened(0.3), 16)
		if on_arrive.is_valid():
			on_arrive.call())
	tween.tween_property(view, "modulate:a", 0.0, 0.25)
	tween.tween_callback(view.queue_free)


## Sparks flying outwards from `at`. `rise` > 0 makes them float up (fire), < 0 fall.
func burst(at: Vector2, color: Color, count: int = 14, speed: float = 160.0, rise: float = 0.0) -> void:
	for i: int in count:
		var spark := Spark.new()
		spark.color = color.lerp(Color.WHITE, _rng.randf() * 0.4)
		spark.radius = _rng.randf_range(2.0, 5.0)
		add_child(spark)
		spark.position = at
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		var travel: Vector2 = dir * speed * _rng.randf_range(0.4, 1.0) + Vector2(0, -rise)
		var seconds: float = _rng.randf_range(0.35, 0.7)
		var tween := spark.create_tween().set_parallel()
		tween.tween_property(spark, "position", at + travel, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(spark.queue_free)


## An expanding ring at `at` (type changes, heals, Joker modifiers).
func ring(at: Vector2, color: Color, radius: float = 50.0, seconds: float = 0.5) -> void:
	var r := Ring.new()
	r.color = color
	add_child(r)
	r.position = at
	r.radius = 6.0
	var tween := r.create_tween().set_parallel()
	tween.tween_property(r, "radius", radius, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(r, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(r.queue_free)


## Text that pops up at `at` and drifts upwards (damage numbers, statuses).
func float_text(at: Vector2, text: String, color: Color, font_size: int = 22, seconds: float = 1.1) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size / 2.0
	label.position = at - label.size / 2.0 + Vector2(_rng.randf_range(-10, 10), 0)
	label.scale = Vector2.ONE * 0.3
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)
	tween.parallel().tween_property(label, "position:y", label.position.y - 46.0, seconds).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, seconds * 0.5).set_delay(seconds * 0.5)
	tween.chain().tween_callback(label.queue_free)


## A bolt from `from` to `to`, then sparks where it lands.
func beam(from: Vector2, to: Vector2, color: Color, seconds: float = 0.4) -> void:
	var line := Line2D.new()
	var points := PackedVector2Array([from])
	var steps: int = 8
	for i: int in range(1, steps):
		var t: float = float(i) / steps
		var normal: Vector2 = (to - from).orthogonal().normalized()
		points.append(from.lerp(to, t) + normal * _rng.randf_range(-14.0, 14.0))
	points.append(to)
	line.points = points
	line.width = 10.0
	line.default_color = color.lightened(0.4)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	var core := Line2D.new()
	core.points = points
	core.width = 3.0
	core.default_color = Color.WHITE
	line.add_child(core)
	var tween := line.create_tween()
	tween.tween_property(line, "width", 2.0, seconds).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(line, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.tween_callback(line.queue_free)
	burst(to, color.lightened(0.3), 22, 200.0)
	flash_circle(to, color, 46.0)


## A soft flash of light at `at`.
func flash_circle(at: Vector2, color: Color, radius: float = 40.0) -> void:
	var glow := Spark.new()
	glow.color = Color(color.lightened(0.4), 0.7)
	glow.radius = radius
	add_child(glow)
	glow.position = at
	var tween := glow.create_tween().set_parallel()
	tween.tween_property(glow, "scale", Vector2.ONE * 1.6, 0.35)
	tween.tween_property(glow, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(glow.queue_free)


## A big line of text across the middle of the table (round starts, eliminations).
func banner(text: String, color: Color, sub: String = "", seconds: float = 1.2) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.05, 0.03, 0.08, 0.88), color, 3, 14, 14, 8))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", color.lightened(0.3))
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)
	if not sub.is_empty():
		var small := Label.new()
		small.text = sub
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		small.add_theme_font_size_override("font_size", 16)
		box.add_child(small)
	add_child(panel)
	panel.size = panel.get_combined_minimum_size()
	panel.pivot_offset = panel.size / 2.0
	panel.position = Vector2(640, 250) - panel.size / 2.0
	panel.scale = Vector2(0.4, 0.4)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(seconds)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(panel.queue_free)


## Rattles a control for a moment (a player taking a hit).
func shake(target: Control, strength: float = 7.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	var home: Vector2 = target.position
	var tween := target.create_tween()
	for i: int in 6:
		var amount: float = strength * (1.0 - i / 6.0)
		tween.tween_property(target, "position", home + Vector2(_rng.randf_range(-amount, amount),
				_rng.randf_range(-amount, amount)), 0.035)
	tween.tween_property(target, "position", home, 0.04)


## A filled dot (sparks, glows).
class Spark extends Node2D:
	var color: Color = Color.WHITE
	var radius: float = 3.0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.5, color.lightened(0.5))


## An outline circle whose radius can be tweened.
class Ring extends Node2D:
	var color: Color = Color.WHITE
	var radius: float = 10.0:
		set(value):
			radius = value
			queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 4.0, true)

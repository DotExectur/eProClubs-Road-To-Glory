extends Node2D
## Presentation layer for Road to Glory matches.
## Match results, events, rewards and progression remain owned by the game backend.

const BG_PATH := "res://assets/road_to_glory/arena_background.png"
const HOME_ATLAS_PATH := "res://assets/road_to_glory/players_home_4x6.png"
const RIVAL_ATLAS_PATH := "res://assets/road_to_glory/players_rival_4x6.png"
const BALL_PATH := "res://assets/road_to_glory/match_ball.png"
const IMPACT_PATH := "res://assets/road_to_glory/match_goal_impact.png"

const IMAGE_SIZE := Vector2(941.0, 1672.0)
const FAR_LEFT := Vector2(0.183, 0.405)
const FAR_RIGHT := Vector2(0.807, 0.405)
const NEAR_RIGHT := Vector2(0.974, 0.626)
const NEAR_LEFT := Vector2(0.027, 0.626)
const HOME_FORMATION := [Vector2(4, 6), Vector2(7, 3), Vector2(7, 9), Vector2(9, 6)]
const RIVAL_FORMATION := [Vector2(16, 6), Vector2(13, 3), Vector2(13, 9), Vector2(11, 6)]
const DEMO_EVENTS := [
	{"minute": 18, "team": "home", "player_index": 2, "outcome": "goal"},
	{"minute": 41, "team": "away", "player_index": 1, "outcome": "goal"},
	{"minute": 73, "team": "home", "player_index": 0, "outcome": "goal"},
]

var _background: Sprite2D
var _actors: Node2D
var _ball: Sprite2D
var _ball_trail: Line2D
var _goal_impact: Sprite2D
var _effects: Node2D
var _hud: CanvasLayer
var _score_label: Label
var _clock_label: Label
var _status_label: Label
var _play_button: Button
var _home_players: Array[AnimatedSprite2D] = []
var _rival_players: Array[AnimatedSprite2D] = []
var _home_keeper: AnimatedSprite2D
var _rival_keeper: AnimatedSprite2D
var _home_score := 0
var _away_score := 0
var _playing := false
var _goal_flash := 0.0
var _elapsed := 0.0
var _home_player_ids: Array = []
var _trail_points: PackedVector2Array = PackedVector2Array()
var _trail_timer := 0.0
var _ball_is_moving := false


func _ready() -> void:
	_background = Sprite2D.new()
	_background.name = "ArenaBackground"
	_background.texture = load(BG_PATH)
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_background.z_index = -30
	add_child(_background)

	_actors = Node2D.new()
	_actors.name = "MatchActors"
	_actors.z_index = 2
	add_child(_actors)
	_effects = Node2D.new()
	_effects.name = "MatchEffects"
	_effects.z_index = 9
	add_child(_effects)
	_build_players()
	_build_ball()
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_elapsed += delta
	if _goal_flash > 0.0:
		_goal_flash = maxf(0.0, _goal_flash - delta)
		queue_redraw()
	for i in range(_home_players.size()):
		_home_players[i].position.y += sin(_elapsed * 2.3 + float(i)) * delta * 0.7
	for i in range(_rival_players.size()):
		_rival_players[i].position.y += sin(_elapsed * 2.1 + float(i) + 1.0) * delta * 0.7
	if is_instance_valid(_ball_trail):
		_trail_timer += delta
		if _ball_is_moving and _trail_timer >= 0.018:
			_trail_timer = 0.0
			_trail_points.append(_ball.position)
			while _trail_points.size() > 15:
				_trail_points.remove_at(0)
			_ball_trail.points = _trail_points
		elif not _ball_is_moving and _trail_points.size() > 0:
			_trail_points.remove_at(0)
			_ball_trail.points = _trail_points


func _draw() -> void:
	if _goal_flash > 0.0:
		var alpha := minf(0.42, _goal_flash * 1.3)
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.70, 1.0, 0.77, alpha), true)


func _build_players() -> void:
	var home_frames := _make_frames(load(HOME_ATLAS_PATH), false)
	var rival_frames := _make_frames(load(RIVAL_ATLAS_PATH), false)
	var keeper_home_frames := _make_frames(load(HOME_ATLAS_PATH), true)
	var keeper_rival_frames := _make_frames(load(RIVAL_ATLAS_PATH), true)
	for i in range(4):
		var home := _make_actor("HomePlayer%d" % (i + 1), home_frames, 0.27)
		var rival := _make_actor("RivalPlayer%d" % (i + 1), rival_frames, 0.27)
		_home_players.append(home)
		_rival_players.append(rival)
		_actors.add_child(home)
		_actors.add_child(rival)
	_home_keeper = _make_actor("HomeGoalkeeper", keeper_home_frames, 0.26)
	_rival_keeper = _make_actor("RivalGoalkeeper", keeper_rival_frames, 0.26)
	_actors.add_child(_home_keeper)
	_actors.add_child(_rival_keeper)


func _make_actor(actor_name: String, frames: SpriteFrames, sprite_scale: float) -> AnimatedSprite2D:
	var actor := AnimatedSprite2D.new()
	actor.name = actor_name
	actor.sprite_frames = frames
	actor.animation = "run" if frames.has_animation("run") else "keeper"
	actor.play()
	actor.centered = true
	actor.scale = Vector2.ONE * sprite_scale
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	actor.z_index = 4
	return actor


func _make_frames(texture: Texture2D, keeper: bool) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var cell_size := Vector2(texture.get_width() / 4.0, texture.get_height() / 6.0)
	var animation_name := "keeper" if keeper else "run"
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, 8.0)
	frames.set_animation_loop(animation_name, true)
	var row := 4 if keeper else 0
	for column in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(column, row) * cell_size, cell_size)
		frames.add_frame(animation_name, atlas)
	if keeper:
		frames.add_animation("save")
		frames.set_animation_speed("save", 12.0)
		frames.set_animation_loop("save", false)
		for column in range(4):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(column, 5) * cell_size, cell_size)
			frames.add_frame("save", atlas)
	else:
		frames.add_animation("strike")
		frames.set_animation_speed("strike", 10.0)
		frames.set_animation_loop("strike", false)
		for column in range(4):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(column, 2) * cell_size, cell_size)
			frames.add_frame("strike", atlas)
	return frames


func _build_ball() -> void:
	_ball_trail = Line2D.new()
	_ball_trail.name = "BallTrail"
	_ball_trail.width = 9.0
	_ball_trail.default_color = Color(0.72, 1.0, 0.49, 0.68)
	_ball_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_ball_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_ball_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	var trail_gradient := Gradient.new()
	trail_gradient.set_color(0, Color(0.9, 1.0, 0.65, 0.0))
	trail_gradient.set_color(1, Color(0.92, 1.0, 0.64, 0.85))
	_ball_trail.gradient = trail_gradient
	_actors.add_child(_ball_trail)
	_ball = Sprite2D.new()
	_ball.name = "MatchBall"
	_ball.texture = load(BALL_PATH)
	_ball.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ball.scale = Vector2(0.075, 0.075)
	_ball.z_index = 8
	_actors.add_child(_ball)
	var ball_glow := PointLight2D.new()
	ball_glow.name = "BallGlow"
	ball_glow.color = Color(0.55, 1.0, 0.31, 0.74)
	ball_glow.energy = 0.6
	ball_glow.texture = _make_glow_texture()
	ball_glow.texture_scale = 0.22
	_ball.add_child(ball_glow)
	_goal_impact = Sprite2D.new()
	_goal_impact.name = "GoalImpact"
	_goal_impact.texture = load(IMPACT_PATH)
	_goal_impact.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_goal_impact.scale = Vector2.ZERO
	_goal_impact.z_index = 7
	_goal_impact.visible = false
	_actors.add_child(_goal_impact)


func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 20)
	safe.add_theme_constant_override("margin_right", 20)
	safe.add_theme_constant_override("margin_top", 24)
	safe.add_theme_constant_override("margin_bottom", 22)
	_hud.add_child(safe)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	safe.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var title := _label("ROAD TO GLORY", 17, Color.WHITE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_pill("STAGE 01", Color(0.55, 1.0, 0.35)))

	var subheader := HBoxContainer.new()
	subheader.add_theme_constant_override("separation", 8)
	column.add_child(subheader)
	var edition := _label("EDIZIONE  ALL TIME", 10, Color(0.85, 0.93, 0.87))
	edition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subheader.add_child(edition)
	subheader.add_child(_pill("◈  1.240", Color(0.95, 0.79, 0.40)))
	subheader.add_child(_pill("✦  86", Color(0.55, 1.0, 0.35)))

	var score_card := PanelContainer.new()
	score_card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.07, 0.052, 0.88), Color(0.52, 1.0, 0.48, 0.36), 16))
	column.add_child(score_card)
	var score_column := VBoxContainer.new()
	score_column.add_theme_constant_override("separation", 5)
	score_card.add_child(score_column)
	var score_line := HBoxContainer.new()
	score_line.alignment = BoxContainer.ALIGNMENT_CENTER
	score_line.add_theme_constant_override("separation", 14)
	score_column.add_child(score_line)
	score_line.add_child(_label("E-PRO", 11, Color(0.43, 1.0, 0.70), true))
	_score_label = _label("0  :  0", 30, Color.WHITE, true)
	score_line.add_child(_score_label)
	score_line.add_child(_label("RIVALS", 11, Color(1.0, 0.40, 0.46), true))
	_clock_label = _label("SIMULAZIONE AUTOMATICA  •  IN ATTESA", 9, Color(0.78, 0.86, 0.80))
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_column.add_child(_clock_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.035, 0.027, 0.93), Color(1.0, 1.0, 1.0, 0.12), 18))
	column.add_child(bottom)
	var bottom_column := VBoxContainer.new()
	bottom_column.add_theme_constant_override("separation", 9)
	bottom.add_child(bottom_column)
	_status_label = _label("SQUADRA  4 + PORTIERE       POTENZA  72", 10, Color(0.78, 0.9, 0.80), true)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_column.add_child(_status_label)
	_play_button = Button.new()
	_play_button.custom_minimum_size = Vector2(0, 54)
	_play_button.text = "AVVIA ANTEPRIMA PARTITA"
	_play_button.add_theme_font_size_override("font_size", 14)
	_play_button.add_theme_color_override("font_color", Color(0.035, 0.075, 0.04))
	_play_button.add_theme_font_override("font", ThemeDB.fallback_font)
	_play_button.add_theme_stylebox_override("normal", _panel_style(Color(0.55, 1.0, 0.35), Color(0.80, 1.0, 0.72), 14))
	_play_button.add_theme_stylebox_override("hover", _panel_style(Color(0.67, 1.0, 0.50), Color.WHITE, 14))
	_play_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.37, 0.84, 0.27), Color.WHITE, 14))
	_play_button.pressed.connect(_start_demo_match)
	bottom_column.add_child(_play_button)
	var caption := _label("ESITO, CARTE E RICOMPENSE RESTANO DETERMINATI DAL SERVER", 8, Color(0.58, 0.68, 0.61))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_column.add_child(caption)


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _pill(text: String, tint: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.06, 0.04, 0.86), tint.darkened(0.48), 12))
	var label := _label(text, 10, tint, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 1)
	pill.add_child(label)
	return pill


func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _layout() -> void:
	if not is_instance_valid(_background):
		return
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var texture_size := _background.texture.get_size()
	var cover := maxf(view.x / texture_size.x, view.y / texture_size.y)
	_background.position = view * 0.5
	_background.scale = Vector2.ONE * cover
	for i in range(4):
		_home_players[i].position = _project_grid(HOME_FORMATION[i])
		_rival_players[i].position = _project_grid(RIVAL_FORMATION[i])
		_home_players[i].z_index = int(_home_players[i].position.y)
		_rival_players[i].z_index = int(_rival_players[i].position.y)
	_home_keeper.position = _project_grid(Vector2(1.45, 6))
	_rival_keeper.position = _project_grid(Vector2(18.55, 6))
	_home_keeper.z_index = int(_home_keeper.position.y)
	_rival_keeper.z_index = int(_rival_keeper.position.y)
	_ball.position = _project_grid(Vector2(10, 6))


func _project_grid(grid: Vector2) -> Vector2:
	var u := clampf(grid.x / 20.0, 0.0, 1.0)
	var v := clampf(grid.y / 12.0, 0.0, 1.0)
	var far := FAR_LEFT.lerp(FAR_RIGHT, u)
	var near := NEAR_LEFT.lerp(NEAR_RIGHT, u)
	var image_point := far.lerp(near, v)
	var view := get_viewport_rect().size
	var scale_factor := maxf(view.x / IMAGE_SIZE.x, view.y / IMAGE_SIZE.y)
	var rendered := IMAGE_SIZE * scale_factor
	var offset := Vector2((view.x - rendered.x) * 0.5, (view.y - rendered.y) * 0.45)
	return image_point * rendered + offset


func _start_demo_match() -> void:
	if _playing:
		return
	_playing = true
	_home_score = 0
	_away_score = 0
	_score_label.text = "0  :  0"
	_play_button.disabled = true
	_play_button.text = "PARTITA IN CORSO"
	_status_label.text = "ANTEPRIMA VISIVA  •  DATI DI ESEMPIO"
	var events: Array = DEMO_EVENTS.duplicate(true)
	await _play_result(events, 2, 1)
	_playing = false
	_play_button.disabled = false
	_play_button.text = "RIGIOCA ANTEPRIMA"
	_status_label.text = "E-PRO CLUBS  •  ESITO DEMO  2 - 1"
	_clock_label.text = "ANTEPRIMA COMPLETATA"


func play_match_result(events: Array, final_home_goals: int, final_away_goals: int, home_player_ids: Array = []) -> void:
	## Public presentation boundary for authoritative battle responses.
	if _playing:
		return
	_playing = true
	_home_score = 0
	_away_score = 0
	_home_player_ids = home_player_ids.duplicate()
	_score_label.text = "0  :  0"
	_play_button.disabled = true
	_play_button.text = "PARTITA IN CORSO"
	await _play_result(events, final_home_goals, final_away_goals)
	_playing = false
	_play_button.disabled = false
	_play_button.text = "GIOCA STAGE"
	_status_label.text = "ESITO UFFICIALE  •  %d - %d" % [final_home_goals, final_away_goals]


func _play_result(raw_events: Array, final_home_goals: int, final_away_goals: int) -> void:
	var events := raw_events.duplicate(true)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("minute", 0)) < int(b.get("minute", 0)))
	var possession_count := maxi(10, events.size() + 2)
	var goals_by_possession := {}
	for goal_index in range(events.size()):
		var slot := int(floor(float((goal_index + 1) * possession_count) / float(events.size() + 1)))
		while goals_by_possession.has(slot) and slot < possession_count - 1:
			slot += 1
		var event: Dictionary = events[goal_index].duplicate(true)
		if not event.has("player_index") and String(event.get("team", "home")) == "home":
			var scorer_id := String(event.get("player_id", ""))
			var roster_index := _home_player_ids.find(scorer_id)
			event["player_index"] = roster_index % 4 if roster_index >= 0 else (goal_index * 3 + 1) % 4
		goals_by_possession[clampi(slot, 0, possession_count - 1)] = event
	for possession_index in range(possession_count):
		var goal_event: Dictionary = goals_by_possession.get(possession_index, {})
		var home_attacking := String(goal_event.get("team", "home" if possession_index % 2 == 0 else "away")) == "home"
		var carrier_index := (possession_index * 7 + 1) % 4
		var receiver_index := (carrier_index + 1 + possession_index % 2) % 4
		var shooter_index := int(goal_event.get("player_index", (possession_index * 3 + 1) % 4)) % 4
		await _animate_possession(home_attacking, carrier_index, receiver_index, shooter_index, goal_event)
		var minute := int(goal_event.get("minute", roundi(float(possession_index + 1) * 90.0 / float(possession_count))))
		_clock_label.text = "%02d'  •  SIMULAZIONE AUTOMATICA" % minute
	_home_score = final_home_goals
	_away_score = final_away_goals
	_score_label.text = "%d  :  %d" % [_home_score, _away_score]
	_goal_flash = 0.8
	queue_redraw()
	await get_tree().create_timer(1.2).timeout


func _animate_possession(home_attacking: bool, carrier_index: int, receiver_index: int, shooter_index: int, goal_event: Dictionary) -> void:
	var direction := 1.0 if home_attacking else -1.0
	var attacking_players := _home_players if home_attacking else _rival_players
	var defending_players := _rival_players if home_attacking else _home_players
	var keeper := _rival_keeper if home_attacking else _home_keeper
	var start_pos: Vector2 = attacking_players[carrier_index].position
	var pass_pos: Vector2 = _project_grid(Vector2(clampf((start_pos.x / get_viewport_rect().size.x * 20.0) + direction * 2.4, 1.0, 19.0), clampf(4.0 + float(receiver_index) * 1.35, 1.0, 11.0)))
	var final_pos: Vector2 = _project_grid(Vector2(10.0 + direction * 7.0, 6.0 + float(shooter_index - 1) * 0.65))
	var first_tween := create_tween().set_parallel(true)
	first_tween.tween_property(attacking_players[carrier_index], "position", pass_pos, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	first_tween.tween_property(_ball, "position", pass_pos + Vector2(0, -3), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	for i in range(defending_players.size()):
		var chase: Vector2 = pass_pos + Vector2(-direction * (18.0 + float(i) * 5.0), (float(i) - 1.5) * 16.0)
		first_tween.tween_property(defending_players[i], "position", chase, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await first_tween.finished
	var second_tween := create_tween().set_parallel(true)
	second_tween.tween_property(attacking_players[receiver_index], "position", final_pos, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	second_tween.tween_property(_ball, "position", final_pos, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await second_tween.finished
	attacking_players[shooter_index].play("strike")
	var target := _project_grid(Vector2(19.1 if home_attacking else 0.9, 6.0))
	var shot := create_tween()
	shot.tween_property(_ball, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if goal_event.is_empty():
		keeper.play("save")
		await shot.finished
		var rebound := create_tween().set_parallel(true)
		rebound.tween_property(_ball, "position", target + Vector2(-direction * 34.0, 18.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rebound.tween_property(keeper, "scale", Vector2(0.29, 0.18), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await rebound.finished
		keeper.scale = Vector2.ONE * 0.26
		keeper.play("keeper")
	else:
		await shot.finished
		_goal_flash = 0.7
		_goal_impact.position = target
		_goal_impact.visible = true
		_goal_impact.scale = Vector2.ZERO
		var impact_tween := create_tween()
		impact_tween.tween_property(_goal_impact, "scale", Vector2.ONE * 0.72, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		impact_tween.tween_property(_goal_impact, "scale", Vector2.ONE * 0.18, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		impact_tween.tween_callback(func() -> void: _goal_impact.visible = false)
		_score_event(String(goal_event.get("team", "home")))
		var celebration := create_tween().set_parallel(true)
		for player in attacking_players:
			celebration.tween_property(player, "scale", Vector2.ONE * 0.32, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			celebration.tween_property(player, "rotation", -0.1 if home_attacking else 0.1, 0.18)
			celebration.tween_property(player, "position:y", player.position.y - 7.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await celebration.finished
		await get_tree().create_timer(0.35).timeout
		for player in attacking_players:
			player.scale = Vector2.ONE * 0.27
			player.rotation = 0.0
			player.play("run")
			_reposition_formation()
		_ball.position = _project_grid(Vector2(10, 6))
		return
	attacking_players[shooter_index].play("run")
	_reposition_formation()
	await get_tree().create_timer(0.17).timeout


func _score_event(team: String) -> void:
	if team == "home":
		_home_score += 1
	else:
		_away_score += 1
	_score_label.text = "%d  :  %d" % [_home_score, _away_score]


func _reposition_formation() -> void:
	var reset := create_tween().set_parallel(true)
	for i in range(4):
		reset.tween_property(_home_players[i], "position", _project_grid(HOME_FORMATION[i]), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		reset.tween_property(_rival_players[i], "position", _project_grid(RIVAL_FORMATION[i]), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await reset.finished

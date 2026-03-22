extends Node2D

# --- Grid constants ---
const COLS := 30
const ROWS := 32
const CELL := 20
const PLAYER_MIN_ROW := ROWS - 3

# --- Segment data ---
class Segment:
	var col: int
	var row: int
	var dir: int
	var shielded: bool
	var color_id: int  # 0=green, 1=red, 2=purple, 3=orange

	func _init(c: int, r: int, d: int, s: bool = false, cid: int = 0) -> void:
		col = c
		row = r
		dir = d
		shielded = s
		color_id = cid

# --- Block data ---
class BlockData:
	var hp: int
	var max_hp: int

	func _init(h: int, m: int) -> void:
		hp = h
		max_hp = m

# --- Particle ---
class Particle:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var life: float
	var max_life: float
	var size: float

	func _init(p: Vector2, v: Vector2, c: Color, l: float, s: float) -> void:
		pos = p
		vel = v
		color = c
		life = l
		max_life = l
		size = s

# --- Bullet ---
class Bullet:
	var x: float
	var y: float
	var vx: float
	var vy: float
	var trail: Array  # Array of Vector2
	var piercing: bool

	func _init(bx: float, by: float, bvx: float, bvy: float, p: bool = false) -> void:
		x = bx
		y = by
		vx = bvx
		vy = bvy
		trail = []
		piercing = p

# --- Power-Up ---
class PowerUp:
	var x: float
	var y: float
	var type: String  # "double", "triple", "rapid", "shield", "piercing"
	var bob_offset: float
	var fall_speed: float

	func _init(px: float, py: float, t: String) -> void:
		x = px
		y = py
		type = t
		bob_offset = randf() * TAU
		fall_speed = 40.0  # pixels per second

# --- Game state ---
enum GameState { MENU, PLAYING, GAME_OVER, LEVEL_COMPLETE }

var state: GameState = GameState.MENU
var score: int = 0
var level: int = 1
var lives: int = 3

var player_col: int = COLS / 2
var player_row: int = ROWS - 1
var player_smooth_x: float = 0.0
var player_smooth_y: float = 0.0

var bullets: Array = []  # Array of Bullet
const BULLET_SPEED := 1200.0
const MAX_BULLETS_NORMAL := 1
const MAX_BULLETS_RAPID := 4

var centipedes: Array = []
var blocks: Dictionary = {}
var powerups: Array = []  # Array of PowerUp

var tick_timer: float = 0.0
var tick_interval: float = 0.12

var player_move_timer: float = 0.0
const PLAYER_MOVE_INTERVAL := 0.035

var invincible: float = 0.0

var particles: Array = []
var screen_shake: float = 0.0
var time_elapsed: float = 0.0

# --- Active power-ups (timers) ---
var powerup_double: float = 0.0      # double shot timer
var powerup_triple: float = 0.0      # triple spread timer
var powerup_rapid: float = 0.0       # rapid fire timer
var powerup_shield: float = 0.0      # shield timer
var powerup_piercing: float = 0.0    # piercing shot timer
const POWERUP_DURATION := 8.0
const POWERUP_DROP_CHANCE := 0.3     # 30% chance on segment kill

# Power-up type definitions: name, color, symbol
const POWERUP_TYPES: Array = ["double", "triple", "rapid", "shield", "piercing"]
const POWERUP_COLORS: Dictionary = {
	"double": Color(0.2, 0.6, 1.0),
	"triple": Color(1.0, 0.4, 0.8),
	"rapid": Color(1.0, 0.8, 0.0),
	"shield": Color(0.3, 1.0, 0.5),
	"piercing": Color(1.0, 0.5, 0.1),
}
const POWERUP_LABELS: Dictionary = {
	"double": "2x",
	"triple": "3x",
	"rapid": "RF",
	"shield": "SH",
	"piercing": "PI",
}
const POWERUP_NAMES: Dictionary = {
	"double": "DOPPELSCHUSS",
	"triple": "DREIFACHSCHUSS",
	"rapid": "SCHNELLFEUER",
	"shield": "SCHILD",
	"piercing": "DURCHSCHLAG",
}

# --- Worm colors (head, body_bright, body_dark) ---
const WORM_PALETTES: Array = [
	[Color(0.3, 1.0, 0.4), Color(0.2, 0.9, 0.3), Color(0.05, 0.4, 0.15)],    # 0: green
	[Color(1.0, 0.35, 0.3), Color(0.9, 0.25, 0.2), Color(0.4, 0.1, 0.08)],    # 1: red
	[Color(0.7, 0.3, 1.0), Color(0.6, 0.2, 0.9), Color(0.25, 0.08, 0.4)],     # 2: purple
	[Color(1.0, 0.7, 0.2), Color(0.9, 0.6, 0.15), Color(0.4, 0.25, 0.05)],    # 3: orange
]

# --- Wave tracking ---
var wave_count: int = 0  # how many times centipedes re-entered from top

# --- Highscore ---
const HIGHSCORE_FILE := "user://highscores.json"
const MAX_HIGHSCORES := 5
var highscores: Array = []  # Array of {score: int, level: int}

# --- Audio ---
var sfx_shoot: AudioStreamPlayer
var sfx_hit: AudioStreamPlayer
var sfx_block_break: AudioStreamPlayer
var sfx_death: AudioStreamPlayer
var sfx_level_up: AudioStreamPlayer
var sfx_powerup: AudioStreamPlayer

# --- HUD ---
var hud_label: Label
var msg_label: Label
var powerup_flash: float = 0.0
var powerup_flash_text: String = ""


func _ready() -> void:
	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)

	hud_label = Label.new()
	hud_label.position = Vector2(10, 2)
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	canvas_layer.add_child(hud_label)

	msg_label = Label.new()
	msg_label.position = Vector2(0, ROWS * CELL + 4)
	msg_label.size = Vector2(COLS * CELL, 30)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 18)
	msg_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	canvas_layer.add_child(msg_label)

	msg_label.text = "ENTER zum Starten"
	_create_sounds()
	_load_highscores()
	_update_hud()

	player_smooth_x = player_col * CELL + CELL / 2.0
	player_smooth_y = player_row * CELL + CELL / 2.0


# ==================== HIGHSCORE ====================
func _load_highscores() -> void:
	highscores = []
	if FileAccess.file_exists(HIGHSCORE_FILE):
		var file := FileAccess.open(HIGHSCORE_FILE, FileAccess.READ)
		if file:
			var json := JSON.new()
			var err := json.parse(file.get_as_text())
			file.close()
			if err == OK and json.data is Array:
				highscores = json.data


func _save_highscores() -> void:
	var file := FileAccess.open(HIGHSCORE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(highscores))
		file.close()


func _submit_highscore() -> void:
	highscores.append({"score": score, "level": level})
	highscores.sort_custom(func(a, b): return a["score"] > b["score"])
	if highscores.size() > MAX_HIGHSCORES:
		highscores.resize(MAX_HIGHSCORES)
	_save_highscores()


func _get_highscore() -> int:
	if highscores.size() > 0:
		return highscores[0]["score"]
	return 0


# ==================== SOUND ====================
func _create_sounds() -> void:
	sfx_shoot = _make_sfx_player(_generate_shoot_sound())
	sfx_hit = _make_sfx_player(_generate_hit_sound())
	sfx_block_break = _make_sfx_player(_generate_break_sound())
	sfx_death = _make_sfx_player(_generate_death_sound())
	sfx_level_up = _make_sfx_player(_generate_levelup_sound())
	sfx_powerup = _make_sfx_player(_generate_powerup_sound())


func _make_sfx_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -6.0
	add_child(p)
	return p


func _generate_wav(samples: PackedFloat32Array, mix_rate: int = 22050) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var s := clampi(int(samples[i] * 32767.0), -32768, 32767)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	wav.data = data
	return wav


func _synth(dur: float, callback: Callable) -> AudioStreamWAV:
	var rate := 22050
	var cnt := int(rate * dur)
	var s := PackedFloat32Array()
	s.resize(cnt)
	for i in range(cnt):
		var t := float(i) / rate
		s[i] = callback.call(t, dur)
	return _generate_wav(s, rate)


func _generate_shoot_sound() -> AudioStreamWAV:
	return _synth(0.08, func(t: float, d: float) -> float:
		return sin(t * lerpf(1800.0, 800.0, t / d) * TAU) * (1.0 - t / d) * 0.4)

func _generate_hit_sound() -> AudioStreamWAV:
	return _synth(0.12, func(t: float, d: float) -> float:
		return (sin(t * 600.0 * TAU) * 0.3 + sin(t * 900.0 * TAU) * 0.2) * (1.0 - t / d))

func _generate_break_sound() -> AudioStreamWAV:
	return _synth(0.2, func(t: float, d: float) -> float:
		var env := (1.0 - t / d) * (1.0 - t / d)
		return (sin(t * 200.0 * TAU) * 0.3 + randf_range(-1.0, 1.0) * 0.15) * env)

func _generate_death_sound() -> AudioStreamWAV:
	return _synth(0.5, func(t: float, d: float) -> float:
		var freq := lerpf(400.0, 80.0, t / d)
		return (sin(t * freq * TAU) * 0.3 + sin(t * freq * 0.5 * TAU) * 0.2) * (1.0 - t / d))

func _generate_levelup_sound() -> AudioStreamWAV:
	return _synth(0.4, func(t: float, d: float) -> float:
		var freq := 1047.0
		if t < 0.1: freq = 523.0
		elif t < 0.2: freq = 659.0
		elif t < 0.3: freq = 784.0
		return sin(t * freq * TAU) * (1.0 - t / d) * 0.35)

func _generate_powerup_sound() -> AudioStreamWAV:
	return _synth(0.25, func(t: float, d: float) -> float:
		var freq := lerpf(600.0, 1400.0, t / d)
		return (sin(t * freq * TAU) * 0.3 + sin(t * freq * 1.5 * TAU) * 0.15) * (1.0 - t / d))


func _play_sfx(player: AudioStreamPlayer) -> void:
	if player.playing:
		player.stop()
	player.play()


# ==================== HUD ====================
func _update_hud() -> void:
	hud_label.text = "SCORE: %d    LEVEL: %d    LIVES: %d    HI: %d" % [score, level, lives, _get_highscore()]


# ==================== LEVEL ====================
func _get_level_config() -> Dictionary:
	return {
		"segments": mini(8 + level * 3, 30),
		"speed": maxf(0.13 - level * 0.01, 0.04),
		"num_blocks": mini(3 + level * 3, 25),
		"max_block_hp": mini(1 + level / 2, 3),
		"shield_chance": clampf(0.05 * (level - 1), 0.0, 0.4),  # 0% at lvl1, up to 40%
	}


func _bk(col: int, row: int) -> String:
	return "%d,%d" % [col, row]


func _init_level() -> void:
	var cfg := _get_level_config()
	tick_interval = cfg["speed"]
	centipedes.clear()
	blocks.clear()
	bullets.clear()
	powerups.clear()
	particles.clear()
	tick_timer = 0.0

	# Keep active power-ups across levels (reward for doing well)
	wave_count = 0

	var shield_chance: float = cfg["shield_chance"]
	var chain: Array = []
	var seg_count: int = cfg["segments"]
	for i in range(seg_count):
		var is_shielded := randf() < shield_chance
		chain.append(Segment.new(COLS - 1 + i, 0, -1, is_shielded, 0))
	centipedes.append(chain)

	var num_blocks: int = cfg["num_blocks"]
	var max_hp: int = cfg["max_block_hp"]
	var placed := 0
	while placed < num_blocks:
		var c := randi_range(0, COLS - 1)
		var r := randi_range(2, ROWS - 6)
		var key := _bk(c, r)
		if not blocks.has(key):
			var hp := randi_range(1, max_hp)
			blocks[key] = BlockData.new(hp, hp)
			placed += 1

	player_col = COLS / 2
	player_row = ROWS - 1
	player_smooth_x = player_col * CELL + CELL / 2.0
	player_smooth_y = player_row * CELL + CELL / 2.0
	invincible = 2.0


func _spawn_centipede_from_top(seg_count: int, color_id: int) -> void:
	var cfg := _get_level_config()
	var shield_chance: float = cfg["shield_chance"]
	# Increase shield chance with each wave
	shield_chance = clampf(shield_chance + wave_count * 0.05, 0.0, 0.5)
	var dir := -1 if randi() % 2 == 0 else 1
	var start_col := COLS - 1 if dir == -1 else 0
	var chain: Array = []
	for i in range(seg_count):
		var is_shielded := randf() < shield_chance
		var col_offset := i * (-dir)  # segments trail behind head
		chain.append(Segment.new(start_col + col_offset, -i, dir, is_shielded, color_id))
	centipedes.append(chain)


func _start_game() -> void:
	score = 0
	level = 1
	lives = 3
	state = GameState.PLAYING
	msg_label.text = ""
	powerup_double = 0.0
	powerup_triple = 0.0
	powerup_rapid = 0.0
	powerup_shield = 0.0
	powerup_piercing = 0.0
	_init_level()
	_update_hud()


func _spawn_particles(pos: Vector2, color: Color, count: int, speed: float) -> void:
	for i in range(count):
		var angle := randf() * TAU
		var spd := randf_range(speed * 0.3, speed)
		var vel := Vector2(cos(angle), sin(angle)) * spd
		var life := randf_range(0.2, 0.6)
		var sz := randf_range(2.0, 5.0)
		particles.append(Particle.new(pos, vel, color, life, sz))


func _maybe_spawn_powerup(col: int, row: int) -> void:
	if randf() < POWERUP_DROP_CHANCE:
		var type_idx := randi_range(0, POWERUP_TYPES.size() - 1)
		var ptype: String = POWERUP_TYPES[type_idx]
		var px: float = col * CELL + CELL / 2.0
		var py: float = row * CELL + CELL / 2.0
		powerups.append(PowerUp.new(px, py, ptype))


func _activate_powerup(ptype: String) -> void:
	match ptype:
		"double":
			powerup_double = POWERUP_DURATION
		"triple":
			powerup_triple = POWERUP_DURATION
		"rapid":
			powerup_rapid = POWERUP_DURATION
		"shield":
			powerup_shield = POWERUP_DURATION
		"piercing":
			powerup_piercing = POWERUP_DURATION
	powerup_flash = 1.5
	powerup_flash_text = POWERUP_NAMES.get(ptype, ptype)
	_play_sfx(sfx_powerup)


func _get_max_bullets() -> int:
	if powerup_rapid > 0:
		return MAX_BULLETS_RAPID
	return MAX_BULLETS_NORMAL


func _fire_bullets() -> void:
	if bullets.size() >= _get_max_bullets():
		return

	var px := player_smooth_x
	var py := player_smooth_y - CELL / 2.0
	var is_piercing := powerup_piercing > 0

	if powerup_triple > 0:
		# Three-way spread
		bullets.append(Bullet.new(px, py, 0.0, -BULLET_SPEED, is_piercing))
		bullets.append(Bullet.new(px, py, -BULLET_SPEED * 0.15, -BULLET_SPEED, is_piercing))
		bullets.append(Bullet.new(px, py, BULLET_SPEED * 0.15, -BULLET_SPEED, is_piercing))
	elif powerup_double > 0:
		# Double sequential (one behind the other)
		bullets.append(Bullet.new(px, py, 0.0, -BULLET_SPEED, is_piercing))
		bullets.append(Bullet.new(px, py + CELL * 1.2, 0.0, -BULLET_SPEED, is_piercing))
	else:
		# Single shot
		bullets.append(Bullet.new(px, py, 0.0, -BULLET_SPEED, is_piercing))

	_play_sfx(sfx_shoot)


# ==================== INPUT ====================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("start"):
		if state == GameState.MENU or state == GameState.GAME_OVER:
			_start_game()
		elif state == GameState.LEVEL_COMPLETE:
			level += 1
			state = GameState.PLAYING
			msg_label.text = ""
			_init_level()
			_update_hud()


# ==================== UPDATE ====================
func _process(delta: float) -> void:
	time_elapsed += delta

	# Update particles
	var alive_particles: Array = []
	for p in particles:
		p.life -= delta
		if p.life > 0:
			p.pos += p.vel * delta
			p.vel *= 0.95
			alive_particles.append(p)
	particles = alive_particles

	if screen_shake > 0:
		screen_shake = maxf(screen_shake - delta * 15.0, 0.0)

	if powerup_flash > 0:
		powerup_flash -= delta

	if state != GameState.PLAYING:
		queue_redraw()
		return

	if invincible > 0.0:
		invincible -= delta

	# Power-up timers
	if powerup_double > 0:
		powerup_double = maxf(powerup_double - delta, 0.0)
	if powerup_triple > 0:
		powerup_triple = maxf(powerup_triple - delta, 0.0)
	if powerup_rapid > 0:
		powerup_rapid = maxf(powerup_rapid - delta, 0.0)
	if powerup_shield > 0:
		powerup_shield = maxf(powerup_shield - delta, 0.0)
	if powerup_piercing > 0:
		powerup_piercing = maxf(powerup_piercing - delta, 0.0)

	# Smooth player interpolation
	var target_x := player_col * CELL + CELL / 2.0
	var target_y := player_row * CELL + CELL / 2.0
	player_smooth_x = lerpf(player_smooth_x, target_x, minf(delta * 20.0, 1.0))
	player_smooth_y = lerpf(player_smooth_y, target_y, minf(delta * 20.0, 1.0))

	# Player movement
	player_move_timer += delta
	if player_move_timer >= PLAYER_MOVE_INTERVAL:
		player_move_timer = 0.0
		if Input.is_action_pressed("move_left") and player_col > 0:
			if not blocks.has(_bk(player_col - 1, player_row)):
				player_col -= 1
		if Input.is_action_pressed("move_right") and player_col < COLS - 1:
			if not blocks.has(_bk(player_col + 1, player_row)):
				player_col += 1
		if Input.is_action_pressed("move_up") and player_row > PLAYER_MIN_ROW:
			if not blocks.has(_bk(player_col, player_row - 1)):
				player_row -= 1
		if Input.is_action_pressed("move_down") and player_row < ROWS - 1:
			if not blocks.has(_bk(player_col, player_row + 1)):
				player_row += 1

	# Shoot
	if Input.is_action_just_pressed("shoot"):
		_fire_bullets()

	# Bullet movement & collision
	var alive_bullets: Array = []
	for b in bullets:
		b.trail.append(Vector2(b.x, b.y))
		if b.trail.size() > 8:
			b.trail.pop_front()

		b.x += b.vx * delta
		b.y += b.vy * delta
		var b_col := int(b.x / CELL)
		var b_row := int(b.y / CELL)

		var bullet_dead := false

		# Off screen
		if b.y < 0 or b.x < 0 or b.x > COLS * CELL:
			bullet_dead = true

		# Block collision
		if not bullet_dead:
			var block_key := _bk(b_col, b_row)
			if blocks.has(block_key):
				var block: BlockData = blocks[block_key]
				block.hp -= 1
				var hit_pos := Vector2(b_col * CELL + CELL / 2.0, b_row * CELL + CELL / 2.0)
				if block.hp <= 0:
					blocks.erase(block_key)
					score += 5
					_spawn_particles(hit_pos, Color(1.0, 0.6, 0.2), 12, 120.0)
					_play_sfx(sfx_block_break)
				else:
					_spawn_particles(hit_pos, Color(1.0, 1.0, 0.5), 4, 60.0)
					_play_sfx(sfx_hit)
				if not b.piercing:
					bullet_dead = true
				screen_shake = 0.3
				_update_hud()

		# Centipede collision
		if not bullet_dead:
			var seg_hit := false
			for ci in range(centipedes.size() - 1, -1, -1):
				if seg_hit and not b.piercing:
					break
				var chain: Array = centipedes[ci]
				for si in range(chain.size() - 1, -1, -1):
					if seg_hit and not b.piercing:
						break
					var seg: Segment = chain[si]
					if seg.col == b_col and seg.row == b_row:
						seg_hit = true
						var hit_pos := Vector2(seg.col * CELL + CELL / 2.0, seg.row * CELL + CELL / 2.0)

						if seg.shielded:
							# Shield absorbs hit
							seg.shielded = false
							score += 5
							_spawn_particles(hit_pos, Color(0.5, 0.8, 1.0), 8, 80.0)
							screen_shake = 0.2
							_play_sfx(sfx_hit)
						else:
							# Segment destroyed
							score += 10
							_spawn_particles(hit_pos, Color(0.2, 1.0, 0.3), 15, 150.0)
							screen_shake = 0.5
							_play_sfx(sfx_hit)

							var cfg := _get_level_config()
							var hp := randi_range(1, cfg["max_block_hp"])
							blocks[_bk(seg.col, seg.row)] = BlockData.new(hp, hp)

							_maybe_spawn_powerup(seg.col, seg.row - 1)

							var before: Array = chain.slice(0, si)
							var after: Array = chain.slice(si + 1)
							if after.size() > 0:
								var head_seg: Segment = after[0]
								head_seg.dir = -head_seg.dir

							centipedes.remove_at(ci)
							if before.size() > 0:
								centipedes.append(before)
							if after.size() > 0:
								centipedes.append(after)

						if not b.piercing:
							bullet_dead = true
						_update_hud()

		if not bullet_dead:
			alive_bullets.append(b)

	bullets = alive_bullets

	# Power-up falling & pickup
	var alive_powerups: Array = []
	for pu in powerups:
		pu.y += pu.fall_speed * delta
		var pu_pos := Vector2(pu.x, pu.y)
		var player_pos := Vector2(player_smooth_x, player_smooth_y)
		var picked_up := false

		# Player proximity pickup (within 1 cell distance)
		if pu_pos.distance_to(player_pos) < CELL:
			picked_up = true

		# Bullet collision pickup
		if not picked_up:
			for b in bullets:
				if Vector2(b.x, b.y).distance_to(pu_pos) < CELL * 0.7:
					picked_up = true
					break

		if picked_up:
			_activate_powerup(pu.type)
			score += 25
			_spawn_particles(pu_pos, POWERUP_COLORS.get(pu.type, Color.WHITE), 10, 100.0)
			_update_hud()
		elif pu.y < ROWS * CELL:
			alive_powerups.append(pu)
		# else: fell off screen, discard

	powerups = alive_powerups

	# Centipede tick
	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		_tick_centipedes()

	# Player collision
	if invincible <= 0.0:
		for chain in centipedes:
			for seg in chain:
				if seg.col == player_col and seg.row == player_row:
					# Shield absorbs hit
					if powerup_shield > 0:
						powerup_shield = 0.0
						invincible = 1.0
						_spawn_particles(
							Vector2(player_smooth_x, player_smooth_y),
							Color(0.3, 1.0, 0.5), 15, 150.0)
						screen_shake = 0.5
						_play_sfx(sfx_hit)
						_update_hud()
						queue_redraw()
						return

					lives -= 1
					_update_hud()
					_spawn_particles(
						Vector2(player_smooth_x, player_smooth_y),
						Color(0.0, 1.0, 1.0), 20, 200.0)
					screen_shake = 1.0
					_play_sfx(sfx_death)
					if lives <= 0:
						state = GameState.GAME_OVER
						_submit_highscore()
						msg_label.text = ""
					else:
						player_col = COLS / 2
						player_row = ROWS - 1
						player_smooth_x = player_col * CELL + CELL / 2.0
						player_smooth_y = player_row * CELL + CELL / 2.0
						bullets.clear()
						invincible = 2.0
					queue_redraw()
					return

	# Win
	var total_segments := 0
	for chain in centipedes:
		total_segments += chain.size()
	if total_segments == 0:
		state = GameState.LEVEL_COMPLETE
		score += 100 * level
		msg_label.text = ""
		_play_sfx(sfx_level_up)

	_update_hud()
	queue_redraw()


func _tick_centipedes() -> void:
	var escaped_segments: Array = []  # [{count, color_id}] for chains that left the bottom

	for chain in centipedes:
		if chain.size() == 0:
			continue
		var old_positions: Array = []
		for seg in chain:
			old_positions.append(Vector2i(seg.col, seg.row))
		var head: Segment = chain[0]
		var next_col := head.col + head.dir
		var next_key := _bk(next_col, head.row)
		if next_col < 0 or next_col >= COLS or blocks.has(next_key):
			head.row += 1
			head.dir = -head.dir
		else:
			head.col = next_col
		for i in range(1, chain.size()):
			chain[i].col = old_positions[i - 1].x
			chain[i].row = old_positions[i - 1].y
			chain[i].dir = head.dir

	# Check for chains that escaped the bottom
	var remaining: Array = []
	for chain in centipedes:
		if chain.size() == 0:
			continue
		# Check if all segments are below the screen
		var all_below := true
		for seg in chain:
			if seg.row < ROWS:
				all_below = false
				break
		if all_below:
			escaped_segments.append({"count": chain.size(), "color_id": chain[0].color_id})
		else:
			remaining.append(chain)
	centipedes = remaining

	# Respawn escaped chains from top + bring a friend
	for esc in escaped_segments:
		wave_count += 1
		var new_color: int = (wave_count) % WORM_PALETTES.size()
		# Original chain comes back from top
		_spawn_centipede_from_top(esc["count"], esc["color_id"])
		# New friend joins (smaller)
		var friend_size := maxi(esc["count"] / 2, 3)
		_spawn_centipede_from_top(friend_size, new_color)


# ==================== DRAWING ====================
func _draw() -> void:
	var shake_offset := Vector2.ZERO
	if screen_shake > 0:
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * screen_shake * 4.0

	# Background gradient
	for r in range(ROWS):
		var t := float(r) / ROWS
		var bg_color := Color(0.02 + t * 0.03, 0.02 + t * 0.01, 0.06 + t * 0.04)
		draw_rect(Rect2(shake_offset.x, r * CELL + shake_offset.y, COLS * CELL, CELL), bg_color)

	# Subtle grid
	for r in range(ROWS + 1):
		var alpha: float = 0.06 + sin(float(r) * 0.3 + time_elapsed * 0.5) * 0.02
		draw_line(
			Vector2(shake_offset.x, r * CELL + shake_offset.y),
			Vector2(COLS * CELL + shake_offset.x, r * CELL + shake_offset.y),
			Color(0.3, 0.4, 0.6, alpha), 0.5)
	for c in range(COLS + 1):
		draw_line(
			Vector2(c * CELL + shake_offset.x, shake_offset.y),
			Vector2(c * CELL + shake_offset.x, ROWS * CELL + shake_offset.y),
			Color(0.3, 0.4, 0.6, 0.04), 0.5)

	# Player zone glow
	for r in range(PLAYER_MIN_ROW, ROWS):
		var t := float(r - PLAYER_MIN_ROW) / (ROWS - PLAYER_MIN_ROW)
		draw_rect(
			Rect2(shake_offset.x, r * CELL + shake_offset.y, COLS * CELL, CELL),
			Color(0.0, 0.3, 0.4, 0.04 + t * 0.03))

	# --- Power-ups on field ---
	for pu in powerups:
		var px: float = pu.x + shake_offset.x
		var py: float = pu.y + shake_offset.y
		var bob := sin(time_elapsed * 4.0 + pu.bob_offset) * 2.0
		px += bob * 0.5
		var pu_color: Color = POWERUP_COLORS.get(pu.type, Color.WHITE)

		# Glow
		draw_circle(Vector2(px, py), CELL / 2.0 + 4.0, Color(pu_color.r, pu_color.g, pu_color.b, 0.2 + sin(time_elapsed * 6.0) * 0.1))
		# Background
		draw_circle(Vector2(px, py), CELL / 2.0 - 1, Color(0.1, 0.1, 0.15))
		# Colored ring
		for a in range(24):
			var angle := float(a) / 24.0 * TAU
			var next_angle := float(a + 1) / 24.0 * TAU
			var r_size := CELL / 2.0 - 2.0
			draw_line(
				Vector2(px + cos(angle) * r_size, py + sin(angle) * r_size),
				Vector2(px + cos(next_angle) * r_size, py + sin(next_angle) * r_size),
				pu_color, 2.0)
		# Label
		var lbl: String = POWERUP_LABELS.get(pu.type, "?")
		var font := ThemeDB.fallback_font
		var ts := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_string(font, Vector2(px - ts.x / 2.0, py + ts.y / 4.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, pu_color)

	# --- Blocks ---
	for key in blocks:
		var block: BlockData = blocks[key]
		var parts: PackedStringArray = key.split(",")
		var c: int = int(parts[0])
		var r: int = int(parts[1])
		var bx := c * CELL + shake_offset.x
		var by := r * CELL + shake_offset.y

		var glow_color: Color
		var face_color: Color
		var dark_color: Color
		if block.hp == 1:
			glow_color = Color(1.0, 0.3, 0.2, 0.3)
			face_color = Color(0.9, 0.25, 0.2)
			dark_color = Color(0.5, 0.12, 0.1)
		elif block.hp == 2:
			glow_color = Color(1.0, 0.8, 0.2, 0.3)
			face_color = Color(0.9, 0.75, 0.2)
			dark_color = Color(0.5, 0.4, 0.1)
		else:
			glow_color = Color(0.2, 1.0, 0.3, 0.3)
			face_color = Color(0.25, 0.85, 0.3)
			dark_color = Color(0.12, 0.45, 0.15)

		draw_rect(Rect2(bx - 2, by - 2, CELL + 4, CELL + 4), glow_color)
		draw_rect(Rect2(bx + 1, by + 1, CELL - 2, CELL - 2), dark_color)
		draw_rect(Rect2(bx + 1, by + 1, CELL - 4, CELL - 4), face_color)
		draw_rect(Rect2(bx + 2, by + 2, CELL - 6, 3), Color(1, 1, 1, 0.2))

		if block.max_hp > 1 and block.hp < block.max_hp:
			var cx := bx + CELL / 2.0
			var crack_col := Color(0, 0, 0, 0.5)
			for _j in range(block.max_hp - block.hp):
				var ox := randf_range(-4, 4)
				draw_line(Vector2(cx + ox, by + 3), Vector2(cx + ox + 2, by + CELL - 3), crack_col, 1.5)

	# --- Centipedes ---
	for chain in centipedes:
		# Connection lines
		for i in range(chain.size() - 1):
			var seg_a: Segment = chain[i]
			var seg_b: Segment = chain[i + 1]
			if seg_a.col >= 0 and seg_a.col < COLS and seg_b.col >= 0 and seg_b.col < COLS:
				if seg_a.row >= 0 and seg_a.row < ROWS and seg_b.row >= 0 and seg_b.row < ROWS:
					var ax := seg_a.col * CELL + CELL / 2.0 + shake_offset.x
					var ay := seg_a.row * CELL + CELL / 2.0 + shake_offset.y
					var bbx := seg_b.col * CELL + CELL / 2.0 + shake_offset.x
					var bby := seg_b.row * CELL + CELL / 2.0 + shake_offset.y
					var palette: Array = WORM_PALETTES[seg_a.color_id % WORM_PALETTES.size()]
					var line_col: Color = palette[2]
					draw_line(Vector2(ax, ay), Vector2(bbx, bby), Color(line_col.r, line_col.g, line_col.b, 0.6), 3.0)

		# Segments
		for i in range(chain.size()):
			var seg: Segment = chain[i]
			if seg.col < 0 or seg.col >= COLS or seg.row < 0 or seg.row >= ROWS:
				continue
			var cx := seg.col * CELL + CELL / 2.0 + shake_offset.x
			var cy := seg.row * CELL + CELL / 2.0 + shake_offset.y
			var is_head := (i == 0)
			var palette: Array = WORM_PALETTES[seg.color_id % WORM_PALETTES.size()]

			var gradient_t := float(i) / maxf(chain.size() - 1, 1)
			var seg_color: Color
			if is_head:
				seg_color = palette[0]
			else:
				var bright: Color = palette[1]
				var dark: Color = palette[2]
				seg_color = Color(
					lerpf(bright.r, dark.r, gradient_t),
					lerpf(bright.g, dark.g, gradient_t),
					lerpf(bright.b, dark.b, gradient_t))

			# Glow
			draw_circle(Vector2(cx, cy), CELL / 2.0 + 2.0, Color(seg_color.r, seg_color.g, seg_color.b, 0.2))
			# Body
			draw_circle(Vector2(cx, cy), CELL / 2.0 - 1.5, seg_color)
			# Highlight
			draw_circle(Vector2(cx - 2, cy - 2), 3.0, Color(1, 1, 1, 0.25))

			# Shield visual
			if seg.shielded:
				var shield_pulse := 0.35 + sin(time_elapsed * 6.0 + float(i) * 0.5) * 0.15
				draw_circle(Vector2(cx, cy), CELL / 2.0 + 1.0, Color(0.4, 0.7, 1.0, shield_pulse))
				# Shield ring
				for a in range(12):
					var angle := float(a) / 12.0 * TAU + time_elapsed * 3.0
					var next_angle := float(a + 1) / 12.0 * TAU + time_elapsed * 3.0
					var ring_r := CELL / 2.0
					draw_line(
						Vector2(cx + cos(angle) * ring_r, cy + sin(angle) * ring_r),
						Vector2(cx + cos(next_angle) * ring_r, cy + sin(next_angle) * ring_r),
						Color(0.5, 0.8, 1.0, shield_pulse + 0.2), 1.5)

			# Head details
			if is_head:
				var head_col: Color = palette[0]
				var eye_off := -4.0 if seg.dir < 0 else 4.0
				draw_circle(Vector2(cx + eye_off - 2, cy - 2), 3.0, Color.WHITE)
				draw_circle(Vector2(cx + eye_off + 2, cy - 2), 3.0, Color.WHITE)
				draw_circle(Vector2(cx + eye_off - 2 + seg.dir, cy - 2), 1.5, Color(0.1, 0.1, 0.1))
				draw_circle(Vector2(cx + eye_off + 2 + seg.dir, cy - 2), 1.5, Color(0.1, 0.1, 0.1))
				draw_line(
					Vector2(cx + seg.dir * 3, cy - 6),
					Vector2(cx + seg.dir * 8, cy - 12),
					Color(head_col.r, head_col.g, head_col.b, 0.7), 1.5)
				draw_line(
					Vector2(cx + seg.dir * 3, cy - 4),
					Vector2(cx + seg.dir * 10, cy - 8),
					Color(head_col.r, head_col.g, head_col.b, 0.7), 1.5)

	# --- Player ---
	if state == GameState.PLAYING:
		var blink := invincible > 0.0 and int(invincible * 8.0) % 2 == 0
		if not blink:
			var px := player_smooth_x + shake_offset.x
			var py := player_smooth_y + shake_offset.y
			var half := CELL / 2.0

			# Shield visual
			if powerup_shield > 0:
				var shield_alpha := 0.2 + sin(time_elapsed * 5.0) * 0.1
				if powerup_shield < 2.0:
					shield_alpha *= fmod(powerup_shield * 4.0, 1.0)  # Flicker when expiring
				draw_circle(Vector2(px, py), half + 5.0, Color(0.3, 1.0, 0.5, shield_alpha))
				for a in range(16):
					var angle := float(a) / 16.0 * TAU + time_elapsed * 2.0
					var next_angle := float(a + 1) / 16.0 * TAU + time_elapsed * 2.0
					draw_line(
						Vector2(px + cos(angle) * (half + 4), py + sin(angle) * (half + 4)),
						Vector2(px + cos(next_angle) * (half + 4), py + sin(next_angle) * (half + 4)),
						Color(0.3, 1.0, 0.5, shield_alpha * 2.0), 1.5)

			# Engine glow
			var glow_intensity := 0.4 + sin(time_elapsed * 12.0) * 0.15
			draw_circle(Vector2(px, py + 4), 8.0, Color(0.0, 0.8, 1.0, glow_intensity * 0.3))

			# Ship body
			var ship_color := Color(0.0, 0.85, 0.95)
			if powerup_piercing > 0:
				ship_color = Color(1.0, 0.6, 0.2)  # Orange when piercing
			elif powerup_triple > 0:
				ship_color = Color(1.0, 0.5, 0.9)  # Pink when triple
			elif powerup_double > 0:
				ship_color = Color(0.3, 0.7, 1.0)  # Blue when double

			var ship_pts := PackedVector2Array([
				Vector2(px, py - half + 1),
				Vector2(px + half - 1, py + half - 2),
				Vector2(px + 3, py + half - 5),
				Vector2(px, py + 2),
				Vector2(px - 3, py + half - 5),
				Vector2(px - half + 1, py + half - 2),
			])
			draw_colored_polygon(ship_pts, ship_color)

			var cockpit_pts := PackedVector2Array([
				Vector2(px, py - half + 5),
				Vector2(px + 3, py + 1),
				Vector2(px, py + 4),
				Vector2(px - 3, py + 1),
			])
			draw_colored_polygon(cockpit_pts, Color(ship_color.r + 0.3, ship_color.g + 0.1, ship_color.b + 0.05).clamp())

			draw_line(Vector2(px, py - half + 2), Vector2(px - 2, py - 2), Color(1, 1, 1, 0.4), 1.5)

			# Muzzle indicators for double/triple
			if powerup_double > 0 or powerup_triple > 0:
				draw_circle(Vector2(px - 5, py - half + 3), 1.5, Color(1, 1, 0.5, 0.7))
				draw_circle(Vector2(px + 5, py - half + 3), 1.5, Color(1, 1, 0.5, 0.7))
			if powerup_triple > 0:
				draw_circle(Vector2(px, py - half), 1.5, Color(1, 1, 0.5, 0.7))

			# Engine flame
			var flame_len := 3.0 + sin(time_elapsed * 20.0) * 2.0
			if powerup_rapid > 0:
				flame_len *= 1.5  # Bigger flame for rapid fire
			var flame_pts := PackedVector2Array([
				Vector2(px - 3, py + half - 3),
				Vector2(px, py + half - 3 + flame_len),
				Vector2(px + 3, py + half - 3),
			])
			draw_colored_polygon(flame_pts, Color(1.0, 0.6, 0.1, 0.8))
			var flame2_pts := PackedVector2Array([
				Vector2(px - 1.5, py + half - 3),
				Vector2(px, py + half - 3 + flame_len * 0.6),
				Vector2(px + 1.5, py + half - 3),
			])
			draw_colored_polygon(flame2_pts, Color(1.0, 1.0, 0.5, 0.9))

	# --- Bullets ---
	for b in bullets:
		# Trail
		for i in range(b.trail.size()):
			var t: float = float(i) / b.trail.size()
			var trail_pos: Vector2 = b.trail[i]
			var alpha: float = t * 0.4
			var trail_size: float = t * 2.5
			var trail_color := Color(1.0, 0.8, 0.2, alpha)
			if b.piercing:
				trail_color = Color(1.0, 0.5, 0.1, alpha)
			draw_circle(trail_pos + shake_offset, trail_size, trail_color)

		var bpos := Vector2(b.x + shake_offset.x, b.y + shake_offset.y)

		# Piercing glow is bigger
		var glow_size := 6.0
		var bullet_color := Color(1.0, 1.0, 0.4)
		if b.piercing:
			glow_size = 8.0
			bullet_color = Color(1.0, 0.6, 0.2)

		draw_circle(bpos, glow_size, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.3))

		var b_pts := PackedVector2Array([
			Vector2(bpos.x, bpos.y - 6),
			Vector2(bpos.x + 3, bpos.y),
			Vector2(bpos.x, bpos.y + 6),
			Vector2(bpos.x - 3, bpos.y),
		])
		draw_colored_polygon(b_pts, bullet_color)
		draw_circle(bpos, 2.0, Color.WHITE)

	# --- Particles ---
	for p in particles:
		var alpha: float = p.life / p.max_life
		var col: Color = Color(p.color.r, p.color.g, p.color.b, alpha)
		var sz: float = p.size * alpha
		draw_circle(p.pos + shake_offset, sz, col)

	# --- Power-up timer bars (bottom-left, above player zone) ---
	_draw_powerup_timers(shake_offset)

	# --- Power-up flash text ---
	if powerup_flash > 0:
		var flash_alpha := minf(powerup_flash, 1.0)
		var flash_y := ROWS * CELL / 2.0 - (1.5 - powerup_flash) * 30.0
		_draw_centered_text(powerup_flash_text, Vector2(COLS * CELL / 2.0, flash_y), 28, Color(1.0, 1.0, 0.3, flash_alpha))

	# --- Overlays ---
	if state == GameState.MENU:
		draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), Color(0, 0, 0, 0.8))
		var cx := COLS * CELL / 2.0
		var cy := ROWS * CELL / 2.0

		_draw_centered_text("CENTIPEDE", Vector2(cx, cy - 100), 42, Color(0.2, 1.0, 0.3))
		_draw_centered_text("CENTIPEDE", Vector2(cx + 1, cy - 99), 42, Color(0.0, 0.6, 0.1, 0.3))

		_draw_centered_text("Pfeiltasten: Bewegen", Vector2(cx, cy - 40), 16, Color(0.6, 0.8, 0.9))
		_draw_centered_text("Leertaste: Schiessen", Vector2(cx, cy - 16), 16, Color(0.6, 0.8, 0.9))
		_draw_centered_text("Power-Ups einsammeln!", Vector2(cx, cy + 10), 14, Color(1.0, 0.8, 0.3))

		# Highscore list
		if highscores.size() > 0:
			_draw_centered_text("HIGHSCORES", Vector2(cx, cy + 46), 16, Color(1.0, 0.8, 0.2))
			for i in range(mini(highscores.size(), MAX_HIGHSCORES)):
				var hs: Dictionary = highscores[i]
				var hs_text := "%d. %d  (Level %d)" % [i + 1, hs["score"], hs["level"]]
				_draw_centered_text(hs_text, Vector2(cx, cy + 66 + i * 18), 13, Color(0.7, 0.7, 0.8))

		var pulse := 0.6 + sin(time_elapsed * 3.0) * 0.4
		var start_y := cy + 76 + mini(highscores.size(), MAX_HIGHSCORES) * 18
		_draw_centered_text("ENTER zum Starten", Vector2(cx, start_y), 20, Color(1.0, 0.9, 0.3, pulse))

	if state == GameState.LEVEL_COMPLETE:
		draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), Color(0, 0, 0, 0.75))
		var cx := COLS * CELL / 2.0
		var cy := ROWS * CELL / 2.0

		_draw_centered_text("LEVEL %d GESCHAFFT!" % level, Vector2(cx, cy - 50), 32, Color(0.2, 1.0, 0.3))
		_draw_centered_text("Bonus: +%d" % (100 * level), Vector2(cx, cy - 10), 20, Color(1.0, 0.9, 0.3))
		_draw_centered_text("Score: %d" % score, Vector2(cx, cy + 20), 22, Color.WHITE)

		var pulse := 0.6 + sin(time_elapsed * 3.0) * 0.4
		_draw_centered_text("ENTER fuer naechstes Level", Vector2(cx, cy + 65), 18, Color(1.0, 0.9, 0.3, pulse))

	if state == GameState.GAME_OVER:
		draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), Color(0, 0, 0, 0.8))
		var cx := COLS * CELL / 2.0
		var cy := ROWS * CELL / 2.0
		_draw_centered_text("GAME OVER", Vector2(cx, cy - 60), 42, Color(1.0, 0.2, 0.2))
		_draw_centered_text("Score: %d" % score, Vector2(cx, cy - 15), 26, Color.WHITE)
		_draw_centered_text("Level: %d" % level, Vector2(cx, cy + 12), 18, Color(0.7, 0.8, 0.9))

		var hs := _get_highscore()
		if score >= hs and score > 0:
			var rainbow := Color.from_hsv(fmod(time_elapsed * 0.5, 1.0), 0.8, 1.0)
			_draw_centered_text("NEUER HIGHSCORE!", Vector2(cx, cy + 42), 22, rainbow)
		else:
			_draw_centered_text("Highscore: %d" % hs, Vector2(cx, cy + 42), 16, Color(0.7, 0.7, 0.5))

		var pulse := 0.6 + sin(time_elapsed * 3.0) * 0.4
		_draw_centered_text("ENTER zum Neustarten", Vector2(cx, cy + 80), 18, Color(1.0, 0.9, 0.3, pulse))


func _draw_powerup_timers(shake_offset: Vector2) -> void:
	var timers: Array = []
	if powerup_double > 0:
		timers.append({"label": "2x", "time": powerup_double, "color": POWERUP_COLORS["double"]})
	if powerup_triple > 0:
		timers.append({"label": "3x", "time": powerup_triple, "color": POWERUP_COLORS["triple"]})
	if powerup_rapid > 0:
		timers.append({"label": "RF", "time": powerup_rapid, "color": POWERUP_COLORS["rapid"]})
	if powerup_shield > 0:
		timers.append({"label": "SH", "time": powerup_shield, "color": POWERUP_COLORS["shield"]})
	if powerup_piercing > 0:
		timers.append({"label": "PI", "time": powerup_piercing, "color": POWERUP_COLORS["piercing"]})

	if timers.size() == 0:
		return

	var bar_w := 80.0
	var bar_h := 10.0
	var gap := 16.0
	var start_x := 8.0 + shake_offset.x
	var start_y: float = (PLAYER_MIN_ROW - 1) * CELL - timers.size() * gap + shake_offset.y

	for i in range(timers.size()):
		var t: Dictionary = timers[i]
		var bx := start_x
		var by := start_y + i * gap
		var ratio: float = t["time"] / POWERUP_DURATION
		var col: Color = t["color"]

		# Label
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(bx, by + bar_h - 1), t["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

		# Bar background
		var label_w := 22.0
		draw_rect(Rect2(bx + label_w, by, bar_w, bar_h), Color(0.15, 0.15, 0.2, 0.8))
		# Bar fill
		var fill_w: float = bar_w * ratio
		draw_rect(Rect2(bx + label_w, by, fill_w, bar_h), Color(col.r, col.g, col.b, 0.8))
		# Bright edge
		if fill_w > 1:
			draw_rect(Rect2(bx + label_w, by, fill_w, 2), Color(1, 1, 1, 0.2))
		# Flicker when low
		if t["time"] < 2.0 and int(time_elapsed * 6.0) % 2 == 0:
			draw_rect(Rect2(bx + label_w, by, fill_w, bar_h), Color(1, 1, 1, 0.15))
		# Border
		draw_rect(Rect2(bx + label_w, by, bar_w, bar_h), Color(col.r, col.g, col.b, 0.4), false, 1.0)


func _draw_centered_text(text: String, pos: Vector2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var draw_pos := Vector2(pos.x - text_size.x / 2.0, pos.y + text_size.y / 4.0)
	draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
 

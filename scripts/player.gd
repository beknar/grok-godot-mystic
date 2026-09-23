@tool
extends CharacterBody2D

# player.png is 6 columns by 10 rows of 48px.
# README rows (0-based): idle 0-2, move 3-5, attack 6-8, death 9.
# Each trio is down, side (right), up. Left is flip_h on the side row.
const FRAME := 48
@export var frame_size: int = 48
const COLS := 6
const ROW_IDLE_DOWN := 0
const ROW_WALK_DOWN := 3
const ROW_WALK_SIDE := 4
const ROW_WALK_UP := 5
const ROW_ATTACK_DOWN := 6
const ROW_ATTACK_SIDE := 7
const ROW_ATTACK_UP := 8
const SPEED := 80.0

const SHEET: Texture2D = preload("res://assets/pack/sprites/characters/player.png")
@export var character_sheet: Texture2D

enum Facing { DOWN, UP, LEFT, RIGHT }
enum State { IDLE, WALK, ATTACK }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

var facing: Facing = Facing.DOWN
var state: State = State.IDLE
var _wired := false


func _ready() -> void:
	_ensure_frames()
	_place_hitbox()
	hitbox.monitoring = false
	if Engine.is_editor_hint():
		sprite.play(&"idle_down")
		camera.enabled = false
		return
	camera.enabled = true
	camera.make_current()
	var map := 16
	# Clearing is 64 by 40 tiles. Limits are the view edges.
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 64 * map
	camera.limit_bottom = 40 * map
	if not _wired:
		_wired = true
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.frame_changed.connect(_on_frame_changed)
	_play(&"idle_down", false)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if state == State.ATTACK:
		velocity = Vector2.ZERO
	elif Input.is_action_just_pressed("attack"):
		_start_attack()
		velocity = Vector2.ZERO
	elif dir != Vector2.ZERO:
		facing = _facing_from_dir(dir)
		state = State.WALK
		velocity = dir * SPEED
		_play_walk()
	else:
		state = State.IDLE
		velocity = Vector2.ZERO
		_play(&"idle_down", false)
	move_and_slide()


func _facing_from_dir(dir: Vector2) -> Facing:
	# Any horizontal component uses the side row, including diagonals.
	# Pure up shows the back. Pure down shows the face.
	if dir.x > 0.0:
		return Facing.RIGHT
	if dir.x < 0.0:
		return Facing.LEFT
	if dir.y > 0.0:
		return Facing.DOWN
	return Facing.UP


func _play_walk() -> void:
	match facing:
		Facing.RIGHT:
			_play(&"walk_side", false)
		Facing.LEFT:
			_play(&"walk_side", true)
		Facing.UP:
			_play(&"walk_up", false)
		_:
			_play(&"walk_down", false)


func _start_attack() -> void:
	state = State.ATTACK
	match facing:
		Facing.RIGHT:
			_play(&"attack_side", false)
		Facing.LEFT:
			_play(&"attack_side", true)
		Facing.UP:
			_play(&"attack_up", false)
		_:
			_play(&"attack_down", false)
	_place_hitbox()
	hitbox.monitoring = false


func _place_hitbox() -> void:
	var shape := hitbox_shape.shape as RectangleShape2D
	var scale := 1.0 if frame_size >= 32 else 0.4
	match facing:
		Facing.RIGHT:
			hitbox_shape.position = Vector2(16, -10) * scale
			shape.size = Vector2(18, 16) * scale
		Facing.LEFT:
			hitbox_shape.position = Vector2(-16, -10) * scale
			shape.size = Vector2(18, 16) * scale
		Facing.UP:
			hitbox_shape.position = Vector2(0, -28) * scale
			shape.size = Vector2(20, 14) * scale
		_:
			hitbox_shape.position = Vector2(0, 8) * scale
			shape.size = Vector2(20, 14) * scale


func _on_frame_changed() -> void:
	if state != State.ATTACK:
		return
	# Frames 2 and 3 are the active hit. Columns 4 and 5 of each attack row are empty.
	hitbox.monitoring = sprite.frame == 2 or sprite.frame == 3


func _on_animation_finished() -> void:
	if state != State.ATTACK:
		return
	if sprite.animation != &"attack_down" and sprite.animation != &"attack_side" and sprite.animation != &"attack_up":
		return
	state = State.IDLE
	hitbox.monitoring = false
	_play(&"idle_down", false)


func _play(anim_name: StringName, flip: bool) -> void:
	sprite.flip_h = flip
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)


func _ensure_frames() -> void:
	var frames := SpriteFrames.new()
	_add_anim(frames, &"idle_down", ROW_IDLE_DOWN, 6.0, true)
	_add_anim(frames, &"walk_down", ROW_WALK_DOWN, 10.0, true)
	_add_anim(frames, &"walk_side", ROW_WALK_SIDE, 10.0, true)
	_add_anim(frames, &"walk_up", ROW_WALK_UP, 10.0, true)
	# Attack rows only have art in the first four columns. The last two are blank,
	# and playing them makes the sprite vanish for a couple of frames.
	_add_anim(frames, &"attack_down", ROW_ATTACK_DOWN, 14.0, false, 4)
	_add_anim(frames, &"attack_side", ROW_ATTACK_SIDE, 14.0, false, 4)
	_add_anim(frames, &"attack_up", ROW_ATTACK_UP, 14.0, false, 4)
	sprite.sprite_frames = frames
	# 48px sheets put the feet on row 42. The 16px warrior fills the cell, feet on row 15.
	sprite.offset = Vector2(0, -18 if frame_size >= 32 else -7)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if frame_size < 32:
		var body := $CollisionShape2D
		var shape := body.shape as RectangleShape2D
		shape.size = Vector2(8, 6)
		body.position = Vector2(0, -4)


func _add_anim(frames: SpriteFrames, anim_name: StringName, row: int, fps: float, looping: bool, frame_count: int = COLS) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, looping)
	for col in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = character_sheet if character_sheet != null else SHEET
		atlas.region = Rect2(col * frame_size, row * frame_size, frame_size, frame_size)
		frames.add_frame(anim_name, atlas)

extends CharacterBody2D

# character_sprite_sheet.png is 3 columns by 4 rows of 32px.
# Every row faces the camera. There is no side, back, or attack art.
# Row 0 is the idle cycle. Row 1 is the walk cycle.
const FRAME := 32
const SHEET: Texture2D = preload("res://assets/painted-lands/forest/character_sprite_sheet.png")
const SPEED := 80.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_ensure_frames()
	if Engine.is_editor_hint():
		sprite.play(&"idle")
		camera.enabled = false
		return
	camera.enabled = true
	camera.make_current()
	_play(&"idle")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		velocity = dir * SPEED
		_play(&"walk")
	else:
		velocity = Vector2.ZERO
		_play(&"idle")
	move_and_slide()


func _play(anim_name: StringName) -> void:
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)


func _ensure_frames() -> void:
	var frames := SpriteFrames.new()
	_add_row(frames, &"idle", 0, 6.0)
	_add_row(frames, &"walk", 1, 10.0)
	sprite.sprite_frames = frames
	# Feet sit on the bottom row of the 32px cell.
	sprite.offset = Vector2(0, -15)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _add_row(frames: SpriteFrames, anim_name: StringName, row: int, fps: float) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, true)
	for col in 3:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(col * FRAME, row * FRAME, FRAME, FRAME)
		frames.add_frame(anim_name, atlas)

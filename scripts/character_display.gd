@tool
extends AnimatedSprite2D

# Standing display only. No movement, no attack, no input.
@export var character_sheet: Texture2D
@export var frame_size: int = 48


func _ready() -> void:
	if character_sheet == null:
		return
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle_down")
	frames.set_animation_speed(&"idle_down", 6.0)
	frames.set_animation_loop(&"idle_down", true)
	for col in 6:
		var atlas := AtlasTexture.new()
		atlas.atlas = character_sheet
		atlas.region = Rect2(col * frame_size, 0, frame_size, frame_size)
		frames.add_frame(&"idle_down", atlas)
	sprite_frames = frames
	# Feet share one ground line: row 42 on a 48px cell, row 15 on a 16px cell.
	offset = Vector2(0, -18 if frame_size >= 32 else -7)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	play(&"idle_down")

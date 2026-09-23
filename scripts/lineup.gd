@tool
extends Node2D

@export var spacing: float = 72.0


func place(origin: Vector2) -> void:
	var figures := get_children()
	var start := origin.x - (figures.size() - 1) * spacing * 0.5
	for i in figures.size():
		figures[i].position = Vector2(start + i * spacing, origin.y)

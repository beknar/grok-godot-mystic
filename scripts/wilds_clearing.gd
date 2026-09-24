@tool
extends "res://scripts/forest_clearing.gd"

const WildsTerrain := preload("res://scripts/wilds_terrain.gd")


func _generate() -> Dictionary:
	return WildsTerrain.new().generate()

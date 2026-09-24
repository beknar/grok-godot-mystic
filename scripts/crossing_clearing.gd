@tool
extends "res://scripts/forest_clearing.gd"

const CrossingTerrain := preload("res://scripts/crossing_terrain.gd")


func _generate() -> Dictionary:
	return CrossingTerrain.new().generate()

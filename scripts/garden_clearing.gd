@tool
extends "res://scripts/forest_clearing.gd"

const GardenTerrain := preload("res://scripts/garden_terrain.gd")


func _generate() -> Dictionary:
	return GardenTerrain.new().generate()

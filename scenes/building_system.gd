extends Node2D

@onready var ground_layer: TileMapLayer = $"../GroundLayer"
@onready var terrain_layer: TileMapLayer = $"../TerrainLayer"
@onready var object_layer: TileMapLayer = $"../ObjectLayer"
@onready var highlight_tile: Node2D = $"../HighlightTile"
@onready var player: Node2D = $"../Player"
@onready var inventory_bar := $"../UI/InventoryBar" 
@onready var highlight_rect: ColorRect = highlight_tile.get_node("HighlightRect")
@onready var ghost_sprite: Sprite2D = highlight_tile.get_node("GhostTile")

const MAX_INTERACT_DISTANCE := 64
const TILE_SIZE := Vector2(16, 16)
const INVENTORY_SIZE := 12

var inventory: Array = []
var selected_slot := 0
var held_tile: Dictionary = {}
var build_mode := true

func _process(_delta):
	if build_mode:
		update_highlight()

		if Input.is_action_just_pressed("pick_up_object"):
			pick_up_tile()
		elif Input.is_action_just_pressed("place_object"):
			place_tile()

		# Scroll wheel to cycle through occupied inventory slots only
		if Input.is_action_just_pressed("scroll_up"):
			var next_slot := selected_slot - 1
			var found := false
			# Search backwards for occupied slot
			for i in range(INVENTORY_SIZE):
				if next_slot < 0:
					next_slot = inventory.size()
				if next_slot < inventory.size() and not inventory[next_slot].is_empty():
					selected_slot = next_slot
					found = true
					break
				next_slot -= 1
			if found:
				update_held_tile()
				
		elif Input.is_action_just_pressed("scroll_down"):
			var next_slot := selected_slot + 1
			var found := false
			# Search forwards for occupied slot
			for i in range(INVENTORY_SIZE):
				if next_slot >= inventory.size():
					next_slot = 0
				if next_slot < inventory.size() and not inventory[next_slot].is_empty():
					selected_slot = next_slot
					found = true
					break
				next_slot += 1
			if found:
				update_held_tile()

		# Slot selection via hotbar keys
		for i in range(1, 13):
			var action := "slot_" + str(i)
			if Input.is_action_just_pressed(action):
				if i - 1 < inventory.size():
					selected_slot = i - 1
					update_held_tile()

func update_held_tile():
	if selected_slot >= 0 and selected_slot < inventory.size():
		var slot_item: Dictionary = inventory[selected_slot]
		if not slot_item.is_empty():
			held_tile = slot_item.duplicate()
		else:
			held_tile.clear()
	else:
		held_tile.clear()

	inventory_bar.update_inventory(inventory, selected_slot)

func update_highlight():
	if highlight_tile == null or held_tile.is_empty():
		highlight_tile.visible = false
		return

	var mouse_pos := get_global_mouse_position()
	
	var cell := object_layer.local_to_map(mouse_pos)
	var cell_center := object_layer.map_to_local(cell)
	
	var highlight_local_pos: Vector2 = highlight_tile.get_parent().to_local(cell_center)
	highlight_tile.position = highlight_local_pos - TILE_SIZE / 2
	highlight_tile.visible = true

	var tile_set := object_layer.tile_set
	if tile_set and held_tile.has("source_id") and held_tile.has("atlas_coords"):
		var source_id := int(held_tile["source_id"])
		var atlas_coords := held_tile["atlas_coords"] as Vector2i

		var tile_source := tile_set.get_source(source_id)
		if tile_source is TileSetAtlasSource:
			var atlas_source := tile_source as TileSetAtlasSource
			var tile_texture := atlas_source.get_texture()
			if tile_texture != null:
				var region := atlas_source.get_tile_texture_region(atlas_coords, 0)
				ghost_sprite.texture = tile_texture
				ghost_sprite.region_enabled = true
				ghost_sprite.region_rect = Rect2(region.position, region.size)
				ghost_sprite.position = TILE_SIZE / 2
				ghost_sprite.modulate = Color(1, 1, 1, 0.5)
			else:
				ghost_sprite.texture = null
				ghost_sprite.region_enabled = false
		else:
			ghost_sprite.texture = null
			ghost_sprite.region_enabled = false
	else:
		ghost_sprite.texture = null
		ghost_sprite.region_enabled = false

	var in_range := is_within_range(cell)
	var occupied := object_layer.get_cell_source_id(cell) != -1
	var buildable := is_tile_buildable(cell)
	if occupied or not in_range or not buildable:
		highlight_rect.color = Color(1, 0, 0, 0.4)
	else:
		highlight_rect.color = Color(0, 1, 0, 0.4)

	highlight_rect.position = Vector2.ZERO
	highlight_rect.size = TILE_SIZE

func pick_up_tile():
	var cell := object_layer.local_to_map(get_global_mouse_position())
	if not is_within_range(cell):
		print("Out of range:", cell)
		return

	var source_id := object_layer.get_cell_source_id(cell)
	if source_id == -1:
		print("No tile to pick up at:", cell)
		return

	var atlas_coords := object_layer.get_cell_atlas_coords(cell)
	var new_tile := {
		"source_id": source_id,
		"atlas_coords": atlas_coords
	}

	# Check if this tile already exists in inventory (for stacking)
	var found_stack := false
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if not item.is_empty() and item.has("source_id") and item.has("atlas_coords"):
			if item["source_id"] == new_tile["source_id"] and item["atlas_coords"] == new_tile["atlas_coords"]:
				# Same tile found, increment count
				if item.has("count"):
					item["count"] += 1
				else:
					item["count"] = 2
				found_stack = true
				update_held_tile()
				break
	
	if not found_stack:
		# First, try to find an empty slot
		var empty_slot := -1
		for i in range(inventory.size()):
			if inventory[i].is_empty():
				empty_slot = i
				break
		
		if empty_slot != -1:
			new_tile["count"] = 1
			inventory[empty_slot] = new_tile
			update_held_tile()
		elif inventory.size() < INVENTORY_SIZE:
			new_tile["count"] = 1
			inventory.append(new_tile)
			update_held_tile()
		else:
			print("Inventory full")
			return

	object_layer.erase_cell(cell)
	print("Picked up tile:", new_tile)

func place_tile():
	if held_tile.is_empty():
		return

	var cell := object_layer.local_to_map(get_global_mouse_position())

	if not is_within_range(cell):
		print("Cannot place: cell out of range at", cell)
		return

	if not is_tile_buildable(cell):
		print("Cannot place: cell not buildable at", cell)
		return

	var source_id := int(held_tile["source_id"])
	var atlas_coords := held_tile["atlas_coords"] as Vector2i
	object_layer.set_cell(cell, source_id, atlas_coords)
	
	# Decrease count or remove item
	if held_tile.has("count") and held_tile["count"] > 1:
		inventory[selected_slot]["count"] -= 1
		# Update held_tile to reflect the new count
		held_tile = inventory[selected_slot].duplicate()
	else:
		inventory[selected_slot] = {}
		held_tile.clear()
	
	update_held_tile()
	
	print("Placed tile from inventory slot", selected_slot)

func is_tile_buildable(cell: Vector2i) -> bool:
	if not ground_layer.get_used_cells().has(cell):
		return false

	var ground_id := ground_layer.get_cell_source_id(cell)
	var object_id := object_layer.get_cell_source_id(cell)
	var terrain_id := terrain_layer.get_cell_source_id(cell)

	if ground_id == -1 or object_id != -1 or terrain_id != -1:
		return false

	return true

func is_within_range(cell: Vector2i) -> bool:
	var cell_local_pos := object_layer.map_to_local(cell)
	var cell_global_pos := object_layer.to_global(cell_local_pos)
	var tile_center := cell_global_pos

	return player.global_position.distance_to(tile_center) <= MAX_INTERACT_DISTANCE

extends Control

const SLOT_COUNT := 12

@onready var slot_container: HBoxContainer = $"PanelContainer/SlotContainer"
@onready var slot_highlight: ColorRect = $SlotHighlight

var slot_icons: Array[TextureRect] = []
var slot_labels: Array[Label] = []
var selected_slot: int = 0

func _ready():
	# Cache slot nodes and create count labels
	for i in range(SLOT_COUNT):
		var slot_name := "Slot_" + str(i + 1)
		var slot := slot_container.get_node(slot_name) as TextureRect
		if slot:
			slot_icons.append(slot)
			
			# Create a label for the count
			var label := Label.new()
			label.name = "CountLabel"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			label.anchor_right = 1.0
			label.anchor_bottom = 1.0
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 2)
			label.visible = false
			slot.add_child(label)
			slot_labels.append(label)
		else:
			push_error("Missing slot node: " + slot_name)
	
	update_highlight()

func update_inventory(inventory: Array, selected: int) -> void:
	selected_slot = selected
	for i in range(SLOT_COUNT):
		if i < inventory.size():
			var tile := inventory[i] as Dictionary
			if not tile.is_empty():
				var tile_data := get_tile_region(tile)
				if tile_data:
					var atlas := AtlasTexture.new()
					atlas.atlas = tile_data["texture"]
					atlas.region = tile_data["region"]
					slot_icons[i].texture = atlas
					slot_icons[i].modulate = Color.WHITE
					
					# Update count label
					if tile.has("count") and tile["count"] > 1:
						slot_labels[i].text = str(tile["count"])
						slot_labels[i].visible = true
					else:
						slot_labels[i].visible = false
				else:
					slot_icons[i].texture = null
					slot_icons[i].modulate = Color(1, 1, 1, 0.2)
					slot_labels[i].visible = false
			else:
				slot_icons[i].texture = null
				slot_icons[i].modulate = Color(1, 1, 1, 0.2)
				slot_labels[i].visible = false
		else:
			slot_icons[i].texture = null
			slot_icons[i].modulate = Color(1, 1, 1, 0.2)
			slot_labels[i].visible = false
	
	update_highlight()
	slot_highlight.visible = true

func update_highlight() -> void:
	if selected_slot >= 0 and selected_slot < slot_icons.size():
		var selected_icon := slot_icons[selected_slot]
		slot_highlight.global_position = selected_icon.global_position
		slot_highlight.set_size(selected_icon.size)

func get_tile_region(tile: Dictionary) -> Dictionary:
	if not tile.has("source_id") or not tile.has("atlas_coords"):
		return {}
	var object_layer := get_parent().get_node("../ObjectLayer")
	var tile_set: TileSet = object_layer.tile_set
	var source_id: int = int(tile["source_id"])
	var atlas_coords: Vector2i = tile["atlas_coords"] as Vector2i
	var tile_source: TileSetSource = tile_set.get_source(source_id)
	if tile_source is TileSetAtlasSource:
		var atlas: TileSetAtlasSource = tile_source as TileSetAtlasSource
		var texture := atlas.get_texture()
		var region := atlas.get_tile_texture_region(atlas_coords, 0)
		return {
			"texture": texture,
			"region": Rect2(region.position, region.size)
		}
	return {}

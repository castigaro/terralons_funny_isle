class_name DropShadow
extends Sprite2D
## Soft drop shadow ellipse under an actor or prop; alpha, size and offset follow the palette shadow block.


func _ready() -> void:
	modulate.a = ArtPalette.shadow()["alpha"]


## Sizes the ellipse for an object of the given visible width (local pixels of the parent); base_y is where the
## object touches the ground below the parent origin (0 for base-origin props, half the height for centred sprites).
func fit(width_px: float, base_y: float = 0.0) -> void:
	var block := ArtPalette.shadow()
	var tex_width := float(texture.get_width()) if texture != null else 1.0
	var sx: float = width_px * block["scale"] / tex_width
	scale = Vector2(sx, sx * block["squash"])
	position = block["offset"] + Vector2(0.0, base_y)

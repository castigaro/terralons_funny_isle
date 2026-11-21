class_name DropShadow
extends Sprite2D
## Soft drop shadow ellipse under an actor or prop; alpha, size and offset follow the palette shadow block, the
## colour comes from the gradient of scenes/castaway/soft_shadow.tres (palette colour shadow at full core alpha).


func _ready() -> void:
	modulate.a = ArtPalette.shadow()["alpha"]


## Sizes the ellipse for an object of the given visible width (local pixels of the parent); base_y is where the
## object touches the ground below the parent origin (0 for base-origin props, half the height for centred sprites).
## The width never drops below the palette min_px, so small objects still show a clear shadow.
func fit(width_px: float, base_y: float = 0.0) -> void:
	var block := ArtPalette.shadow()
	var tex_width := float(texture.get_width()) if texture != null else 1.0
	var width := maxf(width_px * block["scale"], block["min_px"])
	var sx: float = width / tex_width
	scale = Vector2(sx, sx * block["squash"])
	position = block["offset"] + Vector2(0.0, base_y)


## Visible ellipse width in parent pixels.
func width_px() -> float:
	return (float(texture.get_width()) if texture != null else 1.0) * absf(scale.x)

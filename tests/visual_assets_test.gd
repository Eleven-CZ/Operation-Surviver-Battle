extends SceneTree

const CareerCatalog := preload("res://scripts/career_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var asset_paths := [
		"res://assets/generated/arena_war_room_v2.png",
		"res://assets/generated/career_sprites_5x2.png",
		"res://assets/generated/fault_sprites_4x2.png",
		"res://assets/generated/coworker_sprites_4x2.png",
		"res://assets/generated/combat_hud_overlay.png",
		"res://assets/generated/skill_icons_5x2.png",
	]
	for path in asset_paths:
		_require(ResourceLoader.exists(path), "%s is imported" % path)
		var texture: Texture2D = load(path)
		_require(texture != null and texture.get_width() >= 1280 and texture.get_height() >= 720, "%s has production resolution" % path)
	var regions: Array[Rect2] = []
	for career_id in CareerCatalog.ids():
		var texture := CareerCatalog.sprite_texture(career_id)
		_require(texture is AtlasTexture, "%s has an AI character sprite" % career_id)
		regions.append((texture as AtlasTexture).region)
	_require(regions.size() == 10 and regions[0] != regions[9], "ten careers map to distinct atlas cells")
	print("VISUAL_ASSETS_TEST_PASS assets=6 careers=10")
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("VISUAL_ASSETS_TEST_FAIL: " + message)
	quit(1)

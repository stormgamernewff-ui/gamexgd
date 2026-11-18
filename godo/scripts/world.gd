extends Node3D

const TERRAIN_SIZE := 180.0
const TERRAIN_RES := 90
const TOTAL_RELICS := 7

@onready var terrain_container: Node3D = $TerrainContainer
@onready var props_container: Node3D = $PropsContainer
@onready var relics_container: Node3D = $RelicsContainer
@onready var fireflies_container: Node3D = $FirefliesContainer
@onready var player: CharacterBody3D = $Player

@onready var relic_label: Label = $HUD/StatusPanel/VBox/RelicLabel
@onready var compass_label: Label = $HUD/StatusPanel/VBox/CompassLabel
@onready var stamina_label: Label = $HUD/StatusPanel/VBox/StaminaLabel
@onready var overlay: CenterContainer = $HUD/Overlay
@onready var title_label: Label = $HUD/Overlay/Panel/VBox/TitleLabel
@onready var desc_label: Label = $HUD/Overlay/Panel/VBox/DescLabel
@onready var start_button: Button = $HUD/Overlay/Panel/VBox/StartButton

var rng := RandomNumberGenerator.new()
var relics: Array = []
var fireflies: Array = []
var collected_count := 0
var elapsed_time := 0.0
var game_started := false

var trunk_mat: StandardMaterial3D
var pine_mat_dark: StandardMaterial3D
var pine_mat_mid: StandardMaterial3D
var oak_mat: StandardMaterial3D
var rock_mat: StandardMaterial3D
var relic_mat: StandardMaterial3D

func _ready() -> void:
	rng.seed = 42077
	_init_materials()
	_build_terrain()
	_populate_forest()
	_spawn_relics()
	_spawn_fireflies()
	start_button.pressed.connect(_on_start_pressed)
	player.position = Vector3(0.0, _get_height(0.0, 0.0) + 0.5, 0.0)
	player.set_active(false)

func _on_start_pressed() -> void:
	if collected_count >= TOTAL_RELICS:
		_reset_relics()
	game_started = true
	overlay.visible = false
	player.set_active(true)

func _init_materials() -> void:
	trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.26, 0.17, 0.11)
	trunk_mat.roughness = 0.92

	pine_mat_dark = StandardMaterial3D.new()
	pine_mat_dark.albedo_color = Color(0.09, 0.24, 0.13)
	pine_mat_dark.roughness = 0.88

	pine_mat_mid = StandardMaterial3D.new()
	pine_mat_mid.albedo_color = Color(0.13, 0.31, 0.17)
	pine_mat_mid.roughness = 0.85

	oak_mat = StandardMaterial3D.new()
	oak_mat.albedo_color = Color(0.22, 0.38, 0.16)
	oak_mat.roughness = 0.85

	rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.32, 0.35, 0.34)
	rock_mat.roughness = 0.95

	relic_mat = StandardMaterial3D.new()
	relic_mat.albedo_color = Color(0.45, 0.95, 1.0)
	relic_mat.emission_enabled = true
	relic_mat.emission = Color(0.3, 0.9, 1.0)
	relic_mat.emission_energy_multiplier = 3.2

func _get_height(x: float, z: float) -> float:
	var dist_center := Vector2(x, z).length()
	var clearing := smoothstep(6.0, 18.0, dist_center)
	var h := sin(x * 0.045) * cos(z * 0.045) * 3.8
	h += sin(x * 0.11 + 1.2) * sin(z * 0.09 - 0.5) * 1.4
	h += cos((x + z) * 0.025) * 2.2
	return h * clearing

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := TERRAIN_SIZE * 0.5
	var step := TERRAIN_SIZE / float(TERRAIN_RES)

	for gz in range(TERRAIN_RES):
		for gx in range(TERRAIN_RES):
			var x0 := -half + gx * step
			var z0 := -half + gz * step
			var x1 := x0 + step
			var z1 := z0 + step

			var p00 := Vector3(x0, _get_height(x0, z0), z0)
			var p10 := Vector3(x1, _get_height(x1, z0), z0)
			var p01 := Vector3(x0, _get_height(x0, z1), z1)
			var p11 := Vector3(x1, _get_height(x1, z1), z1)

			_add_terrain_tri(st, p00, p10, p11)
			_add_terrain_tri(st, p00, p11, p01)

	st.generate_normals()
	var mesh := st.commit()

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	var t_mat := StandardMaterial3D.new()
	t_mat.vertex_color_use_as_albedo = true
	t_mat.roughness = 0.95
	mesh_inst.material_override = t_mat
	terrain_container.add_child(mesh_inst)

	var static_body := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	col_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(col_shape)
	terrain_container.add_child(static_body)

func _add_terrain_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		var trail := absf(v.z - sin(v.x * 0.06) * 14.0) < 2.8
		var col := Color(0.14, 0.25, 0.11)
		if trail:
			col = Color(0.26, 0.21, 0.14)
		elif v.y > 3.2:
			col = Color(0.24, 0.28, 0.22)
		elif v.y < -1.2:
			col = Color(0.10, 0.20, 0.10)
		st.set_color(col)
		st.add_vertex(v)

func _populate_forest() -> void:
	var half := TERRAIN_SIZE * 0.44
	for i in range(210):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() < 8.5:
			continue
		if absf(z - sin(x * 0.06) * 14.0) < 3.4:
			continue
		var y := _get_height(x, z)
		if rng.randf() < 0.72:
			_create_pine_tree(Vector3(x, y, z), rng.randf_range(0.85, 1.55))
		else:
			_create_oak_tree(Vector3(x, y, z), rng.randf_range(0.85, 1.35))

	for i in range(65):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() < 6.0:
			continue
		_create_rock(Vector3(x, _get_height(x, z), z), rng.randf_range(0.6, 2.2))

func _create_pine_tree(pos: Vector3, scale_f: float) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = rng.randf_range(0.0, TAU)

	var trunk := MeshInstance3D.new()
	var t_mesh := CylinderMesh.new()
	t_mesh.top_radius = 0.18 * scale_f
	t_mesh.bottom_radius = 0.32 * scale_f
	t_mesh.height = 3.4 * scale_f
	trunk.mesh = t_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = 1.6 * scale_f
	tree.add_child(trunk)

	var layers := 4
	for l in range(layers):
		var cone := MeshInstance3D.new()
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = 0.05
		c_mesh.bottom_radius = (2.3 - l * 0.42) * scale_f
		c_mesh.height = (2.6 - l * 0.25) * scale_f
		cone.mesh = c_mesh
		cone.material_override = pine_mat_dark if l % 2 == 0 else pine_mat_mid
		cone.position.y = (3.1 + l * 1.45) * scale_f
		tree.add_child(cone)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.36 * scale_f
	cyl.height = 4.0 * scale_f
	col.shape = cyl
	col.position.y = 2.0 * scale_f
	body.add_child(col)
	tree.add_child(body)

	props_container.add_child(tree)

func _create_oak_tree(pos: Vector3, scale_f: float) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = rng.randf_range(0.0, TAU)

	var trunk := MeshInstance3D.new()
	var t_mesh := CylinderMesh.new()
	t_mesh.top_radius = 0.24 * scale_f
	t_mesh.bottom_radius = 0.42 * scale_f
	t_mesh.height = 3.2 * scale_f
	trunk.mesh = t_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = 1.5 * scale_f
	tree.add_child(trunk)

	for offset in [Vector3(0, 3.8, 0), Vector3(1.1, 3.3, 0.4), Vector3(-1.0, 3.4, -0.5), Vector3(0.2, 3.5, 1.0)]:
		var crown := MeshInstance3D.new()
		var s_mesh := SphereMesh.new()
		s_mesh.radius = 1.65 * scale_f
		s_mesh.height = 2.8 * scale_f
		crown.mesh = s_mesh
		crown.material_override = oak_mat
		crown.position = offset * scale_f
		tree.add_child(crown)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45 * scale_f
	cyl.height = 3.5 * scale_f
	col.shape = cyl
	col.position.y = 1.75 * scale_f
	body.add_child(col)
	tree.add_child(body)

	props_container.add_child(tree)

func _create_rock(pos: Vector3, scale_f: float) -> void:
	var rock := MeshInstance3D.new()
	var r_mesh := SphereMesh.new()
	r_mesh.radius = 0.9 * scale_f
	r_mesh.height = 1.2 * scale_f
	r_mesh.radial_segments = 7
	r_mesh.rings = 4
	rock.mesh = r_mesh
	rock.material_override = rock_mat
	rock.position = pos + Vector3(0, 0.25 * scale_f, 0)
	rock.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.85 * scale_f
	col.shape = sp
	body.add_child(col)
	rock.add_child(body)

	props_container.add_child(rock)

func _spawn_relics() -> void:
	var spots := [
		Vector2(22, -18),
		Vector2(-30, -24),
		Vector2(45, 16),
		Vector2(-48, 28),
		Vector2(14, 52),
		Vector2(-24, 58),
		Vector2(56, -42)
	]
	for s in spots:
		var y := _get_height(s.x, s.y) + 1.35
		var relic := Node3D.new()
		relic.position = Vector3(s.x, y, s.y)

		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.65, 0.65, 0.65)
		mesh_inst.mesh = box
		mesh_inst.material_override = relic_mat
		relic.add_child(mesh_inst)

		var light := OmniLight3D.new()
		light.light_color = Color(0.35, 0.95, 1.0)
		light.light_energy = 2.5
		light.omni_range = 10.0
		relic.add_child(light)

		relics_container.add_child(relic)
		relics.append({"node": relic, "base_y": y, "collected": false})

func _reset_relics() -> void:
	collected_count = 0
	for r in relics:
		r["collected"] = false
		r["node"].visible = true

func _spawn_fireflies() -> void:
	var ff_mat := StandardMaterial3D.new()
	ff_mat.albedo_color = Color(0.85, 1.0, 0.45)
	ff_mat.emission_enabled = true
	ff_mat.emission = Color(0.85, 1.0, 0.45)
	ff_mat.emission_energy_multiplier = 2.8

	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12

	for i in range(90):
		var x := rng.randf_range(-68.0, 68.0)
		var z := rng.randf_range(-68.0, 68.0)
		var y := _get_height(x, z) + rng.randf_range(0.8, 3.8)
		var ff := MeshInstance3D.new()
		ff.mesh = sphere
		ff.material_override = ff_mat
		ff.position = Vector3(x, y, z)
		fireflies_container.add_child(ff)
		fireflies.append({
			"node": ff,
			"origin": Vector3(x, y, z),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.8, 1.8)
		})

func _process(delta: float) -> void:
	elapsed_time += delta

	for ff in fireflies:
		var t: float = elapsed_time * ff["speed"] + ff["phase"]
		ff["node"].position = ff["origin"] + Vector3(sin(t) * 0.8, cos(t * 1.3) * 0.45, cos(t * 0.7) * 0.8)

	var nearest_dist := 9999.0
	for r in relics:
		if r["collected"]:
			continue
		var node: Node3D = r["node"]
		node.rotation.y += delta * 1.4
		node.rotation.x += delta * 0.7
		node.position.y = r["base_y"] + sin(elapsed_time * 2.4) * 0.22

		var d := player.global_position.distance_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
		if game_started and d < 2.2:
			r["collected"] = true
			node.visible = false
			collected_count += 1
			if collected_count >= TOTAL_RELICS:
				game_started = false
				player.set_active(false)
				title_label.text = "FOREST EXPLORED!"
				desc_label.text = "You discovered all 7 ancient relics across Whispering Pines."
				start_button.text = "EXPLORE AGAIN"
				overlay.visible = true

	relic_label.text = "RELICS: %d / %d" % [collected_count, TOTAL_RELICS]
	if nearest_dist < 9000.0:
		compass_label.text = "Nearest Relic: %.1f m" % nearest_dist
	else:
		compass_label.text = "All Relics Discovered!"
	var lantern_txt := "ON" if player.lantern_on else "OFF"
	stamina_label.text = "Stamina: %d%%  |  Lantern [F]: %s" % [int(player.stamina), lantern_txt]

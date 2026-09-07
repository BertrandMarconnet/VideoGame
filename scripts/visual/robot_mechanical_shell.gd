extends RefCounted
## Reuse imported joints and damage zones while exposing the mechanical frame.
func install(visual: Node3D) -> void:
	var art := preload("res://scripts/visual/industrial_visuals.gd").new()
	var metal := art.surface("steel")
	var dark := art.surface("rubber")
	for item in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if mesh.mesh == null:
			continue
		var label := String(mesh.name)
		var size := mesh.get_aabb().size
		if label.begins_with("DZ_") and (label.ends_with("_upper") or label.ends_with("_lower")):
			var piston := CylinderMesh.new()
			piston.top_radius = minf(size.x,size.z) * 0.32
			piston.bottom_radius = piston.top_radius * 1.2
			piston.height = size.y
			piston.radial_segments = 12
			mesh.mesh = piston
			mesh.material_override = metal
		elif label == "DZ_torso_core":
			var core := CylinderMesh.new()
			core.top_radius = 0.19
			core.bottom_radius = 0.15
			core.height = size.y
			core.radial_segments = 12
			mesh.mesh = core
			mesh.material_override = dark
			for rib_index in range(5):
				var rib := MeshInstance3D.new()
				var ring := TorusMesh.new()
				ring.inner_radius = 0.26
				ring.outer_radius = 0.30
				ring.rings = 16
				ring.ring_segments = 6
				rib.mesh = ring
				rib.material_override = metal
				rib.position.y = -0.25 + rib_index * 0.12
				rib.scale.z = 0.72
				mesh.add_child(rib)
		elif label.begins_with("ChestArmor"):
			mesh.scale *= Vector3(0.65,0.62,0.7)
			mesh.rotation.z += -0.18 if "Left" in label else 0.18
			mesh.material_override = metal
		elif "Armor" in label or "Plate" in label:
			mesh.scale *= Vector3(0.75,0.84,0.55)
			mesh.material_override = metal
		elif label == "DZ_sensor_head":
			var head := CapsuleMesh.new()
			head.radius = size.x * 0.38
			head.height = size.y
			head.radial_segments = 16
			head.rings = 4
			mesh.mesh = head
			mesh.material_override = dark
		elif label == "SensorBrow":
			mesh.scale.x = 0.62
			mesh.position.x += 0.09
		elif label.ends_with("_foot") or label.ends_with("_pelvis"):
			mesh.scale.x *= 0.8
	visual.set_meta("mechanical_shell", true)

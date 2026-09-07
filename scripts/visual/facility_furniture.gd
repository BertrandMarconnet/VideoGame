extends RefCounted
## Detailed visual shells share their simple, conservative physics proxy.
func install(game: Node3D) -> void:
	var art: RefCounted = game.visuals_v20
	for body in game.find_children("*", "StaticBody3D", true, false):
		var role := String(body.get_meta("layout_role_v21", ""))
		if role not in ["ArchiveRackV21", "PowerGeneratorV21", "AssemblyMachineV21", "LogisticsCrateV21", "HubConsoleV21"]:
			continue
		for child in body.get_children():
			if child is MeshInstance3D:
				child.queue_free()
		body.set_meta("facility_editable", true)
		var steel: Material = art.surface("steel")
		var paint: Material = art.surface("paint")
		var dark: Material = art.surface("rubber")
		match role:
			"ArchiveRackV21":
				for x in [-2.18, 2.18]:
					for z in [-0.28, 0.28]:
						art.box(body, Vector3(0.07,2.6,0.07),Vector3(x,0,z),steel,"ShelfUpright")
				for level in range(4):
					var y := -1.15 + level * 0.72
					art.box(body,Vector3(4.55,0.055,0.63),Vector3(0,y,0),steel,"ShelfDeck")
					for index in range(7):
						var paper: Material = art.material(Color(0.5 + (index%3)*0.06,0.47,0.32),0,0.9,Color.BLACK)
						art.box(body,Vector3(0.46,0.43,0.48),Vector3(-1.8+index*0.6,y+0.245,0),paper,"ArchiveBox",true)
						art.box(body,Vector3(0.25,0.09,0.006),Vector3(-1.8+index*0.6,y+0.29,0.247),paint,"FileLabel")
			"PowerGeneratorV21":
				art.box(body,Vector3(2.3,0.35,1.85),Vector3(0,-1.2,0),dark,"GeneratorSkid",true)
				art.cylinder(body,0.70,2.25,Vector3(0,-0.05,0),steel,"TransformerCoil")
				for level in range(8):
					art.box(body,Vector3(1.8,0.055,1.3),Vector3(0,-0.8+level*0.22,0),paint,"CoolingFin",true)
				for x in [-0.44,0.44]:
					art.cylinder(body,0.09,0.4,Vector3(x,1.15,0),dark,"CeramicInsulator")
			"AssemblyMachineV21":
				art.box(body,Vector3(4.2,0.65,3.8),Vector3(0,-0.86,0),paint,"MachineBed",true)
				for side in [-1,1]:
					art.cylinder(body,0.13,1.7,Vector3(side*1.65,0,0.8),steel,"HydraulicPost")
					art.cylinder(body,0.18,2.6,Vector3(side*1.1,-0.25,-0.1),dark,"DriveRoller",Vector3(90,0,0))
				art.box(body,Vector3(3.5,0.18,0.5),Vector3(0,0.8,0.8),steel,"PressCrosshead",true)
			"LogisticsCrateV21":
				var timber: Material = art.material(Color(0.37,0.26,0.15),0,0.91,Color.BLACK)
				art.box(body,Vector3(1.25,0.98,1.25),Vector3.ZERO,timber,"ShippingCase",true)
				for x in [-0.45,0.45]:
					art.box(body,Vector3(0.07,1.02,1.28),Vector3(x,0,0),steel,"SteelBand")
				art.box(body,Vector3(0.45,0.30,0.007),Vector3(0,0.06,0.633),paint,"DestinationLabel")
			"HubConsoleV21":
				art.box(body,Vector3(2.2,0.78,0.73),Vector3.ZERO,dark,"DeskCabinet",true)
				art.box(body,Vector3(0.92,0.64,0.56),Vector3(0,0.71,-0.09),paint,"CRTHousing",true)
				var phosphor: Material = art.material(Color(0.035,0.12,0.11),0.05,0.45,Color(0.1,0.45,0.32))
				art.box(body,Vector3(0.70,0.44,0.018),Vector3(0,0.73,-0.385),phosphor,"CurvedScreen",true)
				for index in range(5):
					art.box(body,Vector3(0.48,0.008,0.006),Vector3(-0.06,0.60+index*0.055,-0.4),steel,"CRTText")
				art.box(body,Vector3(0.95,0.045,0.3),Vector3(0,0.44,-0.58),paint,"Keyboard",true)
	# Ribbed wall protection and service tags give scale without obstructing walking.
	for side in [-1,1]:
		for index in range(5):
			var z := -27.0-index*8.0
			for x in [3.69,7.30]:
				art.box(game,Vector3(0.08,1.05,3.1),Vector3(side*x,0.7,z),art.surface("paint"),"WallProtection")
			art.sign_board(game,Vector3(side*3.70,2.65,z),"W-%02d / SERVICE" % (index+1) if side<0 else "E-%02d / SERVICE" % (index+1),-90 if side>0 else 90)
		for z in [-32,-46,-60]:
			art.box(game,Vector3(3.8,0.22,0.18),Vector3(side*5.55,3.55,z),art.surface("steel"),"ServiceBeam",true)

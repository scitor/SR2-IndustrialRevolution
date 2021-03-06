import regions.regions;

tidy class ColonyShipScript {
	string targetName;
	double origRadius;
	ColonyShipScript() {
	}

	void init(ColonyShip& ship) {
		//Create the graphics
		makeMesh(ship);
	}

	void makeMesh(ColonyShip& obj) {
		MeshDesc shipMesh;
		const Shipset@ ss = obj.owner.shipset;
		const ShipSkin@ skin;
		if(ss !is null)
			@skin = ss.getSkin("Colonizer");

		if(obj.owner.ColonizerModel.length != 0) {
			@shipMesh.model = getModel(obj.owner.ColonizerModel);
			@shipMesh.material = getMaterial(obj.owner.ColonizerMaterial);
		}
		else if(skin !is null) {
			@shipMesh.model = skin.model;
			@shipMesh.material = skin.material;
		}
		else {
			@shipMesh.model = model::ColonyShip;
			@shipMesh.material = material::VolkurGenericPBR;
		}

		@shipMesh.iconSheet = spritesheet::HullIcons;
		shipMesh.iconIndex = 0;

		origRadius = obj.radius;
		bindMesh(obj, shipMesh);
	}

	void destroy(ColonyShip& ship) {
		leaveRegion(ship);
	}

	bool onOwnerChange(ColonyShip& obj, Empire@ prevOwner) {
		regionOwnerChange(obj, prevOwner);
		return false;
	}

	double tick(ColonyShip& ship, double time) {
		updateRegion(ship);
		ship.moverTick(time);
		ship.radius = origRadius * ((ship.region is null) ? 10 : 1);
		ship.getNode().scale = ((ship.getNode().scale * 9) + ship.radius) / 10.0;
		return 0.2;
	}

	void syncInitial(ColonyShip& ship, Message& msg) {
		msg >> ship.targetName;
		ship.readMover(msg);
	}

	void syncDetailed(ColonyShip& ship, Message& msg, double tDiff) {
		msg >> ship.targetName;
		ship.readMover(msg);
	}

	void syncDelta(ColonyShip& ship, Message& msg, double tDiff) {
		if(msg.readBit())
			ship.readMoverDelta(msg);
	}
};


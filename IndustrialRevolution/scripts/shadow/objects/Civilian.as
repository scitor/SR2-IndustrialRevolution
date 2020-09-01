import regions.regions;
import resources;
import civilians;

tidy class CivilianScript {
	uint type = 0;
	uint cargoType = 0;
	const ResourceType@ cargoResource;
	int cargoWorth = 0;
	bool mainRun = true;
	int income = 0;
	double Health = 0;

	uint getCivilianType() {
		return type;
	}

	double get_health() {
		return Health;
	}

	double get_maxHealth(const Civilian& obj) {
		return CIV_RADIUS_HEALTH * obj.radius * obj.owner.ModHP.value;
	}

	uint getCargoType() {
		return cargoType;
	}

	uint getCargoResource() {
		if(cargoResource is null)
			return uint(-1);
		return cargoResource.id;
	}

	int getCargoWorth() {
		return cargoWorth;
	}

	bool isMainRun() {
		return mainRun;
	}

	int getIncome() {
		return income;
	}

	void init(Civilian& obj) {
	}

	void destroy(Civilian& obj) {
		removeAmbientSource(obj.id);
		leaveRegion(obj);
	}

	bool onOwnerChange(Civilian& obj, Empire@ prevOwner) {
		regionOwnerChange(obj, prevOwner);
		return false;
	}

	double tick(Civilian& obj, double time) {
		updateRegion(obj);
		if(obj.hasMover)
			obj.moverTick(time);
		return 0.2;
	}

	void makeMesh(Civilian& obj) {
		MeshDesc mesh;
		@mesh.model = getCivilianModel(obj.owner, type, obj.radius);
		@mesh.material = getCivilianMaterial(obj.owner, type, obj.radius);
		@mesh.iconSheet = getCivilianIcon(obj.owner, type, obj.radius).sheet;
		mesh.iconIndex = getCivilianIcon(obj.owner, type, obj.radius).index;

		bindMesh(obj, mesh);
	}

	void _readDelta(Civilian& obj, Message& msg) {
		cargoType = msg.readSmall();
		cargoWorth = msg.readSmall();
		mainRun = msg.readBit();
		Health = obj.maxHealth * msg.readFixed();
		if(msg.readBit()) {
			uint id = msg.readLimited(getResourceCount()-1);
			@cargoResource = getResource(id);
		}
		else {
			@cargoResource = null;
		}
		income = (obj.type == CiT_CustomsOffice) ? CIV_COFFICE_UPKEEP : calcIncomeFromCargoWorth(cargoWorth);
	}

	void syncInitial(Civilian& obj, Message& msg) {
		if(msg.readBit()) {
			if(!obj.hasMover)
				obj.activateMover();
			obj.readMover(msg);
		}
		msg >> type;
		_readDelta(obj, msg);
		makeMesh(obj);
		addAmbientSource("ambient_station", obj.id, obj.position, STATION_SND_RAD);
	}

	void syncDetailed(Civilian& obj, Message& msg, double tDiff) {
		if(msg.readBit()) {
			if(!obj.hasMover)
				obj.activateMover();
			obj.readMover(msg);
		}
		_readDelta(obj, msg);
	}

	void syncDelta(Civilian& obj, Message& msg, double tDiff) {
		if(msg.readBit()) {
			if(!obj.hasMover)
				obj.activateMover();
			obj.readMoverDelta(msg);
		}
		if(msg.readBit())
			_readDelta(obj, msg);
	}
};


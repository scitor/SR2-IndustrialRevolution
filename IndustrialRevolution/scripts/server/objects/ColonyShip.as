from resources import MoneyType;
import regions.regions;
import saving;

tidy class ColonyShipScript {
	int moveId;
	string targetName;
	double origRadius;
	bool leavingRegion = false;

	ColonyShipScript() {
		moveId = -1;
	}

	void load(ColonyShip& obj, SaveFile& msg) {
		loadObjectStates(obj, msg);
		msg >> cast<Savable>(obj.Mover);
		@obj.Origin = msg.readObject();
		@obj.Target = msg.readObject();
		msg >> obj.CarriedPopulation;
		
		if(msg < SV_0033 && obj.Target !is null)
			obj.Target.modIncomingPop(obj.CarriedPopulation);

		msg >> moveId;

		if(msg >= SV_0164_IR)
			msg >> obj.targetName;
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

	void postLoad(ColonyShip& obj) {
		//Create the graphics
		makeMesh(obj);
	}

	void save(ColonyShip& obj, SaveFile& msg) {
		saveObjectStates(obj, msg);
		msg << cast<Savable>(obj.Mover);
		msg << obj.Origin;
		msg << obj.Target;
		msg << obj.CarriedPopulation;

		msg << moveId;
		msg << obj.targetName;
	}

	void init(ColonyShip& ship) {
		//Create the graphics
		ship.sightRange = 0;
		makeMesh(ship);
	}

	void postInit(ColonyShip& ship) {
		if(ship.Target !is null)
			ship.Target.modIncomingPop(ship.CarriedPopulation);
		if(ship.owner !is null && ship.owner.valid)
			ship.owner.modMaintenance(round(80.0 * ship.CarriedPopulation * ship.owner.ColonizerMaintFactor), MoT_Colonizers);
	}

	bool onOwnerChange(ColonyShip& ship, Empire@ prevOwner) {
		if(prevOwner !is null && prevOwner.valid)
			prevOwner.modMaintenance(-round(80.0 * ship.CarriedPopulation * prevOwner.ColonizerMaintFactor), MoT_Colonizers);
		if(ship.owner !is null && ship.owner.valid)
			ship.owner.modMaintenance(round(80.0 * ship.CarriedPopulation * ship.owner.ColonizerMaintFactor), MoT_Colonizers);
		regionOwnerChange(ship, prevOwner);
		return false;
	}

	void destroy(ColonyShip& ship) {
		if(ship.owner !is null && ship.owner.valid && ship.CarriedPopulation > 0)
			ship.owner.modMaintenance(-round(80.0 * ship.CarriedPopulation * ship.owner.ColonizerMaintFactor), MoT_Colonizers);
		if(ship.CarriedPopulation > 0 && ship.Origin !is null && ship.Target !is null) {
			if(ship.Origin.hasSurfaceComponent)
				ship.Origin.reducePopInTransit(ship.Target, ship.CarriedPopulation);
			ship.Target.modIncomingPop(-ship.CarriedPopulation);
		}
		leaveRegion(ship);
	}

	double tick(ColonyShip& ship, double time) {
		Object@ target = ship.Target;
		if(target is null)
			return 0.2;

		ship.targetName = target.name;
		ship.moverTick(time);
		bool regionUpdate = updateRegion(ship);
		ship.radius = origRadius * ((ship.region is null) ? 10 : 1);
		ship.getNode().scale = ((ship.getNode().scale * 9) + ship.radius) / 10.0;

		if(ship.isMoving && !regionUpdate && ship.region !is target.region)
			return 0.2;

		// do pathing
		Region@ curRegion = ship.region;
		Region@ destRegion = target.region;
		if(curRegion is destRegion) { // arrived
			if(ship.moveTo(target, moveId, enterOrbit=false, distance=ship.radius + target.radius + 0.1)) {
				if(target.isPlanet) {
					target.colonyShipArrival(ship.owner, ship.CarriedPopulation);
					if(ship.Origin !is null && ship.Origin.hasSurfaceComponent)
						ship.Origin.reducePopInTransit(target, ship.CarriedPopulation);
					if(ship.owner !is null && ship.owner.valid)
						ship.owner.modMaintenance(-round(80.0 * ship.CarriedPopulation * ship.owner.ColonizerMaintFactor), MoT_Colonizers);
					ship.CarriedPopulation = 0;
				}
				ship.destroy();
			}
		} else if(!leavingRegion) { // spawned, get to system border
			vec3d exitPos = ship.position;
			if(curRegion !is null) {
				exitPos = curRegion.position + (destRegion.position - curRegion.position).normalized(curRegion.OuterRadius * 1.5);
				exitPos.y = curRegion.position.y;
			}
			if(ship.moveTo(exitPos, moveId, enterOrbit=false) || curRegion is null) {
				moveId = -1;
				leavingRegion = true;
			}
		}
		if(leavingRegion) { // leaving
			vec3d enterPos = destRegion.position;
			enterPos += (ship.position - destRegion.position).normalized(destRegion.radius * 0.5);
			enterPos.y = destRegion.position.y;
			if(ship.moveTo(enterPos, moveId, enterOrbit=false) || curRegion is destRegion) {
				moveId = -1;
				leavingRegion = false;
			}
		}

		if(target.isPlanet && ship.owner !is null && ship.owner.major && !target.isEmpireColonizing(ship.owner)) {
			if(ship.Origin !is null && ship.Origin.hasSurfaceComponent && ship.position.distanceToSQ(ship.Origin.position) < pow(3000.0, 2))
				ship.destroy();
		}
		return 0.2;
	}

	void damage(ColonyShip& ship, DamageEvent& evt, double position, const vec2d& direction) {
		ship.Health -= evt.damage;
		if(ship.Health <= 0)
			ship.destroy();
	}

	void syncInitial(const ColonyShip& ship, Message& msg) {
		msg << ship.targetName;
		ship.writeMover(msg);
	}

	void syncDetailed(const ColonyShip& ship, Message& msg) {
		msg << ship.targetName;
		ship.writeMover(msg);
	}

	bool syncDelta(const ColonyShip& ship, Message& msg) {
		bool used = false;
		if(ship.writeMoverDelta(msg))
			used = true;
		else
			msg.write0();
		return used;
	}
};

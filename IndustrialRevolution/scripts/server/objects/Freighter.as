from resources import MoneyType;
import regions.regions;
import saving;
import statuses;
import systems;

const int COLONY_SHIP_MAINTENANCE = 5;

tidy class FreighterScript {
	int moveId = -1;
	double idleTimer = 180.0;
	bool leavingRegion = false;
	string targetName;

	FreighterScript() {
	}

	void makeMesh(Freighter& obj) {
		MeshDesc shipMesh;
		const Shipset@ ss = obj.owner.shipset;
		const ShipSkin@ skin;
		if(ss !is null)
			@skin = ss.getSkin(obj.skin);

		if(skin !is null) {
			@shipMesh.model = skin.model;
			@shipMesh.material = skin.material;
		}
		else {
			@shipMesh.model = model::Fighter;
			@shipMesh.material = material::Ship10;
		}

		@shipMesh.iconSheet = spritesheet::HullIcons;
		shipMesh.iconIndex = 0;

		bindMesh(obj, shipMesh);
	}

	void load(Freighter& obj, SaveFile& msg) {
		loadObjectStates(obj, msg);
		msg >> cast<Savable>(obj.Mover);
		@obj.Origin = msg.readObject();
		@obj.Target = msg.readObject();

		msg >> moveId;

		if(msg >= SV_0109) {
			msg >> obj.StatusId;
			msg >> obj.StatusDuration;
			msg >> obj.SetOrigin;
			msg >> obj.MinLevel;
		}
		if(msg >= SV_0110)
			msg >> obj.VisitHostile;
		if(msg >= SV_0145)
			msg >> obj.skin;

		if(msg >= SV_0164_IR)
			msg >> obj.targetName;
		//Create the graphics
		makeMesh(obj);
	}

	void save(Freighter& obj, SaveFile& msg) {
		saveObjectStates(obj, msg);
		msg << cast<Savable>(obj.Mover);
		msg << obj.Origin;
		msg << obj.Target;

		msg << moveId;

		msg << obj.StatusId;
		msg << obj.StatusDuration;
		msg << obj.SetOrigin;
		msg << obj.MinLevel;
		msg << obj.VisitHostile;
		msg << obj.skin;
		msg << obj.targetName;
	}

	void init(Freighter& ship) {
		ship.maxAcceleration = 2.5;
	}

	void postInit(Freighter& ship) {
		makeMesh(ship);
	}

	bool onOwnerChange(Freighter& ship, Empire@ prevOwner) {
		regionOwnerChange(ship, prevOwner);
		return false;
	}

	void destroy(Freighter& ship) {
		leaveRegion(ship);
	}
	
	double tick(Freighter& ship, double time) {
		Object@ target = ship.Target;
		ship.moverTick(time);
		updateRegion(ship);

		if(ship.isMoving || !checkTarget(ship, time))
			return 0.2;
		ship.targetName = target.name;

		// do pathing
		Region@ curRegion = ship.region;
		Region@ destRegion = target.region;
		if(leavingRegion) { // leaving
			vec3d enterPos = destRegion.position;
			enterPos += (curRegion.position - destRegion.position).normalized(destRegion.radius * 0.85);
			enterPos.y = destRegion.position.y;
			if(ship.moveTo(enterPos, moveId, enterOrbit=false) || enterPos.distanceToSQ(ship.position) < pow(ship.radius * 5, 2)) {
				moveId = -1;
				leavingRegion = false;
			}
		} else if(curRegion is destRegion) { // arrived
			if(ship.moveTo(target, moveId, enterOrbit=false, distance=ship.radius + target.radius + 0.1)) {
				if(target.isPlanet) {
					int status = ship.StatusId;
					if(status == -1)
						status = getStatusID("Happy");
					Empire@ originEmp;
					if(ship.SetOrigin)
						@originEmp = ship.owner;
					target.addStatus(status, ship.StatusDuration, originEmpire=originEmp);
				}
				ship.destroy();
			}
		} else { // spawned, get to system border
			vec3d exitPos = curRegion.position;
			exitPos += (destRegion.position - curRegion.position).normalized(curRegion.radius * 0.85);
			exitPos.y = curRegion.position.y;
			if(ship.moveTo(exitPos, moveId, enterOrbit=false) || exitPos.distanceToSQ(ship.position) < pow(ship.radius * 5, 2)) {
				moveId = -1;
				leavingRegion = true;
			}
		}
		return 0.2;
	}

	bool checkTarget(Freighter& ship, double time) {
		Object@ target = ship.Target;
		if(target is null) {
			idleTimer -= time;
			if(ship.region is null || idleTimer < 0.1)
				ship.destroy();
			Region@ lookIn = ship.region;
			bool local = randomi(0,1) == 0;
			if(!local) {
				SystemDesc@ desc = getSystem(lookIn.SystemId);
				if(desc.adjacent.length > 0)
					@lookIn = getSystem(desc.adjacent[randomi(0, desc.adjacent.length-1)]).object;
			}

			uint plCount = lookIn.planetCount;
			if(plCount > 0) {
				Planet@ targ = lookIn.planets[randomi(0, plCount-1)];
				if(targ !is null && targ.owner.valid && (ship.VisitHostile || !ship.owner.isHostile(targ.owner)) && targ.level >= uint(ship.MinLevel)) {
					@target = targ;
					@ship.Target = targ;
				}
			}
			return false;
		} else if(!target.owner.valid || (!ship.VisitHostile && ship.owner.isHostile(target.owner))) {
			@target = null;
			@ship.Target = null;
			return false;
		}
		return true;
	}

	void damage(Freighter& ship, DamageEvent& evt, double position, const vec2d& direction) {
		ship.Health -= evt.damage;
		if(ship.Health <= 0)
			ship.destroy();
	}

	void syncInitial(const Freighter& ship, Message& msg) {
		msg << ship.targetName;
		msg << ship.skin;
		ship.writeMover(msg);
	}

	void syncDetailed(const Freighter& ship, Message& msg) {
		msg << ship.targetName;
		ship.writeMover(msg);
	}

	bool syncDelta(const Freighter& ship, Message& msg) {
		bool used = false;
		if(ship.writeMoverDelta(msg))
			used = true;
		else
			msg.write0();
		return used;
	}
};

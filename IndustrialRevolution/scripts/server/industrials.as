/** Industrial ship status hook (main AI) and utilities */
from game_start import getClosestSystem, getRandomSystem, systemCount, getSystem;
from statuses import StatusHook;
import saving;
import statuses;
import object_creation;
import oddity_navigation;
import system_pathing;
import civilians;

enum IndustrialNavState {
	INS_NeedPath,
	INS_PathToIntermediate,
	INS_PathToExit,
	INS_PathToNextRegion,
	INS_MovingToTarget,
	INS_FTLToTarget,
	INS_ArrivedAtIntermediate,
	INS_ArrivedAtExit,
	INS_ArrivedAtRegion,
	INS_ArrivedAtDropoff
};

class IndustrialData : Savable {
	IndustrialNavState navState = INS_NeedPath;
	IndustrialNavState navStateMoved = INS_NeedPath;

	Object@ pathTarget;
	Object@ intermediate;
	Region@ prevRegion;
	Region@ nextRegion;

	bool awaitingIntermediate = false;
	bool awaitingGateJump = false;

	void save(SaveFile& file) {
		uint st = uint(navState);
		file << st;
		st = uint(navStateMoved);
		file << st;

		file << awaitingIntermediate;
		file << awaitingGateJump;

		file << pathTarget;
		file << intermediate;
		file << prevRegion;
		file << nextRegion;
	}

	void load(SaveFile& file) {
		uint st = 0;
		file >> st;
		navState = IndustrialNavState(st);
		file >> st;
		navStateMoved = IndustrialNavState(st);

		file >> awaitingIntermediate;
		file >> awaitingGateJump;

		file >> pathTarget;
		file >> intermediate;
		file >> prevRegion;
		file >> nextRegion;
		//@moveTarget = cast<Object>(file.readObject());
	}
};

class IndustrialStatus : StatusHook {
	// all civs use same Status instance(!)
	void onCreate(Object& obj, Status@ status, any@ data) override {
		IndustrialData dat;
		if(status.originObject !is null) {
			print("create "+status.originObject.name);
		//	dat.moveTarget = status.originObject.\
			//print(status.originObject.nativeResourceDestination[0].id);
		}

		data.store(@dat);
		updateRegion(obj);
		obj.setHoldPosition(true);
	}

	void onObjectDestroy(Object& obj, Status@ status, any@ data) override {
		IndustrialData@ dat;
		data.retrieve(@dat);

		/*Ship@ ship = cast<Ship>(obj);
		 auto@ credit = ship.getKillCredit();
		 if(credit !is null)
		 credit.addBonusBudget(dat.currentStored + dat.totalCollected / 2);

		 spawnIndustrialShip();*/
	}

	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		Ship@ ship = cast<Ship>(obj);
		IndustrialData@ dat;
		data.retrieve(@dat);

		//if(status.originObject !is null)
		//	print("tick "+status.originObject.name);

		if(ship.RetrofittingAt !is null) {
			@dat.pathTarget = ship.RetrofittingAt;
			@ship.RetrofittingAt = null;
		} else if(dat.pathTarget is null) {
			print("no path target");
			return true;
		}// else print(dat.pathTarget.name);
		Region@ curRegion = obj.region;
		if(ship.hasOrders && curRegion !is dat.nextRegion)
			return true;

		//Update pathing
		Region@ destRegion;
		if(dat.pathTarget.isRegion)
			@destRegion = cast<Region>(dat.pathTarget);
		else
			@destRegion = dat.pathTarget.region;

		if(curRegion is null && dat.nextRegion is null)
			dat.navState = INS_NeedPath;

		//printForID(obj, 872420271, format("ns $1", navState));
		switch(dat.navState) {
			case INS_NeedPath: {
				if(ship.position.distanceToSQ(dat.pathTarget.position) < sqr(100.0)) {
					dat.navState = INS_ArrivedAtDropoff;
					break;
				}
				if(curRegion is destRegion) {
					dat.navState = INS_ArrivedAtRegion;
					break;
				}
				if(curRegion is null) {
					//Move to closest region
					if (dat.nextRegion is null)
						@dat.nextRegion = findNearestRegion(obj.position);
					vec3d pos = dat.nextRegion.position + (obj.position - dat.nextRegion.position).normalized(dat.nextRegion.radius * 0.85);
					ship.addMoveOrder(pos);
					dat.navState = INS_ArrivedAtRegion;
					break;
				}
				if(dat.nextRegion is null) {
					//Find the next region to path to
					TradePath path(obj.owner);
					path.generate(getSystem(curRegion), getSystem(destRegion));
					if(path.pathSize < 2 || !path.valid) {
						error("no path to target");
						break;
					}
					@dat.nextRegion = path.pathNode[1].object;
				}
				// we have a next region. move to exit
				dat.navState = INS_PathToExit;
				break;
			}
			case INS_PathToExit: { // leaving region
				if(curRegion is null || dat.nextRegion is null) {
					dat.navState = INS_NeedPath;
					break;
				}
				vec3d leaveDest;
				if(hasGateToNextRegion(curRegion, dat.nextRegion, obj.owner)) {
					// we're about to gate jump, no exit, move on to gate
					leaveDest = obj.position;
				} else {
					vec3d offset = (dat.nextRegion.position - curRegion.position).normalized(curRegion.radius * 0.85);
					leaveDest = curRegion.position + quaterniond_fromAxisAngle(vec3d_up(), -pi * 0.01) * offset;
					leaveDest.y = curRegion.position.y - STATION_MAX_RAD;
					leaveDest += random3d(STATION_MAX_RAD);
				}
				ship.addMoveOrder(leaveDest);
				dat.navState = INS_ArrivedAtExit;
				break;
			}
			case INS_PathToNextRegion: { // aka ftl between systems
				if(curRegion is null || dat.nextRegion is null) {
					dat.navState = INS_NeedPath;
					break;
				}
				vec3d enterDest;
				if(hasGateToNextRegion(curRegion, dat.nextRegion, obj.owner)) {
					// we're about to gate jump, set dummy pos in target system and approach gate
					enterDest = dat.nextRegion.position + random3d(dat.nextRegion.radius/5);
					enterDest.y = dat.nextRegion.position.y - STATION_MAX_RAD;
					//ship.addMoveOrder(enterDest);
					dat.awaitingGateJump = true;
				} else {
					vec3d offset = (curRegion.position - dat.nextRegion.position).normalized(dat.nextRegion.radius * 0.85);
					enterDest = dat.nextRegion.position + quaterniond_fromAxisAngle(vec3d_up(), pi * 0.01) * offset;
					enterDest.y = dat.nextRegion.position.y - STATION_MAX_RAD;
					enterDest += random3d(STATION_MAX_RAD);
					/*if(obj.owner.hasTrait(getTraitID("Hyperdrive")) || obj.owner.hasTrait(getTraitID("Jumpdrive"))) {
						setFTLTarget(enterDest, INS_ArrivedAtRegion);
						break;
					} else
						fullImpulse(obj);*/
				}
				ship.addMoveOrder(enterDest);
				dat.navState = INS_ArrivedAtRegion;
				break;
			}
			case INS_ArrivedAtExit: {
				if(curRegion is null || dat.nextRegion is null) {
					dat.navState = INS_NeedPath;
					break;
				}
				@dat.prevRegion = curRegion;
				dat.navState = INS_PathToNextRegion;
				break;
			}
			case INS_ArrivedAtRegion: {
				@dat.nextRegion = null;
				if(dat.prevRegion !is null)
					dat.prevRegion.bumpTradeCounter(obj.owner);
				if(curRegion is destRegion) {
					//Move to destination
					if(dat.pathTarget.hasResources && dat.pathTarget.getCustomsOffice() !is null)
						obj.addGotoOrder(dat.pathTarget.getCustomsOffice());
					else
						obj.addGotoOrder(dat.pathTarget);
				}
				dat.navState = INS_NeedPath;
				break;
			}
			case INS_ArrivedAtDropoff: {
				if(destRegion !is null)
					destRegion.bumpTradeCounter(obj.owner);
				auto@ origin = status.originObject;
				if(origin !is null) {
					/*if(!pathTarget.isRegion)
						for (uint i = 0, cnt = cargoResource.hooks.length; i < cnt; ++i)
							cargoResource.hooks[i].onTradeDeliver(obj, origin, pathTarget);*/

					if(dat.pathTarget !is null && dat.pathTarget.hasCargo)
						ship.transferAllCargoTo(dat.pathTarget);
				}
				obj.destroy();
				break;
			}
		}
		
		return true;
	}

	void save(Status@ status, any@ data, SaveFile& file) override {
		IndustrialData@ dat;
		data.retrieve(@dat);
		file << dat;
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		IndustrialData dat;
		file >> dat;
		data.store(@dat);
	}
};


Ship@ spawnIndustrialShip(Object@ originObject) {
	const Design@ dsg = originObject.owner.getDesign("Freighter");
	if(dsg is null) {
		error("Error: Could not find 'Freighter' design industrial vessel.");
		return null;
	}
	Ship@ ship = createShip(originObject.position, dsg, originObject.owner);

	auto@ status = getStatusType("IndustrialShip");
	if(status !is null) {
		ship.addStatus(status.id, originObject = originObject);
		ship.autoFillSupports = false;
		//ship.setFreeRaiding(true);
	} else {
		error("Error: Could not find 'IndustrialShip' status for managing industrial vessel.");
		return null;
	}
	return ship;
}
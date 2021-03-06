import regions.regions;
import saving;
import systems;
import resources;
import civilians;
import statuses;
import oddity_navigation;
from traits import getTraitID;
from cargo import getCargoType;

const double ACC_STATION = 0.1;
const double ACC_SYSTEM = 4.0;
const double ACC_INTERSYSTEM = 65.0;
const double ACC_INTERSYSTEM_FTL = 3000.0;
const double CIV_REPAIR = 1.0;
const double BLOCKADE_TIMER = 3.0 * 60.0;
const double DEST_RANGE = 20.0;
const double CARGO_DELIVERY_STORAGE_CAP = 3600.0; // don't deliver more than that amount of cargo, ever

tidy class CivilianScript {
	StrategicIconNode@ icon;
	uint type = 0;
	Object@ origin;
	Object@ pathTarget;
	Object@ intermediate;
	Region@ prevRegion;
	Region@ nextRegion;
	Object@ moveTargetObj;
	vec3d moveTargetPos;
	uint navState = CiNS_NeedPath;
	uint navStateMoved = CiNS_NeedPath;
	int moveId = -1;
	bool awaitingIntermediate = false;
	bool awaitingGateJump = false;
	bool mainRun = true;
	double Health = CIV_RADIUS_HEALTH;
	int stepCount = 0;
	int income = 0;
	int64 beam = 0;
	bool delta = false;

	uint cargoType = CT_Goods;
	const ResourceType@ cargoResource;
	int cargoWorth = 0;

	double get_health() {
		return Health;
	}

	double get_maxHealth(const Civilian& obj) {
		return CIV_RADIUS_HEALTH * obj.radius * obj.owner.ModHP.value;
	}

	void load(Civilian& obj, SaveFile& msg) {
		loadObjectStates(obj, msg);
		if(msg.readBit()) {
			obj.activateMover();
			msg >> cast<Savable>(obj.Mover);
		}
		msg >> type;
		msg >> origin;
		msg >> pathTarget;
		msg >> intermediate;
		msg >> prevRegion;
		msg >> nextRegion;
		msg >> moveId;
		if(msg >= SV_0164_IR) {
			msg >> navState;
			msg >> navStateMoved;
			msg >> moveTargetObj;
			msg >> moveTargetPos;
		} else
			msg.readBit(); // was leavingRegion
		msg >> mainRun; // was pickedUp
		msg >> Health;
		msg >> stepCount;
		msg >> income;
		msg >> cargoType;
		if(msg.readBit())
			@cargoResource = getResource(msg.readIdentifier(SI_Resource));
		msg >> cargoWorth;

		addAmbientSource(CURRENT_PLAYER, "ambient_station", obj.id, obj.position, STATION_SND_RAD);
		makeMesh(obj);
	}

	void save(Civilian& obj, SaveFile& msg) {
		saveObjectStates(obj, msg);
		if(obj.hasMover) {
			msg.write1();
			msg << cast<Savable>(obj.Mover);
		}
		else {
			msg.write0();
		}
		msg << type;
		msg << origin;
		msg << pathTarget;
		msg << intermediate;
		msg << prevRegion;
		msg << nextRegion;
		msg << moveId;
		msg << navState;
		msg << navStateMoved;
		msg << moveTargetObj;
		msg << moveTargetPos;
		msg << mainRun;
		msg << Health;
		msg << stepCount;
		msg << income;
		msg << cargoType;
		if(cargoResource is null) {
			msg.write0();
		}
		else {
			msg.write1();
			msg.writeIdentifier(SI_Resource, cargoResource.id);
		}
		msg << cargoWorth;
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

	void setCargoType(Civilian& obj, uint type) {
		cargoType = type;
		@cargoResource = null;
		if(type == CT_Goods)
			cargoWorth = (CARGO_GOODS_WORTH * obj.radius * CIV_RADIUS_WORTH) / (1.0+double(config::CIVILIAN_TRADE_MULT-1)/10); // 95-130%

		modIncomeFromCargoWorth(obj);
	}

	void setCargoResource(Civilian& obj, uint id) {
		@cargoResource = getResource(id);
		if(cargoResource is null) {
			obj.setCargoType(CT_Goods);
			return;
		}
		cargoType = CT_Resource;
		cargoWorth = (cargoResource.cargoWorth * obj.radius * CIV_RADIUS_WORTH) / (1.0+double(config::CIVILIAN_TRADE_MULT-1)/10);

		if(mainRun && cargoResource !is null) {
			for (uint i = 0, cnt = cargoResource.hooks.length; i < cnt; ++i)
				cargoResource.hooks[i].onTradeSpawn(obj, origin, pathTarget);
		}
		modIncomeFromCargoWorth(obj);
	}

	void modIncomeFromCargoWorth(Civilian& obj) {
		if(obj.getCivilianType() == CiT_Freighter)
			obj.modIncome(getCivilianFreighterUpkeep(obj.radius) + calcIncomeFromCargoWorth(cargoWorth) - income);
		else if(obj.getCivilianType() != CiT_PirateHoard)
			// add 10% of transported cargo worth as income
			obj.modIncome(calcIncomeFromCargoWorth(cargoWorth) - income);
		else
			delta = true;
	}

	void modCargoWorth(int diff) {
		cargoWorth += diff;
		delta = true;
	}

	int getStepCount() {
		return stepCount;
	}

	void modStepCount(int mod) {
		stepCount += mod;
	}

	void resetStepCount() {
		stepCount = 0;
	}

	void init(Civilian& obj) {
		obj.sightRange = 0;
	}

	uint getCivilianType() {
		return type;
	}

	void setCivilianType(uint type) {
		this.type = type;
	}

	void modIncome(Civilian& obj, int mod) {
		if(obj.owner !is null && obj.owner.valid)
			obj.owner.modTotalBudget(+mod, MoT_Trade);
		income += mod;
		delta = true;
	}

	void postInit(Civilian& obj) {
		if(type == CiT_Freighter && obj.owner !is null)
			obj.owner.CivilianTradeShips += 1;
		if(type == CiT_Freighter) {
			obj.activateMover();
			obj.maxAcceleration = ACC_SYSTEM;
			obj.rotationSpeed = 1.0;
		} else {
			// for orbiting
			obj.activateMover();
			obj.maxAcceleration = ACC_STATION;
			obj.rotationSpeed = 0.01;
			obj.stopMoving();
			obj.noCollide = true;
			addAmbientSource(CURRENT_PLAYER, "ambient_station", obj.id, obj.position, STATION_SND_RAD);
		}
		makeMesh(obj);
		Health = get_maxHealth(obj);
		delta = true;
	}

	void makeMesh(Civilian& obj) {
		MeshDesc mesh;
		@mesh.model = getCivilianModel(obj.owner, type, obj.radius);
		@mesh.material = getCivilianMaterial(obj.owner, type, obj.radius);

		if(obj.getCivilianType() == CiT_Freighter) {
			@mesh.iconSheet = getCivilianIcon(obj.owner, type, obj.radius).sheet;
			mesh.iconIndex = getCivilianIcon(obj.owner, type, obj.radius).index;
		} else {
			@icon = StrategicIconNode();
			icon.establish(obj, 0.02, getCivilianIcon(obj.owner, type, obj.radius).sheet, getCivilianIcon(obj.owner, type, obj.radius).index);
			//icon.memorable = true;
			if(obj.region !is null)
				obj.region.addStrategicIcon(-3, obj, icon);
		}
		bindMesh(obj, mesh);
	}

	bool onOwnerChange(Civilian& obj, Empire@ prevOwner) {
		if(income != 0 && prevOwner !is null && prevOwner.valid)
			prevOwner.modTotalBudget(-income, MoT_Trade);
		if(type == CiT_Freighter && prevOwner !is null)
			prevOwner.CivilianTradeShips -= 1;
		regionOwnerChange(obj, prevOwner);
		if(type == CiT_Freighter && obj.owner !is null)
			obj.owner.CivilianTradeShips += 1;
		if(income != 0 && prevOwner !is null && obj.owner.valid)
			obj.owner.modTotalBudget(-income, MoT_Trade);
		return false;
	}

	void destroy(Civilian& obj) {
		if((obj.inCombat || obj.engaged) && !game_ending) {
			playParticleSystem("ShipExplosion", obj.position, obj.rotation, obj.radius, obj.visibleMask);
		}
		if(type == CiT_Freighter && cargoResource !is null && mainRun) {
			for(uint i = 0, cnt = cargoResource.hooks.length; i < cnt; ++i)
				cargoResource.hooks[i].onTradeDestroy(obj, origin, pathTarget, null);
		}
		// did we have an origin? set blockaded
		if(origin !is null)
			origin.removeAssignedCivilian(obj);
		if(obj.getCivilianType() != CiT_Freighter)
			removeAmbientSource(CURRENT_PLAYER, obj.id);
		leaveRegion(obj);
		//removeBeam();
		if(obj.owner !is null && obj.owner.valid) {
			if(type == CiT_Freighter)
				obj.owner.CivilianTradeShips -= 1;
			if(income != 0)
				obj.owner.modTotalBudget(-income, MoT_Trade);
		}
		if(icon !is null) {
			if(obj.region !is null)
				obj.region.removeStrategicIcon(-3, icon);
			icon.markForDeletion();
			@icon = null;
		}
	}

	void freeCivilian(Civilian& obj) {
		if(origin !is null && origin.hasResources)
			origin.removeAssignedCivilian(obj);

		Region@ region = obj.region;
		if(region !is null) {
			@origin = null;
			@pathTarget = null;
			@prevRegion = null;
			@nextRegion = null;
			region.freeUpCivilian(obj);
		}
		else {
			@origin = null;
			@pathTarget = null;
			@prevRegion = null;
			@nextRegion = null;
			obj.destroy();
		}
	}

	float timer = 0.f;
	void occasional_tick(Civilian& obj) {
		//Update in combat flags
		bool engaged = obj.engaged;
		obj.inCombat = engaged;
		obj.engaged = false;

		if(engaged && obj.region !is null)
			obj.region.EngagedMask |= obj.owner.mask;
	}

	void gotoTradeStation(Civilian@ station) {
		if(!awaitingIntermediate)
			return;
		awaitingIntermediate = false;
		@intermediate = station;
	}
	
	void gotoTradePlanet(Planet@ planet) {
		if(!awaitingIntermediate)
			return;
		awaitingIntermediate = false;
		@intermediate = planet;
	}

	void setFTLTarget(vec3d pos, uint fNavState) {
		moveTargetPos = pos;
		@moveTargetObj = null;
		navState = CiNS_FTLToTarget;
		navStateMoved = fNavState;
	}

	void setMoveTarget(vec3d pos, uint fNavState) {
		moveTargetPos = pos;
		@moveTargetObj = null;
		navState = CiNS_MovingToTarget;
		navStateMoved = fNavState;
	}

	void setMoveTarget(Object& obj, uint fNavState) {
		moveTargetPos = vec3d();
		@moveTargetObj = obj;
		navState = CiNS_MovingToTarget;
		navStateMoved = fNavState;
	}

	double getInertiaFromSize(Civilian& obj) {
		return 1.0 - (obj.radius - CIV_SIZE_MERCHANT) / CIV_SIZE_TRANSPORTER;
	}

	void quarterImpulse(Civilian& obj) {
		obj.maxAcceleration = getInertiaFromSize(obj) * ACC_SYSTEM;
	}

	void fullImpulse(Civilian& obj) {
		obj.maxAcceleration = getInertiaFromSize(obj) * ACC_INTERSYSTEM;
	}

	void jumpThere(Civilian& obj, vec3d pos) {
		obj.position = pos;
		obj.clearMovement();
	}

	void startBeam(Object@ obj, Object@ target) {
		if(beam == 0) {
			beam = (obj.id << 32) | (0x2 << 24);
			makeBeamEffect(ALL_PLAYERS, beam, obj, target, 0xa0dfffff, obj.radius, "Tractor", -1.0);
		}
	}

	void removeBeam() {
		if(beam != 0) {
			removeGfxEffect(ALL_PLAYERS, beam);
			beam = 0;
		}
	}

	double tick(Civilian& obj, double time) {
		//Update normal stuff
		updateRegion(obj);
		if(obj.hasMover)
			obj.moverTick(time);

		if(icon !is null)
			icon.visible = obj.isVisibleTo(playerEmpire);
	//obj.name = obj.id;
		//Tick occasional stuff
		timer -= float(time);
		if(timer <= 0.f) {
			occasional_tick(obj);
			timer = 1.f;
		}
		//Do repair
		double maxHP = get_maxHealth(obj);
		if(!obj.inCombat && Health < maxHP) {
			Health = min(Health + (CIV_REPAIR * time * obj.radius), maxHP);
			delta = true;
		}

		//waiting for or being a trade station
		if(getCivilianType() != CiT_Freighter) {
			tickStation(obj);
			return 0.4;
		}
		if(awaitingIntermediate)
			return 0.25; // waiting for RegionObjects to come back with result...
		if(pathTarget is null) {
			freeCivilian(obj);
			return 0.4;
		}
		//Update pathing
		Region@ curRegion = obj.region;
		Region@ destRegion;
		if(pathTarget.isRegion)
			@destRegion = cast<Region>(pathTarget);
		else
			@destRegion = pathTarget.region;

		if(curRegion is null && nextRegion is null)
			navState = CiNS_NeedPath;

		//printForID(obj, 872420271, format("ns $1", navState));
		switch(navState) {
			case CiNS_NeedPath: {
				if(curRegion is destRegion) {
					navState = CiNS_ArrivedAtRegion;
					break;
				}
				if(curRegion is null) {
					//Move to closest region
					if (nextRegion is null)
						@nextRegion = findNearestRegion(obj.position);
					vec3d pos = nextRegion.position + (obj.position - nextRegion.position).normalized(nextRegion.radius * 0.85);
					setMoveTarget(pos, CiNS_ArrivedAtRegion);
					fullImpulse(obj);
					break;
				}
				if(nextRegion is null) {
					//Find the next region to path to
					TradePath path(obj.owner);
					path.generate(getSystem(curRegion), getSystem(destRegion));
					if(path.pathSize < 2 || !path.valid) {
						freeCivilian(obj);
						break;
					}
					@nextRegion = path.pathNode[1].object;
					if(!mainRun && randomi(0,9)<3) {
						// (1/3 chance to) check out a local trade station first
						navState = CiNS_PathToIntermediate;
						break;
					}
				}
				// we have a next region. move to exit
				navState = CiNS_PathToExit;
				break;
			}
			case CiNS_PathToIntermediate: { // check for intermediate
				if(curRegion is null) {
					navState = CiNS_NeedPath;
					break;
				}
				if(intermediate is null) {
					awaitingIntermediate = true;
					if(curRegion.hasTradeStation(obj.owner)) {
						vec3d pos = curRegion.position + random3d(curRegion.radius);
						// take station at exit point if we have a next region
						if(nextRegion !is null)
							pos = curRegion.position + (nextRegion.position - curRegion.position).normalized(curRegion.radius);
						curRegion.getTradeStation(obj, obj.owner, pos);
					} else if(!mainRun && curRegion.getPlanetCount(obj.owner) > 0)
						curRegion.getTradePlanet(obj, obj.owner);
					else {
						awaitingIntermediate = false;
						navState = CiNS_PathToExit;
						break;
					}
				} else {
					obj.name = intermediate.name;
					if (intermediate.hasResources && intermediate.getCustomsOffice() !is null)
						setMoveTarget(intermediate.getCustomsOffice(), CiNS_ArrivedAtIntermediate);
					else
						setMoveTarget(intermediate, CiNS_ArrivedAtIntermediate);
					quarterImpulse(obj);
					break;
				}
				return 0.4;
			}
			case CiNS_PathToExit: { // leaving region
				if(curRegion is null || nextRegion is null) {
					navState = CiNS_NeedPath;
					break;
				}
				vec3d leaveDest;
				if(hasGateToNextRegion(curRegion, obj.owner)) {
					// we're about to gate jump, no exit, move on to gate
					leaveDest = obj.position;
				} else {
					vec3d offset = (nextRegion.position - curRegion.position).normalized(curRegion.radius * 0.85);
					leaveDest = curRegion.position + quaterniond_fromAxisAngle(vec3d_up(), -pi * 0.01) * offset;
					leaveDest.y = curRegion.position.y - STATION_MAX_RAD;
					leaveDest += random3d(STATION_MAX_RAD);
				}
				setMoveTarget(leaveDest, CiNS_ArrivedAtExit);
				quarterImpulse(obj);
				break;
			}
			case CiNS_PathToNextRegion: { // aka ftl between systems
				if(curRegion is null || nextRegion is null) {
					navState = CiNS_NeedPath;
					break;
				}
				vec3d enterDest;
				if(hasGateToNextRegion(curRegion, obj.owner)) {
					// we're about to gate jump, set dummy pos in target system and approach gate
					enterDest = nextRegion.position + random3d(nextRegion.radius/5);
					enterDest.y = nextRegion.position.y - STATION_MAX_RAD;
					quarterImpulse(obj);
					awaitingGateJump = true;
				} else {
					vec3d offset = (curRegion.position - nextRegion.position).normalized(nextRegion.radius * 0.85);
					enterDest = nextRegion.position + quaterniond_fromAxisAngle(vec3d_up(), pi * 0.01) * offset;
					enterDest.y = nextRegion.position.y - STATION_MAX_RAD;
					enterDest += random3d(STATION_MAX_RAD);
					if(obj.owner.hasTrait(getTraitID("Hyperdrive")) || obj.owner.hasTrait(getTraitID("Jumpdrive"))) {
						setFTLTarget(enterDest, CiNS_ArrivedAtRegion);
						break;
					} else
						fullImpulse(obj);
				}
				setMoveTarget(enterDest, CiNS_ArrivedAtRegion);
				break;
			}
			case CiNS_MovingToTarget: {
				//removeBeam(); // remove beams we have started
				if ((moveTargetObj is null || !moveTargetObj.valid) && moveTargetPos == vec3d()) {
					//print("no move target");
					navState = CiNS_NeedPath;
					@nextRegion = null;
					break;
				}
				if (awaitingGateJump && curRegion is nextRegion) {
					// system chagned, as expected. assume gate jump complete, set arrived state
					awaitingGateJump = false;
					@moveTargetObj = null;
					moveTargetPos = obj.position;
				}
				if(moveTargetObj !is null && (
						moveTargetObj.position.distanceToSQ(obj.position) < DEST_RANGE * DEST_RANGE ||
						obj.moveTo(moveTargetObj, moveId, enterOrbit=false, distance=DEST_RANGE/2)
					)
				|| moveTargetPos != vec3d() && (
						moveTargetPos.distanceToSQ(obj.position) < DEST_RANGE * DEST_RANGE ||
						obj.moveTo(moveTargetPos, moveId, enterOrbit=false)
					)
				) {
					moveId = -1;
					obj.stopMoving(enterOrbit=false);
					@moveTargetObj = null;
					moveTargetPos = vec3d();
					navState = navStateMoved;
				}
				break;
			}
			case CiNS_FTLToTarget: {
				//removeBeam(); // remove beams we have started
				if(moveTargetPos == vec3d()) {
					navState = CiNS_NeedPath;
					@nextRegion = null;
					break;
				}
				if(obj.owner.hasTrait(getTraitID("Jumpdrive"))) {
					playParticleSystem("FTLEnterSilent", obj.position, obj.rotation, obj.radius/2, obj.visibleMask);
					jumpThere(obj, moveTargetPos);
					playParticleSystem("FTLExitSilent", moveTargetPos, obj.rotation, obj.radius/2, obj.visibleMask);
					navState = CiNS_ArrivedAtRegion;
					break;
				}
				if(!obj.inFTL)
					playParticleSystem("FTLEnterSilent", obj.position, obj.rotation, obj.radius/2, obj.visibleMask);
				if(moveTargetPos.distanceToSQ(obj.position) < DEST_RANGE * DEST_RANGE
					|| obj.FTLTo(moveTargetPos, ACC_INTERSYSTEM_FTL, moveId))
				{
					moveId = -1;
					obj.FTLDrop();
					playParticleSystem("FTLExitSilent", obj.position, obj.rotation, obj.radius/2, obj.visibleMask);
					@moveTargetObj = null;
					moveTargetPos = vec3d();
					navState = navStateMoved;
				}
				break;
			}
			case CiNS_ArrivedAtIntermediate: {
				// do trade stuff with station
				if(!tradeWithObject(obj, intermediate) && curRegion !is null)
					curRegion.bumpTradeCounter(obj.owner); // didn't trade means we 'want' more stations
				@intermediate = null;
				if(pathTarget !is null)
					obj.name = pathTarget.name;
				navState = CiNS_PathToExit;
				break;
			}
			case CiNS_ArrivedAtExit: {
				if(curRegion is null || nextRegion is null) {
					navState = CiNS_NeedPath;
					break;
				}
				@prevRegion = curRegion;
				navState = CiNS_PathToNextRegion;
				break;
			}
			case CiNS_ArrivedAtRegion: {
				@nextRegion = null;
				if(prevRegion !is null)
					prevRegion.bumpTradeCounter(obj.owner);
				if(!mainRun && randomi(0,9)<3) {
					// (1/3 chance to) check out a local trade station first
					navState = CiNS_PathToIntermediate;
					break;
				}
				if(curRegion is destRegion) {
					//Move to destination
					if(pathTarget.hasResources && pathTarget.getCustomsOffice() !is null)
						setMoveTarget(pathTarget.getCustomsOffice(), CiNS_ArrivedAtDropoff);
					else
						setMoveTarget(pathTarget, CiNS_ArrivedAtDropoff);
					quarterImpulse(obj);
					break;
				}
				navState = CiNS_NeedPath;
				break;
			}
			case CiNS_ArrivedAtDropoff: {
				if(destRegion !is null)
					destRegion.bumpTradeCounter(obj.owner);
				if(mainRun) {
					if(origin !is null && cargoResource !is null) {
						if(!pathTarget.isRegion)
							for (uint i = 0, cnt = cargoResource.hooks.length; i < cnt; ++i)
								cargoResource.hooks[i].onTradeDeliver(obj, origin, pathTarget);

						if(pathTarget !is null && pathTarget.hasCargo) {
							uint amount = uint(pathTarget.getCargoStored(cargoResource.cargoType));
							double toAdd = min(CARGO_DELIVERY_STORAGE_CAP - amount, obj.radius * CIV_RADIUS_HEALTH);
							// quickhack @TODO: do properly
							if(cargoResource.ident == "BaseMaterial" || cargoResource.ident == "BioMass" || cargoResource.ident == "Ore")
								toAdd = min(CARGO_DELIVERY_STORAGE_CAP - amount, obj.radius * CIV_RADIUS_FIRST);

							if(toAdd > 0) {
								auto@ type = ::getCargoType(cargoResource.cargoType);
								pathTarget.addCargo(type.id, toAdd);
							}
						}
					}
					// start trading with the planets resource
					const ResourceType@ rt = getResource(pathTarget.primaryResourceType);
					if(rt !is null && rt.exportable)
						obj.setCargoResource(pathTarget.primaryResourceType);
					mainRun = false;
				}
				if(!tradeWithObject(obj, pathTarget) && curRegion !is null)
					curRegion.bumpTradeCounter(obj.owner);

				freeCivilian(obj);
				break;
			}
		}
		return 0.2;
	}

	bool tradeWithObject(Civilian& obj, Object@ tradeObj) {
		//startBeam(obj, tradeObj);
		// who do we have here
		Civilian@ tradeStation = cast<Civilian>(tradeObj);
		if(tradeStation !is null) {
			// we sell good stuff (but not to customs offices)
			if(obj.getCargoType() == CT_Resource && tradeStation.getCivilianType() != CiT_CustomsOffice) {
				if(tradeStation.getCargoType() == CT_Goods) { // Goods stations will always buy
					tradeStation.setCargoResource(obj.getCargoResource());
					return true;
				} else if(obj.getCargoResource() != tradeStation.getCargoResource()) {
					if(isResourceWorthTrading(tradeStation.getCargoResource(), false)) {
						tradeStation.setCargoResource(obj.getCargoResource());
						return true; // they bought our stuff, now get the heck outta here
					}
				}
			}
			// lets check the market
			if(!mainRun && tradeStation.getCargoType() == CT_Resource)
				return buyFromObject(obj, tradeStation);
		}
		if(mainRun) // we dont buy on our delivery run
			return false;

		// buy from planets
		Planet@ tradePlanet = cast<Planet>(tradeObj);
		if(tradePlanet !is null && getResource(tradePlanet.primaryResourceType) !is null)
			return buyFromObject(obj, tradePlanet);

		// buy from asteroids
		Asteroid@ tradeAsteroid = cast<Asteroid>(tradeObj);
		if(tradeAsteroid !is null && getResource(tradeAsteroid.primaryResourceType) !is null)
			return buyFromObject(obj, tradeAsteroid);

		return false;
	}

	bool buyFromObject(Civilian& obj, Object& tradeObj) {
		uint resId = uint(-1);
		Civilian@ civ = cast<Civilian>(tradeObj);
		if(civ !is null)
			resId = civ.getCargoResource();
		else if(tradeObj.hasResources)
			resId = tradeObj.primaryResourceType;

		if(resId == uint(-1))
			return false;

		if(obj.getCargoType() == CT_Goods) {
			obj.setCargoResource(resId);
			return true; // bought
		} else if(obj.getCargoResource() != resId) {
			if(isResourceWorthTrading(resId)) {
				obj.setCargoResource(resId);
				return true;
			}
		}
		return false;
	}

	bool isResourceWorthTrading(uint otherResourceTypeId, bool buying = true) {
		const ResourceType@ otherRes = getResource(otherResourceTypeId);
		if(otherRes is null)
			return false;

		uint otherWorth = otherRes.cargoWorth > 0 ? otherRes.cargoWorth : CARGO_GOODS_WORTH;
		double chance = 0.0;
		if(buying)
			chance = otherWorth / getCargoWorth() / 3; // 33% chance to 'buy' if resource is worth the same
		else
			chance = getCargoWorth() / otherWorth / 3;

		return randomd() < chance;
	}

	void tickStation(Civilian& obj) {
		// simulate rotation
		if(origin is null)
			return;
		if(origin.owner !is obj.owner) {
			// nothing to see here
			obj.inCombat = true;
			obj.destroy();
		} else if(getCivilianType() == CiT_CustomsOffice) {
			// handle terraforming
			if (origin.primaryResourceType != getCargoResource()) {
				if (origin.primaryResourceType == uint(-1))
					obj.setCargoType(CT_Goods);
				else
					obj.setCargoResource(origin.primaryResourceType);
			}
		}
	}

	bool hasGateToNextRegion(Region& curRegion, Empire& owner) {
		if(hasOddityLink(curRegion, nextRegion))
			return true;

		if(owner.hasStargates()) {
			Object@ thisGate = owner.getStargate(curRegion.position);
			Object@ otherGate = owner.getStargate(nextRegion.position);
			return thisGate !is null && thisGate.region is curRegion
			&& otherGate !is null && otherGate.region is nextRegion;
		}
		return false;
	}

	void printForID(Object& obj, const int id, string str) {
		if (obj.id == id) {
			print(str);
		}
	}

	void setOrigin(Object@ origin) {
		@this.origin = origin;
		delta = true;
	}

	void pathTo(Civilian& obj, Object@ target) {
		navState = CiNS_NeedPath;
		@pathTarget = target;
		@prevRegion = null;
		@nextRegion = null;
		@origin = null;
		@intermediate = null;
		delta = true;
	}

	void damage(Civilian& obj, DamageEvent& evt, double position, const vec2d& direction) {
		if(!obj.valid || obj.destroying)
			return;
		obj.engaged = true;
		Health = max(0.0, Health - evt.damage);
		delta = true;
		if(Health <= 0.0) {
			if(cargoWorth > 0) {
				Empire@ other = evt.obj.owner;
				if(other !is null && other.major) {
					other.addBonusBudget(cargoWorth);
					cargoWorth = 0;
				}
			}
			if(cargoResource !is null) {
				for(uint i = 0, cnt = cargoResource.hooks.length; i < cnt; ++i)
					cargoResource.hooks[i].onTradeDestroy(obj, origin, pathTarget, evt.obj);
			}
			obj.destroy();
		}
	}

	void _writeDelta(const Civilian& obj, Message& msg) {
		msg.writeSmall(cargoType);
		msg.writeSmall(cargoWorth);
		msg.writeBit(mainRun);
		msg.writeFixed(obj.health/obj.maxHealth);
		if(cargoResource !is null) {
			msg.write1();
			msg.writeLimited(cargoResource.id, getResourceCount()-1);
		}
		else {
			msg.write0();
		}
	}

	void syncInitial(const Civilian& obj, Message& msg) {
		if(obj.hasMover) {
			msg.write1();
			obj.writeMover(msg);
		}
		else {
			msg.write0();
		}
		msg << type;
		_writeDelta(obj, msg);
	}

	void syncDetailed(const Civilian& obj, Message& msg) {
		if(obj.hasMover) {
			msg.write1();
			obj.writeMover(msg);
		}
		else {
			msg.write0();
		}
		_writeDelta(obj, msg);
	}

	bool syncDelta(const Civilian& obj, Message& msg) {
		bool used = false;
		if(obj.hasMover && obj.writeMoverDelta(msg))
			used = true;
		else
			msg.write0();
		if(delta) {
			used = true;
			delta = false;
			msg.write1();
			_writeDelta(obj, msg);
		}
		else {
			msg.write0();
		}
		return used;
	}
};

void dumpPlanetWaitTimes() {
	uint cnt = playerEmpire.planetCount;
	double avg = 0.0, maxTime = 0.0;
	for(uint i = 0; i < cnt; ++i) {
		Planet@ pl = playerEmpire.planetList[i];
		if(pl !is null && pl.getNativeResourceDestination(playerEmpire, 0) !is null) {
			double timer = pl.getCivilianTimer();
			print(pl.name+" -- "+timer);
			avg += timer;
			if(timer > maxTime)
				maxTime = timer;
		}
	}
	avg /= double(cnt);
	print(" AVERAGE: "+avg);
	print(" MAX: "+maxTime);
}

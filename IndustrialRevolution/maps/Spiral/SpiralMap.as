#include "include/map.as"

enum MapSetting {
	M_SystemCount,
	M_Flatten,
	M_GalaxyGases,
	M_ColoredGases
};

#section server
final class SpiralArm {
	double angle = 0;
	array<SystemData@> systems;
	uint sysCount = 0;
	array<uint> homeworlds;
};
#section all

class SpiralMap : Map {
	SpiralMap() {
		super();

		name = locale::SPIRAL_GALAXY;
		description = locale::SPIRAL_GALAXY_DESC;

		color = 0x00e9ffff;
		icon = "maps/Spiral/spiral.png";
		sortIndex = 1000;
	}

#section client
	void makeSettings() {
		Number(locale::SYSTEM_COUNT, M_SystemCount, DEFAULT_SYSTEM_COUNT, decimals=0, step=10, min=4, halfWidth=true);
		Toggle(locale::FLATTEN, M_Flatten, false, halfWidth=true);
		Frequency("Galaxy Gases", M_GalaxyGases, 1.0, min = 0.0, max = 10.0, tooltip = "How much gas should the galaxy have (GPU intensive)");
		Toggle("Colored Gases", M_ColoredGases, false, halfWidth=true);
	}

#section server
	void placeSystems() {
		uint players = estPlayerCount;
		if(players == 0)
			players = 1;

		const uint armCount = max(min(players, 6), 3);
		const uint systemCount = max(uint(getSetting(M_SystemCount, DEFAULT_SYSTEM_COUNT)), armCount + 1);
		bool flatten = getSetting(M_Flatten, 0.0) != 0.0;
		
		uint coreSystems = max(systemCount / 4, 1);
		uint perArm = (systemCount - coreSystems) / armCount;
		coreSystems = systemCount - (perArm * armCount);
		
		double systemSpacing = modSpacing(DEFAULT_SPACING);
		const double coreHeightVariation = flatten ? 0.0 : 4000.0;
		const double heightVariation = flatten ? 0.0 : 2400.0;
		const double spiralBase = systemSpacing * double(systemCount) / 75.0;
		const double spiralCurve = 0.5;
		
		int coreSysType = -1;
		if(systemCount > 50) {
			auto@ bh = getSystemType("CoreBlackhole");
			if(bh !is null)
				coreSysType = bh.id;
		}
		addSystem(vec3d(), 500, false, coreSysType);
		
		coreSystems -= 1;
		double coreRingDist = 0.0;
		
		//Create a bar until we can create a ring with a nice thicknes/radius ratio
		{
			const double barAngle = randomd(0,pi);
			
			const double sysArea = sqr(systemSpacing*0.5);
			const double goalArea = sysArea * double(coreSystems);
			
			//area = pi*r_o^2 - pi*r_i^2 = pi*(r_o^2 - r_i^2)
			//sqrt(area/pi - r_i^2) = r_o
			
			double minRadius = systemSpacing;
			double maxRadius = sqrt(goalArea/pi - minRadius*minRadius);
			
			//Add two bar systems
			while((maxRadius - minRadius) > 0.2 * minRadius && coreSystems >= 5) {
				addSystem(vec3d(cos(barAngle) * minRadius, randomd(-1.0,1.0) * coreHeightVariation, sin(barAngle) * minRadius), quality=250, canHaveHomeworld=false);
				addSystem(vec3d(cos(barAngle) * -minRadius, randomd(-1.0,1.0) * coreHeightVariation, sin(barAngle) * -minRadius), quality=250, canHaveHomeworld=false);
				coreSystems -= 2;
				minRadius += systemSpacing;
				maxRadius = sqrt(goalArea/pi - minRadius*minRadius);
			}
			
			uint ring = 1;
			coreRingDist = minRadius;
			while(coreSystems > 0) {
				uint ringSystems = min(coreSystems, 7 + ring);
				
				ringSystems = min(uint(coreRingDist * twopi / systemSpacing), coreSystems);
				if(ringSystems < coreSystems && ringSystems * 2 > coreSystems)
					ringSystems = (coreSystems + 1) / 2;
				
				for(uint i = 0; i < ringSystems; ++i) {
					double r = coreRingDist + randomd(-0.3, 0.0) * systemSpacing;
					double ang = twopi * (double(i) + randomd(-0.25,0.25)) / double(ringSystems);
					addSystem(vec3d(cos(ang) * r, randomd(-1.0, 1.0) * coreHeightVariation, sin(ang) * r), quality=100, canHaveHomeworld=false);
				}
				
				coreSystems -= ringSystems;
				if(coreSystems > 0)
					coreRingDist += systemSpacing;		
				++ring;
			}
		}
		
		double armWidth = (twopi * 0.85) / double(armCount);
		
		array<SpiralArm> arms(armCount);
		{
			uint playersPerArm = players / armCount;
			
			array<uint> armPlayers(armCount, playersPerArm);
			uint left = players - (playersPerArm * armCount);
			while(left != 0) {
				uint index = randomi(0, armCount-1);
				if(armPlayers[index] == playersPerArm) {
					armPlayers[index] += 1;
					left -= 1;
				}
			}
			
			double ang = randomd(0, pi);
			for(uint i = 0; i < armCount; ++i) {
				SpiralArm@ arm = arms[i];
				arm.sysCount = perArm;
				arm.angle = ang;
				ang += twopi / double(armCount);
				
				uint armPlayerCount = armPlayers[i];
				
				for(uint i = 0; i < armPlayerCount; ++i)
					arm.homeworlds.insertLast(uint(float(arm.sysCount) * float(i + 1) / float(armPlayerCount + 1)));
			}
		}
		
		double curve = randomi(0,1) == 1 ? 1.0 : -1.0;
		
		for(uint i = 0; i < armCount; ++i) {
			SpiralArm@ arm = arms[i];
			double rSq = sqr(coreRingDist + systemSpacing);
			
			const double angFactor = max(min(coreRingDist,spiralBase*2.0), spiralBase * 0.5) * 3.0 / double(armCount);
			
			const uint maxRing = 30;
			array<vec3d> recent;
			uint ringInd = 0;
			
			for(uint j = 0, cnt = arm.sysCount; j < cnt; ++j) {
				//Fill in systems, picking a variety of points and choosing a decent sensible one
				vec3d pos;
				while(true) {
					double radius = sqrt(rSq);
					double angle = arm.angle + curve * log(radius/spiralBase) / spiralCurve;
					if(angle >= pi) angle -= twopi;
					
					double sysAngSize = systemSpacing / (twopi * radius);
					
					angle += randomd(-0.5,0.5) * (armWidth - sysAngSize) / (0.5*radius/angFactor);
					double rad = radius + randomd(-0.1,0.1) * systemSpacing;
					
					pos = vec3d(cos(angle) * rad, 0.0, sin(angle) * rad);
					rSq += systemSpacing * 8000.0;
					
					bool validPos = true;
					for(uint r = 0, rcnt = recent.length; r < rcnt; ++r) {
						if(pos.distanceToSQ(recent[r]) < sqr(systemSpacing)) {
							validPos = false;
							break;
						}
					}
					
					if(validPos)
						break;
				}
				
				rSq += systemSpacing * 10000.0;
				if((j+1)%10 == 0) //Disrupt periodic structure that tends to form
					rSq += systemSpacing * 10000.0;
				
				if(recent.length < maxRing)
					recent.insertLast(pos);
				else
					recent[ringInd++ % maxRing] = pos;
				
				pos.y = randomd(-heightVariation, heightVariation);
				
				arm.systems.insertLast(addSystem(pos));
			}
			
			for(uint j = 0, cnt = arm.homeworlds.length; j < cnt; ++j)
				addPossibleHomeworld(arm.systems[arm.homeworlds[j]]);
		}
	}

	void generateGas() {
		array<vec3d> planned;
		double gasesMulti = getSetting(M_GalaxyGases, 1.0);
		if(gasesMulti < 0.01)
			return;
		for(uint i = 0; i < systems.length; ++i) {
			vec3d sysPos = systems[i].position;
			double sysRad = systems[i].radius;
			for(uint k=0, cnt = 6; k < cnt; ++k) {
				vec3d pos = random2to3d(0, sysRad * 3, sysPos);
				double pct = pos.distanceTo(origin) / radius;
				//pos.y = randomd(-sqr(1-pct)*(radius/8), sqr(1-pct)*(radius/20));
				planned.insertLast(pos);
			}
			for(uint a = 0, cnt = systems[i].adjacent.length; a < cnt; a++) {
				for(uint k=0, cnt = 10*gasesMulti; k < cnt; ++k) {
					if(getSystem(systems[i].adjacent[a]) is null)
						continue;
					vec3d pos = randomBetween(sysPos, getSystem(systems[i].adjacent[a]).position, sysRad * 3);
					double pct = pos.distanceTo(origin) / radius;
					pos.y += randomd(-sqr(1-pct)*(radius/20), sqr(1-pct)*(radius/20));
					planned.insertLast(pos);
				}
			}
		}
		// clear systems
		for(uint i = 0; i < systems.length; ++i) {
			vec3d sysPos = systems[i].position;
			double sysRad2 = sqr(systems[i].radius * 1.5);
			for(int p = planned.length-1; p > -1; --p) {
				if(sysPos.distanceToSQ(planned[p]) < sysRad2)
					planned.removeAt(p);
			}
		}
		for(uint p = 0; p < planned.length; ++p) {
			vec3d pos = planned[p];
			double pct = pos.distanceTo(origin) / radius;
			double edgePct = pos.distanceTo(origin) / (radius * 0.6);
			Colorf fcol;
			if(getSetting(M_ColoredGases, 0.0) != 0.0)
				fcol.fromHSV((360.0 * edgePct) % 360.0, sqr(0.6-pct/10), sqr(1-pct/1.1));
			else
				fcol.fromHSV(0.0, 0.0, sqr(1-pct/1.1));
			fcol.a = randomd(0.1,0.3);
			//planned.insertLast(pos);
			createGalaxyGas(pos, randomd(10000.0, 14000.0) / min(1.5, max(0.8, gasesMulti)), Color(fcol), randomi(0,9)<1);
		}
	}

	SystemDesc@ getSystem(uint index) {
		if(index >= systems.length)
			return null;
		return systems[index];
	}
#section all
};

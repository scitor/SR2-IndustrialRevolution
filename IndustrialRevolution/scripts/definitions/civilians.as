enum CargoType {
	CT_Resource,
	CT_Goods,
};

enum CivilianType {
	CiT_Freighter,
	CiT_Station,
	CiT_CustomsOffice,
	CiT_PirateHoard,
};

enum CivilianNavState {
	CiNS_NeedPath,
	CiNS_PathToIntermediate,
	CiNS_PathToExit,
	CiNS_PathToNextRegion,
	CiNS_MovingToTarget,
	CiNS_FTLToTarget,
	CiNS_ArrivedAtIntermediate,
	CiNS_ArrivedAtExit,
	CiNS_ArrivedAtRegion,
	CiNS_ArrivedAtDropoff
};

array<const Model@> CivilianModels = {
	model::Fighter,
	model::CommerceStation,
	model::Research_Station,
	model::Depot,
};

array<const Material@> CivilianMaterials = {
	material::Ship10,
	material::GenericPBR_CommerceStation,
	material::GenericPBR_Research_Station,
	material::GenericPBR_Depot,
};

array<Sprite> CivilianIcons = {
	Sprite(spritesheet::HullIcons, 2),
	Sprite(spritesheet::OrbitalIcons, 0),
	Sprite(spritesheet::OrbitalIcons, 0),
	Sprite(spritesheet::OrbitalIcons, 0),
};

const double CIV_SIZE_MERCHANT = 2.0;
const double CIV_SIZE_CARAVAN = 2.7;
const double CIV_SIZE_FREIGHTER = 5.0;
const double CIV_SIZE_TRANSPORTER = 5.4;

const double CIV_RADIUS_WORTH = 0.5;
const double CIV_RADIUS_HEALTH = 25.0;

const int CIV_COFFICE_UPKEEP = -10;
const int CIV_FREIGHTER_UPKEEP = -1;

const double STATION_MIN_RAD = 5.0;
const double STATION_MAX_RAD = 10.0;
const double STATION_SND_RAD = 2.0;

uint calcIncomeFromCargoWorth(int cargoWorth) {
	return max(1, int(double(cargoWorth) * 0.1));
}

const Model@ getCivilianModel(Empire@ owner, uint type, double radius) {
	if(owner !is null) {
		auto@ ss = owner.shipset;
		if(ss !is null) {
			const ShipSkin@ skin;
			if(type == CiT_Freighter)
				@skin = ss.getSkin("Freighter");

			if(skin !is null)
				return skin.model;
		}
	}
	return CivilianModels[type];
}

const Material@ getCivilianMaterial(Empire@ owner, uint type, double radius) {
	if(owner !is null) {
		auto@ ss = owner.shipset;
		if(ss !is null) {
			const ShipSkin@ skin;
			if(type == CiT_Freighter)
				@skin = ss.getSkin("Freighter");

			if(skin !is null)
				return skin.material;
		}
	}
	return CivilianMaterials[type];
}

double randomCivilianFreighterSize() {
	uint ra = round(sqr(randomd()) * 3);
	switch(ra) {
		case 1:
			return CIV_SIZE_CARAVAN;
		case 2:
			return CIV_SIZE_FREIGHTER;
		case 3:
			return CIV_SIZE_TRANSPORTER;
	}
	return CIV_SIZE_MERCHANT;
}

double getCivilianFreighterUpkeep(double radius) {
	if(radius > CIV_SIZE_FREIGHTER)
		return CIV_FREIGHTER_UPKEEP * 4;
	else if(radius > CIV_SIZE_CARAVAN)
		return CIV_FREIGHTER_UPKEEP * 3;
	else if(radius > CIV_SIZE_MERCHANT)
		return CIV_FREIGHTER_UPKEEP * 2;
	return CIV_FREIGHTER_UPKEEP;
}

string getCivilianName(uint type, double radius) {
	if(type == CiT_Freighter) {
		if(radius > CIV_SIZE_FREIGHTER)
			return locale::CIVILIAN_TRANSPORTER;
		else if(radius > CIV_SIZE_CARAVAN)
			return locale::CIVILIAN_FREIGHTER;
		else if(radius > CIV_SIZE_MERCHANT)
			return locale::CIVILIAN_CARAVAN;
		return locale::CIVILIAN_MERCHANT;
	}
	else if(type == CiT_Station) {
		return locale::CIVILIAN_STATION;
	}
	else if(type == CiT_CustomsOffice) {
		return locale::CIVILIAN_CUSTOMS_OFFICE;
	}
	else if(type == CiT_PirateHoard) {
		return locale::PIRATE_HOARD;
	}
	return locale::CIVILIAN;
}

Sprite getCivilianIcon(Empire@ owner, uint type, double radius) {
	if(type == CiT_Freighter) {
		if(radius > CIV_SIZE_FREIGHTER)
			return Sprite(spritesheet::HullIcons, 5);
		else if(radius > CIV_SIZE_CARAVAN)
			return Sprite(spritesheet::HullIcons, 4);
		else if(radius > CIV_SIZE_MERCHANT)
			return Sprite(spritesheet::HullIcons, 3);
		return Sprite(spritesheet::HullIcons, 2);
	}
	return CivilianIcons[type];
}

NameGenerator stationNames;
bool stationNamesInitialized = false;
string getRandomStationName() {
	if(!stationNamesInitialized) {
		stationNamesInitialized = true;
		stationNames.read("data/station_names.txt");
		stationNames.useGeneration = false;
	}
	string randName = stationNames.generate();

	const array<string> grAlpha = {"Alpha","Beta","Gamma","Delta","Epsilon","Zeta","Eta","Theta","Iota","Kappa",
		"Lambda","Mu","Nu","Xi","Omicron","Pi","Rho","Sigma","Tau","Upsilon","Phi","Chi","Psi","Omega"};
	if(randomi(0,9)<1)
		randName = format("$1 $2", randName, grAlpha[randomi(0, grAlpha.length-1)]);

	return randName;
}
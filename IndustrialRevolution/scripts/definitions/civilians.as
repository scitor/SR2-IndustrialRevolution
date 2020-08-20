enum CargoType {
	CT_Resource,
	CT_Goods,
};

enum CivilianType {
	CiT_Freighter,
	CiT_Station,
	CiT_CustomsOffice,
};

enum CivilianNavState {
	CiNS_NeedPath,
	CiNS_PathToIntermediate,
	CiNS_PathToExit,
	CiNS_PathToNextRegion,
	CiNS_MovingToTarget,
	CiNS_ArrivedAtIntermediate,
	CiNS_ArrivedAtExit,
	CiNS_ArrivedAtRegion,
	CiNS_ArrivedAtDropoff
};

array<const Model@> CivilianModels = {
	model::Fighter,
	model::CommerceStation,
	model::Depot,
};

array<const Material@> CivilianMaterials = {
	material::Ship10,
	material::GenericPBR_CommerceStation,
	material::GenericPBR_Depot,
};

array<Sprite> CivilianIcons = {
	Sprite(spritesheet::HullIcons, 2),
	Sprite(spritesheet::OrbitalIcons, 0),
	Sprite(spritesheet::OrbitalIcons, 0),
};

const double CIV_SIZE_MIN = 2.0;
const double CIV_SIZE_MAX = 5.4;
const double CIV_SIZE_FREIGHTER = 2.7;
const double CIV_SIZE_CARAVAN = 5.0;

const double CIV_RADIUS_WORTH = 1.0;

const int CIV_COFFICE_INCOME = 10;
const int CIV_CARAVAN_INCOME = 15;
const int CIV_STATION_INCOME = 20;

const double STATION_MIN_RAD = 5.0;
const double STATION_MAX_RAD = 10.0;

vec2d VEC2_NULL(INFINITY, INFINITY);
vec3d VEC3_NULL(INFINITY, INFINITY, INFINITY);

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
	return sqr(randomd()) * (CIV_SIZE_MAX - CIV_SIZE_MIN) + CIV_SIZE_MIN;
}

string getCivilianName(uint type, double radius) {
	if(type == CiT_Freighter) {
		if(radius >= CIV_SIZE_CARAVAN)
			return locale::CIVILIAN_CARAVAN;
		else if(radius >= CIV_SIZE_FREIGHTER)
			return locale::CIVILIAN_FREIGHTER;
		return locale::CIVILIAN_MERCHANT;
	}
	else if(type == CiT_Station) {
		return locale::CIVILIAN_STATION;
	}
	return locale::CIVILIAN;
}

Sprite getCivilianIcon(Empire@ owner, uint type, double radius) {
	if(type == CiT_Freighter) {
		if(radius >= CIV_SIZE_CARAVAN)
			return Sprite(spritesheet::HullIcons, 4);
		else if(radius >= CIV_SIZE_FREIGHTER)
			return Sprite(spritesheet::HullIcons, 3);
	}
	return CivilianIcons[type];
}

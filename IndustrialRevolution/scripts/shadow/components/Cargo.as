import cargo;

tidy class Cargo : CargoStorage, Component_Cargo {
	uint CargoModId = 0;
	void getCargo() {
		yield(this);
	}

	double get_cargoCapacity() {
		return capacity;
	}

	double get_cargoStored() {
		return filled;
	}

	double getCargoStored(uint typeId) {
		auto@ type = getCargoType(typeId);
		if(type is null)
			return -1.0;
		return get(type);
	}

	double getCargoStored(const string& typeIdent) {
		auto@ type = getCargoType(typeIdent);
		if(type is null)
			return -1.0;
		return get(type);
	}

	uint get_cargoTypes() {
		if(types is null)
			return 0;
		return types.length;
	}

	uint get_cargoType(uint index) {
		if(types is null)
			return uint(-1);
		if(index >= types.length)
			return uint(-1);
		return types[index].id;
	}

	uint get_cargoModID() const {
		return CargoModId;
	}

	void readCargo(Message& msg) {
		msg >> this;
	}

	void readCargoDelta(Message& msg) {
		readCargo(msg);
	}
};

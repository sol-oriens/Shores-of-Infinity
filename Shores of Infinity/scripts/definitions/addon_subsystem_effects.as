import hooks;
from subsystem_effects import SubsystemEffect, SolarData;
from ability_effects import getMassFor;
from statuses import getStatusID;

class SolarThrust : SubsystemEffect {
	Document doc("Modify the ship's thrust based on how much light it is getting.");
	Argument min_boost(AT_Decimal, doc="Minimum boost when on a cold star or far away from a star.");
	Argument max_boost(AT_Decimal, doc="Maximum boost when on a hot star or close to a star.");
	Argument step(AT_Decimal, "0.05", doc="Only apply changes in steps of this size.");
	Argument temperature_max(AT_Decimal, "15000", doc="Solar temperature (modified by distance) that triggers the maximum boost.");

#section server
	void tick(SubsystemEvent& event, double time) const override {
		SolarData@ dat;
		event.data.retrieve(@dat);
		if(dat is null) {
			@dat = SolarData();
			event.data.store(@dat);
		}

		dat.timer -= time;
		if(dat.timer <= 0) {
			Object@ obj = event.obj;
			Region@ reg = obj.region;

			dat.timer += 1.0;
			if(obj.velocity.lengthSQ <= 1.0 && !obj.inCombat)
				dat.timer += 10.0;

			Ship@ ship = cast<Ship>(obj);
			double powerFactor = event.workingPercent;
			if(ship !is null) {
				const Design@ dsg = ship.blueprint.design;
				if(dsg !is null)
					powerFactor *= dsg.total(SV_SolarPower);
			}

			double newBoost = 0.0;
			if(reg !is null) {
				double solarFactor = reg.starTemperature * (1.0 - (obj.position.distanceTo(reg.position) / reg.radius));
				newBoost = 100 * (min_boost.decimal + clamp(solarFactor / temperature_max.decimal, 0.0, max_boost.decimal));
				newBoost *= powerFactor;
			}

			newBoost = round(newBoost / step.decimal) * step.decimal;
			if(abs(dat.prevBoost - newBoost) >= step.decimal * 0.5) {
				obj.modAccelerationBonus((newBoost - dat.prevBoost) / getMassFor(obj));
				dat.prevBoost = newBoost;
			}
		}
	}

	void save(SubsystemEvent& event, SaveFile& file) const {
		SolarData@ dat;
		event.data.retrieve(@dat);

		if(dat is null) {
			double t = 0.0;
			file << t << t;
		}
		else {
			file << dat.timer;
			file << dat.prevBoost;
		}
	}

	void load(SubsystemEvent& event, SaveFile& file) const {
		SolarData dat;
		event.data.store(@dat);

		file >> dat.timer;
		file >> dat.prevBoost;
	}
#section all
};

class LaserThrust : SubsystemEffect {
	Document doc("Modify the ship's thrust based on how much laser light it is getting.");
	Argument status(AT_Status, doc="Status to check for laser thrust. Requires a variable status effect.");
	Argument min_boost(AT_Decimal, doc="Minimum boost when receiving no laser or far away from the laser source.");
	Argument max_boost(AT_Decimal, doc="Maximum boost when close to a powerful laser.");
	Argument step(AT_Decimal, "0.05", doc="Only apply changes in steps of this size.");

#section server
	void tick(SubsystemEvent& event, double time) const override {
		SolarData@ dat;
		event.data.retrieve(@dat);
		if(dat is null) {
			@dat = SolarData();
			event.data.store(@dat);
		}

		dat.timer -= time;
		if(dat.timer <= 0) {
			Object@ obj = event.obj;

			dat.timer += 1.0;
			if(obj.velocity.lengthSQ <= 1.0 && !obj.inCombat)
				dat.timer += 10.0;

			Ship@ ship = cast<Ship>(obj);
			double powerFactor = event.workingPercent;
			if(ship !is null) {
				const Design@ dsg = ship.blueprint.design;
				if(dsg !is null)
					powerFactor *= dsg.total(SV_LaserPower);
			}

			double newBoost = 0.0;
			double laserFactor = 0.0;

			for(uint i = 0, cnt = obj.statusEffectCount; i < cnt; ++i) {
				if (obj.statusEffectType[i] == uint(status.integer)) {
					double variable = obj.variable[i];
					if (variable != -1.0)
						laserFactor += variable;
					Object@ origin = obj.statusEffectOriginObject[i];
					if (origin !is null)
						laserFactor *= (1.0 - (obj.position.distanceTo(origin.position) / 250000.0));
				}
			}

			newBoost = 100 * (min_boost.decimal + clamp(laserFactor, 0.0, max_boost.decimal));
			newBoost *= powerFactor;

			newBoost = round(newBoost / step.decimal) * step.decimal;
			if(abs(dat.prevBoost - newBoost) >= step.decimal * 0.5) {
				obj.modAccelerationBonus((newBoost - dat.prevBoost) / getMassFor(obj));
				dat.prevBoost = newBoost;
			}
		}
	}

	void save(SubsystemEvent& event, SaveFile& file) const {
		SolarData@ dat;
		event.data.retrieve(@dat);

		if(dat is null) {
			double t = 0.0;
			file << t << t;
		}
		else {
			file << dat.timer;
			file << dat.prevBoost;
		}
	}

	void load(SubsystemEvent& event, SaveFile& file) const {
		SolarData dat;
		event.data.store(@dat);

		file >> dat.timer;
		file >> dat.prevBoost;
	}
#section all
};

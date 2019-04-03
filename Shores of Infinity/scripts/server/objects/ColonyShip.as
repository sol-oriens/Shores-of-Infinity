from resources import MoneyType;
import regions.regions;
import saving;

tidy class ColonyShipScript {
	const Model@ model;
	const Material@ material;
	const SpriteSheet@ sheet;
	StrategicIconNode@ icon;
	uint iconIndex = 0;
	int moveId;

	ColonyShipScript() {
		moveId = -1;
	}

	void setIcon(ColonyShip& obj) {
		double iconSize = 0.01;

		@icon = StrategicIconNode();
		icon.setObjectRotation(true);
		icon.establish(obj, iconSize, sheet, iconIndex);

		if(obj.region !is null)
			obj.region.addStrategicIcon(-2, obj, icon);
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

	}

	void makeMesh(ColonyShip& obj) {
		const Shipset@ ss = obj.owner.shipset;
		const ShipSkin@ skin;
		if(ss !is null)
			@skin = ss.getSkin("Colonizer");

		if(obj.owner.ColonizerModel.length != 0) {
			@model = getModel(obj.owner.ColonizerModel);
			@material = getMaterial(obj.owner.ColonizerMaterial);
		}
		else if(skin !is null) {
			@model = skin.model;
			@material = skin.material;
		}
		else {
			@model = model::ColonyShip;
			@material = material::VolkurGenericPBR;
		}

		@sheet = spritesheet::HullIcons;

		MeshDesc shipMesh;
		@shipMesh.model = model;
		@shipMesh.material = material;
		@shipMesh.iconSheet = sheet;
		shipMesh.iconIndex = iconIndex;

		bindMesh(obj, shipMesh);
	}

	void postLoad(ColonyShip& obj) {
		//Create the graphics
		makeMesh(obj);
		obj.setIcon();
		Node@ node = obj.getNode();
		if(node !is null)
			node.animInvis = true;
	}

	void save(ColonyShip& obj, SaveFile& msg) {
		saveObjectStates(obj, msg);
		msg << cast<Savable>(obj.Mover);
		msg << obj.Origin;
		msg << obj.Target;
		msg << obj.CarriedPopulation;

		msg << moveId;
	}

	void init(ColonyShip& ship) {
		ship.sightRange = 0;

		//Create the graphics
		makeMesh(ship);
	}

	void postInit(ColonyShip& ship) {
		if(ship.Target !is null)
			ship.Target.modIncomingPop(ship.CarriedPopulation);
		if(ship.owner !is null && ship.owner.valid)
			ship.owner.modMaintenance(round(80.0 * ship.CarriedPopulation * ship.owner.ColonizerMaintFactor), MoT_Colonizers);
		ship.setIcon();
		Node@ node = ship.getNode();
		if(node !is null)
			node.animInvis = true;
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
		if(icon !is null) {
			icon.markForDeletion();
			@icon = null;
		}
		leaveRegion(ship);
	}

	double tick(ColonyShip& ship, double time) {
		Object@ target = ship.Target;

		if(moveId == -1 && target is null)
			return 0.2;
		ship.moverTick(time);

		updateRegion(ship);

		if(target is null) {
			ship.destroy();
		}
		else if(ship.position.distanceTo(target.position) <= (ship.radius + target.radius + 0.1) || ship.moveTo(target, moveId, enterOrbit=false)) {
			ship.destroy();
			if(target.isPlanet) {
				target.colonyShipArrival(ship.owner, ship.CarriedPopulation);
				if(ship.Origin !is null && ship.Origin.hasSurfaceComponent)
					ship.Origin.reducePopInTransit(ship.Target, ship.CarriedPopulation);
				if(ship.owner !is null && ship.owner.valid)
					ship.owner.modMaintenance(-round(80.0 * ship.CarriedPopulation * ship.owner.ColonizerMaintFactor), MoT_Colonizers);
				ship.CarriedPopulation = 0;
			}
		}
		else if(target.isPlanet && ship.owner !is null && ship.owner.major && !target.isEmpireColonizing(ship.owner)) {
			if(ship.Origin !is null && ship.Origin.hasSurfaceComponent && ship.position.distanceTo(ship.Origin.position) < 3000.0)
				ship.destroy();
		}
		return 0.2;
	}

	void damage(ColonyShip& ship, DamageEvent& evt, double position, const vec2d& direction) {
		ship.Health -= evt.damage;
		if(ship.Health <= 0) {
			if(ship.owner !is null && ship.owner.valid && ship.owner.GloryMode == 2) {
				ship.owner.Glory -= 5 * ship.CarriedPopulation;
			}
			ship.destroy();
		}
	}

	void syncInitial(const ColonyShip& ship, Message& msg) {
		ship.writeMover(msg);
	}

	void syncDetailed(const ColonyShip& ship, Message& msg) {
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

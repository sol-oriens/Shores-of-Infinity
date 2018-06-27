import settings.map_lib;
import hooks;
import biomes;
import buildings;
import resources;
import planet_types;
import camps;
import anomalies;
import pickups;
import block_effects;
import addon_block_effects;
import artifacts;
import statuses;
from map_systems import IMapHook, MapHook, getSystemType;
import generic_hooks;
from resources import RARITY_DISTRIBUTION;
import cargo;
import ship_groups;

#section server
import systems;
import object_creation;
import remnant_designs;
from objects.Asteroid import createAsteroid;
from objects.Anomaly import createAnomaly;
from objects.Artifact import createArtifact;
from objects.Oddity import createNebula;
from empire import Creeps;
#section all

//MakeStar(<Temperature>, <Radius> = 100, <Position> = (0, 0, 0), Suffix = "")
// Generate a star with the specified temperature, radius and position.
class MakeStar : MapHook {
	double AVG_STAR_HEALTH = 20000000000;

	Document doc("Creates a star in the system.");
	Argument tempK("Temperature", AT_Range, doc="Star temperature in Kelvin.");

	//SoI - Scaling
	Argument rad("Radius", AT_Range, "1000.0", doc="Radius of the star");

	Argument position("Position", AT_Position, "(0, 0, 0)", doc="Position relative to the center of the system to create the star.");
	Argument suffix("Suffix", AT_Locale, "", doc="Suffix to append to the star name.");
	Argument normalDist("NormalTempRange", AT_Boolean, "False", doc="Whether to use a normal or flat distribution for the star temperature.");
	Argument moves(AT_Boolean, "False", doc="Whether the star can move and the light should track it.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		double temp = 0.0;
		if(tempK.isRange && arguments[4].boolean)
			temp = normald(tempK.decimal, rad.decimal2 * config::SCALE_STARS);
		else
			temp = tempK.fromRange();
		double radius = rad.fromRange() * config::SCALE_STARS;
		vec3d pos = position.fromPosition();

		//Create star
		ObjectDesc starDesc;
		starDesc.type = OT_Star;
		starDesc.flags |= objNoDamage;
		if(system !is null) {
			starDesc.name = format(locale::SYSTEM_STAR, system.name);
			if(suffix.str.length > 0)
				starDesc.name += " "+arguments[3].str;
			starDesc.position = system.position + pos;
		}
		else {
			starDesc.name = locale::SYSTEM_STAR;
		}
		starDesc.radius = radius;
		starDesc.delayedCreation = true;

		Star@ star = cast<Star>(makeObject(starDesc));

		if(system !is null)
			@star.region = system.object;
		star.temperature = temp;
		star.finalizeCreation();
		if(system !is null)
			system.object.enterRegion(star);

		//Create star node
		Node@ node = bindNode(star, "StarNode");
		node.color = blackBody(temp, max((temp + 15000.0) / 40000.0, 1.0));
		if(system !is null)
			node.hintParentObject(system.object, false);

		//SoI - Scaling: rescale HP back to vanilla size ratio
		double hp = AVG_STAR_HEALTH * (radius / (750.0 * config::SCALE_STARS));
		star.Health = hp;
		star.MaxHealth = hp;

		//Create light
		LightDesc lightDesc;

		//SoI - Scaling: increased light reach
		float scale = 8000.f;
		lightDesc.att_quadratic = 1.f / (scale * scale);

		lightDesc.position = vec3f(star.position);
		lightDesc.diffuse = node.color * 1.0f;
		lightDesc.specular = lightDesc.diffuse;
		lightDesc.radius = star.radius;

		if(moves.boolean)
			makeLight(lightDesc, node);
		else
			makeLight(lightDesc);

		if(data !is null)
			@data.star = star;
		@current = star;
	}
#section all
};

//MakeNeutronStar(<Radius> = 20, <Position> = (0, 0, 0))
// Generate a neutron star with the specified radius and position.
class MakeNeutronStar : MapHook {
	double NEUTRON_STAR_HEALTH = 20000000000;

	Document doc("Creates a neutron star in the system.");
	Argument position("Position", AT_Position, "(0, 0, 0)", doc="Position relative to the center of the system to create the star.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		double radius = 200.0 * config::SCALE_STARS;
		vec3d pos = arguments[0].fromPosition();

		//Create star
		ObjectDesc starDesc;
		starDesc.type = OT_Star;
		starDesc.flags |= objNoDamage;
		starDesc.name = format(locale::SYSTEM_STAR, system.name);
		starDesc.position = system.position + pos;
		starDesc.radius = radius;
		starDesc.delayedCreation = true;

		Star@ star = cast<Star>(makeObject(starDesc));
		star.alwaysVisible = true;

		@star.region = system.object;
		star.temperature = 600000.0;
		star.finalizeCreation();
		system.object.enterRegion(star);

		star.Health = NEUTRON_STAR_HEALTH;
		star.MaxHealth = NEUTRON_STAR_HEALTH;

		//Create star node
		Node@ node = bindNode(star, "NeutronStarNode");
		node.color = blackBody(16000.0, max((16000.0 + 15000.0) / 40000.0, 1.0));
		node.hintParentObject(system.object, false);
		cast<NeutronStarNode>(node).establish(star);

		//Create light
		LightDesc lightDesc;

		//SoI - Scaling: increased light reach
		float scale = 8000.f;
		lightDesc.att_quadratic = 1.f / (scale * scale);

		lightDesc.position = vec3f(star.position);
		lightDesc.diffuse = node.color * 1.0f;
		lightDesc.diffuse.a = 0.f;
		lightDesc.specular = lightDesc.diffuse;
		lightDesc.radius = star.radius;
		makeLight(lightDesc);

		if(data !is null)
			@data.star = star;
		@current = star;
	}
#section all
};

//MakeBlackhole(<Radius> = 20, <Position> = (0, 0, 0))
// Generate a black hole with the specified radius and position.
class MakeBlackhole : MapHook {
	double BLACKHOLE_HEALTH = 200000000000;

	Document doc("Creates a black hole in the system.");

	//SoI - Scaling
	Argument rad("Radius", AT_Range, "180.0:200.0", doc="Radius of the event horizon.");

	Argument position("Position", AT_Position, "(0, 0, 0)", doc="Position relative to the center of the system to create the black hole.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		double radius = rad.fromRange() * config::SCALE_STARS;
		vec3d pos = position.fromPosition();

		//SoI - Scaling: make supermassive black holes supermassive
		double healthFactor = 1.0;
		if(data !is null && config::SUPERMASSIVE_BLACK_HOLES > 0 && getSystemType(data.systemType) is getSystemType("CoreBlackhole")) {
			radius *= 25;
			system.radius += 75000;
			healthFactor = 25.0;
		}

		//Create star
		ObjectDesc starDesc;
		starDesc.type = OT_Star;
		starDesc.flags |= objNoDamage;
		starDesc.name = format(locale::SYSTEM_BLACKHOLE, system.name);
		starDesc.position = system.position + pos;
		starDesc.radius = radius;
		starDesc.delayedCreation = true;

		Star@ star = cast<Star>(makeObject(starDesc));
		star.alwaysVisible = true;

		@star.region = system.object;
		star.temperature = 0.0;
		star.finalizeCreation();
		system.object.enterRegion(star);

		star.Health = BLACKHOLE_HEALTH * healthFactor;
		star.MaxHealth = BLACKHOLE_HEALTH * healthFactor;

		//Create star node
		Node@ node = bindNode(star, "BlackholeNode");
		node.color = blackBody(16000.0, max((16000.0 + 15000.0) / 40000.0, 1.0));
		node.hintParentObject(system.object, false);
		cast<BlackholeNode>(node).establish(star);

		//Create light
		LightDesc lightDesc;
		lightDesc.att_quadratic = 1.f/(2000.f*2000.f);
		lightDesc.position = vec3f(star.position);
		lightDesc.diffuse = node.color * 1.0f;
		lightDesc.diffuse.a = 0.f;
		lightDesc.specular = lightDesc.diffuse;
		lightDesc.radius = star.radius;
		makeLight(lightDesc);

		if(data !is null)
			@data.star = star;
		@current = star;
	}
#section all
};

int parseRarity(const string& v) {
	if(v.equals_nocase("common")) {
		return RR_Common;
	}
	else if(v.equals_nocase("uncommon")) {
		return RR_Uncommon;
	}
	else if(v.equals_nocase("rare")) {
		return RR_Rare;
	}
	else if(v.equals_nocase("epic")) {
		return RR_Epic;
	}
	else {
		error(" Error: Invalid rarity spec "+escape(v));
		return -1;
	}
}

bool parseResourceSpec(array<const ResourceType@>@ resPossib, const string& v) {
	if(v.findFirst(":") == -1) {
		if(v == "null")
			return true;
		const ResourceType@ type = getResource(v);
		if(type is null) {
			error(" Error: Invalid resource "+escape(v));
			return false;
		}
		resPossib.insertLast(type);
		return true;
	}
	else {
		array<string>@ args = v.split(":");
		if(args.length > 3) {
			error(" Error: Invalid resource spec "+escape(v));
			return false;
		}

		int rarity = INT_MAX;
		if(args[0].equals_nocase("randomtype")) {
			if(args.length == 3)
				rarity = parseRarity(args[2]);
			const ResourceClass@ cls = getResourceClass(args[1]);
			if(cls is null) {
				error(" Error: Invalid resource type "+escape(v));
				return false;
			}

			for(uint i = 0, cnt = cls.types.length; i < cnt; ++i) {
				if(rarity != INT_MAX && cls.types[i].rarity != rarity)
					continue;
				if(cls.types[i].artificial || cls.types[i].distribution <= 0)
					continue;
				if(cls.types[i].unique)
					continue;
				resPossib.insertLast(cls.types[i]);
			}
			return true;
		}
		else if(args[0].equals_nocase("randomlevel")) {
			uint lv = toInt(args[1]);
			if(args.length == 3)
				rarity = parseRarity(args[2]);
			for(uint i = 0, cnt = getResourceCount(); i < cnt; ++i) {
				auto@ res = getResource(i);
				if(res.level != lv)
					continue;
				if(rarity != INT_MAX && res.rarity != rarity)
					continue;
				if(res.artificial || res.unique)
					continue;
				if(res.limitlessLevel)
					continue;
				if(res.frequency <= 0 || res.distribution <= 0)
					continue;
				resPossib.insertLast(res);
			}
			return true;
		}
		else if(args[0].equals_nocase("randomrarity")) {
			if(args.length == 2)
				rarity = parseRarity(args[1]);
			for(uint i = 0, cnt = getResourceCount(); i < cnt; ++i) {
				auto@ res = getResource(i);
				if(rarity != INT_MAX && res.rarity != rarity)
					continue;
				if(res.artificial || res.unique)
					continue;
				if(res.frequency <= 0 || res.distribution <= 0)
					continue;
				resPossib.insertLast(res);
			}
			return true;
		}
		else if(args[0].equals_nocase("levelgte")) {
			uint lv = toInt(args[1]);
			if(args.length == 3)
				rarity = parseRarity(args[2]);
			for(uint i = 0, cnt = getResourceCount(); i < cnt; ++i) {
				auto@ res = getResource(i);
				if(res.level < lv)
					continue;
				if(rarity != INT_MAX && res.rarity != rarity)
					continue;
				if(res.artificial || res.unique)
					continue;
				if(res.limitlessLevel)
					continue;
				if(res.frequency <= 0 || res.distribution <= 0)
					continue;
				resPossib.insertLast(res);
			}
			return true;
		}
		else {
			for(uint i = 0, cnt = args.length; i < cnt; ++i) {
				auto@ res = getResource(args[i]);
				if(res is null) {
					error(" Error: Invalid resource spec "+escape(v));
					return false;
				}
				resPossib.insertLast(res);
			}
			return true;
		}
	}
}

//MakePlanet(<Resource> = Distributed, <Radius> = 60:140, <Orbit Spacing> = 2750:3250,
//           <Grid Size> = (-1, -1))
// Create a new planet with <Resource> and size <Radius>. Spaced in the orbit from
// the last planet by <Orbit Spacing>.
class MakePlanet : MapHook {
	int AVG_PLANET_GRID_WIDTH = 15;
	int AVG_PLANET_GRID_HEIGHT = 9;
	double AVG_PLANET_HEALTH = 1500000000;
	array<const ResourceType@> resPossib;
	bool distribute = false;
	bool weight = false;
	PlanetClass planetClass;

	Document doc("Create a new planet in the system.");
	Argument resource(AT_Custom, "distributed", doc="The primary resource on the planet. 'distributed' to randomize.");
	Argument secondary_resource(AT_Custom, "none", doc="The secondary resource on the planet. 'ruled' to correlate the secondary resource with the resources defined by the primary resource. Should be Level 0 and non-exportable. Use with caution.");

	//SoI - Scaling
	Argument radius(AT_Range, "60:140", doc="Size of the planet, can be a random range.");
	Argument orbit_spacing(AT_Range, "2750:3250", doc="Distance from the previous planet.");

	Argument grid_size(AT_Position2D, "(-1, -1)", doc="Size of the planet's surface grid. (-1,-1) to randomize based on radius.");
	Argument conditions(AT_Boolean, "True", doc="Whether to let the planet randomly generate a condition.");
	Argument distribute_resource(AT_Boolean, "False", doc="Whether or not the selected resources should be frequency distributed.");
	Argument moons(AT_Boolean, "True", doc="Whether this planet should have a randomized amount of moons generated on it to start with.");
	Argument rings(AT_Boolean, "True", doc="Whether the planet can have rings generated around it.");
	Argument classification(AT_Custom, "Rocky", doc="'Gas' for a gas planet, 'Icy' for an icy planet. Any other value defaults to a rocky planet.");
	Argument giant(AT_Boolean, "False", doc="Whether the planet is giant.");
	Argument force_native_biome(AT_Boolean, "False", doc="Whether to force the resource native biome on the whole planet surface");
	Argument add_status(AT_Status, EMPTY_DEFAULT, doc="A status to add to the planet after it is spawned.");
	Argument physics(AT_Boolean, "True", doc="Whether the planet should be a physical object.");

	bool instantiate() override {
		//Get resource selection mode
		if(resource.str.equals_nocase("distributed"))
			distribute = true;
		else if(resource.str.equals_nocase("weighted"))
			weight = true;
		else if(!parseResourceSpec(resPossib, resource.str))
			return false;
		//Get planet classification
		if (classification.str.equals_nocase("gas"))
			planetClass = PC_Gas;
		else if (classification.str.equals_nocase("icy"))
			planetClass = PC_Icy;
		else
			planetClass = PC_Rocky;
		return MapHook::instantiate();
	}

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		const ResourceType@ resource;
		if(resPossib.length > 0) {
			if(resPossib.length == 1)
				@resource = resPossib[0];
			else if(distribute_resource.boolean) {
				double roll = randomd();
				double freq = 0.0;
				for(uint i = 0, cnt = resPossib.length; i < cnt; ++i) {
					freq += resPossib[i].frequency;
					double chance = resPossib[i].frequency / freq;
					if(roll < chance) {
						@resource = resPossib[i];
						roll /= chance;
					}
					else {
						roll = (roll - chance) / (1.0 - chance);
					}
				}
			}
			else
				@resource = resPossib[randomi(0, resPossib.length-1)];
		}

		if(data is null && distribute)
			@resource = getDistributedResource();
		if (weight)
			@resource = getClassWeightedResource(planetClass);
		if(resource !is null)
			markResourceUsed(resource);

		double planetRadius = radius.decimal;
		if(radius.isRange)
			planetRadius = normald(radius.decimal, radius.decimal2);
		double spacing = orbit_spacing.fromRange() * config::SYSTEM_SIZE;

		//SoI - Gas Giants: make gas giants giant
		//SoI - Ice Giants: make ice giants giant
		if (resource !is null && giant.boolean) {
			switch (planetClass)
			{
				case PC_Gas:
					planetRadius += 140;
					spacing = randomd(5250, 5450);
					break;
				case PC_Icy:
					planetRadius += 100;
					spacing = randomd(5000, 5200);
					break;
				default:
					planetRadius += 140;
					spacing = randomd(5250, 5450);
			}
		}

		planetRadius *= config::SCALE_PLANETS;
		spacing *= config::SCALE_PLANETS;

		system.radius += spacing;

		double pos = system.radius;
		if(spacing == 0)
			pos = randomd(200, system.radius);

		double angle = randomd(0,twopi);
		vec3d offset(cos(angle) * pos, 0, sin(angle) * -pos);

		ObjectDesc planetDesc;
		planetDesc.flags |= objNoDamage;
		planetDesc.flags |= objMemorable;
		planetDesc.type = OT_Planet;
		planetDesc.delayedCreation = true;
		@planetDesc.owner = null;
		planetDesc.radius = planetRadius;
		planetDesc.position = system.position + offset;

		if(!physics.boolean) {
			planetDesc.flags |= objNoPhysics;
			planetDesc.flags |= objNoCollide;
		}

		planetDesc.name = system.name + " ";
		if(data !is null)
			appendRoman(data.planets.length + 1, planetDesc.name);
		else
			appendRoman(system.object.planetCount + 1, planetDesc.name);

		Planet@ planet = cast<Planet>(makeObject(planetDesc));
		@planet.region = system.object;

		if(data !is null)
			data.planets.insertLast(planet);

		//Generate biomes
		const Biome@ biome1;
		if(resource is null) {
			@biome1 = getDistributedBiome();
		}
		else {
			@biome1 = getBiome(resource.nativeBiome);
			if(biome1 is null)
				@biome1 = getDistributedBiome();
		}

		const Biome@ biome2 = getDistributedBiome();
		const Biome@ biome3 = getDistributedBiome();

		//Figure out planet size
		//SoI - Scaling: rescale radius for grid size calculation
		double scaledRadius = 0;

		//SoI - Gas Giants: force the grid to a specific size to avoid a big surface displaying a scroll bar before even displaying moon bases
		//SoI - Ice Giants: force the grid to a specific size to avoid a big surface displaying a scroll bar before even displaying moon bases
		//The loss of space is not a problem since the biome is useless anyway
		if (resource !is null && giant.boolean && (planetClass == PC_Gas || planetClass == PC_Icy))
			scaledRadius = 160;
		else
			//min_planet_radius + 100 * (radius - min_planet_radius) / (max_planet_radius - min_planet_radius)
			scaledRadius = 60 * config::SCALE_PLANETS + 100 * (planetRadius - 60 * config::SCALE_PLANETS) / (140 * config::SCALE_PLANETS - 60 * config::SCALE_PLANETS);

		double sizeFact = clamp(scaledRadius / 100.0, 0.1, 5.0);

		int gridW = round(AVG_PLANET_GRID_WIDTH * sizeFact);
		int gridH = round(AVG_PLANET_GRID_HEIGHT * sizeFact);

		vec2d givenGrid = grid_size.fromPosition2D();
		if(givenGrid.x > 0)
			gridW = ceil(givenGrid.x);
		if(givenGrid.y > 0)
			gridH = ceil(givenGrid.y);

		//Figure out planet type
		//SoI - Gas Giants: lock planet type on gas biome
		//SoI - Ice Giants: lock planet type on ice biome
		if (resource !is null && force_native_biome.boolean) {
			const PlanetType@ planetType = getBestPlanetType(biome1, null, null);
			planet.PlanetType = planetType.id;
		}
		else {
			const PlanetType@ planetType = getBestPlanetType(biome1, biome2, biome3);
			planet.PlanetType = planetType.id;
		}

		//SoI - Scaling: increased orbit / gravity well based on planet size
		if (resource !is null && resource.ident == "Ringworld")
			//Ringworlds shouldn't have gravity wells as they have no core
			//Orbit size is the star's
			planet.OrbitSize = system.radius;
		else
		{
			//Planet volume is generally related to mass which governs gravity well size
			//Get the planet volume
			double volume = pow(planetRadius, 3.0) * 4 / 3 * pi;
			//Apply a cube root and a "clever" factor
			planet.OrbitSize = pow(volume, 1.0/3.0) * 5.5;
		}

		//Setup orbit
		planet.orbitAround(system.position, offset.length);
		planet.orbitSpin(randomd(35.0, 90.0));

		//Create the planet surface
		uint resId = uint(-1);
		if(resource !is null)
			resId = resource.id;

		//SoI - Gas Giants: force gas giants to their base biome only
		//SoI - Ice Giants: force ice giants to their base biome only
		if (resource !is null && force_native_biome.boolean) {
			planet.initSurface(resId, gridW, gridH, biome1.id);
		}
		else {
			planet.initSurface(resId, gridW, gridH, biome1.id, biome2.id, biome3.id);
		}

		//Make node
		PlanetNode@ plNode = cast<PlanetNode>(bindNode(planet, "PlanetNode"));
		plNode.establish(planet);
		plNode.planetType = planet.PlanetType;

		//Setup rings
		//SoI - Gas Giants: gas giants almost always have rings
		//SoI - Ice Giants: ice giants almost always have rings
		if (rings.boolean && (giant.boolean && randomi(0,9) < 9 || !giant.boolean && randomi(0,9) == 0)) {
			uint style = randomi();
			plNode.addRing(style);
			planet.setRing(style);
		}

		if(resource !is null)
			resource.applyGraphics(planet, plNode);
		else if(distribute && data !is null)
			data.distributedResources.insertLast(planet);

		double health = AVG_PLANET_HEALTH * sizeFact;
		planet.Health = health;
		planet.MaxHealth = health;

		planet.finalizeCreation();

		//Setup condition
		if(conditions.boolean && data !is null) {
			if(randomd() < config::PLANET_CONDITION_CHANCE)
				data.distributedConditions.insertLast(planet);
		}

		//Setup moons
		//SoI - Gas Giants: gas giants should have at least 4 moons
		//SoI - Ice Giants: ice giants should have at least 2 moons
		if (resource !is null && giant.boolean) {
			int min, max;
			switch (planetClass) {
				case PC_Gas:
					min = 4;
					max = 8;
					break;
				case PC_Icy:
					min = 2;
					max = 6;
					break;
				default:
					min = 0;
					max = 0;
			}
			for (uint i = 0, cnt = randomi(min, max); i < cnt; ++i) {
				planet.addMoon();
				planet.addStatus(getStatusID("Moon"));
			}
		}
		if(moons.boolean) {
			while(randomd() < config::PLANET_MOON_CHANCE) {
				planet.addMoon();
				planet.addStatus(getStatusID("Moon"));
			}
		}

		//Add a secondary resource if any
		if (!secondary_resource.str.equals_nocase("none")) {
			string secondaryResourceSpec = "";
			if (secondary_resource.str.equals_nocase("ruled")) {
				//Get the resource spec
				for (uint i = 0, cnt = resource.secondaryResources.length; i < cnt; ++i) {
					if (secondaryResourceSpec.length > 0)
						secondaryResourceSpec += ":";
					secondaryResourceSpec += resource.secondaryResources[i];
				}
			}
			else
				secondaryResourceSpec = secondary_resource.str;

			if (secondaryResourceSpec.length > 0) {
				AddPlanetResource secondaryResourceHook;
				secondaryResourceHook.initClass();
				secondaryResourceHook.resID.str = secondaryResourceSpec;
				secondaryResourceHook.instantiate();
				secondaryResourceHook.trigger(data, system, planet);
			}
		}

		//Place in region
		system.object.enterRegion(planet);
		plNode.hintParentObject(system.object, false);

		if(add_status.integer != -1)
			planet.addStatus(add_status.integer);

		@current = planet;
	}

#section all
};

#section server
Planet@ spawnPlanetSpec(const vec3d& point, const string& resourceSpec, bool distributeResource = true, double radius = 0.0, bool physics = true) {
	MakePlanet plHook;
	plHook.initClass();
	plHook.resource.str = resourceSpec;
	plHook.distribute_resource.boolean = distributeResource;
	plHook.moons.boolean = false;
	plHook.rings.boolean = false;
	plHook.conditions.boolean = false;
	plHook.physics.boolean = physics;
	if(radius != 0)
		plHook.radius.set(radius);
	plHook.instantiate();

	Object@ current;

	auto@ reg = getRegion(point);
	auto@ sys = getSystem(reg);
	plHook.trigger(null, sys, current);

	auto@ planet = cast<Planet>(current);
	planet.orbitAround(point, sys.position);
	return planet;
}
#section all

class MakeMoon : MapHook {
	Document doc("Add a moon to the previously generated planet.");
	Argument size(AT_Decimal, "0", doc="Radius size of the moon.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ obj = current;
		if(obj.isPlanet) {
			cast<Planet>(obj).addMoon(size.decimal);
			obj.addStatus(getStatusID("Moon"));
		}
	}
#section all
};

class BonusHealth : MapHook {
	Document doc("Add bonus health to the star or planet.");
	Argument amount(AT_Decimal, doc="Amount of bonus health to add.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ obj = current;
		if(obj.isPlanet) {
			Planet@ pl = cast<Planet>(obj);
			pl.Health += amount.decimal;
			pl.MaxHealth += amount.decimal;
		}
		else if(obj.isStar) {
			Star@ star = cast<Star>(obj);
			star.Health += amount.decimal;
			star.MaxHealth += amount.decimal;
		}
	}
#section all
};

class MakeNebula : MapHook {
	Document doc("Turn the system into a nebula.");
	Argument color(AT_Color, "#f0c870", doc="Color of the nebula.");

	array<Color> colorPossibs;

	bool instantiate() override {
		auto@ txt = color.str.split(":");
		for(uint i = 0, cnt = txt.length; i < cnt; ++i)
			colorPossibs.insertLast(toColor(txt[i]));
		return MapHook::instantiate();
	}

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Color col = colorPossibs[randomi(0, colorPossibs.length-1)];
		createNebula(system.position, system.radius, color=col.rgba, region=system.object);
	}
#section all
};

//ExpandSystem(<Radius> = 1000)
// Expand the current system's size by <Radius>.
class ExpandSystem : MapHook {
	Document doc("Expands the system boundary.");
	Argument radius("Radius", AT_Range, "1000", doc="Amount to add to the current system radius.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		system.radius += arguments[0].fromRange() * config::SCALE_STARS;
	}
#section all
};

//ExpandSystemMinimum(<Radius> = 1000)
// Expand the current system's size to <Radius> if its current radius is smaller.
class ExpandSystemMinimum : MapHook {
	Document doc("Expands the system boundary to a minimum radius if smaller.");
	Argument radius("Radius", AT_Range, "17500", doc="Minimum system radius.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		double radius = arguments[0].fromRange() * config::SCALE_STARS;
		if (system.radius < radius)
			system.radius = radius;
	}
#section all
};

//SetupOrbit(<Radius> = 100, <Position> = (0, 0, 0), Orbit Pct = -1.0)
// Setup an orbit on the previous object.
class SetupOrbit : MapHook {
	Document doc("Gives the previously created object an orbit.");
	Argument radius("Radius", AT_Range, "100.0", doc="Radius at which the object should orbit.");
	Argument position("Position", AT_Position, "(0, 0, 0)", doc="Position relative to the system to orbit around.");
	Argument pct("Orbit Pct", AT_Range, "-1.0", doc="Percent through the year to start the orbit (0-1).");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ cur = current;
		if(cur is null || !cur.hasOrbit)
			return;

		double radius = arguments[0].fromRange() * config::SCALE_STARS;
		vec3d pos = arguments[1].fromPosition() + system.position;
		double pct = arguments[2].fromRange();
		vec2d off = random2d();
		cur.position = pos + vec3d(off.x, 0, off.y);
		cur.orbitAround(pos, radius);
		if(pct >= 0)
			cur.setOrbitPct(pct);
	}
#section all
};

class AddRegionStatus : MapHook {
	Document doc("Add a status that is given to all objects in the system it can apply to.");
	Argument status(AT_Status, doc="Type of status to add to objects in the system.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		system.object.addRegionStatus(null, status.integer);
	}
#section all
};

class NoRegionVision : MapHook {
	Document doc("Indicate that this system does not have automatic shared region vision.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		system.donateVision = false;
	}
#section all
};

//AddPlanetResource(<Resource> = Distributed)
// Add another resource to the previously generated object.
class AddPlanetResource : MapHook {
	Document doc("Adds a single resource to the most recently created planet.");
	Argument resID("Resource", AT_Custom, "distributed", doc="Type or types of resource to choose from.");
	array<const ResourceType@> resPossib;
	bool distribute = false;

	bool instantiate() {
		if(arguments[0].str.equals_nocase("distributed"))
			distribute = true;
		else if(!parseResourceSpec(resPossib, arguments[0].str))
			return false;
		return MapHook::instantiate();
	}

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ cur = current;
		if(cur is null || !cur.hasResources)
			return;

		const ResourceType@ resource;
		if(resPossib.length > 0) {
			if(resPossib.length == 1)
				@resource = resPossib[0];
			else
				@resource = resPossib[randomi(0, resPossib.length-1)];
		}
		if(data is null && distribute)
			@resource = getDistributedResource();
		if(cur.isAsteroid) {
			return;
		}
		else {
			if(resource !is null) {
				markResourceUsed(resource);
				cur.addResource(resource.id);
			}
			else if(distribute && data !is null)
				data.distributedResources.insertLast(cur);
		}
	}
#section all
};

//AddResource(<Tile Resource>, <Amount>)
// Add an income to the previously generated object.
class AddResource : MapHook {
	Document doc("Adds a basic resource income to the most recently created planet.");
	Argument tileRes("Tile Resource", AT_TileResource, doc="Type of basic resource to produce.");
	Argument rate("Rate", AT_Integer, "1", doc="Amount of generation to add.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ cur = current;
		if(cur is null || !cur.hasSurfaceComponent)
			return;
		cur.modResource(arguments[0].integer, +arguments[1].integer);
	}
#section all
};

//NoNeedPopulationForLevel()
// Set the current planet to not need population to level up.
class NoNeedPopulationForLevel : MapHook {
#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ cur = current;
		if(cur is null || !cur.hasSurfaceComponent)
			return;
		cur.setNeedsPopulationForLevel(false);
	}
#section all
};

//Rename(<Name>)
// Rename the object.
class Rename : MapHook {
	Document doc("Renames the most recently created object.");
	Argument name("Name", AT_Locale, doc="Name for the object.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ cur = current;
		if(cur is null)
			return;
		cur.name = arguments[0].str;
	}
#section all
};

//NameSystem(<Name>)
// Rename the system.
class NameSystem : MapHook {
	Document doc("Renames the system.");
	Argument name("Name", AT_Locale, doc="Name for the system.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		system.object.name = arguments[0].str;
		system.name = arguments[0].str;
	}
#section all
};

//AddQuality(<Amount> = 100)
// Add extra quality to the system. Affects various distributions.
class AddQuality : MapHook {
	Document doc("Adds quality to the system. Quality decides quantity and value of resources, anomalies, etc.");
	Argument amt("Amount", AT_Range, doc="Quality to add. 100 is a typical improvement.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(data !is null)
			data.quality += arguments[0].fromRange();
	}
#section all
};

//AddPopulation(<Amount>)
// Add <Amount> population to the previous planet.
class AddPopulation : MapHook {
	Document doc("Adds population to the most recently created planet.");
	Argument amt("Amount", AT_Range, doc="Population to add.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ cur = current;
		if(cur is null || !cur.hasSurfaceComponent)
			return;
		cur.addPopulation(arguments[0].fromRange());
	}
#section all
};

//SpawnBuilding(<Type>, <Position>)
// Spawn a <Type> building on the previous planet at <Position>.
class SpawnBuilding : MapHook {
	Document doc("Places a building on the most recently created planet.");
	Argument type("Type", AT_Custom, doc="Building ID to place.");
	Argument pos("Position", AT_Position2D, doc="Where to place the center of the building on the planet.");
	Argument develop(AT_Boolean, "False", doc="Whether to mark all tiles its on as developed.");
	const BuildingType@ bldType;

	bool instantiate() {
		@bldType = getBuildingType(arguments[0].str);
		if(bldType is null) {
			error(" Error: Could not find building type: '"+escape(arguments[0].str)+"'");
			return false;
		}
		return MapHook::instantiate();
	}

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ cur = current;
		if(cur is null || !cur.hasSurfaceComponent)
			return;
		cur.spawnBuilding(bldType.id, vec2i(arguments[1].fromPosition2D()), develop.boolean);
	}
#section all
};

class ForceUsefulSurface : MapHook {
	Document doc("Force the planet to have a percentage of useful region on its surface.");
	Argument percent(AT_Decimal, doc="Percent of the surface that needs to be useful.");
	Argument biome(AT_PlanetBiome, doc="Biome to fill the planet with to ensure surface.");

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ cur = current;
		if(cur is null || !cur.hasSurfaceComponent)
			return;
		auto@ type = getBiome(biome.str);
		if(type !is null)
			cur.forceUsefulSurface(percent.decimal, type.id);
		else
			print("No such biome: "+biome.str);
	}
#section all
};

//MakeAsteroid(<Resource> = Distributed, <Distribution Chance> = 0.4)
// Create a new asteroid with the given resource available.
// If <Resource> is set to Distributed, distribute some random resources
// with <Distribution Chance>.
class MakeAsteroid : MapHook {
	Document doc("Creates an asteroid in the system.");
	Argument cargo(AT_Cargo, EMPTY_DEFAULT, doc="Type of cargo to create on the asteroid.");
	Argument cargo_amount(AT_Range, "50:1250", doc="Amount of cargo for the asteroid to have.");
	Argument resource(AT_Custom, EMPTY_DEFAULT, doc="Resource to put on the asteroid.");
	Argument distribution_chance(AT_Decimal, "0.4", doc="For distributed resources, chance to add additional resource. Repeats until failure.");

#section server
	array<const ResourceType@> resPossib;
	bool distribute = false;
	bool noResource = false;

	bool instantiate() {
		if(resource.str.length != 0) {
			if(resource.str.equals_nocase("distributed"))
				distribute = true;
			else if(resource.str.equals_nocase("none"))
				noResource = true;
			else if(!parseResourceSpec(resPossib, resource.str))
				return false;
		}
		return MapHook::instantiate();
	}

	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		vec2d rpos = get2dPos(system, 0.8);
		vec3d pos = system.position + vec3d(rpos.x, randomd(-50.0, 50.0), rpos.y);
		Asteroid@ roid = createAsteroid(pos, system.object, delay=true);
		roid.orbitAround(system.position);
		roid.orbitSpin(randomd(20.0, 60.0));
		@current = roid;

		if(noResource) {
			roid.initMesh();
			return;
		}

		double totChance = config::ASTEROID_OCCURANCE + config::RESOURCE_ASTEROID_OCCURANCE;
		double resChance = config::RESOURCE_ASTEROID_OCCURANCE;
		double roll = randomd(0, totChance);

		int cargoType = cargo.integer;
		if(cargoType == -1) {
			auto@ ore = getCargoType("Ore");
			if(ore !is null)
				cargoType = ore.id;
		}

		bool cargoSpec = cargo.integer != -1 && config::ASTEROID_OCCURANCE != 0;
		bool resSpec = (resPossib.length != 0 || distribute) && config::RESOURCE_ASTEROID_OCCURANCE != 0;

		if((cargoSpec && !resSpec) || ((cargoSpec == resSpec) && roll >= resChance)) {
			roid.addCargo(cargoType, cargo_amount.fromRange());
		}
		else {
			if(distribute || resPossib.length == 0) {
				do {
					const ResourceType@ type = getDistributedAsteroidResource();
					if(roid.getAvailableCostFor(type.id) < 0.0)
						roid.addAvailable(type.id, type.asteroidCost);
				}
				while(randomd() < distribution_chance.decimal);
			}
			else {
				const ResourceType@ resource;
				if(resPossib.length > 0) {
					if(resPossib.length == 1)
						@resource = resPossib[0];
					else
						@resource = resPossib[randomi(0, resPossib.length-1)];
				}

				if(resource !is null) {
					if(roid.getAvailableCostFor(resource.id) < 0.0)
						roid.addAvailable(resource.id, resource.asteroidCost);
				}
			}
		}

		roid.initMesh();
	}
#section all
};

class MakeAsteroidBelt : MapHook {
	Document doc("Creates an asteroid belt in the system.");
	Argument count("Count", AT_Range, "50:100", doc="Number of asteroids in the belt.");
	Argument cargo(AT_Cargo, "Ore", doc="Type of cargo to create on the asteroid belt.");
	Argument cargo_amount(AT_Range, "50:500", doc="Amount of cargo for the asteroids to have.");
	Argument distribution_chance(AT_Decimal, "0.4", doc="For distributed resources, chance to add additional resource. Repeats until failure.");
	Argument radius(AT_Custom, "random", doc="Numeric radius of the belt. \"Random\" for random radius. \"Inner\" for radius near the core. \"Outer\" for radius near the edge.");
	Argument layers(AT_Decimal, "0", doc="Number of successive layers of asteroids in the belt. Number of layers relative to asteroid count if 0.");

	bool instantiate() {
		if(arguments[0].fromRange() <= 0)
			return false;
		return MapHook::instantiate();
	}

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(config::ASTEROID_OCCURANCE == 0)
			return;

		//Allow to specify a fixed radius or specific keywords
		double beltRadius = 0;
		if (radius.str.equals_nocase("random"))
			beltRadius = randomd(0.4, 1.0) * system.radius;
			else if (radius.str.equals_nocase("inner"))
				beltRadius = randomd(0.4, 0.7) * system.radius;
		else if (radius.str.equals_nocase("outer"))
			beltRadius = randomd(0.8, 1.0) * system.radius;
		else {
			beltRadius = toDouble(radius.str);
			if (beltRadius == 0) {
				error("MakeAsteroidBelt: Invalid radius value: "+ escape(radius.str));
				return;
			}
			beltRadius = min(beltRadius, 1.0 * system.radius);
		}

		uint count = uint(arguments[0].fromRange());

		double resFactor = config::RESOURCE_ASTEROID_OCCURANCE / (count / 4);
		double totChance = config::ASTEROID_OCCURANCE + resFactor;
		double resChance = resFactor;

		uint remaining = count;
		uint layers = uint(arguments[5].fromRange());
		if (layers == 0) {
			uint lyrs = floor(count / randomi(15, 25));
			layers = max(1, lyrs);
		}
		for(uint i = 0, cnt = layers; i < cnt; ++i) {
			if (i > 0)
				beltRadius += randomd(250.0, 500.0);
			double angle = randomd(0, twopi);
			//Uneven repartition between layers for a more natural look
			uint layercnt = max(1, randomi((count / layers) * 0.8, (count / layers) * 1.2));
			remaining -= layercnt;
			if (i == layers - 1)
				layercnt += remaining;
			for(uint i = 0, cnt = layercnt; i < cnt; ++i) {
				angle += twopi / double(cnt);
				double ang = angle + randomd(-0.25, 0.25) * twopi / double(cnt);

				vec3d pos = system.position + vec3d(cos(ang) * beltRadius, randomd(-50.0, 50.0), sin(ang) * beltRadius);

				Asteroid@ roid = createAsteroid(pos, system.object, delay = true);
				roid.orbitAround(system.position);
				roid.orbitSpin(randomd(20.0, 60.0));
				@current = roid;

				if(randomd(0, totChance) >= resChance && cargo.integer != -1) {
					roid.addCargo(cargo.integer, cargo_amount.fromRange());
				}
				else {
					do {
						const ResourceType@ type = getDistributedAsteroidResource();
						if(roid.getAvailableCostFor(type.id) < 0.0)
							roid.addAvailable(type.id, type.asteroidCost);
					}
					while(randomd() < distribution_chance.decimal);
				}

				roid.initMesh();
			}
		}
	}
#section all
};

//SetMine()
// Set the previously generated asteroid as an owned mine for the current empire.
class SetMine : MapHook {
#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(data.homeworlds is null || data.currentHomeworld is null)
			return;

		Empire@ emp = @data.currentHomeworld;
		Object@ cur = current;
		Asteroid@ roid = cast<Asteroid>(cur);
		if (roid !is null) {
			//Sometimes the resource is not yet created
			//Wait a bit
			sleep(1);
			if (roid.getAvailableCount() > 0) {
				setOnFirstResource(roid, emp);
			}
			else {
				//Try again
				sleep(5);
				if (roid.getAvailableCount() > 0) {
					setOnFirstResource(roid, emp);
				}
			}
		}
	}

	void setOnFirstResource(Asteroid@ roid, Empire@ emp) {
		uint resId = roid.getAvailable(0);
		roid.setup(null, emp, resId);
	}
#section all
};

//MakeAnomaly(<Type> = Distributed)
// Generate a anomaly field in this system of type <Type>.
class MakeAnomaly : MapHook {
	Document doc("Creates an anomaly in the system.");
	Argument anomType("Type", AT_Custom, "distributed", doc="Type of anomaly to create.");
	const AnomalyType@ type;

	bool instantiate() {
		if(!arguments[0].str.equals_nocase("distributed")) {
			@type = getAnomalyType(arguments[0].str);
			if(type is null) {
				error(" Error: Could not find anomaly type: "+arguments[0].str);
				return false;
			}
		}
		return MapHook::instantiate();
	}

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		const AnomalyType@ gen = type;
		if(gen is null)
			@gen = getDistributedAnomalyType();

		vec2d rpos = get2dPos(system, 0.8);
		vec3d pos = system.position + vec3d(rpos.x, randomd(-50.0, 50.0), rpos.y);
		Anomaly@ anomaly = createAnomaly(pos, gen.id);
		@current = anomaly;
	}
#section all
};

class SpawnRandomRemnants : MapHook {
	Document doc("Spawn a remnant fleet with a random design at a particular size.");
	Argument size(AT_Integer, doc="Base size of the remnant flagship.");
	Argument occupation(AT_Range, "0.8", doc="Percentage of support that is filled.");
	Argument gametime_size(AT_Range, "0", doc="If spawned after game start, increase the flagship size by this much per minute of game time.");
	Argument offset(AT_Decimal, "0", doc="Minimum offset from the edge of the system to the fleet.");

#section server
	void postTrigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		int sz = size.integer;
		sz += round(gametime_size.fromRange() * gameTime / 60.0);

		vec2d campPos = get2dPos(system, 0.95, offset.decimal);
		vec3d pos = system.position + vec3d(campPos.x, 0, campPos.y);

		spawnRemnantFleet(pos, sz, occupation.fromRange());
	}
#section all
}

//MakeCreepCamp(<Type> = Distributed)
// Generate a creep camp in this system of type <Type>.
class MakeCreepCamp : MapHook {
	Document doc("Creates a creep camp in the system.");
	Argument campID("Type", AT_Custom, "distributed", doc="Type of camp to create.");
	Argument offset(AT_Decimal, "0", doc="Minimum offset from the edge of the system to the camp.");
	const CampType@ campType;

	MakeCreepCamp() {
		argument("Type", AT_Custom, "distributed");
	}

	bool instantiate() {
		if(!arguments[0].str.equals_nocase("distributed")) {
			@campType = getCreepCamp(arguments[0].str);
			if(campType is null) {
				error(" Error: Could not find creep camp type: '"+escape(arguments[0].str)+"'");
				return false;
			}
		}
		return MapHook::instantiate();
	}

#section server
	void postTrigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(config::REMNANT_OCCURANCE == 0.0)
			return;

		const CampType@ type = campType;
		if(type is null)
			@type = getDistributedCreepCamp();

		vec2d campPos = get2dPos(system, 0.95, offset.decimal);
		vec3d pos = system.position + vec3d(campPos.x, 0, campPos.y);

		makeCreepCamp(pos, type, system.object);
	}
#section all
};

#section server
void makeCreepCamp(const vec3d& pos, const CampType@ type, Region@ region = null) {
	//Create pickup
	Pickup@ pickup;
	double roll = randomd(0.0, type.pickupFrequency);
	for(uint i = 0, cnt = type.pickups.length; i < cnt; ++i) {
		const PickupType@ ptype = type.pickups[i];
		if(roll <= ptype.frequency) {
			double minRad = 20.0 + ptype.physicalSize * 2.0;
			double maxRad = 40.0 + ptype.physicalSize * 4.0;
			vec2d off = random2d(minRad, maxRad);

			@pickup = createPickup(pos + vec3d(off.x, randomd(5.0, 10.0), off.y), ptype.id, defaultEmpire);
			pickup.finalizeCreation();
			pickup.setCampType(type.id);

			if(region !is null) {
				@pickup.region = region;
				region.enterRegion(pickup);
			}
			break;
		}
		else {
			roll -= ptype.frequency;
		}
	}

	//Add statuses to region
	if(region !is null) {
		for(uint i = 0, cnt = type.region_statuses.length; i < cnt; ++i)
			region.addRegionStatus(null, type.region_statuses[i].id);
	}

	//Create defenders
	Object@ lastLeader;
	for(uint i = 0, cnt = type.ships.length; i < cnt; ++i) {
		const Design@ dsg = type.ships[i];
		uint minCnt = type.shipMins[i];
		uint maxCnt = type.shipMaxes[i];
		int amt = randomi(minCnt, maxCnt);

		if(!dsg.hull.hasTag(ST_IsSupport)) {
			for(; amt > 0; --amt) {
				vec3d leaderPos = pos;
				if(lastLeader !is null)
					leaderPos += random3d(10.0, 40.0);

				@lastLeader = createShip(leaderPos, dsg, Creeps, free=true, memorable=true);
				lastLeader.setAutoMode(config::REMNANT_AGGRESSION == 0 ? AM_HoldPosition : AM_RegionBound);
				lastLeader.sightRange = 0;
				lastLeader.setRotation(quaterniond_fromAxisAngle(vec3d_up(), randomd(-pi, pi)));

				for(uint i = 0, cnt = type.statuses.length; i < cnt; ++i)
					lastLeader.addStatus(type.statuses[i].id);

				if(type.shipNames[i].length != 0) {
					lastLeader.name = type.shipNames[i];
					lastLeader.named = true;
				}

				pickup.addPickupProtector(lastLeader);
			}
		}
		else {
			for(; amt > 0; --amt)
				createShip(lastLeader.position, dsg, Creeps, lastLeader, free=true);
		}
	}

	//Create randomized defenders
	if(type.flagshipSize > 0) {
		vec3d leaderPos = pos;
		if(lastLeader !is null)
			leaderPos += random3d(10.0, 40.0);
		@lastLeader = spawnRemnantFleet(leaderPos, type.flagshipSize, type.supportOccupation);
		lastLeader.setAutoMode(config::REMNANT_AGGRESSION == 0 ? AM_HoldPosition : AM_RegionBound);

		for(uint i = 0, cnt = type.statuses.length; i < cnt; ++i)
			lastLeader.addStatus(type.statuses[i].id);
		pickup.addPickupProtector(lastLeader);
	}
	if(type.targetStrength > 0) {
		vec3d leaderPos = pos;
		if(lastLeader !is null)
			leaderPos += random3d(10.0, 40.0);
		@lastLeader = spawnRemnantFleet(leaderPos, composeRemnantFleet(type.targetStrength));
		lastLeader.setAutoMode(config::REMNANT_AGGRESSION == 0 ? AM_HoldPosition : AM_RegionBound);

		for(uint i = 0, cnt = type.statuses.length; i < cnt; ++i)
			lastLeader.addStatus(type.statuses[i].id);
		pickup.addPickupProtector(lastLeader);
	}
}
#section all

class SetStaticSeeableRange : MapHook {
	Document doc("Set the seeable range of static objects (anomalies, asteroids, etc) in this system.");
	Argument range(AT_Decimal, doc="Seeable range to set.");

#section server
	void postTrigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		for(uint i = 0, cnt = system.object.objectCount; i < cnt; ++i) {
			Object@ obj = system.object.objects[i];
			if(obj.hasStatuses)
				continue;
			obj.seeableRange = range.decimal;
		}
	}
#section all
};

//MakeAdjacentAsteroid(<Resource> = Distributed, <Distribution Chance> = 0.4)
// Create a new asteroid with the given resource available in an adjacent system.
// If <Resource> is set to Distributed, distribute some random resources
// with <Distribution Chance>.
class MakeAdjacentAsteroid : MapHook {
	Document doc("Creates an asteroid in an adjacent system.");
	Argument cargo(AT_Cargo, EMPTY_DEFAULT, doc="Type of cargo to create on the asteroid.");
	Argument cargo_amount(AT_Range, "50:1250", doc="Amount of cargo for the asteroid to have.");
	Argument resource(AT_Custom, EMPTY_DEFAULT, doc="Resource to put on the asteroid.");
	Argument distribution_chance(AT_Decimal, "0.4", doc="For distributed resources, chance to add additional resource. Repeats until failure.");
	Argument farther(AT_Boolean, "False", doc="If true, the asteroid will spawn one system farther.");

#section server
	array<const ResourceType@> resPossib;
	bool distribute = false;
	bool noResource = false;

	bool instantiate() {
		if(resource.str.length != 0) {
			if(resource.str.equals_nocase("distributed"))
				distribute = true;
			else if(resource.str.equals_nocase("none"))
				noResource = true;
			else if(!parseResourceSpec(resPossib, resource.str))
				return false;
		}
		return MapHook::instantiate();
	}

	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(system.adjacent.length == 0)
			return;
		if(data !is null && data.ignoreAdjacencies)
			return;

		int at = randomi(0, data.adjacentData.length - 1);
		SystemData@ adjacent = data.adjacentData[at];

		if (farther.boolean) {
			array<uint> tried;
			do {
				at = randomi(0, adjacent.adjacentData.length - 1);
				if (tried.find(at) == -1) {
					tried.insertLast(at);
					auto@ potential = adjacent.adjacentData[at];
					//Check that the chosen system isn't the origin
					if (potential !is data) {
						//Check that the chosen system is not actually at a lesser distance from the origin
						if (potential.adjacentData.find(data) == -1) {
							@adjacent = potential;
							break;
						}
					}
				}
			} //If at the galaxy's edge, it is possible to actually run out of options, so spawn the asteroid in the current system
			while (tried.length < adjacent.adjacentData.length);
		}

		SystemDesc@ other = getSystem(adjacent.sysIndex);
		vec2d rpos = get2dPos(other, 0.8);
		vec3d pos = other.position + vec3d(rpos.x, randomd(-50.0, 50.0), rpos.y);
		Asteroid@ roid = createAsteroid(pos, other.object, delay=true);
		roid.orbitAround(other.position);
		roid.orbitSpin(randomd(20.0, 60.0));
		@current = roid;

		if(noResource) {
			roid.initMesh();
			return;
		}

		double totChance = config::ASTEROID_OCCURANCE + config::RESOURCE_ASTEROID_OCCURANCE;
		double resChance = config::RESOURCE_ASTEROID_OCCURANCE;
		double roll = randomd(0, totChance);

		int cargoType = cargo.integer;
		if(cargoType == -1) {
			auto@ ore = getCargoType("Ore");
			if(ore !is null)
				cargoType = ore.id;
		}

		bool cargoSpec = cargo.integer != -1 && config::ASTEROID_OCCURANCE != 0;
		bool resSpec = (resPossib.length != 0 || distribute) && config::RESOURCE_ASTEROID_OCCURANCE != 0;

		if((cargoSpec && !resSpec) || ((cargoSpec == resSpec) && roll >= resChance)) {
			roid.addCargo(cargoType, cargo_amount.fromRange());
		}
		else {
			if(distribute || resPossib.length == 0) {
				do {
					const ResourceType@ type = getDistributedAsteroidResource();
					if(roid.getAvailableCostFor(type.id) < 0.0)
						roid.addAvailable(type.id, type.asteroidCost);
				}
				while(randomd() < distribution_chance.decimal);
			}
			else {
				const ResourceType@ resource;
				if(resPossib.length > 0) {
					if(resPossib.length == 1)
						@resource = resPossib[0];
					else
						@resource = resPossib[randomi(0, resPossib.length-1)];
				}

				if(resource !is null) {
					if(roid.getAvailableCostFor(resource.id) < 0.0)
						roid.addAvailable(resource.id, resource.asteroidCost);
				}
			}
		}

		roid.initMesh();
	}
#section all
};

//MakeAdjacentCreepCamp(<Type> = Distributed, <Place Far> = False)
// Generate a creep camp in an adjacent system of type <Type>.
class MakeAdjacentCreepCamp : MapHook {
	Document doc("Creates a creep camp in an adjacent system.");
	Argument campID("Type", AT_Custom, "distributed", doc="Type of camp to create.");
	Argument placeFar("Place Far", AT_Boolean, "True", doc="Whether the camp should be pushed to the edge of the system.");
	const CampType@ campType;

	bool instantiate() {
		if(!arguments[0].str.equals_nocase("distributed")) {
			@campType = getCreepCamp(arguments[0].str);
			if(campType is null) {
				error(" Error: Could not find creep camp type: '"+escape(arguments[0].str)+"'");
				return false;
			}
		}
		return MapHook::instantiate();
	}

#section server
	void postTrigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(data !is null && data.ignoreAdjacencies)
			return;
		if(config::REMNANT_OCCURANCE == 0.0)
			return;
		const CampType@ type = campType;
		if(type is null)
			@type = getDistributedCreepCamp();

		if(system.adjacent.length == 0)
			return;
		int at = randomi(0, system.adjacent.length-1);
		SystemDesc@ other = getSystem(system.adjacent[at]);
		vec2d campPos = get2dPos(other, 0.8);
		if(arguments[1].boolean) {
			vec3d off = (other.position - system.position).normalized(other.radius * 0.8);
			campPos = vec2d(off.x, off.z);
		}

		vec3d pos = other.position + vec3d(campPos.x, 0, campPos.y);

		makeCreepCamp(pos, type);
	}
#section all
};

//MakeArtifact(<Type> = Distributed)
// Generate a anomaly field in this system of type <Type>.
class MakeArtifact : MapHook {
	Document doc("Creates an artifact in the system.");
	Argument artifactType("Type", AT_Custom, "distributed", doc="Type of artifact to create.");
	const ArtifactType@ type;

	bool instantiate() {
		if(!arguments[0].str.equals_nocase("distributed")) {
			@type = getArtifactType(arguments[0].str);
			if(type is null) {
				error(" Error: Could not find artifact type: "+arguments[0].str);
				return false;
			}
		}
		return MapHook::instantiate();
	}

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(data !is null)
			data.artifacts += 1;
		@current = makeArtifact(system, type is null ? getDistributedArtifactType(system.contestation).id : type.id);
	}
#section all
};

#section server
Artifact@ makeArtifact(SystemDesc@ system, uint type = uint(-1)) {
	const ArtifactType@ gen;
	if(type == uint(-1))
		@gen = getDistributedArtifactType();
	else
		@gen = getArtifactType(type);
	vec2d rpos = get2dPos(system, 1.0, 2500);//random2d(150.0, system.radius - 250.0);
	vec3d pos = system.position + vec3d(rpos.x, randomd(-50.0, 50.0), rpos.y);
	Artifact@ obj = createArtifact(pos, gen, system.object);
	obj.orbitAround(system.position);
	@obj.region = system.object;
	system.object.enterRegion(obj);
	return obj;
}
#section all

//RepeatHomeworlds()
// Repeats the block for every homeworld in this system, and sets
// the object to the appropriate empire's homeworld.
class RepeatHomeworlds : BlockEffect {
#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const {
		if(data.homeworlds is null)
			return;
		for(uint n = 0, ncnt = data.homeworlds.length; n < ncnt; ++n) {
			Empire@ emp = @data.currentHomeworld = data.homeworlds[n];
			for(uint i = 0, cnt = inner.length; i < cnt; ++i) {
				auto@ cur = cast<IMapHook@>(inner[i]);
				if(cur !is null)
					cur.trigger(data, system, current);
			}

			Object@ cur = current;
			Planet@ pl = cast<Planet>(cur);
			if(pl !is null) {
				@pl.owner = emp;
				@emp.Homeworld = pl;
			}
		}
	}
#section all
};

//AddAdjacentAnomalies(<Amount>)
// Add <Amount> anomaly to random adjacent systems.
class AddAdjacentAnomalies : MapHook {
	Document doc("Creates anomalies in adjacent systems.");
	Argument count("Count", AT_Range, doc="Number to create.");
	MakeAnomaly maker;

#section server
	void postTrigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(system.adjacent.length == 0)
			return;
		if(data !is null && data.ignoreAdjacencies)
			return;
		if(config::ANOMALY_OCCURANCE == 0.0)
			return;

		uint cnt = arguments[0].fromRange();
		for(uint i = 0; i < cnt; ++i) {
			int at = randomi(0, system.adjacent.length-1);
			SystemDesc@ other = getSystem(data.adjacentData[at].sysIndex);
			maker.trigger(data.adjacentData[at], other, current);
		}
	}
#section all
};

//AddAdjacentArtifacts(<Amount>)
// Add <Amount> anomaly to random adjacent systems.
class AddAdjacentArtifacts : MapHook {
	Document doc("Creates artifacts in adjacent systems.");
	Argument count("Count", AT_Range, doc="Number to create.");
	MakeArtifact maker;

#section server
	void postTrigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(system.adjacent.length == 0)
			return;
		if(data !is null && data.ignoreAdjacencies)
			return;

		uint cnt = arguments[0].fromRange();
		for(uint i = 0; i < cnt; ++i) {
			int at = randomi(0, system.adjacent.length-1);
			SystemDesc@ other = getSystem(data.adjacentData[at].sysIndex);
			maker.trigger(data.adjacentData[at], other, current);
		}
	}
#section all
};

//GuaranteeAdjacentResource(<Resource>, <Distance> = 1)
// Guarantee an adjacent resource out of a type spec.
class GuaranteeAdjacentResource : MapHook {
	Document doc("Attempts to guarantee that specific reosurces will be available in adjacent systems. Logs on failure.");
	Argument res("Resource", AT_Custom, doc="Type(s) of resource to guarantee. Only one will be picked.");
	Argument count("Distance", AT_Integer, "1", doc="System hop distance within which to allow the resource.");
	array<const ResourceType@> resPossib;

	bool instantiate() {
		if(!parseResourceSpec(resPossib, arguments[0].str))
			return false;
		return MapHook::instantiate();
	}

#section server
	void add(array<Object@>& objects, array<SystemData@>& sources, SystemData@ data, int distance) {
		for(uint i = 0, cnt = data.adjacentData.length; i < cnt; ++i) {
			auto@ other = data.adjacentData[i];
			for(uint n = 0, ncnt = other.distributedResources.length; n < ncnt; ++n) {
				Planet@ pl = cast<Planet>(other.distributedResources[n]);
				if(pl !is null) {
					objects.insertLast(pl);
					sources.insertLast(other);
				}
			}
			if(distance > 1)
				add(objects, sources, other, distance-1);
		}
	}

	void postTrigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(data is null)
			return;
		if(data.ignoreAdjacencies)
			return;

		const ResourceType@ resource;
		if(resPossib.length > 0) {
			if(resPossib.length == 1)
				@resource = resPossib[0];
			else
				@resource = resPossib[randomi(0, resPossib.length-1)];
		}
		if(resource is null)
			return;

		array<Object@> objects;
		array<SystemData@> sources;
		add(objects, sources, data, arguments[1].integer);

		if(objects.length != 0) {
			uint i = randomi(0, objects.length-1);
			Object@ target = objects[i];
			sources[i].distributedResources.remove(target);

			target.addResource(resource.id);
			auto@ node = cast<PlanetNode>(target.getNode());
			if(node !is null)
				resource.applyGraphics(target, node);
		}
		else {
			warn("WARNING: Map guarantee '"+arguments[0].str+"' could not find planet around system '"+system.name+"'.");
		}
	}
#section all
};

class OnPlanet : MapHook {
	GenericEffect@ eff;
	Document doc("Run the passed hook as a single-time planet effect hook on the object. Because it only runs once, hooks with ticks or data storage will not work!");
	Argument hook(AT_Custom, doc="Hook to run.");

	bool instantiate() override {
		@eff = cast<GenericEffect>(parseHook(hook.str, "planet_effects::"));
		if(eff is null) {
			error("GenericEffect(): could not find inner hook: "+escape(hook.str));
			return false;
		}
		return MapHook::instantiate();
	}

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ c = current;
		if(c !is null)
			eff.enable(c, null);
	}
#section all
};

class Trigger : MapHook {
	BonusEffect@ eff;
	Document doc("Run the specified hook on the current object.");
	Argument hook(AT_Custom, doc="Hook to run.");

	bool instantiate() override {
		@eff = cast<BonusEffect>(parseHook(hook.str, "bonus_effects::"));
		if(eff is null) {
			error("Trigger(): could not find inner hook: "+escape(hook.str));
			return false;
		}
		return MapHook::instantiate();
	}

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		Object@ c = current;
		if(c is null)
			eff.activate(c, null);
	}
#section all
};

class TriggerRegion : MapHook {
	BonusEffect@ eff;
	Document doc("Run the specified hook on the current region.");
	Argument hook(AT_Custom, doc="Hook to run.");

	bool instantiate() override {
		@eff = cast<BonusEffect>(parseHook(hook.str, "bonus_effects::"));
		if(eff is null) {
			error("TriggerRegion(): could not find inner hook: "+escape(hook.str));
			return false;
		}
		return MapHook::instantiate();
	}

#section server
	void trigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {
		if(system !is null)
			eff.activate(system.object, null);
	}
#section all
};

//Copy a region during map generation
void mapCopyRegion(SystemDesc@ from, SystemDesc@ to, uint typeMask = ~0) {
#section server
	Region@ reg = from.object;
	reg.wait();

	Object@ current;

	MakePlanet plHook;
	plHook.initClass();
	plHook.instantiate();
	plHook.distribute = false;
	plHook.resPossib.length = 1;

	MakeAsteroid roidHook;
	roidHook.noResource = true;
	roidHook.initClass();
	roidHook.instantiate();

	MakeStar starHook;
	starHook.initClass();
	starHook.instantiate();
	
	MakeBlackhole blackHoleHook;
	blackHoleHook.initClass();
	blackHoleHook.instantiate();
	
	MakeNeutronStar neutronHook;
	neutronHook.initClass();
	neutronHook.instantiate();

	MakeAnomaly anomalyHook;
	anomalyHook.initClass();
	anomalyHook.instantiate();

	MakeArtifact artifactHook;
	artifactHook.initClass();
	artifactHook.instantiate();

	//Mirror region properties
	to.donateVision = from.donateVision;
	from.object.mirrorRegionStatusTo(to.object);

	//Copy
	for(uint i = 0, cnt = reg.objectCount; i < cnt; ++i) {
		Object@ obj = reg.objects[i];

		if(typeMask & (1<<obj.type) == 0)
			continue;

		vec3d destPos = obj.position - from.position;
		destPos.z = -destPos.z;
		destPos += to.position;

		if(obj.isPlanet) {
			obj.wait();

			@plHook.resPossib[0] = getResource(obj.primaryResourceType);
			plHook.radius.set(obj.radius);
			plHook.grid_size.set(vec2d(obj.surfaceGridSize));

			plHook.trigger(null, to, current);

			Planet@ pl = cast<Planet>(current);
			pl.orbitAround(destPos, to.position);
			to.radius = from.radius;

			if(pl.statusInstanceCount != 0 || obj.statusInstanceCount != 0) {
				for(uint j = 0, jcnt = pl.statusInstanceCount; j < jcnt; ++j)
					pl.removeStatus(pl.statusInstanceId[j]);
				for(uint j = 0, jcnt = obj.statusInstanceCount; j < jcnt; ++j)
					pl.addStatus(obj.statusInstanceType[j]);
			}

			pl.mirrorSurfaceFrom(obj);
		}
		else if(obj.isAsteroid) {
			Asteroid@ base = cast<Asteroid>(obj);
			base.wait();

			//This avoids asteroids always having resource asteroid icons
			if (base.cargoTypes != 0) {
				roidHook.arguments[0].integer = base.cargoType[0];
				roidHook.arguments[1].set(base.getCargoStored(base.cargoType[0]));
				roidHook.noResource = false;
			}
			else {
				roidHook.arguments[0].integer = -1;
				roidHook.noResource = true;
			}

			roidHook.trigger(null, to, current);

			Asteroid@ roid = cast<Asteroid>(current);
			roid.orbitAround(destPos, to.position);

			for(uint i = 0, cnt = base.getAvailableCount(); i < cnt; ++i)
				roid.addAvailable(base.getAvailable(i), base.getAvailableCost(i));
		}
		else if(obj.isStar) {
			Star@ base = cast<Star>(obj);
			
			if (base.temperature > 0.0 && base.temperature < 300000.0) {
				starHook.arguments[0].set(base.temperature);
				starHook.arguments[1].set(base.radius);
				starHook.arguments[2].set(destPos - to.position);
				
				starHook.trigger(null, to, current);
			}
			else if (base.temperature >= 300000.0 && base.temperature <= 600000.0) {
				neutronHook.arguments[0].set(destPos - to.position);
				
				neutronHook.trigger(null, to, current);
			}
			else {
				blackHoleHook.arguments[0].set(base.radius);
				blackHoleHook.arguments[1].set(destPos - to.position);
				
				blackHoleHook.trigger(null, to, current);
			}
		}
		else if(obj.isArtifact) {
			Artifact@ base = cast<Artifact>(obj);

			@artifactHook.type = getArtifactType(base.ArtifactType);
			artifactHook.trigger(null, to, current);

			Artifact@ artifact = cast<Artifact>(current);
			artifact.orbitAround(destPos, to.position);
		}
		else if(obj.isAnomaly) {
			Anomaly@ base = cast<Anomaly>(obj);

			@anomalyHook.type = getAnomalyType(base.anomalyType);

			anomalyHook.trigger(null, to, current);

			Anomaly@ anomaly = cast<Anomaly>(current);
			anomaly.position = destPos;
			anomaly.clearOptions();
			for(uint i = 0, cnt = base.optionCount; i < cnt; ++i)
				anomaly.addOption(base.option[i]);
		}
		else if(obj.isPickup) {
			Pickup@ base = cast<Pickup>(obj);

			Pickup@ pickup = createPickup(destPos, base.PickupType, defaultEmpire);
			pickup.finalizeCreation();

			Ship@ baseProt = cast<Ship>(base.getProtector());
			if(baseProt !is null) {
				baseProt.wait();

				vec3d leadPos = baseProt.position - from.position;
				leadPos.z = -leadPos.z;
				leadPos += to.position;

				Ship@ leader = createShip(leadPos,
						baseProt.blueprint.design, Creeps, free=true, memorable=true);
				leader.name = baseProt.name;
				leader.named = baseProt.named;
				leader.setAutoMode(config::REMNANT_AGGRESSION == 0 ? AM_HoldPosition : AM_RegionBound);
				leader.sightRange = 0;

				pickup.addPickupProtector(leader);

				for(uint n = 0, ncnt = baseProt.supportCount; n < ncnt; ++n) {
					Ship@ supp = cast<Ship>(baseProt.supportShip[n]);
					if(supp !is null)
						createShip(leadPos, supp.blueprint.design, Creeps, leader, free=true);
				}
			}
		}
		else if(obj.isOddity) {
			Oddity@ odd = cast<Oddity>(obj);
			if(odd.isGate())
				continue;

			ObjectDesc desc;
			desc.type = OT_Oddity;
			desc.radius = odd.radius;
			desc.position = destPos;
			desc.flags |= objNoPhysics;
			desc.flags |= objNoDamage;

			auto@ mirr = Oddity(desc);
			mirr.noCollide = true;
			mirr.makeVisuals(odd.getVisualType(), color=odd.getVisualColor());
		}
	}
#section all
}

class ForceMakeCreepCamp : MapHook {
	Document doc("Creates a creep camp in the system, even if Remnant occurrence is set to zero.");
	Argument campID("Type", AT_Custom, "distributed", doc="Type of camp to create.");
	Argument offset(AT_Decimal, "0", doc="Minimum offset from the edge of the system to the camp.");
	const CampType@ campType;

	bool instantiate() {
		if(!arguments[0].str.equals_nocase("distributed")) {
			@campType = getCreepCamp(arguments[0].str);
			if(campType is null) {
				error(" Error: Could not find creep camp type: '"+escape(arguments[0].str)+"'");
				return false;
			}
		}
		return MapHook::instantiate();
	}

#section server
	void postTrigger(SystemData@ data, SystemDesc@ system, Object@& current) const override {

		const CampType@ type = campType;
		if(type is null)
			@type = getDistributedCreepCamp();

		vec2d campPos = random2d(200.0, (system.radius - offset.decimal) * 0.95);
		vec3d pos = system.position + vec3d(campPos.x, 0, campPos.y);

		makeCreepCamp(pos, type, system.object);
	}
#section all
};

//SoI - Scaling: get a random point in the system but outside the radius of the star(s)
//Make sure that objects do not spawn inside a star but can be relatively close whatever its radius and the system radius are
vec2d get2dPos(SystemDesc@ system, double radiusFactor = 1.0, double edgeOffset = 0.0) {
	double maxRadius = (system.radius - edgeOffset) * radiusFactor;
	double minRadius = 0.25 * system.radius;

	vec2d pos = random2d(minRadius, maxRadius);
	if (pos.x <= 4000.0 * config::SCALE_STARS && pos.y <= 4000.0 * config::SCALE_STARS)
		if (maxRadius > 5000.0 * config::SCALE_STARS)
			pos = random2d(4000.0 * config::SCALE_STARS, maxRadius);
		else
			pos = random2d(4000.0 * config::SCALE_STARS, 4500.0 * config::SCALE_STARS);

	return pos;
}

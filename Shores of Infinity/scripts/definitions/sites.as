#priority init 2000
import hooks;
import saving;

export Site, SiteContainer, SiteType, SiteOption, SiteState, SiteKind;
export getSiteType, getSiteTypeCount, getSiteTypes;
export getDistributedSiteType;
export Targets;

enum SiteKind {
	SK_HomeworldSite,
	SK_TerrestrialSite,
};

tidy final class SiteOption {
	uint id = 0;
	Sprite icon;
	string ident, desc;
	string blurb;
	bool isSafe = true;
	double chance = 1.0;

	array<ISiteHook@> hooks;

	array<SiteResult@> results;
	double resultTotal = 0.0;

	void choose(Site@ site, Empire@ emp) const {
		for(uint i = 0, cnt = hooks.length; i < cnt; ++i)
			hooks[i].choose(site, emp);

		double roll = randomd(0.0, resultTotal);
		for(uint i = 0, cnt = results.length; i < cnt; ++i) {
			if(roll <= results[i].chance) {
				results[i].choose(site, emp);
				break;
			}
			roll -= results[i].chance;
		}
	}

	bool giveOption(Site@ site, Empire@ emp) const {
		for(uint i = 0, cnt = hooks.length; i < cnt; ++i) {
			if(!hooks[i].giveOption(site, emp))
				return false;
		}
		return true;
	}
};

tidy class SiteResult {
	double chance = 1.0;
	array<ISiteHook@> hooks;

	void choose(Site@ site, Empire@ emp) const {
		for(uint i = 0, cnt = hooks.length; i < cnt; ++i)
			hooks[i].choose(site, emp);
	}
};

interface ISiteHook {
	void init(SiteType@ type);
	void choose(Site@ site, Empire@ emp) const;
	bool giveOption(Site@ site, Empire@ emp) const;
};

tidy class SiteHook : Hook, ISiteHook {
	void init(SiteType@ type) {}
	void choose(Site@ site, Empire@ emp) const {}
	bool giveOption(Site@ site, Empire@ emp) const { return true; }
};

tidy class SiteType {
	uint id = 0;
	string ident, name = locale::SITE, desc, narrative;
	string modelName = "", matName = "";
	string spriteName;

	double frequency = 1.0;
	double scanTime = 60.0;
	bool unique = false;

	double stateTotal = 0.0;
	array<SiteState@> states;
	array<SiteOption@> options;

	const SiteState@ getState() const {
		if(states.length == 0)
			return null;
		double value = randomd(0.0, stateTotal);
		for(uint i = 0, cnt = states.length; i < cnt; ++i) {
			if(value <= states[i].frequency)
				return states[i];
			value -= states[i].frequency;
		}
		return states[states.length-1];
	}

	const SiteOption@ getOption(const string& ident) const {
		for(uint i = 0, cnt = options.length; i < cnt; ++i) {
			if(options[i].ident == ident)
				return options[i];
		}
		return null;
	}

	const SiteState@ getState(const string& ident) const {
		for(uint i = 0, cnt = states.length; i < cnt; ++i) {
			if(states[i].ident == ident)
				return states[i];
		}
		return null;
	}
};

class SiteTypeList {
	SiteType@[] types;
	double totalFrequency = 0;

	void add(SiteType@ type) {
		types.insertLast(type);
		totalFrequency += type.frequency;
	}
};

tidy class SiteState {
	uint id = 0;
	string ident;
	string narrative;
	string modelName = "", matName = "";
	string spriteName;
	array<const SiteOption@> options;
	array<double> option_chances;
	array<string> def_options;
	double frequency = 1.0;
};

interface SiteContainer {
	void create(Site@ site);
};

class Site : Serializable, Savable {
	uint id;
	Object@ obj;
	int siteTypeId = -1;
	const SiteType@ type;
	const SiteState@ state;
	array<const SiteOption@> options;

	bool choiceDelta = false;

	Site() {}

	void create(Object& owner, uint typeId) {
		@obj = owner;
		siteTypeId = typeId;
		@type = getSiteType(typeId);
		if (type is null)
			@type = getSiteType(0);

		auto@ state = type.getState();
		progressToState(state.id);
	}

	void destroy() {
		Planet@ pl = cast<Planet>(obj);
		if (pl !is null) {
			pl.destroySite(id);
		}
	}

	float get_progress() const {
		return 1.0;
		/*if(player == SERVER_PLAYER)
			return 1.0;
		else if(player.emp is null || !player.emp.valid)
			return 0.0;
		else
			return progresses[player.emp.index];*/
	}

	string get_narrative() const {
		if(get_progress() < 1.f)
			return type.desc;
		else if(state !is null && state.narrative.length > 0)
			return state.narrative;
		else
			return type.narrative;
	}

	uint get_optionCount() const {
		if(get_progress() < 1.f)
			return 0;
		else
			return options.length;
	}

	uint get_option(uint index) {
		if(get_progress() < 1.f || index >= options.length)
			return 0;
		else
			return options[index].id;
	}

	string get_sprite() const {
		if(type is null)
			return "";
		else if(get_progress() >= 1.f && state !is null && state.spriteName.length > 0)
			return state.spriteName;
		else
			return type.spriteName;
	}

	void progressToState(uint stateID) {
		@state = type.states[stateID];
		if(state !is null) {
			for(uint i = 0; i < state.options.length; ++i) {
				auto option = state.options[i];
				if(option.chance < 1.f && randomd() > option.chance)
					continue;
				float chance = state.option_chances[i];
				if(chance < 1.f && randomd() > chance)
					continue;
				options.insertLast(option);
			}
		}
		if(options.length == 0) {
			destroy();
		}
		choiceDelta = true;
	}

	void chooseOption(uint option) {
		Planet@ pl = cast<Planet>(obj);
		if (pl !is null) {
			pl.chooseSiteOption(id, option);
		}
	}

	void choose(uint option, Object@ target = null) {
		if(option >= options.length || get_progress() < 1.f)
			return;

		auto@ opt = options[option];

		options.length = 0;
		opt.choose(this, obj.owner);

		if(options.length == 0) {
			destroy();
		}
		choiceDelta = true;
	}

	void write(Message& msg) {
		msg.writeSmall(id);
		msg.writeSmall(siteTypeId);
		msg.writeSmall(type.id);

		msg.writeSmall(options.length);
		for(uint i = 0, cnt = options.length; i < cnt; ++i)
			msg.writeSmall(options[i].id);

		if(state is null) {
			uint id = uint(-1);
			msg.writeSmall(id);
		}
		else
			msg.writeSmall(state.id);

		msg << obj;
	}

	void read(Message& msg) {
		id = msg.readSmall();
		siteTypeId = msg.readSmall();
		@type = getSiteType(msg.readSmall());

		options.length = msg.readSmall();
		for(uint i = 0, cnt = options.length; i < cnt; ++i) {
			uint id = 0;
			id = msg.readSmall();
			@options[i] = type.options[id % type.options.length];
		}

		uint stateId = 0;
		stateId = msg.readSmall();
		if(stateId < type.states.length)
			@state = type.states[stateId];

		@obj = msg.readObject();
	}

	void save(SaveFile& file) {
		file << id;
		file << siteTypeId;
		file.writeIdentifier(SI_Site, type.id);

		uint cnt = options.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			file.writeIdentifier(SI_SiteOption, options[i].id);
		if(state is null) {
			uint id = uint(-1);
			file << id;
		}
		else
			file << state.id;

		file << obj;
	}

	void load(SaveFile& file) {
		file >> id;
		file >> siteTypeId;
		@type = getSiteType(file.readIdentifier(SI_Site));

		uint cnt = 0;
		file >> cnt;
		options.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			uint id = 0;
			file >> id;
			@options[i] = type.options[id % type.options.length];
		}

		uint stateId = 0;
		file >> stateId;
		if(stateId < type.states.length)
			@state = type.states[stateId];

		@obj = file.readObject();
	}
};

void parseLine(string& line, SiteType@ site, SiteResult@ result, ReadFile@ file) {
	//Try to find the design
	if(line.findFirst("(") == -1) {
		error("Invalid line during " + site.ident+": "+escape(line));
	}
	else {
		if(site.options.length == 0) {
			error("Missing 'Pickup:' line for: "+escape(line));
			return;
		}

		//Hook line
		auto@ hook = cast<ISiteHook>(parseHook(line, "site_effects::", instantiate=false, file=file));
		if(hook !is null) {
			if(result !is null)
				result.hooks.insertLast(hook);
			else
				site.options[site.options.length-1].hooks.insertLast(hook);
		}
	}
}

void loadSite(const string& filename) {
	ReadFile file(filename, true);

	string key, value;
	SiteType@ site;
	SiteOption@ opt;
	SiteState@ state;
	SiteResult@ result;

	uint index = 0;
	while(file++) {
		key = file.key;
		value = file.value;

		if(file.fullLine) {
			if(site is null) {
				error("Missing 'Site: ID' line in " + filename);
				continue;
			}
			if(opt is null) {
				error("Missing 'Option: ID' line in " + filename);
				continue;
			}

			string line = file.line;
			parseLine(line, site, result, file);
		}
		else if(key == "Site") {
			if(site !is null)
				addSiteType(site);
			@state = null;
			@opt = null;
			@result = null;
			if (key == "Site")
				@site = SiteType();
			site.ident = value;
			if(site.ident.length == 0)
				site.ident = filename+"__"+index;

			@opt = null;
			++index;
		}
		else if(site is null) {
			error("Missing 'Site: ID' line in " + filename);
		}
		else if(key == "Name") {
			site.name = localize(value);
		}
		else if(key == "Scan Time") {
			site.scanTime = toDouble(value);
		}
		else if(key == "Unique") {
			site.unique = toBool(value);
		}
		else if(key == "Model") {
			if(state !is null)
				state.modelName = value;
			else
				site.modelName = value;
		}
		else if(key == "Material") {
			if(state !is null)
				state.matName = value;
			else
				site.matName = value;
		}
		else if(key == "Sprite") {
			if(state !is null)
				state.spriteName = value;
			else
				site.spriteName = value;
		}
		else if(key == "Description") {
			if(site.desc.length == 0)
				site.desc = localize(value);
			else if(opt !is null)
				opt.desc = localize(value);
			else
				error("Duplicate Description for " + site.ident + ". Missing Option line?");
		}
		else if(key == "Blurb") {
			if(opt !is null)
				opt.blurb = localize(value);
		}
		else if(key == "Narrative") {
			if(state !is null)
				state.narrative = localize(value);
			else
				site.narrative = localize(value);
		}
		else if(key == "Frequency") {
			if(state !is null)
				state.frequency = toDouble(value);
			else
				site.frequency = toDouble(value);
		}
		else if(key == "Icon") {
			if(opt !is null)
				opt.icon = getSprite(value);
			else
				file.error("Icon outside option block.");
		}
		else if(key == "Option") {
			@state = null;
			@result = null;
			@opt = SiteOption();
			opt.id = site.options.length;
			opt.ident = value;
			if(opt.ident.length == 0)
				opt.ident = site.ident + "__opt__" + site.options.length;

			site.options.insertLast(opt);
		}
		else if(key == "Safe") {
			if(opt !is null)
				opt.isSafe = toBool(value);
		}
		else if(key == "State") {
			@opt = null;
			@result = null;
			@state = SiteState();
			state.id = site.states.length;
			state.ident = value;
			state.modelName = site.modelName;
			state.matName = site.matName;
			state.spriteName = site.spriteName;
			if(state.ident.length == 0)
				state.ident = site.ident+"__state__"+site.states.length;
			site.states.insertLast(state);
		}
		else if(key == "Result") {
			if(opt is null) {
				file.error("Result outside option block.");
				continue;
			}
			@state = null;
			@result = SiteResult();
			if(value.length == 0)
				result.chance = 1.0;
			else
				result.chance = toDouble(value);

			opt.resultTotal += result.chance;
			opt.results.insertLast(result);
		}
		else if(key == "Chance") {
			if(opt is null) {
				file.error("Chance outside option block.");
				continue;
			}
			double chance = 0.0;
			if(value.findFirst("%") == -1)
				chance = toDouble(value);
			else
				chance = toDouble(value) / 100.0;
			opt.chance = chance;
		}
		else if(key == "Choice") {
			if(state is null) {
				file.error("Choice outside state block.");
				continue;
			}

			int pos = value.findFirst("=");
			if(pos == -1) {
				state.def_options.insertLast(value);
				state.option_chances.insertLast(1.0);
			}
			else {
				state.def_options.insertLast(value.substr(0, pos).trimmed());
				state.option_chances.insertLast(toDouble(value.substr(pos+1)) / 100.0);
			}
		}
		else {
			string line = file.line;
			parseLine(line, site, result, file);
		}
	}

	if(site !is null)
		addSiteType(site);
}

void preInit() {
	//Initialize lists
	@homeworldSiteTypes = SiteTypeList();
	@terrestrialSiteTypes = SiteTypeList();
	//Load site types
	FileList list("data/sites", "*.txt", true);
	for(uint i = 0, cnt = list.length; i < cnt; ++i)
		loadSite(list.path[i]);
}

void init() {
	auto@ list = siteTypes;
	for(uint i = 0, cnt = list.length; i < cnt; ++i) {
		auto@ type = list[i];
		type.stateTotal = 0;
		for(uint o = 0, ocnt = type.options.length; o < ocnt; ++o) {
			auto@ opt = type.options[o];
			for(uint n = 0, ncnt = opt.hooks.length; n < ncnt; ++n) {
				if(!cast<Hook>(opt.hooks[n]).instantiate())
					error("Could not instantiate hook: "+addrstr(opt.hooks[n])+" in "+type.ident);
				opt.hooks[n].init(type);
			}
			for(uint n = 0, ncnt = opt.results.length; n < ncnt; ++n) {
				auto@ res = opt.results[n];
				for(uint j = 0, jcnt = res.hooks.length; j < jcnt; ++j) {
					if(!cast<Hook>(res.hooks[j]).instantiate())
						error("Could not instantiate hook: "+addrstr(res.hooks[j])+" in "+type.ident);
					res.hooks[j].init(type);
				}
			}
		}
		for(uint o = 0, ocnt = type.states.length; o < ocnt; ++o) {
			auto@ state = type.states[o];
			type.stateTotal += state.frequency;
			for(uint n = 0, ncnt = state.def_options.length; n < ncnt; ++n) {
				auto@ opt = type.getOption(state.def_options[n]);
				if(opt !is null)
					state.options.insertLast(opt);
				else
					error("Could not find option: "+state.def_options[n]);
			}
		}
	}
}

SiteType@[] siteTypes;
dictionary idents;
SiteTypeList@ homeworldSiteTypes;
SiteTypeList@ terrestrialSiteTypes;

SiteTypeList@ getSiteTypes(SiteKind kind) {
	switch (kind) {
		case SK_HomeworldSite:
			return homeworldSiteTypes;
		case SK_TerrestrialSite:
			return terrestrialSiteTypes;
		default: error("Undefined site kind");
	}
	return terrestrialSiteTypes;
}

const SiteType@ getSiteType(uint id) {
	if(id >= siteTypes.length)
		return null;
	return siteTypes[id];
}

const SiteType@ getSiteType(const string& ident) {
	SiteType@ site;
	if(idents.get(ident, @site))
		return site;
	return null;
}

uint getSiteTypeCount() {
	return getSiteTypeCount(terrestrialSiteTypes);
}

uint getSiteTypeCount(SiteTypeList& list) {
	return list.types.length;
}

const SiteType@ getDistributedSiteType() {
	return getDistributedSiteType(terrestrialSiteTypes);
}

const SiteType@ getDistributedSiteType(SiteTypeList& list) {
	double num = randomd(0, list.totalFrequency);
	for(uint i = 0, cnt = list.types.length; i < cnt; ++i) {
		auto@ type = list.types[i];
		double freq = type.frequency;
		if(num <= freq) {
			if(type.unique) {
				list.totalFrequency -= type.frequency;
				type.frequency = 0;
			}
			return type;
		}
		num -= freq;
	}
	return list.types[list.types.length-1];
}

void addSiteType(SiteType@ type) {
	type.id = siteTypes.length;
	siteTypes.insertLast(type);
	idents.set(type.ident, @type);

	terrestrialSiteTypes.add(type);
	//print("add " + type.id + " name = " + type.name + " length = " + siteTypes.length);
}

void saveIdentifiers(SaveFile& file) {
	for(uint i = 0, cnt = siteTypes.length; i < cnt; ++i) {
		auto type = siteTypes[i];
		file.addIdentifier(SI_Site, type.id, type.ident);
	}
}

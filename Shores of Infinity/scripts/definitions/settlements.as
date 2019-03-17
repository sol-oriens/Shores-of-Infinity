#priority init 2000
import saving;
import hooks;
import util.formatting;

from statuses import getStatusID;
from traits import getTraitID;

const string VeryPositive = "Very Positive";
const string Positive = "Positive";
const string None = "None";
const string Negative = "Negative";
const string VeryNegative = "Very Negative";

enum SettlementMorale {
  SM_Low,
  SM_Medium,
  SM_High,
};

abstract class MoraleModifier {
  int moraleEffect = 0;
  
  string getMoraleEffect() {
    string value;
    switch (moraleEffect) {
      case 2:
        value = VeryPositive;
        break;
      case 1:
        value = Positive;
        break;
      case -1:
        value = Negative;
        break;
      case -2:
        value = VeryNegative;
        break;
      default:
        value = None;
        break;
    }
    toLowercase(value);
    return value;
  }
  
  void setMoraleEffect(string value) {
    if (value == VeryPositive)
      moraleEffect = 2;
    else if (value == Positive)
      moraleEffect = 1;
    else if (value == Negative)
      moraleEffect = -1;
    else if (value == VeryNegative)
      moraleEffect = -2;
    else
      moraleEffect = 0;
  }
};

tidy final class SettlementFocusType : MoraleModifier {
  string ident, name = locale::FOCUS_BASIC;
  uint id;
  uint priority = 0;
  array<ISettlementHook@> hooks;
  array<Hook@> ai;
  
  bool canEnable(Object& obj) const {
		for(uint i = 0, cnt = hooks.length; i < cnt; ++i) {
			if(!hooks[i].canEnable(obj))
				return false;
		}
		return true;
	}
  
  int opCmp(const SettlementFocusType@ other) const {
		if(priority < other.priority)
			return -1;
		if(priority > other.priority)
			return 1;
		return 0;
	}
};

tidy final class CivilActType : MoraleModifier {
  string ident, name = "", description, category;
  uint id;
  
  int maintainCost = 0;
  array<ISettlementHook@> hooks;
  array<Hook@> ai;
  
  string formatTooltip() const {
		string tt;
		tt += format("[font=Medium][b]$1[/b][/font]\n", name);
		tt += description;
    tt += format("[nl/]\n" + locale::TT_MORALE_EFFECT + ": [b]$1[/b]", getMoraleEffect());

		return tt;
	}
  
  bool canEnable(Object& obj) const {
    for(uint i = 0, cnt = hooks.length; i < cnt; ++i) {
      if(!hooks[i].canEnable(obj))
      return false;
    }
    return true;
  }
};

interface ISettlementHook {
  bool canEnable(Object& obj) const;
  void enable(Object& obj, any@ data) const;
  void disable(Object& obj, any@ data) const;
  void tick(Object& obj, any@ data, double time) const;
  void save(any@ data, SaveFile& file) const;
	void load(any@ data, SaveFile& file) const;
};

tidy class SettlementHook : Hook, ISettlementHook {
  bool canEnable(Object& obj) const { return true; }
  void enable(Object& obj, any@ data) const {}
  void disable(Object& obj, any@ data) const {}
  void tick(Object& obj, any@ data, double time) const {}
  void save(any@ data, SaveFile& file) const {}
	void load(any@ data, SaveFile& file) const {}
};

tidy final class SettlementFocus : Savable {
  const SettlementFocusType@ type;
  array<any> data;
  
  SettlementFocus() {
  }
  
  SettlementFocus(const SettlementFocusType@ type) {
    @this.type = type;
    data.length = type.hooks.length;
  }
  
  void enable(Object& obj) {
    for(uint i = 0, cnt = type.hooks.length; i < cnt; ++i)
			type.hooks[i].enable(obj, data[i]);
  }
  
  void disable(Object& obj) {
    for(uint i = 0, cnt = type.hooks.length; i < cnt; ++i)
			type.hooks[i].disable(obj, data[i]);
  }
  
  void tick(Object& obj, double time) {
    for(uint i = 0, cnt = type.hooks.length; i < cnt; ++i)
			type.hooks[i].tick(obj, data[i], time);
  }
  
  void save(SaveFile& file) {
    file.writeIdentifier(SI_SettlementFocus, type.id);
    for(uint i = 0, cnt = type.hooks.length; i < cnt; ++i)
      type.hooks[i].save(data[i], file);
  }
  
  void load(SaveFile& file) {
    @type = getSettlementFocusType(file.readIdentifier(SI_SettlementFocus));
    data.length = type.hooks.length;
    for(uint i = 0, cnt = type.hooks.length; i < cnt; ++i)
      type.hooks[i].load(data[i], file);
  }
};

tidy final class CivilAct : Savable {
  const CivilActType@ type;
  array<any> data;
  
  CivilAct() {
  }
  
  CivilAct(const CivilActType@ type) {
    @this.type = type;
    data.length = type.hooks.length;
  }
  
  void enable(Object& obj) {
    for(uint i = 0, cnt = type.hooks.length; i < cnt; ++i)
			type.hooks[i].enable(obj, data[i]);
  }
  
  void disable(Object& obj) {
    for(uint i = 0, cnt = type.hooks.length; i < cnt; ++i)
			type.hooks[i].disable(obj, data[i]);
  }
  
  void tick(Object& obj, double time) {
    for(uint i = 0, cnt = type.hooks.length; i < cnt; ++i)
			type.hooks[i].tick(obj, data[i], time);
  }
  
  int opCmp(const CivilAct@ other) const {
		if(type.id < other.type.id)
			return -1;
		if(type.id > other.type.id)
			return 1;
		return 0;
	}
  
  void save(SaveFile& file) {
    file.writeIdentifier(SI_CivilAct, type.id);
    for(uint i = 0, cnt = type.hooks.length; i < cnt; ++i)
      type.hooks[i].save(data[i], file);
  }
  
  void load(SaveFile& file) {
    @type = getCivilActType(file.readIdentifier(SI_CivilAct));
    data.length = type.hooks.length;
    for(uint i = 0, cnt = type.hooks.length; i < cnt; ++i)
      type.hooks[i].load(data[i], file);
  }
};

void parseLine(string& line, SettlementFocusType@ type, ReadFile@ file) {
	//Try to find the hook
	if (line.findFirst("(") == -1) {
		error("Invalid line for " + type.ident + ": " + escape(line));
	}
	else {
		//Hook line
		auto@ hook = cast<ISettlementHook>(parseHook(line, "settlement_effects::", instantiate=false, file=file));
		if (hook !is null)
			type.hooks.insertLast(hook);
	}
}

void parseLine(string& line, CivilActType@ type, ReadFile@ file) {
	//Try to find the hook
	if (line.findFirst("(") == -1) {
		error("Invalid line for " + type.ident + ": " + escape(line));
	}
	else {
		//Hook line
		auto@ hook = cast<ISettlementHook>(parseHook(line, "settlement_effects::", instantiate=false, file=file));
		if (hook !is null)
			type.hooks.insertLast(hook);
	}
}

void loadSettlementFoci(const string& filename) {
	ReadFile file(filename, true);

	string key, value;
	SettlementFocusType@ type;

	uint index = 0;
	while(file++) {
		key = file.key;
		value = file.value;

		if(file.fullLine) {
			string line = file.line;
			parseLine(line, type, file);
		}
		else if(key == "SettlementFocus") {
			if(type !is null)
				addSettlementFocusType(type);
			if (key == "SettlementFocus")
				@type = SettlementFocusType();
			type.ident = value;
			if(type.ident.length == 0)
				type.ident = filename + "__" + index;

			++index;
		}
		else if(type is null) {
			error("Missing 'SettlementFocus: ID' line in " + filename);
		}
		else if(key.equals_nocase("Name")) {
			type.name = localize(value);
		}
    else if (key.equals_nocase("Priority")) {
      type.priority = toUInt(value);
    }
    else if (key.equals_nocase("Morale Effect")) {
      type.setMoraleEffect(value);
    }
		else {
			string line = file.line;
			parseLine(line, type, file);
		}
	}

	if(type !is null)
		addSettlementFocusType(type);
}

void loadCivilActs(const string& filename) {
	ReadFile file(filename, true);

	string key, value;
	CivilActType@ type;
  string[] civilActCategories;

	uint index = 0;
	while(file++) {
		key = file.key;
		value = file.value;

		if(file.fullLine) {
			string line = file.line;
			parseLine(line, type, file);
		}
		else if(key == "CivilAct") {
			if(type !is null)
				addCivilActType(type);
			if (key == "CivilAct")
				@type = CivilActType();
			type.ident = value;
			if(type.ident.length == 0)
				type.ident = filename + "__" + index;

			++index;
		}
		else if(type is null) {
			error("Missing 'CivilAct: ID' line in " + filename);
		}
		else if(key.equals_nocase("Name")) {
			type.name = localize(value);
    }
    else if(key.equals_nocase("Description")) {
			type.description = localize(value);
		}
    else if(key.equals_nocase("Category")) {
			type.category = value;
      if (civilActCategories.find(value) != -1)
        civilActCategories.insertLast(value);
		}
    else if (key.equals_nocase("Morale Effect")) {
      type.setMoraleEffect(value);
    }
    else if(key.equals_nocase("Maintenance")) {
			type.maintainCost = toInt(value);
		}
		else {
			string line = file.line;
			parseLine(line, type, file);
		}
	}

	if(type !is null)
		addCivilActType(type);
}

void preInit() {
	FileList focusList("data/settlements/foci", "*.txt", true);
	for(uint i = 0, cnt = focusList.length; i < cnt; ++i)
		loadSettlementFoci(focusList.path[i]);
  FileList civilActList("data/settlements/civil_acts", "*.txt", true);
	for(uint i = 0, cnt = civilActList.length; i < cnt; ++i)
		loadCivilActs(civilActList.path[i]);
}

int shipPopulationStatus = -1;
int mothershipPopulationStatus = -1;
void init() {
  shipPopulationStatus = getStatusID("ShipPopulation");
  mothershipPopulationStatus = getStatusID("MothershipPopulation");
  
	auto@ list = foci;
	for(uint i = 0, cnt = list.length; i < cnt; ++i) {
		auto@ type = list[i];
		for(uint n = 0, ncnt = type.hooks.length; n < ncnt; ++n)
			if(!cast<Hook>(type.hooks[n]).instantiate())
				error("Could not instantiate hook: " + addrstr(type.hooks[n]) + " in " + type.ident);
		for(uint n = 0, ncnt = type.ai.length; n < ncnt; ++n) {
			if(!type.ai[n].instantiate())
				error("Could not instantiate AI hook: " + addrstr(type.ai[n]) + " in settlement focus " + type.ident);
		}
	}
}

SettlementFocusType@[] foci;
CivilActType@[] civilActs;
dictionary focusIdents, civilActIdents;

SettlementFocusType@[] getAvailableFoci(Object& obj) {
  array<SettlementFocusType@> availableFoci;
  SettlementFocusType@ focus;
  
  for (uint i = 0, cnt = foci.length; i < cnt; ++i) {
    @focus = foci[i];
    if (focus.canEnable(obj))
      availableFoci.insertLast(focus);
  }
  //Sort by priority for autoFocus
  availableFoci.sortDesc();
  return availableFoci;
}

CivilActType@[] getAvailableCivilActs(Object& obj) {
  array<CivilActType@> availableCivilActs;
  CivilActType@ civilAct;
  
  for (uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
    @civilAct = civilActs[i];
    if (civilAct.canEnable(obj))
      availableCivilActs.insertLast(civilAct);
  }
  return availableCivilActs;
}

const SettlementFocusType@ getSettlementFocusType(uint id) {
	if(id < foci.length)
		return foci[id];
	else
		return null;
}

const CivilActType@ getCivilActType(uint id) {
	if(id < civilActs.length)
		return civilActs[id];
	else
		return null;
}

void addSettlementFocusType(SettlementFocusType@ focus) {
	focus.id = foci.length;
	foci.insertLast(focus);
	focusIdents.set(focus.ident, @focus);
}

void addCivilActType(CivilActType@ civilAct) {
  civilAct.id = civilActs.length;
  civilActs.insertLast(civilAct);
  civilActIdents.set(civilAct.ident, @civilAct);
}

void saveIdentifiers(SaveFile& file) {
	for(uint i = 0, cnt = foci.length; i < cnt; ++i) {
		auto type = foci[i];
		file.addIdentifier(SI_SettlementFocus, type.id, type.ident);
	}
  for(uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
		auto type = civilActs[i];
		file.addIdentifier(SI_CivilAct, type.id, type.ident);
	}
}

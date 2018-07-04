#priority init 2000
import hooks;

from generic_effects import AddStatus;
from statuses import getStatusID;
from traits import getTraitID;

enum SettlementMorale {
  SM_Low,
  SM_Medium,
  SM_High,
};

tidy final class SettlementFocus {
  string ident, name = locale::FOCUS_BASIC;
  uint id;
  uint unlockType;
  uint unlockId;
  double minPop = 0;
  double maxPop = 0;
  array<ISettlementHook@> hooks;
  array<Hook@> ai;
  
  bool canEnable(Object& obj) const {
		for(uint i = 0, cnt = hooks.length; i < cnt; ++i) {
			if(!hooks[i].canEnable(obj))
				return false;
		}
		return true;
	}
};

interface ISettlementHook {
  void enable(Object& obj, any@ data) const;
  void disable(Object& obj, any@ data) const;
  bool canEnable(Object& obj) const;
};

tidy class SettlementHook : Hook, ISettlementHook {
  void enable(Object& obj, any@ data) const {}
  void disable(Object& obj, any@ data) const {}
  bool canEnable(Object& obj) const { return true; }
};

SettlementFocus@[] getAvailableFoci(Object& obj, Empire@ emp) {
  array<SettlementFocus@> availableFoci;
  SettlementFocus@ focus;
  
  for (uint i = 0, cnt = foci.length; i < cnt; ++i) {
    @focus = foci[i];
    if (focus.canEnable(obj))
      availableFoci.insertLast(focus);
  }
  return availableFoci;
}

void parseLine(string& line, SettlementFocus@ focus, ReadFile@ file) {
	//Try to find the hook
	if(line.findFirst("(") == -1) {
		error("Invalid line for " + focus.ident +": "+ escape(line));
	}
	else {
		//Hook line
		auto@ hook = cast<ISettlementHook>(parseHook(line, "settlement_effects::", instantiate=false, file=file));
		if(hook !is null) {
			if(focus !is null)
				focus.hooks.insertLast(hook);
		}
	}
}

void loadSettlementFocus(const string& filename) {
	ReadFile file(filename, true);

	string key, value;
	SettlementFocus@ focus;

	uint index = 0;
	while(file++) {
		key = file.key;
		value = file.value;

		if(file.fullLine) {
			string line = file.line;
			parseLine(line, focus, file);
		}
		else if(key == "SettlementFocus") {
			if(focus !is null)
				addSettlementFocus(focus);
			if (key == "SettlementFocus")
				@focus = SettlementFocus();
			focus.ident = value;
			if(focus.ident.length == 0)
				focus.ident = filename + "__" + index;

			++index;
		}
		else if(focus is null) {
			error("Missing 'SettlementFocus: ID' line in " + filename);
		}
		else if(key.equals_nocase("Name")) {
			focus.name = localize(value);
		}
		else {
			string line = file.line;
			parseLine(line, focus, file);
		}
	}

	if(focus !is null)
		addSettlementFocus(focus);
}

void preInit() {
	FileList list("data/settlements/foci", "*.txt", true);
	for(uint i = 0, cnt = list.length; i < cnt; ++i)
		loadSettlementFocus(list.path[i]);
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
				error("Could not instantiate hook: "+addrstr(type.hooks[n])+" in "+type.ident);
		for(uint n = 0, ncnt = type.ai.length; n < ncnt; ++n) {
			if(!type.ai[n].instantiate())
				error("Could not instantiate AI hook: "+addrstr(type.ai[n])+" in settlement focus "+type.ident);
		}
	}
}

SettlementFocus@[] foci;
dictionary idents;

void addSettlementFocus(SettlementFocus@ focus) {
	focus.id = foci.length;
	foci.insertLast(focus);
	idents.set(focus.ident, @focus);
}

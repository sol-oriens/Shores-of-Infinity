import hooks;
from requirement_effects import Requirement;
from settlements import shipPopulationStatus, mothershipPopulationStatus;
import resources;

class RequireNativeResource : Requirement {
	Document doc("This can only work if the planet has a particular resource.");
	Argument resource(AT_PlanetResource, doc="Resource to require.");
	Argument primary(AT_Boolean, "True", doc="Whether the resource must be the primary resource.");
	Argument hide(AT_Boolean, "True", doc="Hide when unavailable.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if(ignoreState && !hide.boolean)
			return true;
		if(!obj.hasResources)
			return false;
		if (primary.boolean)
			return obj.primaryResourceType == uint(resource.integer);
		else {
			for(uint i = 0, cnt = obj.nativeResourceCount; i < cnt; ++i) {
				if(obj.nativeResourceType[i] == uint(resource.integer))
					return true;
			}
			return false;
		}
	}
};

class ConflictNativeResource : Requirement {
	Document doc("This can only work if the planet has a different resource than a particular resource.");
	Argument resource(AT_PlanetResource, doc="Resource to conflict with.");
	Argument hide(AT_Boolean, "True", doc="Hide when unavailable.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if(ignoreState && !hide.boolean)
			return true;
		if(!obj.hasResources)
			return false;
		return obj.primaryResourceType != uint(resource.integer);
	}
};

class RequirePopulation : Requirement {
	Document doc("This can only work if the object has a certain amount of population.");
	Argument min_population(AT_Decimal, "1", doc="Minimum population needed.");
	Argument max_population(AT_Decimal, "-1", doc="Maximum population needed. -1 for no maximum");

	bool meets(Object& obj, bool ignoreState = false) const override {
		double minPop = min_population.decimal;
		double maxPop = max_population.decimal;
		if (obj.hasSurfaceComponent)
			return obj.population >= minPop - 0.0001 && (maxPop == -1 || obj.population <= maxPop);
		else if (obj.hasStatuses) {
			int shipPop = obj.getStatusStackCountAny(shipPopulationStatus);
			int mothershipPop = obj.getStatusStackCountAny(mothershipPopulationStatus);
			return (shipPop >= minPop || mothershipPop >= minPop) && (maxPop == -1 || shipPop <= maxPop || mothershipPop <= maxPop);
		}
		return false;
	}
};

import hooks;
from requirement_effects import Requirement;
from statuses import getStatusID;
import resources;

class RequireNativeResource : Requirement {
	Document doc("This can only work if the planet has a particular resource.");
	Argument resource(AT_Custom, doc="Resource to require.");
	Argument hide(AT_Boolean, "True", doc="Hide when unavailable.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if(ignoreState && !hide.boolean)
			return true;
		if(!obj.hasResources)
			return false;
		auto@ res = getResource(obj.primaryResourceType);
		if(res is null)
			return false;
		return res.ident.equals_nocase(resource.str);
	}
};

class ConflictNativeResource : Requirement {
	Document doc("This can only work if the planet has a different resource than a particular resource.");
	Argument resource(AT_Custom, doc="Resource to conflict with.");
	Argument hide(AT_Boolean, "True", doc="Hide when unavailable.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if(ignoreState && !hide.boolean)
			return true;
		if(!obj.hasResources)
			return false;
		auto@ res = getResource(obj.primaryResourceType);
		if(res is null)
			return false;
		return !res.ident.equals_nocase(resource.str);
	}
};

class RequirePopulation : Requirement {
	Document doc("This can only work if the object has a certain amount of population.");
	Argument population(AT_Decimal, "1", doc="Minimum population needed.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if (obj.hasSurfaceComponent)
			return obj.population >= population.decimal - 0.0001;
		else if (obj.hasStatuses)
			return obj.getStatusStackCountAny(getStatusID("ShipPopulation")) > 1 || obj.getStatusStackCountAny(getStatusID("MothershipPopulation")) > 1;
		return false;
	}
};

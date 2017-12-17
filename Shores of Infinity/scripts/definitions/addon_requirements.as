import hooks;
from requirement_effects import Requirement;
import resources;

class RequireNativeResource : Requirement {
	Document doc("This can only work if the planet has a particular resource.");
	Argument resource(AT_Custom, doc="Resource to require.");
	Argument hide(AT_Boolean, "True", doc="Hide when unavailable.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if(ignoreState && !hide.boolean)
			return true;
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
		auto@ res = getResource(obj.primaryResourceType);
		if(res is null)
			return false;
		return !res.ident.equals_nocase(resource.str);
	}
};

import hooks;
from consume_effects import ConsumeEffect;
import icons;

class ConsumeResearchStatusCount : ConsumeEffect {
	Document doc("Requires a payment of Research to build this construction, based on the amount of stacks of a status present.");
	Argument status(AT_Status, doc="Status to count.");
	Argument base_cost("Base Amount", AT_Integer, "0", doc="Research Cost.");
	Argument cost("Amount", AT_Integer, doc="Research Cost.");

	bool canConsume(Object& obj, const Targets@ targs, bool ignoreCost) const {
		if(ignoreCost)
			return true;
		return obj.owner.ResearchPoints >= get(obj);
	}

	int get(Object& obj) const {
		return base_cost.integer + cost.integer * obj.getStatusStackCountAny(status.integer);
	}

	bool formatCost(Object& obj, const Targets@ targs, string& value) const {
		value = toString(get(obj), 0)+" "+locale::RESOURCE_RESEARCH;
		return true;
	}

	bool getCost(Object& obj, string& value, Sprite& icon) const {
		value = standardize(get(obj), true);
		icon = icons::Research;
		return true;
	}

	bool getVariable(Object& obj, Sprite& sprt, string& name, string& value, Color& color) const {
		value = standardize(get(obj), true);
		sprt = icons::Research;
		name = locale::RESOURCE_RESEARCH + " "+locale::COST;
		color = colors::Research;
		return true;
	}

#section server
	bool consume(Object& obj, const Targets@ targs) const override {
		if(!obj.owner.consumeResearchPoints(get(obj)))
			return false;
		return true;
	}

	void reverse(Object& obj, const Targets@ targs, bool cancel) const override {
		obj.owner.freeResearchPoints(get(obj));
	}
#section all
};

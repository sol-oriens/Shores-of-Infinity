import hooks;
import statuses;
from statuses import StatusHook;
from resources import MoneyType;

class BudgetMaintenance : StatusHook {
	Document doc("This status requires a maintenance cost.");
	Argument amount(AT_Decimal, "0", doc="Base amount of money it costs.");
	Argument per_shipsize(AT_Decimal, "0", doc="When on a ship, increase maintenance cost by the ship design size multiplied by this.");

#section server
  void onAddStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) {
		double amt = amount.decimal;
		if(per_shipsize.decimal != 0 && obj.isShip)
			amt += cast<Ship>(obj).blueprint.design.size * per_shipsize.decimal;

		if(obj.owner !is null)
			obj.owner.modMaintenance(amt, MoT_Colonizers);
		data.store(amt);
	}

  void onRemoveStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) {
		double amt = 0;
		data.retrieve(amt);

		if(obj.owner !is null)
			obj.owner.modMaintenance(-amt, MoT_Colonizers);
	}

	bool onOwnerChange(Object& obj, Status@ status, any@ data, Empire@ prevOwner, Empire@ newOwner) override {
		double amt = 0;
		data.retrieve(amt);
		if(prevOwner !is null)
			prevOwner.modMaintenance(-amt, MoT_Colonizers);
		if(newOwner !is null)
			newOwner.modMaintenance(amt, MoT_Colonizers);
		return true;
	}

	void save(Status@ status, any@ data, SaveFile& file) override {
		double amt = 0;
		data.retrieve(amt);
		file << amt;
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		double amt = 0;
		file >> amt;
		data.store(amt);
	}
#section all
};

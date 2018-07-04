import hooks;
import statuses;
from statuses import StatusHook;
from resources import MoneyType;

class BudgetMaintenanceData {
	double amount;
	int type;
};

class BudgetMaintenance : StatusHook {
	Document doc("This status requires a maintenance cost.");
	Argument amount(AT_Decimal, "0", doc="Base amount of money it costs.");
	Argument type(AT_Custom, doc="Maintenance type. Supported types : Buildings, Colonizers, Planet Upkeep");
	Argument per_shipsize(AT_Decimal, "0", doc="When on a ship, increase maintenance cost by the ship design size multiplied by this.");

#section server
	void onCreate(Object& obj, Status@ status, any@ data) {
		BudgetMaintenanceData@ maintData = BudgetMaintenanceData();

		maintData.amount = amount.decimal;
		if(per_shipsize.decimal != 0 && obj.isShip)
			maintData.amount += cast<Ship>(obj).blueprint.design.size * per_shipsize.decimal;

		if (type.str.equals_nocase("Buildings"))
			maintData.type = int(MoT_Buildings);
		else if (type.str.equals_nocase("Colonizers"))
			maintData.type = int(MoT_Colonizers);
		else if (type.str.equals_nocase("Planet Upkeep"))
			maintData.type = int(MoT_Planet_Upkeep);
		else
			error("BudgetMaintenance: Invalid maintenance type specified.");

		data.store(@maintData);
	}

  void onAddStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) {
		BudgetMaintenanceData@ maintData;
    data.retrieve(@maintData);

		if(obj.owner !is null)
			obj.owner.modMaintenance(maintData.amount, maintData.type);
		data.store(@maintData);
	}

  void onRemoveStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) {
		BudgetMaintenanceData@ maintData;
		data.retrieve(@maintData);

		if(obj.owner !is null)
			obj.owner.modMaintenance(-maintData.amount, maintData.type);
	}

	bool onOwnerChange(Object& obj, Status@ status, any@ data, Empire@ prevOwner, Empire@ newOwner) override {
		BudgetMaintenanceData@ maintData;
		data.retrieve(@maintData);
		if(prevOwner !is null)
			prevOwner.modMaintenance(-maintData.amount, maintData.type);
		if(newOwner !is null)
			newOwner.modMaintenance(maintData.amount, maintData.type);
		return true;
	}

	void save(Status@ status, any@ data, SaveFile& file) override {
		BudgetMaintenanceData@ maintData;
		data.retrieve(@maintData);
		file << maintData.amount;
		file << maintData.type;
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		BudgetMaintenanceData@ maintData = BudgetMaintenanceData();
		file >> maintData.amount;
		file >> maintData.type;
		data.store(@maintData);
	}
#section all
};

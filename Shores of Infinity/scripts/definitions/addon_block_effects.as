import hooks;
from block_effects import BlockEffect;

class ActiveConfigOption : BlockEffect {
	Document doc("Inner hooks in this block are exectuted only if a config option has a particular value.");
	Argument option(AT_Custom, doc="Config option to check.");
	Argument value(AT_Decimal, "1.0", doc="Value for the option to check for.");

	bool prepare(Argument@& dat) const override {
		return config::get(option.str) == value.decimal;
	}

	bool feed(Argument@& dat, Hook@& hook, uint& num) const override {
		if (num < inner.length) {
			@hook = inner[num];
			num += 1;
			return true;
		}
		return false;
	}
};

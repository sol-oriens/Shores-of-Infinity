import hooks;
from block_effects import BlockEffect;

class QuickStartOption : BlockEffect {
	Document doc("Inner hooks in this block are exectuted only if the player selected the Quick Start game option.");
	bool prepare(Argument@& dat) const override {
		if (config::QUICK_START == 0)
			return false;
		return true;
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

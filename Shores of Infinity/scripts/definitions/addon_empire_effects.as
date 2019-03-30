import generic_hooks;
import settlements;

class ModGlobalMorale : EmpireEffect, TriggerableGeneric {
	Document doc("Modifies the morale of all settlements owned by this effect's owner.");
	Argument amount(AT_Decimal, doc="How much to add or subtract from the morale value.");
	Argument descriptor(AT_Custom, doc=
		"Descriptor of morale modifier. Can be VeryPositive, Positive, Negative or VeryNegative" +
		"This effect is ten times less effective than local morale modifiers and globally capped.");

		int value = 0;

		bool instantiate() override {
			value = GlobalMoraleEffect(descriptor.str).stat;
			return true;
		}

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.GlobalMorale = clamp(owner.GlobalMorale.value + amount.decimal, -1.0, 1.0);
	}

	void disable(Empire& owner, any@ data) const override {
		owner.GlobalMorale -= clamp(owner.GlobalMorale.value + amount.decimal, -1.0, 1.0);
	}
#section all
};

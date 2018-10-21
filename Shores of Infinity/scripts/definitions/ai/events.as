from orbitals import OrbitalModule;

//Event callbacks definitions

funcdef void OwnedSystemAdded(ref& sender, EventArgs& args);
funcdef void OwnedSystemRemoved(ref& sender, EventArgs& args);
funcdef void BorderSystemAdded(ref& sender, EventArgs& args);
funcdef void BorderSystemRemoved(ref& sender, EventArgs& args);
funcdef void OutsideBorderSystemAdded(ref& sender, EventArgs& args);
funcdef void OutsideBorderSystemRemoved(ref& sender, EventArgs& args);
funcdef void PlanetAdded(ref& sender, EventArgs& args);
funcdef void PlanetRemoved(ref& sender, EventArgs& args);
funcdef void TradeRouteNeeded(ref& sender, EventArgs& args);
funcdef void OrbitalRequested(ref& sender, EventArgs& args);

//Event interfaces

interface IOwnedSystemEvents {
	void onOwnedSystemAdded(ref& sender, EventArgs& args);
	void onOwnedSystemRemoved(ref& sender, EventArgs& args);
};

interface IBorderSystemEvents {
	void onBorderSystemAdded(ref& sender, EventArgs& args);
	void onBorderSystemRemoved(ref& sender, EventArgs& args);
};

interface IOutsideBorderSystemEvents {
	void onOutsideBorderSystemAdded(ref& sender, EventArgs& args);
	void onOutsideBorderSystemRemoved(ref& sender, EventArgs& args);
};

interface IPlanetEvents {
	void onPlanetAdded(ref& sender, EventArgs& args);
	void onPlanetRemoved(ref& sender, EventArgs& args);
};

interface ITradeRouteNeededEvents {
  void onTradeRouteNeeded(ref& sender, EventArgs& args);
};

interface IOrbitalRequestEvents {
	void onOrbitalRequested(ref& sender, EventArgs& args);
};

// Generic type for event arguments

class EventArgs {
  
};

// Specialized event arguments

class TradeRouteNeededEventArgs : EventArgs {
  Territory@ territory1;
  Territory@ territory2;
};

class OrbitalRequestedEventArgs : EventArgs {
  Region@ region;
  const OrbitalModule@ module;
  double priority;
  double expire;
  uint moneyType;
};

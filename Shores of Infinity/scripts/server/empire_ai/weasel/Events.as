// Events
// ------
// Notifies subscribed components of events raised by other components.
//
import empire_ai.weasel.WeaselAI;

import ai.events;

final class Events : AIComponent {
  //Event callbacks
  array<OwnedSystemAdded@> onOwnedSystemAdded;
	array<OwnedSystemRemoved@> onOwnedSystemRemoved;
	array<BorderSystemAdded@> onBorderSystemAdded;
	array<BorderSystemRemoved@> onBorderSystemRemoved;
	array<OutsideBorderSystemAdded@> onOutsideBorderSystemAdded;
	array<OutsideBorderSystemRemoved@> onOutsideBorderSystemRemoved;
  array<PlanetAdded@> onPlanetAdded;
	array<PlanetRemoved@> onPlanetRemoved;
  array<TradeRouteNeeded@> onTradeRouteNeeded;
  array<OrbitalRequested@> onOrbitalRequested;
  
  //Event delegate registration
  void registerOwnedSystemEvents(IOwnedSystemEvents& events) {
		onOwnedSystemAdded.insertLast(OwnedSystemAdded(events.onOwnedSystemAdded));
		onOwnedSystemRemoved.insertLast(OwnedSystemRemoved(events.onOwnedSystemRemoved));
	}

	void registerBorderSystemEvents(IBorderSystemEvents& events) {
		onBorderSystemAdded.insertLast(BorderSystemAdded(events.onBorderSystemAdded));
		onBorderSystemRemoved.insertLast(BorderSystemRemoved(events.onBorderSystemRemoved));
	}

	void registerOutsideBorderSystemEvents(IOutsideBorderSystemEvents& events) {
		onOutsideBorderSystemAdded.insertLast(OutsideBorderSystemAdded(events.onOutsideBorderSystemAdded));
		onOutsideBorderSystemRemoved.insertLast(OutsideBorderSystemRemoved(events.onOutsideBorderSystemRemoved));
	}
  
  void registerPlanetEvents(IPlanetEvents& events) {
			onPlanetAdded.insertLast(PlanetAdded(events.onPlanetAdded));
			onPlanetRemoved.insertLast(PlanetRemoved(events.onPlanetRemoved));
	}
  
  void registerOrbitalRequestEvents(IOrbitalRequestEvents& events) {
		onOrbitalRequested.insertLast(OrbitalRequested(events.onOrbitalRequested));
	}
  
  //Event notifications
  void notifyOwnedSystemAdded(ref@ sender, EventArgs& args) {
		for (uint i = 0, cnt = onOwnedSystemAdded.length; i < cnt; ++i)
			onOwnedSystemAdded[i](sender, args);
	}

	void notifyOwnedSystemRemoved(ref@ sender, EventArgs& args) {
		for (uint i = 0, cnt = onOwnedSystemRemoved.length; i < cnt; ++i)
			onOwnedSystemRemoved[i](sender, args);
	}

	void notifyBorderSystemAdded(ref@ sender, EventArgs& args) {
		for (uint i = 0, cnt = onBorderSystemAdded.length; i < cnt; ++i)
			onBorderSystemAdded[i](sender, args);
	}

	void notifyBorderSystemRemoved(ref@ sender, EventArgs& args) {
		for (uint i = 0, cnt = onBorderSystemRemoved.length; i < cnt; ++i)
			onBorderSystemRemoved[i](sender, args);
	}

	void notifyOutsideBorderSystemAdded(ref@ sender, EventArgs& args) {
		for (uint i = 0, cnt = onOutsideBorderSystemAdded.length; i < cnt; ++i)
			onOutsideBorderSystemAdded[i](sender, args);
	}

	void notifyOutsideBorderSystemRemoved(ref@ sender, EventArgs& args) {
		for (uint i = 0, cnt = onOutsideBorderSystemRemoved.length; i < cnt; ++i)
			onOutsideBorderSystemRemoved[i](sender, args);
	}
  
  void notifyPlanetAdded(ref@ sender, EventArgs& args) {
		for (uint i = 0, cnt = onPlanetAdded.length; i < cnt; ++i)
			onPlanetAdded[i](sender, args);
	}

	void notifyPlanetRemoved(ref@ sender, EventArgs& args) {
		for (uint i = 0, cnt = onPlanetRemoved.length; i < cnt; ++i)
			onPlanetRemoved[i](sender, args);
	}
  
  void notifyTradeRouteNeeded(ref@ sender, EventArgs& args) {
    for (uint i = 0, cnt = onTradeRouteNeeded.length; i < cnt; ++i) {
      onTradeRouteNeeded[i](sender, args);
    }
  }
  
  void notifyOrbitalRequested(ref@ sender, EventArgs& args) {
		for (uint i = 0, cnt = onOrbitalRequested.length; i < cnt; ++i)
			onOrbitalRequested[i](sender, args);
	}
  
  void create() {
  }
  
  void save(SaveFile& file) {
  }
  
  void load(SaveFile& file) {
  }
};

AIComponent@ createEvents() {
	return Events();
}

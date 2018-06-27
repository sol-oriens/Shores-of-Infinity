#priority init 2000

from traits import getTraitID;

enum SettlementMorale {
  SM_Low,
  SM_Medium,
  SM_High,
};

enum SettlementFocusId {
  SFID_Basic,             //Default
  SFID_Money,             //Capitalism government
  SFID_MoneyExtreme,      //Capitalism government
  SFID_Influence,         //Theocracy governement
  SFID_InfluenceExtreme,  //Theocracy governement
  SFID_Defense,           //Empire government
  SFID_DefenseExtreme,    //Empire government
  SFID_Labor,             //Communism government
  SFID_LaborExtreme,      //Communism government
};

tidy final class SettlementFocus {
  
  SettlementFocus(SettlementFocusId id, string name) {
    this.id = id;
    this.name = name;
  }
  
  uint id;
  string name;
};

SettlementFocus@[] getAvailableFoci(const Object& obj, const Empire& emp) {
  array<SettlementFocus@> foci;
  SettlementFocus@ focus;
  
  if (obj.isPlanet) {
    auto@ pl = cast<Planet>(obj);
    if (pl.level <= 1) {
      @focus = SettlementFocus(SFID_Basic, locale::FOCUS_BASIC);
      foci.insertLast(focus);
    }
  }
  else if (obj.isShip) {
    @focus = SettlementFocus(SFID_Basic, locale::FOCUS_BASIC);
    foci.insertLast(focus);
  }
  if (emp.hasTrait(getTraitID("Capitalism"))) {
    @focus = SettlementFocus(SFID_Money, locale::FOCUS_MONEY);
    foci.insertLast(focus);
  }
  else if (emp.hasTrait(getTraitID("Theocracy"))) {
    @focus = SettlementFocus(SFID_Influence, locale::FOCUS_INFLUENCE);
    foci.insertLast(focus);
  }
  else if (emp.hasTrait(getTraitID("Empire"))) {
    @focus = SettlementFocus(SFID_Defense, locale::FOCUS_DEFENSE);
    foci.insertLast(focus);
  }
  else if (emp.hasTrait(getTraitID("Communism"))) {
    @focus = SettlementFocus(SFID_Labor, locale::FOCUS_LABOR);
    foci.insertLast(focus);
  }
  
  return foci;
}

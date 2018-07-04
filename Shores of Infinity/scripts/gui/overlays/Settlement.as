import elements.BaseGuiElement;
import elements.GuiSkinElement;
import elements.GuiText;
import elements.GuiSprite;
import elements.GuiButton;
import elements.GuiDropdown;
import elements.GuiOverlay;
import elements.GuiPanel;
import settlements;

from gui import animate_time;

const double ANIM1_TIME = 0.15;
const double ANIM2_TIME = 0.001;

interface SettlementParent : IGuiElement {
	void close();
	Object@ get_object();
	void triggerUpdate();
};

class SettlementOverlay : GuiOverlay, SettlementParent {
  Object@ obj;
	SettlementDisplay@ settlement;
  
  SettlementOverlay(IGuiElement@ parent, Object@ obj) {
    @this.obj = obj;
		super(parent);
		
		@settlement = SettlementDisplay(this, vec2i(parent.size.width/2, parent.size.height),
					Alignment(Right-0.5f-250, Top+20, Right-0.5f+250, Bottom-20));
		settlement.animate(ANIM1_TIME);
  }
  
  bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Confirmed:
				triggerUpdate();
			break;
		}
		return GuiOverlay::onGuiEvent(evt);
	}
  
  Object@ get_object() {
		return obj;
	}

	void triggerUpdate() {
	}
	
	void update(double time) {
		settlement.update(time);
	}
};

class DisplayBox : BaseGuiElement {
	SettlementParent@ overlay;
	Alignment@ targetAlign;

	DisplayBox(SettlementParent@ ov, vec2i origin, Alignment@ target) {
		@overlay = ov;
		@targetAlign = target;
		super(overlay, recti_area(origin, vec2i(1,1)));
		visible = false;
		updateAbsolutePosition();
	}
  
  void animate(double animTime = ANIM2_TIME, bool visible = true) {
		this.visible = visible;
		animate_time(this, targetAlign.resolve(overlay.size), animTime);
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Animation_Complete:
				@alignment = targetAlign;
				return true;
		}
		return BaseGuiElement::onGuiEvent(evt);
	}

	bool pressed = false;
	bool onMouseEvent(const MouseEvent& evt, IGuiElement@ source) override {
		switch(evt.type) {
			case MET_Button_Down:
				if(evt.button == 0) {
					pressed = true;
					return true;
				}
				break;
			case MET_Button_Up:
				if(evt.button == 0 && pressed) {
					pressed = false;
					return true;
				}
				break;
		}
		return BaseGuiElement::onMouseEvent(evt, source);
	}

	void remove() override {
		@overlay = null;
		BaseGuiElement::remove();
	}

	void update(double time) {
	}

	void draw() override {
		skin.draw(SS_OverlayBox, SF_Normal, AbsolutePosition, Color(0x888888ff));
		BaseGuiElement::draw();
	}
};

class SettlementDisplay : DisplayBox {
  Object@ obj;
  
  GuiPanel@ panel;
  GuiSkinElement@ nameBox, moraleBox, panelBox;
	GuiText@ name, morale, focus;
	GuiDropdown@ focusList;
  GuiSprite@ moraleIcon;
  
  SettlementDisplay(SettlementParent@ ov, vec2i origin, Alignment@ target) {
		super(ov, origin, target);
    @obj = ov.object;
    
    //Header
		@nameBox = GuiSkinElement(this, Alignment(Left+8, Top+8, Left+0.5f-4, Top+42), SS_PlainOverlay);
		@name = GuiText(nameBox, Alignment().padded(8, 0), locale::SETTLEMENT);
		name.font = FT_Medium;
		
		@moraleBox = GuiSkinElement(this, Alignment(Left+0.5f+4, Top+8, Right-8, Top+42), SS_PlainOverlay);
		@moraleIcon = GuiSprite(moraleBox, Alignment(Left+8, Top+5, Width=24, Height=24));
		@morale = GuiText(moraleBox, Alignment(Left+40, Top, Right-8, Bottom));
		morale.font = FT_Medium;
    
    //Panel
    @panelBox = GuiSkinElement(this, Alignment(Left+8, Top+50, Right-8, Top+250), SS_PatternBox);
    GuiSkinElement bottomBar(panelBox, Alignment(Left+4, Bottom-34, Right-4, Bottom), SS_PlainBox);
    @panel = GuiPanel(panelBox, Alignment(Left, Top, Right, Bottom-34));
    
		@focus = GuiText(panelBox, Alignment(Left+8, Top+2, Left+0.5f-4, Height=32), locale::FOCUS_INPUT);
		@focusList = GuiDropdown(panelBox, Alignment(Left+0.5f+4, Top+2, Right-4, Height=32));
		
		if (obj.owner is playerEmpire) {
			updateMorale();
			updateFocusList();
		}
  }
	
	bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Changed:
				if(evt.caller is focusList) {
					auto@ focusElement = cast<FocusElement>(focusList.getItemElement(focusList.selected));
					if (obj.isPlanet) {
						auto@ pl = cast<Planet>(obj);
						pl.focusId = focusElement.focus.id;
					}
					else if (obj.isShip) {
						auto@ ship = cast<Ship>(obj);
						if (ship.hasSettlement)
							ship.focusId = focusElement.focus.id;
					}
				}
				return true;
		}
		return BaseGuiElement::onGuiEvent(evt);
	}
  
  double updateTimer = 0.0;
	double longTimer = 5.0;
	void update(double time) override {
		updateTimer -= time;
		longTimer -= time;
		if(updateTimer <= 0) {
			updateTimer = randomd(0.1,0.9);
			if(longTimer <= 0) {
				if (obj.owner is playerEmpire) {
					updateMorale();
					updateFocusList();
				}
				longTimer = 5.0;
			}
      
			bool isSettlement = false;
	    if (obj.isPlanet)
	      isSettlement = cast<Planet>(obj).isSettlement;
			else if (obj.isShip) {
				auto@ ship = cast<Ship>(obj);
				if (ship.hasSettlement)
					isSettlement = ship.isSettlement;
			}
			
      if (isSettlement) {
        nameBox.visible = true;
				moraleBox.visible = true;
        panelBox.visible = true;
      }
      else {
        nameBox.visible = false;
				moraleBox.visible = false;
        panelBox.visible = false;
      }
    }
  }
  
  void updateMorale() {
		uint currentMorale;
    if (obj.isPlanet)
			currentMorale = cast<Planet>(obj).morale;
		else if (obj.isShip) {
			auto@ ship = cast<Ship>(obj);
			if (ship.hasSettlement)
				currentMorale = ship.morale;
		}
		else return;
		
    switch (currentMorale) {
      case SM_Low:
				morale.text = locale::MORALE_LOW;
				moraleIcon.desc = Sprite(material::MaskAngry);
				break;
      case SM_High:
				morale.text = locale::MORALE_HIGH;
				moraleIcon.desc = Sprite(material::MaskHappy);
				break;
      default:
				morale.text = locale::MORALE_MEDIUM;
				moraleIcon.desc = Sprite(material::MaskNeutral);
				break;
    }
		morale.text += " " + locale::MORALE;
  }
	
	void updateFocusList() {
		int currentFocusId;
		if (obj.isPlanet)
			currentFocusId = cast<Planet>(obj).focusId;
		else if (obj.isShip) {
			auto@ ship = cast<Ship>(obj);
			if (ship.hasSettlement)
				currentFocusId = ship.focusId;
		}
		else return;
		
		focusList.clearItems();
		
		array<SettlementFocus@> foci = getAvailableFoci(obj, playerEmpire);
		for (uint i = 0, cnt = foci.length; i < cnt; ++i) {
			focusList.addItem(FocusElement(foci[i]));
			if (int(foci[i].id) == currentFocusId)
				focusList.selected = i;
		}
	}
};

class FocusElement : GuiListText {
	const SettlementFocus@ focus;
	
	FocusElement(const SettlementFocus& focus) {
			@this.focus = focus;
			super(focus.name);
	}
};

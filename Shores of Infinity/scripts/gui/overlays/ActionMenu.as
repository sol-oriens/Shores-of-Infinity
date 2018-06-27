import elements.BaseGuiElement;
import elements.GuiButton;
import elements.GuiOverlay;
import icons;

from gui import animate_time;
from overlays.Settlement import SettlementDisplay, SettlementParent;
from overlays.Construction import ConstructionDisplay, ConstructionParent;
from buildings import BuildingType;

const double ANIM1_TIME = 0.15;
const double ANIM2_TIME = 0.001;
const uint BORDER = 20;
const uint WIDTH = 500;

interface ActionMenuParent : IGuiElement {
	void close();
	Object@ get_object();
	void triggerUpdate();
  SettlementDisplay@ get_settlementDisplay() const;
  ConstructionDisplay@ get_constructionDisplay() const;
};

class ActionMenuOverlay : GuiOverlay, ActionMenuParent, SettlementParent, ConstructionParent {
  Object@ obj;
	Object@ slave;
  
  ActionMenuDisplay@ actionMenu;
  SettlementDisplay@ settlement;
	ConstructionDisplay@ construction;
  
  ActionMenuOverlay(IGuiElement@ parent, Object@ obj) {
		if(obj.isOrbital) {
			Orbital@ orb = cast<Orbital>(obj);
			if(orb.hasMaster()) {
				@slave = obj;
				@obj = orb.getMaster();
			}
		}
		
    @this.obj = obj;
		super(parent);
    
    @settlement = SettlementDisplay(this, vec2i(parent.size.width/2, parent.size.height),
					Alignment(Right-0.5f-250, Top+BORDER+40, Right-0.5f+250, Bottom-BORDER));
    @construction = ConstructionDisplay(this, vec2i(parent.size.width/2, parent.size.height),
					Alignment(Right-0.5f-250, Top+BORDER+40, Right-0.5f+250, Bottom-BORDER));
    @actionMenu = ActionMenuDisplay(this, vec2i(parent.size.width/2, parent.size.height),
          Alignment(Right-0.5f-250, Top+BORDER, Right-0.5f+250, Top+BORDER+40));
    
		if (obj.hasConstruction)
			construction.visible = true;
		else if (obj.hasSettlement)
			settlement.visible = true;
		
		actionMenu.animate(ANIM1_TIME);
    settlement.animate(ANIM1_TIME, settlement.visible);
	  construction.animate(ANIM1_TIME, construction.visible);
  }
  
  bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Confirmed:
				triggerUpdate();
			break;
		}
		return GuiOverlay::onGuiEvent(evt);
	}
	
	void close() override {
		actionMenu.visible = false;
		settlement.visible = false;
		construction.visible = false;
		GuiOverlay::close();
	}
  
  void startBuild(const BuildingType@ type) {
  }
  
  Object@ get_object() {
		return obj;
	}

	Object@ get_slaved() {
		return slave;
	}

	void triggerUpdate() {
	}
	
	void update(double time) {
		actionMenu.update(time);
		settlement.update(time);
		construction.update(time);
	}
  
  SettlementDisplay@ get_settlementDisplay() const {
		return settlement;
	}
	
  ConstructionDisplay@ get_constructionDisplay() const {
		return construction;
	}
};

class DisplayBox : BaseGuiElement {
	ActionMenuParent@ overlay;
	Alignment@ targetAlign;

	DisplayBox(ActionMenuParent@ ov, vec2i origin, Alignment@ target) {
		@overlay = ov;
		@targetAlign = target;
		super(overlay, recti_area(origin, vec2i(1,1)));
		visible = false;
		updateAbsolutePosition();
	}

	void animate(double animTime = ANIM2_TIME) {
		visible = true;
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

	void draw() {
		skin.draw(SS_OverlayBox, SF_Normal, AbsolutePosition, Color(0x888888ff));
		BaseGuiElement::draw();
	}
};

class ActionMenuDisplay : DisplayBox, SettlementParent, ConstructionParent {
  Object@ obj;
  SettlementDisplay@ settlementDisplay;
  ConstructionDisplay@ constructionDisplay;
  
  BaseGuiElement@ buttonBox;
  GuiButton@ settlementButton;
  GuiButton@ constructionButton;
  
  ActionMenuDisplay(ActionMenuParent@ ov, vec2i origin, Alignment@ target) {
		super(ov, origin, target);
    @obj = ov.object;
    @settlementDisplay = ov.settlementDisplay;
    @constructionDisplay = ov.constructionDisplay;
		
		if (!checkChildren()) {
			error("ActionMenuDisplay: ActionMenuParent child displays not initialized.");
			return;
		}
    
    @buttonBox = BaseGuiElement(this, Alignment(Left + 4, Top, Right - 4, Bottom));
    
    @settlementButton = GuiButton(buttonBox, Alignment(Left, Top + 2, Right - WIDTH / 2 + 4, Bottom - 4));
		settlementButton.text = locale::SETTLEMENT;
		settlementButton.toggleButton = true;
		settlementButton.disabled = true;
		settlementButton.style = SS_TabButton;
		settlementButton.buttonIcon = Sprite(spritesheet::ResourceIcons, 38);
    
    @constructionButton = GuiButton(buttonBox, Alignment(Left + WIDTH / 2 - 4, Top + 2, Right, Bottom - 4));
		constructionButton.text = locale::CONSTRUCTION;
		constructionButton.toggleButton = true;
    constructionButton.pressed = true;
		constructionButton.disabled = true;
		constructionButton.style = SS_TabButton;
		constructionButton.buttonIcon = Sprite(spritesheet::ResourceIconsSmall, 46);
		
		settlementDisplay.visible = false;
    
    updateButtons();
  }
  
  bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Clicked:
				if(evt.caller is settlementButton) {
					settlementButton.pressed = true;
					settlementDisplay.visible = true;
					constructionButton.pressed = false;
          constructionDisplay.visible = false;
					updateAbsolutePosition();
				}
				else if(evt.caller is constructionButton) {
					constructionButton.pressed = true;
					constructionDisplay.visible = true;
					settlementButton.pressed = false;
          settlementDisplay.visible = false;
					updateAbsolutePosition();
				}
			break;
		}
		return DisplayBox::onGuiEvent(evt);
	}
    
  double updateTimer = 0.0;
	double longTimer = 5.0;
  void update(double time) override {
    updateTimer -= time;
		longTimer -= time;
		if(updateTimer <= 0) {
			updateTimer = randomd(0.1, 0.9);
      if(longTimer <= 0) {
				updateButtons();
				longTimer = 5.0;
			}
    }
  }
  
  void updateButtons() {
		if (!checkChildren())
			return;
		bool isSettlement = false;
    if (obj.isPlanet)
      isSettlement = cast<Planet>(obj).isSettlement;
		else if (obj.isShip) {
			auto@ ship = cast<Ship>(obj);
			if (ship.hasSettlement)
				isSettlement = ship.isSettlement;
		}
		
		if (isSettlement)
      settlementButton.disabled = false;
    else
      settlementButton.disabled = true;
			
    if (obj.hasConstruction)
      constructionButton.disabled = false;
    else
      constructionButton.disabled = true;
      
    if (constructionButton.disabled) {
      constructionButton.pressed = false;
      constructionDisplay.visible = false;
      if (!settlementButton.disabled) {
        settlementButton.pressed = true;
        settlementDisplay.visible = true;
      }
    }
  }
	
	bool checkChildren() {
		return !(settlementDisplay is null || constructionDisplay is null);
	}
  
  void close() {
  }
  
  void startBuild(const BuildingType@ type) {
  }
  
  Object@ get_object() {
		return obj;
	}

	Object@ get_slaved() {
		return null;
	}
  
  void triggerUpdate() {
	}
};

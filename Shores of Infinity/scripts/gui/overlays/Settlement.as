import elements.BaseGuiElement;
import elements.GuiSkinElement;
import elements.GuiText;
import elements.GuiMarkupText;
import elements.GuiSprite;
import elements.GuiButton;
import elements.GuiCheckbox;
import elements.GuiDropdown;
import elements.GuiOverlay;
import elements.GuiAccordion;
import elements.GuiPanel;
import elements.MarkupTooltip;
import icons;
import settlements;
import util.formatting;

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

	GuiPanel@ upperPanel, middlePanel, civilActsPanel;
	GuiSkinElement@ nameBox, moraleBox, typeBox, upperPanelBox, middlePanelBox, civilActBox;
	GuiText@ name, morale, type, focus, civilActs;
	GuiDropdown@ focusList;
	GuiAccordion@ civilActList;
	GuiSprite@ moraleIcon, typeIcon;

	GuiButton@ autoFocusButton;
	GuiButton@ cancelCivilActsButton;

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

		//Upper panel
		@upperPanelBox = GuiSkinElement(this, Alignment(Left+8, Top+50, Right-8, Top+250), SS_DesignOverviewBG);
		GuiSkinElement upperPanelBottomBar(upperPanelBox, Alignment(Left+4, Bottom-34, Right-4, Bottom), SS_PlainBox);
		@upperPanel = GuiPanel(upperPanelBox, Alignment(Left, Top, Right, Bottom-34));

		@typeBox = GuiSkinElement(upperPanelBox, Alignment(Left, Top, Right, Height=64), SS_Highlight);
		@typeIcon = GuiSprite(typeBox, Alignment(Left+8, Top+8, Width=48, Height=48));
		@type = GuiText(typeBox, Alignment(Left+72, Top, Right-8, Bottom));
		type.font = FT_Medium;

		@focus = GuiText(upperPanelBox, Alignment(Left+8, Top+72, Left+0.5f-4, Height=32), locale::FOCUS_INPUT);
		@focusList = GuiDropdown(upperPanelBox, Alignment(Left+0.5f+4, Top+72, Right-4, Height=32));

		@autoFocusButton = GuiButton(upperPanelBox, Alignment(Right-8-32, Bottom-32, Width=30, Height=30));
		autoFocusButton.style = SS_IconToggle;
		autoFocusButton.color = Color(0x00ff00ff);
		autoFocusButton.toggleButton = true;
		autoFocusButton.setIcon(Sprite(spritesheet::ActionBarIcons, 0));
		setMarkupTooltip(autoFocusButton, locale::TT_AUTO_FOCUS, width=300);

		//Middle panel
		@middlePanelBox = GuiSkinElement(this, Alignment(Left+8, Top+250+10, Right-8, Top+650+10), SS_DesignOverviewBG);
		middlePanelBox.color = Color(0x6dd6caff);
		GuiSkinElement middlePanelBottomBar(middlePanelBox, Alignment(Left+4, Bottom-34, Right-4, Bottom), SS_PlainBox);
		@middlePanel = GuiPanel(middlePanelBox, Alignment(Left, Top, Right, Bottom-34));

		@civilActs = GuiText(middlePanelBox, Alignment(Left+8, Top, Right, Top+30), locale::CIVIL_ACTS);
		civilActs.font = FT_Medium;

		@civilActsPanel = GuiPanel(middlePanel, Alignment(Left, Top+34, Right, Bottom));
		@civilActList = GuiAccordion(civilActsPanel, recti(0, 0, 500, 50));
		civilActList.multiple = true;
		civilActList.clickableHeaders = true;

		@cancelCivilActsButton = GuiButton(middlePanelBox, Alignment(Right-8-32, Bottom-32, Width=30, Height=30));
		cancelCivilActsButton.style = SS_IconButton;
		cancelCivilActsButton.color = Color(0x00ff00ff);
		cancelCivilActsButton.setIcon(icons::Clear);
		setMarkupTooltip(cancelCivilActsButton, locale::TT_CANCEL_CIVIL_ACTS, width=300);

		if (obj.owner is playerEmpire) {
			updateVariables();
			updateAutoFocus();
			updateFocusList();
			updateCivilActList(expandAll = true);
		}
	}

	void updateAbsolutePosition() {
		DisplayBox::updateAbsolutePosition();
		if(civilActList !is null) {
			if(civilActsPanel.vert.visible)
				civilActList.size = vec2i(civilActsPanel.size.width - 20, civilActList.size.height);
			else
				civilActList.size = vec2i(civilActsPanel.size.width, civilActList.size.height);
		}
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Changed:
				if(evt.caller is focusList) {
					auto@ focusElement = cast<FocusElement>(focusList.getItemElement(focusList.selected));
					if (focusElement !is null && focusElement.focus.id != obj.focusId) {
						obj.setFocus(focusElement.focus.id);
						//Deactivate autoFocus
						obj.autoFocus = false;
						updateVariables();
						updateAutoFocus();
					}
					return true;
				}
				break;
			case GUI_Clicked:
				if (evt.caller is autoFocusButton) {
					obj.autoFocus = !obj.autoFocus;
					return true;
				}
				if (evt.caller is cancelCivilActsButton) {
					for(uint i = 0, cnt = obj.civilActCount; i < cnt; ++i) {
						uint id = obj.getCivilActTypeId(i);
						const CivilActType@ civilAct = getCivilActType(id);
						obj.removeCivilAct(civilAct.id);
						--i; --cnt;
					}
					updateCivilActList();
					updateVariables();
					return true;
				}
				break;
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
					updateVariables();
					updateAutoFocus();
					updateFocusList();
					updateCivilActList();
				}
				longTimer = 5.0;
			}

			if (obj.isSettlement) {
				nameBox.visible = true;
				moraleBox.visible = true;
				upperPanelBox.visible = true;
				middlePanelBox.visible = true;
			}
			else {
				nameBox.visible = false;
				moraleBox.visible = false;
				upperPanelBox.visible = false;
				middlePanelBox.visible = false;
			}
			updateAbsolutePosition();
		}
	}

	void updateVariables() {
		switch (obj.morale) {
			case SM_Critical:
				morale.text = locale::MORALE_CRITICAL;
				moraleIcon.desc = getSprite("MaskAngry * #f00");
				break;
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

		const SettlementType@ settlement = getSettlementType(obj.settlementTypeId);
		if (settlement !is null) {
			type.text = settlement.name;
			typeIcon.desc = settlement.icon;
			setMarkupTooltip(typeBox, settlement.formatTooltip(), width=300);
		}
	}

	void updateFocusList() {
		focusList.clearItems();

		array<SettlementFocusType@> foci = getAvailableFoci(obj);
		for (uint i = 0, cnt = foci.length; i < cnt; ++i) {
			focusList.addItem(FocusElement(foci[i]));
			if (foci[i].id == obj.focusId) {
				focusList.selected = i;
			}
		}
	}

	void updateAutoFocus() {
		if (obj.autoFocus)
			autoFocusButton.pressed = true;
		else
			autoFocusButton.pressed = false;
	}

	void updateCivilActList(bool expandAll = false) {
		civilActList.clearSections();

		array<GuiListbox@> cats;
		array<string> catNames;
		array<CivilActType@> civilActs = getAvailableCivilActs(obj);
		for(uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
			auto@ civilAct = civilActs[i];

			GuiListbox@ list;
			for(uint n = 0, ncnt = cats.length; n < ncnt; ++n) {
				if(catNames[n] == civilAct.category) {
					@list = cats[n];
					break;
				}
			}

			if(list is null) {
				@list = GuiListbox(this, recti(0, 0, 100, 20));
				list.style = SS_NULL;
				list.itemHeight = 30;
				list.multiple = true;

				MarkupTooltip tt(400, 0.f, true, true);
				tt.Lazy = true;
				tt.LazyUpdate = false;
				tt.Padding = 4;
				@list.tooltipObject = tt;

				catNames.insertLast(civilAct.category);
				cats.insertLast(list);
			}

			list.addItem(CivilActElement(this, civilAct, obj));
		}

		uint[] foundIds;
		for(uint i = 0, cnt = cats.length; i < cnt; ++i) {
			auto@ list = cats[i];
			list.sortAsc();

			string title = localize("#CIVIL_ACT_CAT_" + catNames[i]);
			if(title[0] == '#')
				title = catNames[i];

			uint sec = civilActList.addSection(title, list);
			if (expandAll)
				civilActList.openSection(sec);
			else {
				if (civilActList.opened[sec])
					civilActList.animSize[sec] = 1.0;
			}
			list.updateHover();

			for(uint j = 0, jcnt = obj.civilActCount; j < jcnt; ++j) {
				uint id = obj.getCivilActTypeId(j);
				if (foundIds.find(id) != -1)
					continue;
				for(uint k = 0, kcnt = list.itemCount; k < kcnt; ++k) {
					auto@ ele = cast<CivilActElement>(list.getItemElement(k));
					if (ele.civilAct.id == id) {
						list.SelectedItems[k] = true;
						ele.selected = true;
						foundIds.insertLast(id);
						break;
					}
				}
			}
		}

		gui_root.updateHover();
	}
};

const string slashStr("/");

class FocusElement : GuiListText {
	const SettlementFocusType@ focus;
	string ttText;

	FocusElement(const SettlementFocusType& focus) {
			@this.focus = focus;
			super(focus.name);
			ttText = focus.formatTooltip();
	}
};

class CivilActElement : GuiListText {
	SettlementDisplay@ parent;
	const CivilActType@ civilAct;
	Object@ obj;
	Color nameColor = colors::White;
	string costText;
	string maintainText;
	string ttText;

	bool selected = false;

	CivilActElement(SettlementDisplay@ disp, CivilActType@ civilAct, Object@ obj) {
		super(civilAct.name);
		@this.parent = disp;
		@this.civilAct = civilAct;
		@this.obj = obj;
		costText = formatMoney(0);
		maintainText = formatMoney(civilAct.getMaintainCost(obj));
		ttText = civilAct.formatTooltip();
	}

	string get_tooltipText() override {
		return ttText;
	}

	int opCmp(const GuiListElement@ other) const override {
		const auto@ element = cast<CivilActElement>(other);
		if(text < element.text)
			return -1;
		if(text > element.text)
			return 1;
		return 0;
	}

	void draw(GuiListbox@ ele, uint flags, const recti& pos) override {
		const Font@ font = ele.skin.getFont(ele.TextFont);

		//Background element
		ele.skin.draw(SS_GlowButton, flags, pos);

		int x = pos.width - 2;

		//Name
		font.draw(pos=pos.padded(4, 0, 0, 0), vertAlign=0.5, text=text, ellipsis=locale::ELLIPSIS, color=nameColor);
		if(maintainText.length != 0) {
			x -= 135;
			icons::Money.draw(recti_area(vec2i(x, 3)+pos.topLeft, vec2i(24, 24)));
			font.draw(pos=recti_area(vec2i(x+28, 0)+pos.topLeft, vec2i(92, 30)),
					horizAlign=0.0, vertAlign=0.5,
					text=costText, ellipsis=locale::ELLIPSIS, color=colors::White);
			font.draw(pos=recti_area(vec2i(x+28, 0)+pos.topLeft, vec2i(92, 30)),
					horizAlign=0.5, vertAlign=0.5,
					text=slashStr, ellipsis=locale::ELLIPSIS, color=colors::White);
			font.draw(pos=recti_area(vec2i(x+28, 0)+pos.topLeft, vec2i(92, 30)),
					horizAlign=1.0, vertAlign=0.5,
					text=maintainText, ellipsis=locale::ELLIPSIS, color=colors::White);
		}
	}

	bool onMouseEvent(const MouseEvent& event) override {
		switch(event.type) {
			case MET_Button_Up:
				if(event.button == 0) {
					if (selected == false) {
						obj.addCivilAct(civilAct.id);
						selected = true;
					}
					else {
						obj.removeCivilAct(civilAct.id);
						selected = false;
					}
					parent.updateVariables();
					GuiListText::onMouseEvent(event);
				}
			break;
		}
		return false;
	}
};

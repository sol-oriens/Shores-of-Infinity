import elements.BaseGuiElement;
import elements.GuiOverlay;
import elements.GuiBackgroundPanel;
import elements.GuiMarkupText;
import elements.GuiText;
import elements.GuiListbox;
import elements.GuiProgressbar;
import elements.Gui3DObject;
import elements.GuiButton;
import elements.GuiPanel;
import elements.GuiSprite;
from dialogs.MessageDialog import message;
import sites;
import targeting.ObjectTarget;

class Option : GuiButton {
	const SiteOption@ option;
	GuiSprite@ icon;
	GuiMarkupText@ content;
	uint index;

	Option(IGuiElement@ parent) {
		super(parent, recti());
		@icon = GuiSprite(this, Alignment(Left+4, Top+0.5f-30, Left+64, Top+0.5f+30));
		@content = GuiMarkupText(this, recti(68, 4, 100, 100));
		style = SS_ChoiceBox;
	}

	int set(const SiteOption@ option, int y, uint index) {
		@this.option = option;
		this.index = index;
		position = vec2i(4, y);
		size = vec2i(parent.size.width-8, size.height);
		content.size = vec2i(size.width - 72, content.size.height);
		content.text = option.desc;
		icon.desc = option.icon;
		updateAbsolutePosition();
		size = vec2i(size.width, max(content.size.height + 12, 68));
		return size.height;
	}
};

class SiteOverlay : GuiOverlay {
	Site@ site;
	Object@ obj;
	GuiBackgroundPanel@ bg;
	GuiBackgroundPanel@ choices;

	GuiPanel@ descPanel;
	GuiMarkupText@ description;
	GuiText@ progressLabel;
	GuiSprite@ icon;
	GuiProgressbar@ bar;

	GuiPanel@ choicePanel;
	array<Option@> options;

	SiteOverlay(IGuiElement@ parent, Object@ obj, uint siteId) {
		@this.obj = obj;
		Site s;
		Planet@ planet = cast<Planet>(obj);
		if (planet !is null) {
			if (!receive(planet.selectSite(siteId), s))
				return;
		}
		else
			return;

		@site = s;

		super(parent);

		uint left = 500;
		uint right = 500;
		uint total = left + 12 + right;

		@bg = GuiBackgroundPanel(this, Alignment(Left+0.5f-total/2, Top+0.5f-200, Left+0.5f-total/2+left, Top+0.5f+200));
		bg.title = site.type.name;
		bg.titleColor = Color(0x00ff00ff);

		@choices = GuiBackgroundPanel(this, Alignment(Left+0.5f-total/2+left+12, Top+0.5f-300, Left+0.5f+total/2, Top+0.5f+300));
		choices.title = locale::SITE_CHOICES;
		choices.titleColor = Color(0xff8000ff);

		@progressLabel = GuiText(choices, Alignment(Left+8, Top+0.4f-30, Right-8, Top+0.4f-3), locale::SCAN_PROGRESS);
		progressLabel.horizAlign = 0.5;
		progressLabel.vertAlign = 1.0;
		@bar = GuiProgressbar(choices, Alignment(Left+12, Top+0.4f+3, Right-12, Top+0.4f+30));
		bar.frontColor = Color(0x6aadcbff);

		@descPanel = GuiPanel(bg, Alignment(Left+4, Top+36, Left+left-4, Bottom-8));

		@description = GuiMarkupText(descPanel, recti_area(4, 0, left-8, 100), site.narrative);
		description.fitWidth = true;
		@icon = GuiSprite(descPanel, recti_area(200, 150, 100, 100), getSprite(site.sprite));

		@choicePanel = GuiPanel(choices, Alignment(Left, Top+38, Right, Bottom));
		choicePanel.visible = true;

		closeSelf = false;
		updateAbsolutePosition();
		update();
		bringToFront();

		overlays.insertLast(this);
	}

	void remove() {
		overlays.remove(this);
		GuiOverlay::remove();
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Clicked:
				{
					Option@ opt = cast<Option>(evt.caller);
					if(opt !is null) {
						site.chooseOption(opt.index);
						timer = 0.05f;
					}
				}
				refreshState();
			break;
		}
		return GuiOverlay::onGuiEvent(evt);
	}

	void refreshState() {
		Site s;
		Planet@ pl = cast<Planet>(obj);
		if (pl !is null) {
			if (receive(pl.refreshCurrentSite(), s)) {
				@site = s;
				return;
			}
		}

		@site = null;
	}

	float timer = 0.f;
	void update() {
		if (site is null) {
			GuiOverlay::close();
			return;
		}
		timer -= frameLength;
		if(timer <= 0.f) {
			float progress = site.progress;
			if(progress >= 1.f) {
				description.text = site.narrative;

				uint optCount = site.optionCount;

				choicePanel.visible = true;
				progressLabel.visible = false;
				bar.visible = false;

				uint oldCnt = options.length;
				for(uint i = optCount; i < oldCnt; ++i)
					options[i].remove();
				options.length = optCount;
				int y = 0;
				for(uint i = 0; i < optCount; ++i) {
					SiteOption@ option = site.type.options[site.option[i]];

					if(options[i] is null)
						@options[i] = Option(choicePanel);

					y += options[i].set(option, y, i) + 8;
				}
			}
			else {
				choicePanel.visible = false;
				progressLabel.visible = true;
				bar.visible = true;
			}

			if(bar.visible) {
				bar.progress = progress;
				bar.text = toString(floor(progress * 100.0),0) + "%";
			}

			icon.draw();
			updateAbsolutePosition();
			timer += 1.f;
		}
	}

	void updateAbsolutePosition() {
		GuiOverlay::updateAbsolutePosition();
	}
};

array<SiteOverlay@> overlays;
void tick(double time) {
	for(uint i = 0, cnt = overlays.length; i < cnt; ++i)
		overlays[i].update();
}

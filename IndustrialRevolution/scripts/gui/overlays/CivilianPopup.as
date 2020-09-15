import overlays.Popup;
import elements.GuiText;
import elements.GuiMarkupText;
import elements.GuiButton;
import elements.GuiSprite;
import elements.Gui3DObject;
import elements.GuiResources;
import elements.GuiProgressbar;
import elements.GuiSkinElement;
from overlays.ContextMenu import openContextMenu;
import icons;
import resources;
import civilians;

class CivilianPopup : Popup {
	GuiText@ name;
	Gui3DObject@ objView;
	GuiText@ objDesc;
	GuiSprite@ objStatusIcon;
	Civilian@ obj;
	double lastUpdate = -INFINITY;
	GuiResourceGrid@ resources;

	GuiText@ cargoLabel;
	GuiMarkupText@ worth;
	GuiMarkupText@ cargoText;
	GuiText@ speedometer;

	GuiProgressbar@ health;

	CivilianPopup(BaseGuiElement@ parent) {
		super(parent);
		size = vec2i(190, 185);

		@name = GuiText(this, Alignment(Left+4, Top+2, Right-4, Top+24));
		name.horizAlign = 0.5;

		@objDesc = GuiText(this, Alignment(Left+6, Top+28, Right-4, Top+42));
		objDesc.font = FT_Detail;
		objDesc.stroke = colors::Black;
		@objView = Gui3DObject(this, Alignment(Left+4, Top+25, Right-4, Top+110));
		@objStatusIcon = GuiSprite(objView, Alignment(Left+2, Top+44, Width=24, Height=24), spritesheet::ActionBarIcons, 4);
		objStatusIcon.visible = false;
		@speedometer = GuiText(objView, Alignment(Left+6, Bottom-27, Right-2, Height=12));
		speedometer.font = FT_Detail;
		speedometer.stroke = colors::Black;
		speedometer.visible = false;
		speedometer.horizAlign = 1.0;
		@health = GuiProgressbar(this, Alignment(Left+3, Top+95, Right-4, Top+122));
		health.tooltip = locale::HEALTH;
		GuiSprite healthIcon(health, Alignment(Left+2, Top+1, Width=24, Height=24), icons::Health);

		GuiSkinElement resBand(this, Alignment(Left+3, Bottom-64, Right-4, Bottom-32), SS_SubTitle);
		resBand.color = Color(0xaaaaaaff);
		@cargoText = GuiMarkupText(resBand, Alignment(Left+3, Top+4, Right-3, Bottom-2));
		cargoText.defaultFont = FT_Bold;
		@resources = GuiResourceGrid(resBand, Alignment(Left+3, Top+3, Right-3, Bottom-2));

		GuiSkinElement descBand(this, Alignment(Left+3, Bottom-34, Right-4, Bottom-2), SS_SubTitle);
		@cargoLabel = GuiText(descBand, Alignment(Left+5, Top+2, Right-5, Bottom-2), locale::SHIP_CARGO);
		cargoLabel.font = FT_Detail;
		cargoLabel.stroke = colors::Black;
		@worth = GuiMarkupText(descBand, Alignment(Left+5, Top+4, Right-5, Bottom-2));
		updateAbsolutePosition();
	}

	bool compatible(Object@ Obj) {
		return Obj.isCivilian;
	}

	void set(Object@ Obj) {
		@obj = cast<Civilian>(Obj);
		@objView.object = Obj;
		@resources.drawFrom = obj;
		lastUpdate = -INFINITY;
	}

	Object@ get() {
		return obj;
	}

	void draw() {
		Popup::updatePosition(obj);
		recti bgPos = AbsolutePosition;

		uint flags = SF_Normal;
		SkinStyle style = SS_GenericPopupBG;
		if(isSelectable && Hovered)
			flags |= SF_Hovered;
		if(obj.owner !is null) {
			skin.draw(style, flags, bgPos, obj.owner.color);
			if(obj.owner.flag !is null)
				obj.owner.flag.draw(
					objView.absolutePosition.aspectAligned(1.0, horizAlign=1.0, vertAlign=1.0),
					obj.owner.color * Color(0xffffff30));
		}
		else
			skin.draw(style, flags, bgPos, Color(0xffffffff));

		BaseGuiElement::draw();
	}

	bool onGuiEvent(const GuiEvent& evt) {
		switch(evt.type) {
			case GUI_Clicked:
				if(evt.caller is objView) {
					dragging = false;
					if(!dragged) {
						switch(evt.value) {
							case OA_LeftClick:
								emitClicked(PA_Select);
								return true;
							case OA_RightClick:
								openContextMenu(obj);
								return true;
							case OA_MiddleClick:
							case OA_DoubleClick:
								if(isSelectable)
									emitClicked(PA_Select);
								else
									emitClicked(PA_Manage);
								return true;
						}
					}
				}
			break;
		}
		return Popup::onGuiEvent(evt);
	}

	void update() {
		if(frameTime - 0.5 < lastUpdate)
			return;

		lastUpdate = frameTime;
		const Font@ ft = skin.getFont(FT_Normal);

		//Update name
		name.text = getCivilianName(obj.getCivilianType(), obj.radius);
		if(ft.getDimension(name.text).x > name.size.width)
			name.font = FT_Detail;
		else
			name.font = FT_Normal;

		//Update hp display
		double curHP = obj.health;
		double maxHP = obj.maxHealth;

		Color high(0x00ff00ff);
		Color low(0xff0000ff);

		health.progress = curHP / maxHP;
		health.frontColor = low.interpolate(high, health.progress);
		health.text = standardize(curHP)+" / "+standardize(maxHP);

		//Update resources
		uint type = obj.getCargoType();
		int value = obj.getCargoWorth();
		objDesc.color = obj.owner.color;
		if(obj.velocity.length > 0) {
			speedometer.visible = true;
			speedometer.color = obj.owner.color;
			speedometer.text = formatSpeed(obj.velocity.length);
		} else
			speedometer.visible = false;

		if(type == CT_Goods) {
			resources.visible = false;
			cargoText.visible = true;
			cargoText.text = locale::CARGO_GOODS;
		}
		else if(type == CT_Resource) {
			const ResourceType@ res = getResource(obj.getCargoResource());
			resources.visible = true;
			cargoText.visible = false;
			if(res !is null) {
				resources.types.length = 1;
				@resources.types[0] = res;
				resources.typeMode = true;
				resources.setSingleMode();
			}
			else {
				resources.types.length = 0;
			}
		}

		if(obj.owner !is playerEmpire)
			worth.text = format(locale::SHIP_CARGO_WORTH, formatMoney(value));
		else {
			if(obj.getCivilianType() == CiT_Freighter) {
				objStatusIcon.visible = true;
				objStatusIcon.sprite = obj.isMainRun() ? 4 : 9;
				objStatusIcon.tooltip = obj.isMainRun() ? locale::CIVILIAN_MAINRUN_DESC : locale::CIVILIAN_TRADERUN_DESC;
			} else
				objStatusIcon.visible = false;
			objDesc.text = obj.name;
			int income = obj.getIncome();
			cargoLabel.text = income > 0 ? locale::SHIP_CARGO_INCOME : locale::SHIP_CARGO_UPKEEP;
			worth.text = format(locale::SHIP_CARGO_WORTH_INCOME, formatMoney(value), formatMoney(income), toString(income < 0 ? low : high));
		}

		Popup::update();
		Popup::updatePosition(obj);
	}
};

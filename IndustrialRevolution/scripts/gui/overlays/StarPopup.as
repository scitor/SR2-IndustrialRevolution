import overlays.Popup;
import elements.GuiText;
import elements.GuiButton;
import elements.GuiSprite;
import elements.Gui3DObject;
import elements.GuiProgressbar;
import elements.MarkupTooltip;
import icons;
from overlays.ContextMenu import openContextMenu;
import util.formatting;
const uint coronaPadding = 20;

class StarPopup : Popup {
	GuiText@ name;
	Gui3DObject@ objView;
	Star@ obj;
	double lastUpdate = -INFINITY;

	GuiSprite@ defIcon;
	GuiText@ speedometer;
	GuiText@ objDesc;

	GuiProgressbar@ health;

	StarPopup(BaseGuiElement@ parent) {
		super(parent);
		size = vec2i(150 + 2*coronaPadding, 160 + 2*coronaPadding);

		@name = GuiText(this, Alignment(Left+4, Top+2, Right-4, Top+24).padded(coronaPadding,coronaPadding));
		name.horizAlign = 0.5;

		@objView = Gui3DObject(this, Alignment(Left+4, Top+24, Right-4, Bottom-6));

		@objDesc = GuiText(objView, Alignment(Left+1+coronaPadding, Bottom-12-coronaPadding, Right-4, Height=12));
		objDesc.stroke = colors::Black;
		objDesc.font = FT_Detail;

		@speedometer = GuiText(objView, Alignment(Left+3, Bottom-12-coronaPadding, Right-2-coronaPadding, Height=12));
		speedometer.font = FT_Detail;
		speedometer.stroke = colors::Black;
		speedometer.visible = false;
		speedometer.horizAlign = 1.0;

		@defIcon = GuiSprite(objView, Alignment(Left+20, Top+20, Width=40, Height=40));
		defIcon.desc = icons::Defense;
		setMarkupTooltip(defIcon, locale::TT_IS_DEFENDING);
		defIcon.visible = false;

		@health = GuiProgressbar(this, Alignment(Left+3+coronaPadding, Bottom-40-coronaPadding, Right-4-coronaPadding, Height=22));
		health.visible = false;

		auto@ healthIcon = GuiSprite(health, Alignment(Left+4, Top, Width=22, Height=22), icons::Health);
		healthIcon.noClip = true;

		updateAbsolutePosition();
	}

	bool compatible(Object@ Obj) {
		return Obj.isStar;
	}

	void set(Object@ Obj) {
		@obj = cast<Star>(Obj);
		@objView.object = Obj;
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

		Color col;
		Region@ reg = obj.region;
		if(reg !is null) {
			Empire@ other = reg.visiblePrimaryEmpire;
			if(other !is null)
				col = other.color;
		}

		skin.draw(style, flags, bgPos.padded(coronaPadding,coronaPadding), col);
		if(obj.owner !is null && obj.owner.flag !is null) {
			obj.owner.flag.draw(
				objView.absolutePosition.aspectAligned(1.0, horizAlign=1.0, vertAlign=1.0),
				obj.owner.color * Color(0xffffff30));
		}
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
		if(frameTime - 0.2 < lastUpdate)
			return;

		lastUpdate = frameTime;
		const Font@ ft = skin.getFont(FT_Normal);

		defIcon.visible = playerEmpire.isDefending(obj.region);

		//Update name
		name.text = obj.name;
		if(ft.getDimension(name.text).x > name.size.width)
			name.font = FT_Detail;
		else
			name.font = FT_Normal;

		objDesc.text = format("$1-$2", starClass(obj.temperature, obj.radius), locale::SYSTEM_STAR);
		if(obj.temperature < 1.0)
			objDesc.text = locale::SYSTEM_BLACKHOLE;
		else if(obj.radius > 500) {
			if(obj.temperature < 2000.0)
				objDesc.text = locale::SYSTEM_STAR_RED_GIANT;
			else
				objDesc.text = locale::SYSTEM_STAR_BRIGHT_GIANT;
		} else if(obj.radius < 50) {
			if(obj.temperature < 2000.0)
				objDesc.text = locale::SYSTEM_STAR_RED_DWARF;
			else
				objDesc.text = locale::SYSTEM_NEUTRON_STAR;
		}
		if(obj.velocity.length > 0) {
			speedometer.visible = true;
			speedometer.text = formatSpeed(obj.velocity.length);
		} else
			speedometer.visible = false;

		//Update health
		if(obj.Health < obj.MaxHealth) {
			health.progress = obj.Health / obj.MaxHealth;
			health.frontColor = colors::Red.interpolate(colors::Green, health.progress);
			health.text = standardize(obj.Health)+" / "+standardize(obj.MaxHealth);
			health.visible = true;
		}
		else {
			health.visible = false;
		}

		Popup::update();
		Popup::updatePosition(obj);
	}

	string starClass(double temperature, double radius) {
		const string starClasses = "MKGFABO";
		return starClasses.substr(max(0, min(starClasses.length-1, int(((radius - 50) / 250) + (temperature/2000)))), 1);
	}
};

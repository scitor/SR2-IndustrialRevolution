import overlays.Popup;
import elements.GuiText;
import elements.GuiButton;
import elements.GuiSprite;
import elements.Gui3DObject;
import elements.GuiProgressbar;
from overlays.ContextMenu import openContextMenu;
import util.formatting;
import icons;

class ObjectPopup : Popup {
	GuiText@ name;
	Gui3DObject@ objView;
	Object@ obj;
	GuiText@ objDesc;
	GuiText@ speedometer;
	GuiProgressbar@ health;
	double lastUpdate = -INFINITY;

	ObjectPopup(BaseGuiElement@ parent) {
		super(parent);
		size = vec2i(150, 128);

		@name = GuiText(this, Alignment(Left+4, Top+2, Right-4, Height=22));
		name.horizAlign = 0.5;

		@objView = Gui3DObject(this, Alignment(Left+4, Top+25, Right-4, Height=100));

		@objDesc = GuiText(objView, Alignment(Left+2, Top+2, Right-4, Top+12));
		objDesc.font = FT_Detail;
		objDesc.stroke = colors::Black;

		@speedometer = GuiText(objView, Alignment(Left+6, Top+86, Right-2, Bottom));
		speedometer.font = FT_Detail;
		speedometer.stroke = colors::Black;
		speedometer.horizAlign = 1.0;
		speedometer.visible = false;

		@health = GuiProgressbar(this, Alignment(Left+3, Bottom-26, Right-4, Height=22));
		health.visible = false;

		auto@ healthIcon = GuiSprite(health, Alignment(Left+4, Top, Width=22, Height=22), icons::Health);
		healthIcon.noClip = true;

		updateAbsolutePosition();
	}

	bool compatible(Object@ Obj) {
		return obj is Obj;
	}

	void set(Object@ Obj) {
		@obj = Obj;
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
		if(obj.isStar) {
			Region@ reg = obj.region;
			if(reg !is null) {
				Empire@ other = reg.visiblePrimaryEmpire;
				if(other !is null)
					col = other.color;
			}
		}
		else if(obj.owner !is null)
			col = obj.owner.color;

		skin.draw(style, flags, bgPos, col);
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

		//Update name
		name.text = obj.name;
		if(ft.getDimension(name.text).x > name.size.width)
			name.font = FT_Detail;
		else
			name.font = FT_Normal;

		if(obj.hasMover && obj.velocity.length > 0) {
			speedometer.visible = true;
			speedometer.color = obj.owner.color;
			speedometer.text = formatSpeed(obj.velocity.length);
		} else
			speedometer.visible = false;

		//Update health
		if(obj.isColonyShip || obj.isFreighter) {
			double objHealth, maxHealth = 50;
			Freighter@ freighter = cast<Freighter>(obj);
			ColonyShip@ colonyShip = cast<ColonyShip>(obj);
			if(freighter !is null) {
				objHealth = freighter.Health;
				objDesc.text = freighter.targetName;
			} else if(colonyShip !is null) {
				objHealth = colonyShip.Health;
				objDesc.text = colonyShip.targetName;
			}

			objDesc.color = obj.owner.color;
			maxHealth = max(objHealth, maxHealth);
			health.progress = objHealth / maxHealth;
			health.frontColor = colors::Red.interpolate(colors::Green, health.progress);
			health.text = standardize(objHealth)+" / "+standardize(maxHealth);
			health.visible = true;

			size = vec2i(150, 150);
		}
		else {
			size = vec2i(150, 128);
			health.visible = false;
		}
		Popup::update();
		Popup::updatePosition(obj);
	}
};

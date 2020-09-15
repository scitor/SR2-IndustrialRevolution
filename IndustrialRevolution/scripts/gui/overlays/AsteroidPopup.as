import overlays.Popup;
import elements.GuiText;
import elements.GuiButton;
import elements.GuiSprite;
import elements.Gui3DObject;
import elements.GuiSkinElement;
import elements.GuiStatusBox;
import elements.GuiResources;
import elements.GuiCargoDisplay;
from overlays.ContextMenu import openContextMenu;
import resources;
import cargo;
import statuses;

class AsteroidPopup : Popup {
	GuiText@ name;
	Gui3DObject@ objView;
	Asteroid@ obj;
	double lastUpdate = -INFINITY;

	GuiSkinElement@ band;
	GuiResourceGrid@ resources;
	GuiCargoDisplay@ cargo;

	GuiSkinElement@ statusBox;
	array<GuiStatusBox@> statusIcons;
	GuiText@ speedometer;

	AsteroidPopup(BaseGuiElement@ parent) {
		super(parent);
		size = vec2i(160, 135);

		@name = GuiText(this, Alignment(Left+4, Top+2, Right-4, Top+24));
		name.horizAlign = 0.5;

		@objView = Gui3DObject(this, Alignment(Left+4, Top+25, Right-4, Top+100));
		@cargo = GuiCargoDisplay(objView, Alignment(Left+4, Top+2, Right-4, Height=26));

		@speedometer = GuiText(objView, Alignment(Left+6, Bottom-10, Right-2, Bottom));
		speedometer.font = FT_Detail;
		speedometer.stroke = colors::Black;
		speedometer.horizAlign = 1.0;
		speedometer.visible = false;

		@band = GuiSkinElement(this, Alignment(Left+3, Bottom-35, Right-4, Height=33), SS_SubTitle);
		band.color = Color(0xaaaaaaff);

		@resources = GuiResourceGrid(band, Alignment(Left+4, Top+4, Right-3, Bottom-4));
		resources.visible = false;

		@statusBox = GuiSkinElement(this, Alignment(Right-2, Top, Right+34, Bottom), SS_PlainBox);
		statusBox.noClip = true;
		statusBox.visible = false;

		updateAbsolutePosition();
	}

	bool compatible(Object@ Obj) {
		return Obj.isAsteroid;
	}

	void set(Object@ Obj) {
		@obj = cast<Asteroid>(Obj);
		@objView.object = Obj;
		//objView.internalRotation = quaterniond_fromAxisAngle(random3d(1.0), randomd(-pi,pi));
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
		name.text = obj.name;
		if(ft.getDimension(name.text).x > name.size.width)
			name.font = FT_Detail;
		else
			name.font = FT_Normal;

		if(obj.velocity.length > 0) {
			speedometer.visible = true;
			speedometer.color = obj.owner.color;
			speedometer.text = formatSpeed(obj.velocity.length);
		} else
			speedometer.visible = false;

		cargo.update(obj);
		if(obj.cargoTypes != 0)
			drawRectangle(cargo.absolutePosition, Color(0x00000040));
		if(obj.nativeResourceCount != 0) {
			resources.visible = true;

			resources.resources.syncFrom(obj.getAllResources());
			resources.setSingleMode();

			band.visible = resources.length != 0;
		} else
			band.visible = false;

		if(band.visible)
			size = vec2i(160, 135);
		else
			size = vec2i(160, 105);

		//Update statuses
		{
			array<Status> statuses;
			if(obj.statusEffectCount > 0)
				statuses.syncFrom(obj.getStatusEffects());
			if(!obj.visible) {
				for(uint i = 0, cnt = statuses.length; i < cnt; ++i) {
					if(statuses[i].type.conditionFrequency <= 0 && statuses[i].type.visibility != StV_Global) {
						statuses.removeAt(i);
						--i; --cnt;
					}
				}
			}
			uint prevCnt = statusIcons.length, cnt = statuses.length;
			for(uint i = cnt; i < prevCnt; ++i)
				statusIcons[i].remove();
			statusIcons.length = cnt;
			statusBox.visible = cnt != 0;
			for(uint i = 0; i < cnt; ++i) {
				auto@ icon = statusIcons[i];
				if(icon is null) {
					@icon = GuiStatusBox(statusBox, recti_area(2, 2+32*i, 30, 30));
					icon.noClip = true;
					@statusIcons[i] = icon;
				}
				icon.update(statuses[i]);
			}
		}

		Popup::update();
		Popup::updatePosition(obj);
	}
};

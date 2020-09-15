#section game
import elements.BaseGuiElement;
import elements.GuiSprite;
import elements.GuiText;
import elements.MarkupTooltip;
import cargo;

class GuiCargoDisplay : BaseGuiElement {
	array<GuiSprite@> icons;
	array<GuiText@> values;

	int padding = 2;
	int iconSize = 21;

	GuiCargoDisplay(IGuiElement@ parent, Alignment@ align) {
		super(parent, align);
	}

	GuiCargoDisplay(IGuiElement@ parent, const recti& pos) {
		super(parent, pos);
	}

	void update(Object& obj) {
		uint oldCnt = icons.length;
		uint newCnt = obj.cargoTypes;
		for(uint i = newCnt; i < oldCnt; ++i) {
			icons[i].remove();
			values[i].remove();
		}
		icons.length = newCnt;
		values.length = newCnt;
		for(uint i = oldCnt; i < newCnt; ++i) {
			@icons[i] = GuiSprite(this, recti(21,21));
			@values[i] = GuiText(this, recti());
			values[i].font = FT_Detail;
			values[i].stroke = colors::Black;
			values[i].horizAlign = 0.5;
		}

		const Font@ ft = skin.getFont(FT_Normal);
		int x = padding, s = size.height-padding-padding;
		for(uint i = 0; i < newCnt; ++i) {
			auto@ type = getCargoType(obj.cargoType[i]);
			if(type is null)
				continue;
			double amount = obj.getCargoStored(type.id);
			string ttip = format("[font=Medium]$1[/font] [img=$2;24/]\n$3", type.name, getSpriteDesc(type.icon), type.description);

			icons[i].rect = recti_area(x, padding, iconSize, iconSize);
			icons[i].desc = type.icon;
			setMarkupTooltip(icons[i], ttip);
			//x += s + padding;

			string txt = standardize(amount, true);
			int w = s + padding;

			values[i].rect = recti_area(x, padding + 8, w, s);
			values[i].text = txt;
			setMarkupTooltip(values[i], ttip);
			x += iconSize + padding;
		}
	}
};

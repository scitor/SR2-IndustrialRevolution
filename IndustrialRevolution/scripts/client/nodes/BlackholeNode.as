
//Draws a blackhole and its accretion disk
final class BlackholeNodeScript {	
	BlackholeNodeScript(Node& node) {
		node.transparent = true;
		node.customColor = true;
		node.autoCull = false;
	}
	
	void establish(Node& node, Star& star) {
		auto@ gfx = PersistentGfx();
		if(star.radius > 100.0)
			gfx.establish(star, "BlackholeGlitterJets");
		else
			gfx.establish(star, "BlackholeGlitter");
		gfx.rotate(quaterniond_fromAxisAngle(vec3d_right(), pi * 0.5));
	}
	
	bool preRender(Node& node) {
		return isSphereVisible(node.abs_position, 20.0 * node.abs_scale);
	}

	void render(Node& node) {
		double dist = node.sortDistance / (2500.0 * node.abs_scale * pixelSizeRatio);
		
		if(dist < 1.0) {
			node.applyTransform();
			
			material::Blackhole.switchTo();
			model::Sphere_max.draw(node.sortDistance / (node.abs_scale * pixelSizeRatio));
			
			undoTransform();
			
			renderPlane(material::AccretionDisk, node.abs_position, node.abs_scale * 40.0 * (1.0-dist), Color(0xffffffff));
			if(dist < 0.5)
				renderBillboard(material::GravitationLens, node.abs_position + (cameraPos - node.abs_position).normalize(node.abs_scale*1.5), node.abs_scale * 10.0 * (0.5-dist), 0.0, Color(0x00000000));
		}
		
		if(dist > 0.5) {
			Color col(node.color);
			col.a = dist > 1.0 ? 255 : int((dist - 0.5)*255.0/0.5);
			renderBillboard(material::DistantStar, node.abs_position, node.abs_scale * 320.0, 0.0, col);
		}
	}
};

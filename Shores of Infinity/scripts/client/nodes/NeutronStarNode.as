
//Draws a neutron star and its accretion disk
final class NeutronStarNodeScript {
	double storedTime = 0;
	double rotation = 0;

	NeutronStarNodeScript(Node& node) {
		node.transparent = true;
		node.customColor = true;
		node.autoCull = false;
	}

	void establish(Node& node, Star& star) {
		/*auto@ gfx = PersistentGfx();
		gfx.establish(star, "BlackholeGlitter");
		gfx.rotate(quaterniond_fromAxisAngle(vec3d_right(), pi * 0.5));*/
	}

	bool preRender(Node& node) {
		return isSphereVisible(node.abs_position, 20.0 * node.abs_scale);
	}

	void render(Node& node) {
		double dist = node.sortDistance / (2500.0 * node.abs_scale * pixelSizeRatio);

		if(dist < 1.0) {
			vec3d upLeft, upRight, center = node.abs_position;
			getBillboardVecs(center, upLeft, upRight, 0.0);

			upLeft *= node.abs_scale * 1.5;
			upRight *= node.abs_scale * 1.5;

			renderPlane(material::AccretionDisk, node.abs_position, node.abs_scale * 10.0, Color(0xffffffff));

			Color col(node.color);
			col.r = 64;
			col.g = 64;


			double elapsedTime = storedTime - gameTime;
			storedTime = gameTime;
			rotation += elapsedTime;
			if (rotation > pi * 2)
				rotation = 0;
			renderBillboard(material::DistantStar, node.abs_position, node.abs_scale * 15, rotation, col);
		}

		if(dist > 0.5) {
			Color col(node.color);
			col.a = dist > 1.0 ? 255 : int((dist - 0.5)*255.0/0.5);

			//SoI - Scaling
			renderBillboard(material::DistantStar, node.abs_position, node.abs_scale * 256.0 * config::SCALE_SPACING, 0.0, col);
		}
	}
};

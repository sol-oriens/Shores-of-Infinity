
//Draws a brown dwarf star
final class BrownDwarfNodeScript {

	BrownDwarfNodeScript(Node& node) {
		node.transparent = true;
		node.customColor = true;
		node.autoCull = false;
	}

	bool preRender(Node& node) {
		return isSphereVisible(node.abs_position, 20.0 * node.abs_scale);
	}

	void render(Node& node) {
		double dist = node.sortDistance / (2500.0 * node.abs_scale * pixelSizeRatio);

		if(dist < 1.0) {
			node.applyTransform();

			material::BrownDwarf.switchTo();
			model::Sphere_max.draw(node.sortDistance / (node.abs_scale * pixelSizeRatio));

			undoTransform();
		}

		if(dist > 0.5) {
			Color col(node.color);
			col.a = dist > 1.0 ? 255 : int((dist - 0.5)*255.0/0.5);

			//SoI - Scaling
			renderBillboard(material::DistantStar, node.abs_position, node.abs_scale * 256.0 * config::SCALE_SPACING, 0.0, col);
		}
	}
};

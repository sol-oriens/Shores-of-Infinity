import orbitals;
from nodes.FleetPlane import SHOW_FLEET_PLANES;

//SoI - Scaling: max icon size
const double MAX_SIZE = 10000.0;

final class PickupNodeScript {
	const Pickup@ obj;
	const OrbitalModule@ def;
	double fleetPlane = 0.0;

	PickupNodeScript(Node& node) {
		node.transparent = true;
		node.memorable = true;
	}

	void establish(Node& node, Pickup& pickup, uint type) {
		@obj = pickup;
		@def = getOrbitalModule(type);
	}

	void setFleetPlane(double radius) {
		fleetPlane = radius;
	}

	void render(Node& node) {
		if(def is null)
			return;

		if(fleetPlane != 0 && node.sortDistance < 2000.0 && node.sortDistance >= 150.0 && SHOW_FLEET_PLANES) {
			Color color(0xffffff14);
			//SoI - Scaling
			if(node.sortDistance < 500.0)
				color.a = double(color.a) * (node.sortDistance - 150.0) / 100.0;
			renderPlane(material::FleetCircle, node.abs_position, fleetPlane, color);
		}

		node.applyTransform();

		def.material.switchTo();
		def.model.draw();

		undoTransform();

		//SoI - Scaling
		if(node.sortDistance > 1000.0 && def.distantIcon.valid) {
			//SoI - Scaling: pickup icon size
			double size = obj.radius * def.iconSize;
			size *= node.sortDistance * 0.09;
			size = min(size, MAX_SIZE);
			if(obj.selected)
				size *= 1.1;

			Empire@ owner = obj.owner;
			Color col;
			if(owner !is null)
				col = owner.color;
			renderBillboard(def.distantIcon.sheet, def.distantIcon.index, node.abs_position, size, 0.0, col);
		}
	}
};

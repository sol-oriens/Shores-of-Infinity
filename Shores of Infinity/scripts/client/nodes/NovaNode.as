//Draws an expanding, darkening nova
final class NovaNodeScript {
	double life = 0, duration = 900.0;
	double lastTick = gameTime;
	double alpha = 1.0;

	NovaNodeScript(Node& node) {
		node.transparent = true;
		node.customColor = true;
	}

	bool preRender(Node& node) {
		double t = gameTime;
		if(t > lastTick) {
			double time = t - lastTick;
			lastTick = t;

			life += time;
			if(life > duration) {
				node.markForDeletion();
				return false;
			}

			alpha = 1.0 - (life / duration);

			//SoI - Scaling
			node.scale = 10000.0 * config::SCALE_STARS + 10000.0 * config::SCALE_STARS * life / duration;

			node.rebuildTransform();
		}

		return true;
	}

	void render(Node& node) {
		node.applyTransform();

		shader::NOVA_AGE = life / duration;

		material::Nova.switchTo();
		model::Sphere_max.draw(node.sortDistance / (node.abs_scale * pixelSizeRatio));

		undoTransform();
	}
};

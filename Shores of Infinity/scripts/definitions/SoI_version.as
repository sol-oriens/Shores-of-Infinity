import version;
import ABEM_version;

namespace SoI {
	const array<string> VERSIONS = {
		"v2.0.3",
	};

	const array<string> REVISIONS = {
		"5101",
		"5095",
	};
	const string MOD_NAME = "Shores of Infinity v0.3.3b";
	const string MOD_REVISION = "2004172240";
	const string MOD_VERSION = MOD_NAME + " (revision " + MOD_REVISION + ") for Star Ruler 2 " + VERSIONS[0] + " (revision " + REVISIONS[0]
		+ ", currently using " + GAME_VERSION + " " + SCRIPT_VERSION + ")";
	const string RS_MOD_VERSION = ::MOD_NAME + " (revision " + ::MOD_REVISION + ")";

	string getLowestSupported(string input) {
		print(input.split("; ")[0]);
		return input.split("; ")[0];
	};

	bool checkSupported() {
		bool resultA = false;
		bool resultB = false;
		for(uint i = 0; i < VERSIONS.length; ++i) {
			if(VERSIONS[i].equals_nocase(GAME_VERSION)) {
				resultA = true;
				break;
			}
		}
		if(resultA) {
			for(uint i = 0; i < REVISIONS.length; ++i) {
				if(("r" + REVISIONS[i]).equals_nocase(SCRIPT_VERSION)) {
					resultB = true;
					break;
				}
			}
		}
		if(resultA && resultB)
			return true;
		else {
			error("Mod " + MOD_NAME + " does not support current game version " + GAME_VERSION + "(" + SCRIPT_VERSION + "), use with caution!");
			return false;
		}
	}
}

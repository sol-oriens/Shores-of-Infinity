//Search for a match in multiple values without a ugly
//if (foo == bar) || (foo == baz) || ..." list
//Allow a syntax close to a switch / case structure with variables
final class Lookup {
	private int _nValue;
	private string _sValue;

	Lookup(int value) {
		_nValue = value;
	}
	
	Lookup(string value) {
		_sValue = value;
	}

	bool isIn(const int[]& values) {
		return values.find(_nValue) != -1;
	}
	
	bool isIn(const string[]& values) {
	return values.find(_sValue) != -1;
	}
};

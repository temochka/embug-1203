#include <exception>
#include <iostream>

class EmbugA {
	int base;

	public:
	EmbugA(int base) : base(base) {}
	
	int demo(int x) {
		if (x < 0) {
			throw std::runtime_error("This will not get caught.");
		}
		return base + x;
	}
};

extern "C" {
	int embuga_demo(int x) {
		EmbugA embug(42);
		try {
			return embug.demo(x);
		}
		catch (const std::exception &) {
			std::cerr << "Error!\n";
		}
		return -1;
	}
}


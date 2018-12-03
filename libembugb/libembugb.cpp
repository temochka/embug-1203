#include <exception>
#include <iostream>

class EmbugB {
	int base;

	public:
	EmbugB(int base) : base(base) {}
	
	int demo(int x) {
		if (x < 0) {
			throw std::runtime_error("This will not get caught.");
		}
		return base + x;
	}
};

extern "C" {
	int embugb_demo(int x) {
		EmbugB embug(42);
		try {
			return embug.demo(x);
		}
		catch (const std::exception &) {
			std::cerr << "Error!\n";
		}
		return -1;
	}
}


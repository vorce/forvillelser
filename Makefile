.PHONY: build

all: build ;

clean:
	rm -rf build

build:
	mix gonz.build forvillelser all

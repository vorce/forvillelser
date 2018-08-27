.PHONY: build

all: build ;

deps: mix.exs
	mix deps.get
	touch deps

clean:
	rm -rf build

build: deps
	mix gonz.build forvillelser docs

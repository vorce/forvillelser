.PHONY: build dev

all: build ;

deps: mix.exs
	mix local.hex --force
	mix local.rebar --force
	mix deps.get
	touch deps

clean:
	rm -rf build

build: deps
	mix gonz.build forvillelser build

dev: build
	mix gonz.serve build 4001
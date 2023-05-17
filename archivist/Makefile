.PHONY: build

build:
	sam build

invoke: build
	sam local invoke -e test-input.json


.PHONY: build run

DERIVED_DATA_PATH ?= .build/XcodeDerivedData

build:
	DERIVED_DATA_PATH="$(DERIVED_DATA_PATH)" ./scripts/run.sh --build-only

run:
	DERIVED_DATA_PATH="$(DERIVED_DATA_PATH)" ./scripts/run.sh

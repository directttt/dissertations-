.PHONY: help phase0 phase1 phase2 phase3 phase4 run list

PY ?= python

help:
	@echo "Targets:"
	@echo "  make list                 - list built-in phase presets"
	@echo "  make run CFG=exp/<file>   - run one YAML config"
	@echo "  make phase0|phase1|...    - run a full phase preset"

list:
	@cd ./ && $(PY) -m src.cli list

run:
	@test -n "$(CFG)" || (echo "Missing CFG. Example: make run CFG=exp/exp_baseline_seed41.yaml" && exit 1)
	@cd ./ && $(PY) -m src.cli run --config $(CFG)

phase0:
	@cd ./ && $(PY) -m src.cli phase --name phase0

phase1:
	@cd ./ && $(PY) -m src.cli phase --name phase1

phase2:
	@cd ./ && $(PY) -m src.cli phase --name phase2

phase3:
	@cd ./ && $(PY) -m src.cli phase --name phase3

phase4:
	@cd ./ && $(PY) -m src.cli phase --name phase4


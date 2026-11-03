.PHONY: check assets

check:
	bash -n setup.sh update.sh
	python3 -m py_compile generate_icon.py tools/build_assets.py
	@echo "syntax checks passed"

assets:
	python3 tools/build_assets.py

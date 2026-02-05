
.PHONY: lint test deps check-plenary

PLENARY_DIR ?= tests/vendor/plenary.nvim
PLENARY_REF ?= v0.1.4

deps: $(PLENARY_DIR)

$(PLENARY_DIR):
	@mkdir -p $(dir $@)
	git clone --depth 1 --branch $(PLENARY_REF) https://github.com/nvim-lua/plenary.nvim $@

lint:
	stylua --check lua plugin tests

check-plenary:
	@if [ ! -d "$(PLENARY_DIR)" ]; then \
		echo "Plenary not found at $(PLENARY_DIR)."; \
		echo "Provide PLENARY_DIR or run 'make deps' to fetch it."; \
		exit 1; \
	fi

test: check-plenary
	PLENARY_DIR="$(PLENARY_DIR)" nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/prompt-yank { minimal_init = './tests/minimal_init.lua' }" -c "qa!"

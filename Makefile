# ==============================================================================
# MING Stack Makefile
# ==============================================================================

.PHONY: help up down restart logs ps clean pull build test-mqtt test-sandbox \
        ollama-pull ollama-list up-edge up-genai status interactive start stop \
        run-inference

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
CYAN   := \033[0;36m
RED    := \033[0;31m
BOLD   := \033[1m
DIM    := \033[2m
NC     := \033[0m

# Service groups
EDGE_SERVICES := mqtt influxdb node-red grafana
GENAI_SERVICES := n8n ollama letta kokoro

# Default target
help:
	@echo ""
	@printf "$(BOLD)$(CYAN)  MING Stack$(NC) - Available Commands\n"
	@echo "  ════════════════════════════════════════════"
	@echo ""
	@printf "  $(BOLD)Core:$(NC)\n"
	@printf "    $(GREEN)make up$(NC)              Start all services\n"
	@printf "    $(GREEN)make down$(NC)            Stop all services\n"
	@printf "    $(GREEN)make restart$(NC)         Restart all services\n"
	@printf "    $(GREEN)make status$(NC)          Show service status table\n"
	@printf "    $(GREEN)make logs$(NC)            Follow logs for all services\n"
	@printf "    $(GREEN)make ps$(NC)              Docker compose ps\n"
	@printf "    $(GREEN)make pull$(NC)            Pull latest images\n"
	@printf "    $(GREEN)make clean$(NC)           Stop and remove volumes\n"
	@echo ""
	@printf "  $(BOLD)Modular:$(NC)\n"
	@printf "    $(GREEN)make interactive$(NC)     Interactive service selector\n"
	@printf "    $(GREEN)make up-edge$(NC)         Start Edge AI layer only\n"
	@printf "    $(GREEN)make up-genai$(NC)        Start Gen AI layer only\n"
	@printf "    $(GREEN)make start SERVICE=x$(NC) Start a service + its deps\n"
	@printf "    $(GREEN)make stop SERVICE=x$(NC)  Stop a service (warns about deps)\n"
	@echo ""
	@printf "  $(BOLD)Ollama:$(NC)\n"
	@printf "    $(GREEN)make ollama-pull$(NC)     Pull default model (llama3.2)\n"
	@printf "    $(GREEN)make ollama-list$(NC)     List downloaded models\n"
	@echo ""
	@printf "  $(BOLD)Testing:$(NC)\n"
	@printf "    $(GREEN)make test-mqtt$(NC)       Publish test data to MQTT\n"
	@printf "    $(GREEN)make test-sandbox$(NC)    Publish test data to sandbox bucket\n"
	@echo ""
	@printf "  $(BOLD)Edge Impulse:$(NC)\n"
	@printf "    $(GREEN)make build$(NC)           Build Edge Impulse runner image\n"
	@printf "    $(GREEN)make run-inference$(NC)   Run inference (demo mode)\n"
	@echo ""

# ------------------------------------------------------------------------------
# Core Commands
# ------------------------------------------------------------------------------

up:
	@echo "Starting MING stack..."
	docker compose up -d
	@echo ""
	@echo "Services started! Access them at:"
	@printf "  $(CYAN)Grafana$(NC):   http://localhost:3000\n"
	@printf "  $(CYAN)Node-RED$(NC):  http://localhost:1880\n"
	@printf "  $(CYAN)n8n$(NC):       http://localhost:5678\n"
	@printf "  $(CYAN)InfluxDB$(NC):  http://localhost:8086\n"
	@printf "  $(CYAN)Letta$(NC):     http://localhost:8283\n"
	@printf "  $(CYAN)Ollama$(NC):    http://localhost:11434\n"
	@printf "  $(CYAN)Kokoro$(NC):    http://localhost:8880\n"
	@echo ""

down:
	@echo "Stopping MING stack..."
	docker compose down

restart:
	@echo "Restarting MING stack..."
	docker compose restart

logs:
	docker compose logs -f

ps:
	docker compose ps

pull:
	@echo "Pulling latest images..."
	docker compose pull

clean:
	@printf "$(RED)$(BOLD)  WARNING: This will DELETE ALL DATA (InfluxDB, Grafana, Ollama models, etc.)$(NC)\n"
	@read -p "  Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo "Stopping services and removing volumes..."; \
		docker compose down -v; \
		echo "Cleaned up!"; \
	else \
		echo "Cancelled."; \
	fi

# ------------------------------------------------------------------------------
# Status (colorized service table)
# ------------------------------------------------------------------------------

status:
	@echo ""
	@printf "$(BOLD)$(CYAN)  MING Stack - Service Status$(NC)\n"
	@echo "  ════════════════════════════════════════════════════════════════════"
	@printf "  $(BOLD)%-14s %-12s %-8s %-12s %s$(NC)\n" "SERVICE" "STATUS" "PORT" "LAYER" "URL"
	@printf "  $(DIM)%-14s %-12s %-8s %-12s %s$(NC)\n" "─────────────" "──────────" "──────" "──────────" "───────────────────────────"
	@for svc in mqtt influxdb node-red grafana n8n ollama letta kokoro; do \
		container="ming-$$svc"; \
		state=$$(docker inspect --format='{{.State.Status}}' $$container 2>/dev/null || echo "stopped"); \
		case $$svc in \
			mqtt)      port="1883"; layer="Edge AI"; url="-" ;; \
			influxdb)  port="8086"; layer="Edge AI"; url="http://localhost:8086" ;; \
			node-red)  port="1880"; layer="Edge AI"; url="http://localhost:1880" ;; \
			grafana)   port="3000"; layer="Edge AI"; url="http://localhost:3000" ;; \
			n8n)       port="5678"; layer="Gen AI";  url="http://localhost:5678" ;; \
			ollama)    port="11434"; layer="Gen AI"; url="http://localhost:11434" ;; \
			letta)     port="8283"; layer="Gen AI";  url="http://localhost:8283" ;; \
			kokoro)    port="8880"; layer="Gen AI";  url="http://localhost:8880" ;; \
		esac; \
		if [ "$$state" = "running" ]; then \
			printf "  $(BOLD)%-14s$(NC) $(GREEN)%-12s$(NC) %-8s $(CYAN)%-12s$(NC) %s\n" "$$svc" "running" "$$port" "$$layer" "$$url"; \
		else \
			printf "  $(BOLD)%-14s$(NC) $(RED)%-12s$(NC) %-8s $(DIM)%-12s$(NC) $(DIM)%s$(NC)\n" "$$svc" "$$state" "$$port" "$$layer" "-"; \
		fi; \
	done
	@echo ""

# ------------------------------------------------------------------------------
# Interactive Service Selector
# ------------------------------------------------------------------------------

interactive:
	@bash scripts/selector.sh

# ------------------------------------------------------------------------------
# Granular Start/Stop with Dependency Awareness
# ------------------------------------------------------------------------------

# Dependency map
deps_mqtt :=
deps_influxdb :=
deps_node-red := mqtt influxdb
deps_grafana := influxdb
deps_n8n := mqtt ollama
deps_ollama :=
deps_letta := ollama
deps_kokoro :=

# Reverse deps (what breaks)
rdeps_mqtt := node-red n8n
rdeps_influxdb := node-red grafana
rdeps_ollama := n8n letta
rdeps_node-red :=
rdeps_grafana :=
rdeps_n8n :=
rdeps_letta :=
rdeps_kokoro :=

start:
ifndef SERVICE
	@printf "$(RED)  Usage: make start SERVICE=<name>$(NC)\n"
	@printf "  Available: $(BOLD)mqtt influxdb node-red grafana n8n ollama letta kokoro$(NC)\n"
	@exit 1
endif
	@deps="$(deps_$(SERVICE))"; \
	if [ -n "$$deps" ]; then \
		printf "$(YELLOW)  Auto-starting dependencies: $(BOLD)$$deps$(NC)\n"; \
		docker compose up -d $$deps; \
	fi
	@printf "$(GREEN)  Starting $(BOLD)$(SERVICE)$(NC)$(GREEN)...$(NC)\n"
	@docker compose up -d $(SERVICE)
	@printf "$(GREEN)$(BOLD)  Done!$(NC)\n"

stop:
ifndef SERVICE
	@printf "$(RED)  Usage: make stop SERVICE=<name>$(NC)\n"
	@printf "  Available: $(BOLD)mqtt influxdb node-red grafana n8n ollama letta kokoro$(NC)\n"
	@exit 1
endif
	@rdeps="$(rdeps_$(SERVICE))"; \
	if [ -n "$$rdeps" ]; then \
		for dep in $$rdeps; do \
			state=$$(docker inspect --format='{{.State.Status}}' "ming-$$dep" 2>/dev/null || echo "stopped"); \
			if [ "$$state" = "running" ]; then \
				printf "$(RED)  WARNING: Stopping '$(SERVICE)' will affect running service: $(BOLD)$$dep$(NC)\n"; \
			fi; \
		done; \
	fi
	@printf "$(YELLOW)  Stopping $(BOLD)$(SERVICE)$(NC)$(YELLOW)...$(NC)\n"
	@docker compose stop $(SERVICE)
	@printf "$(GREEN)$(BOLD)  Done!$(NC)\n"

# ------------------------------------------------------------------------------
# Partial Stack Commands
# ------------------------------------------------------------------------------

up-edge:
	@echo "Starting Edge AI layer..."
	docker compose up -d $(EDGE_SERVICES)

up-genai:
	@echo "Starting Gen AI layer..."
	docker compose up -d $(GENAI_SERVICES)

# ------------------------------------------------------------------------------
# Ollama Commands
# ------------------------------------------------------------------------------

ollama-pull:
	@echo "Pulling llama3.2 model..."
	docker compose exec ollama ollama pull llama3.2

ollama-list:
	docker compose exec ollama ollama list

# ------------------------------------------------------------------------------
# Testing Commands
# ------------------------------------------------------------------------------

test-mqtt:
	@echo "Publishing test sensor data to MQTT..."
	docker run --rm --network ming-network eclipse-mosquitto:2 \
		mosquitto_pub -h mqtt -t 'sensors/temperature' \
		-m '{"value": 23.5, "unit": "C", "device": "test-sensor"}'
	@echo "Publishing test inference result..."
	docker run --rm --network ming-network eclipse-mosquitto:2 \
		mosquitto_pub -h mqtt -t 'inference/results' \
		-m '{"model": "test", "label": "idle", "confidence": 0.95, "latency": 25.3}'
	@echo "Done! Check Node-RED debug panel."

test-sandbox:
	@printf "$(CYAN)  Publishing test data to sandbox bucket...$(NC)\n"
	@docker run --rm --network ming-network eclipse-mosquitto:2 \
		mosquitto_pub -h mqtt -t 'sandbox/sensors/temperature' \
		-m '{"value": 22.1, "unit": "C", "device": "sandbox-sensor-1", "sandbox": true}'
	@docker run --rm --network ming-network eclipse-mosquitto:2 \
		mosquitto_pub -h mqtt -t 'sandbox/sensors/humidity' \
		-m '{"value": 65.3, "unit": "%", "device": "sandbox-sensor-1", "sandbox": true}'
	@docker run --rm --network ming-network eclipse-mosquitto:2 \
		mosquitto_pub -h mqtt -t 'sandbox/inference/results' \
		-m '{"model": "sandbox-test", "label": "anomaly", "confidence": 0.87, "latency": 18.5, "sandbox": true}'
	@printf "$(GREEN)  Sandbox test data published!$(NC)\n"
	@printf "$(DIM)  Configure Node-RED to route 'sandbox/#' topics to the sandbox bucket.$(NC)\n"
	@printf "$(DIM)  View in Grafana using the 'InfluxDB-Sandbox' datasource.$(NC)\n"

# ------------------------------------------------------------------------------
# Edge Impulse Commands
# ------------------------------------------------------------------------------

build:
	@echo "Building Edge Impulse runner image..."
	docker build -t ming-edge-impulse .

run-inference:
	@echo "Running Edge Impulse inference (demo mode)..."
	docker run --rm -it --network ming-network \
		-e MQTT_BROKER=ming-mqtt \
		ming-edge-impulse

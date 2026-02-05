# ==============================================================================
# MING Stack Makefile
# ==============================================================================

.PHONY: help up down restart logs ps clean pull build test-mqtt ollama-pull

# Default target
help:
	@echo "MING Stack - Available Commands"
	@echo "================================"
	@echo ""
	@echo "  make up            Start all services"
	@echo "  make down          Stop all services"
	@echo "  make restart       Restart all services"
	@echo "  make logs          Follow logs for all services"
	@echo "  make ps            Show running services"
	@echo "  make pull          Pull latest images"
	@echo "  make clean         Stop services and remove volumes"
	@echo ""
	@echo "  make up-edge       Start Edge AI layer only"
	@echo "  make up-genai      Start Gen AI layer only"
	@echo ""
	@echo "  make ollama-pull   Pull default Ollama model (llama3.2)"
	@echo "  make test-mqtt     Publish test message to MQTT"
	@echo ""
	@echo "  make build         Build Edge Impulse runner image"
	@echo "  make run-inference Run Edge Impulse inference (demo mode)"
	@echo ""

# ------------------------------------------------------------------------------
# Core Commands
# ------------------------------------------------------------------------------

up:
	@echo "Starting MING stack..."
	docker compose up -d
	@echo ""
	@echo "Services started! Access them at:"
	@echo "  - Grafana:   http://localhost:3000"
	@echo "  - Node-RED:  http://localhost:1880"
	@echo "  - n8n:       http://localhost:5678"
	@echo "  - InfluxDB:  http://localhost:8086"
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
	@echo "Stopping services and removing volumes..."
	docker compose down -v
	@echo "Cleaned up!"

# ------------------------------------------------------------------------------
# Partial Stack Commands
# ------------------------------------------------------------------------------

up-edge:
	@echo "Starting Edge AI layer..."
	docker compose up -d mqtt influxdb node-red grafana

up-genai:
	@echo "Starting Gen AI layer..."
	docker compose up -d n8n ollama letta kokoro

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

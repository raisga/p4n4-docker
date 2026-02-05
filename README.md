# ming-wei

> Dockerized **MING stack** (with Edge Impulse) and Gen AI services support, bootstraping development environment for IoT and Edge AI engineers.

The MING stack (MQTT, InfluxDB, Node-RED, Grafana) is a proven open-source foundation for IoT data pipelines. This project packages it into a single `docker compose` setup and extends it with **Edge Impulse** for on-device ML inference and a **Gen AI** layer (n8n, Letta, Ollama, Kokoro) for intelligent automation and natural-language interaction.

---

## Table of Contents

- [Architecture](#architecture)
- [Stack Components](#stack-components)
  - [Edge AI Layer](#edge-ai-layer)
  - [Gen AI Layer](#gen-ai-layer)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Usage](#usage)
- [Default Ports](#default-ports)
- [Default Credentials](#default-credentials)
- [Resources](#resources)
- [License](#license)

---

## Architecture

```
    ┌───────────────────────────────────────────────────────────────────────┐  
    │                              Edge AI Layer                            │  
    └───────────────────────────────────────────────────────────────────────┘  
     [Edge Impulse] ──► [MQTT] ──► [Node-RED]  ──► [InfluxDB]  ──► [Grafana]   
                           │           ▲               ▲                       
                           │           │               │                       
                           │           │               │                       
                           ▼           │               │                       
                         ┌───────────────────────────────┐                     
    [Cloud Services] ◀► │          Gen AI Layer         │                      
                         └───────────────────────────────┘                     
                                  [n8n]                                        
                                 /     \                                       
                                ▼       ▼                                      
                           [Letta]   [Kokoro]                                  
                              │                                                
                              ▼                                                
                          [Ollama]                                             
```

**Data flow:** Edge Impulse runs ML models on a device and publishes inference results over MQTT. InfluxDB stores the time-series data, Node-RED orchestrates workflows and business logic, and Grafana visualizes everything. The Gen AI layer connects through n8n, which can subscribe to MQTT topics or query InfluxDB, then delegate to Letta agents backed by Ollama LLMs and Kokoro text-to-speech.

---

## Stack Components

### Edge AI Layer

| Service | Role | Description |
|---------|------|-------------|
| **[Eclipse Mosquitto (MQTT)](https://mosquitto.org/)** | Message Broker | A lightweight MQTT broker that acts as the central nervous system of the IoT pipeline. Devices and services publish/subscribe to topics to exchange sensor readings, inference results, and commands with minimal overhead. |
| **[InfluxDB](https://www.influxdata.com/)** | Time-Series Database | Purpose-built for high-write, time-stamped workloads. Stores every inference result and sensor reading with nanosecond precision so you can query, downsample, and retain data efficiently. |
| **[Node-RED](https://nodered.org/)** | Workflow Engine | A low-code, flow-based programming tool for wiring together MQTT topics, HTTP APIs, databases, and custom logic. Ideal for building IoT processing pipelines, alerting rules, and device control flows without writing boilerplate. |
| **[Grafana](https://grafana.com/)** | Data Visualization | A dashboarding platform that connects directly to InfluxDB (and other data sources) to render real-time charts, gauges, and alerts. Provides at-a-glance operational visibility into device health and inference performance. |
| **[Edge Impulse](https://edgeimpulse.com/)** | ML Inference | An end-to-end platform for developing and deploying embedded ML models. The Linux SDK runs trained models on-device and streams classification or anomaly-detection results into MQTT for downstream processing. |

### Gen AI Layer

| Service | Role | Description |
|---------|------|-------------|
| **[n8n](https://n8n.io/)** | Workflow Automation | A self-hosted workflow automation platform with 400+ integrations. Bridges the Edge AI and Gen AI layers by subscribing to MQTT events or polling InfluxDB, then triggering LLM-powered actions, notifications, or cloud service calls. |
| **[Letta](https://github.com/letta-ai/letta)** | AI Agent Framework | Provides stateful, long-term-memory agents that can reason over conversation history and tool calls. Acts as the orchestration brain that decides when and how to invoke Ollama for generation or Kokoro for speech output. |
| **[Ollama](https://ollama.com/)** | Local LLM Runtime | Runs open-weight large language models (Llama, Mistral, Gemma, etc.) entirely on local hardware with a simple REST API. Keeps inference private and eliminates external API costs. |
| **[Kokoro](https://github.com/remsky/Kokoro-FastAPI)** | Text-to-Speech | A fast, local TTS engine that converts LLM-generated text into natural-sounding audio. Enables voice-based alerts, spoken summaries, or accessibility interfaces without cloud dependencies. |

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/) (v2.0+)
- At least **8 GB RAM** available to Docker (16 GB recommended when running Ollama with larger models)
- An [Edge Impulse](https://edgeimpulse.com/) account and a trained project (for on-device inference)

---

## Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/raisga/ming-wei.git
   cd ming-wei
   ```

2. **Configure environment variables**

   ```bash
   cp .env.example .env
   # Edit .env to set passwords, tokens, and model names
   ```

3. **Start the stack**

   ```bash
   docker compose up -d
   ```

4. **Verify services are running**

   ```bash
   docker compose ps
   ```

5. **Open the dashboards**

   - Grafana: <http://localhost:3000>
   - Node-RED: <http://localhost:1880>
   - n8n: <http://localhost:5678>
   - InfluxDB: <http://localhost:8086>

6. **(Optional) Pull an Ollama model**

   ```bash
   make ollama-pull
   # Or manually: docker compose exec ollama ollama pull llama3.2
   ```

---

## Project Structure

```
ming-wei/
├── docker-compose.yml          # Main orchestration file for all services
├── Dockerfile                  # Edge Impulse inference runner image
├── Makefile                    # Convenience commands (make up, make down, etc.)
├── .env.example                # Environment template (copy to .env)
├── .gitignore                  # Git ignore rules
├── config/
│   ├── mosquitto/
│   │   └── mosquitto.conf      # MQTT broker configuration
│   ├── node-red/
│   │   ├── settings.js         # Node-RED runtime settings
│   │   └── flows.json          # Sample MQTT-to-InfluxDB flow
│   └── grafana/
│       └── provisioning/
│           ├── datasources/
│           │   └── datasources.yml   # Auto-configure InfluxDB datasource
│           └── dashboards/
│               ├── dashboards.yml    # Dashboard provisioning config
│               └── json/
│                   └── iot-overview.json  # Sample IoT dashboard
├── scripts/
│   └── inference.py            # Edge Impulse inference script with MQTT
├── LICENSE
└── README.md
```

---

## Usage

### Using Make Commands

```bash
make help           # Show all available commands

make up             # Start the full stack
make down           # Stop all services
make restart        # Restart all services
make logs           # Follow logs from all services
make ps             # Show service status

make up-edge        # Start only Edge AI layer (MQTT, InfluxDB, Node-RED, Grafana)
make up-genai       # Start only Gen AI layer (n8n, Ollama, Letta, Kokoro)

make test-mqtt      # Publish test messages to MQTT
make ollama-pull    # Pull llama3.2 model into Ollama
make clean          # Stop services and remove all data volumes
```

### Testing the Data Pipeline

1. Start the stack: `make up`
2. Open Node-RED: <http://localhost:1880>
3. Deploy the sample flow (it auto-loads from `flows.json`)
4. Publish test data:

   ```bash
   make test-mqtt
   ```

5. Open Grafana: <http://localhost:3000> and view the "IoT Overview" dashboard

### Running Edge Impulse Inference

Build and run the inference container (demo mode without a real model):

```bash
make build
make run-inference
```

For real inference with a trained model:

```bash
docker run --rm -it --network ming-network \
  --device /dev/video0 \
  -v /path/to/model.eim:/app/model/model.eim \
  -e EI_MODEL_PATH=/app/model/model.eim \
  -e MQTT_BROKER=ming-mqtt \
  ming-edge-impulse
```

### GPU Support for Ollama

To enable NVIDIA GPU acceleration, edit `docker-compose.yml` and uncomment the `deploy` section under the `ollama` service:

```yaml
ollama:
  # ...
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
```

---

## Default Ports

| Service          | Port                              |
|------------------|-----------------------------------|
| MQTT (Mosquitto) | `1883` (MQTT), `9001` (WebSocket) |
| InfluxDB         | `8086`                            |
| Node-RED         | `1880`                            |
| Grafana          | `3000`                            |
| n8n              | `5678`                            |
| Letta            | `8283`                            |
| Ollama           | `11434`                           |
| Kokoro           | `8880`                            |

---

## Default Credentials

All credentials can be customized in `.env`. Defaults (from `.env.example`):

| Service  | Username | Password        |
|----------|----------|-----------------|
| InfluxDB | `admin`  | `adminpassword` |
| Grafana  | `admin`  | `adminpassword` |
| n8n      | `admin`  | `adminpassword` |

**Note:** Change these before deploying to production!

---

## Resources

- [MING Stack Tutorial](https://github.com/ArthurKretzer/tutorial-ming-stack) -- IIoT data stack tutorial presented at XIV SBESC (2024) with Docker Compose setup, Node-RED flows, and Grafana dashboards
- [MING Stack with Edge Impulse](https://www.edgeimpulse.com/blog/accelerate-edge-ai-application-development-with-the-ming-stack-edge-impulse/) -- Tech stack architecture and integration guide
- [Edge Impulse Linux SDK (Python)](https://github.com/edgeimpulse/linux-sdk-python) -- Python SDK for on-device inference
- [Eclipse Mosquitto](https://mosquitto.org/) -- MQTT broker documentation
- [InfluxDB Documentation](https://docs.influxdata.com/) -- Time-series database docs
- [Node-RED Documentation](https://nodered.org/docs/) -- Flow-based programming tool docs
- [Grafana Documentation](https://grafana.com/docs/) -- Visualization platform docs
- [n8n Documentation](https://docs.n8n.io/) -- Workflow automation docs
- [Letta Documentation](https://docs.letta.com/) -- AI agent framework docs
- [Ollama Documentation](https://github.com/ollama/ollama) -- Local LLM runtime docs
- [Kokoro FastAPI](https://github.com/remsky/Kokoro-FastAPI) -- TTS engine docs

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).


# ==============================================================================
# Edge Impulse Linux Runner
# ==============================================================================
# This Dockerfile builds a container for running Edge Impulse models on Linux
# devices. It can be used standalone or as a sidecar to the MING stack.
#
# Build:
#   docker build -t ming-edge-impulse .
#
# Run:
#   docker run --rm -it \
#     --device /dev/video0 \
#     -e EI_API_KEY=your-api-key \
#     ming-edge-impulse
# ==============================================================================

FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libatlas-base-dev \
    libportaudio2 \
    libsndfile1 \
    libasound2-dev \
    libopencv-dev \
    python3-opencv \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Edge Impulse Linux SDK and dependencies
RUN pip install --no-cache-dir \
    edge_impulse_linux \
    paho-mqtt \
    numpy \
    opencv-python-headless \
    Pillow

# Create app directory
WORKDIR /app

# Copy inference script
COPY scripts/inference.py /app/inference.py

# Environment variables
ENV MQTT_BROKER=mqtt
ENV MQTT_PORT=1883
ENV MQTT_TOPIC=inference/results
ENV EI_MODEL_PATH=/app/model

# Default command
CMD ["python", "/app/inference.py"]

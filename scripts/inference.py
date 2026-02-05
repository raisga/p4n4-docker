#!/usr/bin/env python3
"""
Edge Impulse Inference Runner with MQTT Publishing

This script runs Edge Impulse models on Linux devices and publishes
inference results to an MQTT broker for integration with the MING stack.

Usage:
    python inference.py

Environment Variables:
    EI_API_KEY      - Edge Impulse API key (for downloading models)
    EI_MODEL_PATH   - Path to local .eim model file (alternative to API key)
    MQTT_BROKER     - MQTT broker hostname (default: mqtt)
    MQTT_PORT       - MQTT broker port (default: 1883)
    MQTT_TOPIC      - Topic to publish results (default: inference/results)
    CAMERA_DEVICE   - Camera device index (default: 0)
"""

import json
import os
import sys
import time
from datetime import datetime

import paho.mqtt.client as mqtt

# Edge Impulse imports (graceful fallback if not available)
try:
    from edge_impulse_linux.image import ImageImpulseRunner
    EI_AVAILABLE = True
except ImportError:
    EI_AVAILABLE = False
    print("Warning: Edge Impulse SDK not available. Running in demo mode.")


class MQTTPublisher:
    """Simple MQTT publisher for inference results."""

    def __init__(self, broker: str, port: int, topic: str):
        self.broker = broker
        self.port = port
        self.topic = topic
        self.client = mqtt.Client(client_id="edge-impulse-runner")
        self.connected = False

    def connect(self):
        """Connect to MQTT broker with retry logic."""
        max_retries = 10
        retry_delay = 5

        for attempt in range(max_retries):
            try:
                self.client.connect(self.broker, self.port, 60)
                self.client.loop_start()
                self.connected = True
                print(f"Connected to MQTT broker at {self.broker}:{self.port}")
                return True
            except Exception as e:
                print(f"MQTT connection attempt {attempt + 1}/{max_retries} failed: {e}")
                time.sleep(retry_delay)

        print("Failed to connect to MQTT broker")
        return False

    def publish(self, result: dict):
        """Publish inference result to MQTT topic."""
        if not self.connected:
            return False

        payload = json.dumps(result)
        self.client.publish(self.topic, payload, qos=1)
        return True

    def disconnect(self):
        """Disconnect from MQTT broker."""
        self.client.loop_stop()
        self.client.disconnect()


def run_inference_loop(runner, publisher: MQTTPublisher, camera_device: int = 0):
    """Main inference loop for image classification."""
    import cv2

    cap = cv2.VideoCapture(camera_device)
    if not cap.isOpened():
        print(f"Error: Cannot open camera device {camera_device}")
        return

    model_info = runner.model_info
    print(f"Model: {model_info.get('project', {}).get('name', 'Unknown')}")
    print(f"Labels: {runner.labels}")

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                print("Error: Cannot read frame from camera")
                continue

            # Run inference
            start_time = time.time()
            features, cropped = runner.get_features_from_image(frame)
            result = runner.classify(features)
            latency = (time.time() - start_time) * 1000  # ms

            # Find best classification
            classifications = result.get("result", {}).get("classification", {})
            if classifications:
                best_label = max(classifications, key=classifications.get)
                confidence = classifications[best_label]

                # Publish to MQTT
                inference_result = {
                    "timestamp": datetime.utcnow().isoformat(),
                    "model": model_info.get("project", {}).get("name", "unknown"),
                    "label": best_label,
                    "confidence": round(confidence, 4),
                    "latency": round(latency, 2),
                    "all_labels": {k: round(v, 4) for k, v in classifications.items()}
                }
                publisher.publish(inference_result)

                print(f"[{inference_result['timestamp']}] {best_label}: {confidence:.2%} ({latency:.1f}ms)")

            # Small delay to avoid overwhelming the system
            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\nStopping inference...")
    finally:
        cap.release()


def run_demo_mode(publisher: MQTTPublisher):
    """Run in demo mode when Edge Impulse SDK is not available."""
    import random

    labels = ["idle", "movement", "anomaly"]
    print("Running in demo mode - publishing synthetic inference results")

    try:
        while True:
            # Generate synthetic inference result
            label = random.choice(labels)
            confidence = random.uniform(0.7, 0.99)

            inference_result = {
                "timestamp": datetime.utcnow().isoformat(),
                "model": "demo-model",
                "label": label,
                "confidence": round(confidence, 4),
                "latency": round(random.uniform(10, 50), 2),
                "all_labels": {l: round(random.uniform(0, 1), 4) for l in labels}
            }

            # Normalize confidence values
            total = sum(inference_result["all_labels"].values())
            inference_result["all_labels"] = {
                k: round(v / total, 4) for k, v in inference_result["all_labels"].items()
            }
            inference_result["confidence"] = inference_result["all_labels"][label]

            publisher.publish(inference_result)
            print(f"[{inference_result['timestamp']}] {label}: {confidence:.2%}")

            time.sleep(1)

    except KeyboardInterrupt:
        print("\nStopping demo mode...")


def main():
    # Configuration from environment
    mqtt_broker = os.environ.get("MQTT_BROKER", "mqtt")
    mqtt_port = int(os.environ.get("MQTT_PORT", "1883"))
    mqtt_topic = os.environ.get("MQTT_TOPIC", "inference/results")
    model_path = os.environ.get("EI_MODEL_PATH", "")
    camera_device = int(os.environ.get("CAMERA_DEVICE", "0"))

    print("=" * 60)
    print("Edge Impulse Inference Runner")
    print("=" * 60)
    print(f"MQTT Broker: {mqtt_broker}:{mqtt_port}")
    print(f"MQTT Topic: {mqtt_topic}")
    print("=" * 60)

    # Initialize MQTT publisher
    publisher = MQTTPublisher(mqtt_broker, mqtt_port, mqtt_topic)
    if not publisher.connect():
        sys.exit(1)

    try:
        if EI_AVAILABLE and model_path and os.path.exists(model_path):
            # Run with actual Edge Impulse model
            with ImageImpulseRunner(model_path) as runner:
                runner.init()
                run_inference_loop(runner, publisher, camera_device)
        else:
            # Run demo mode
            run_demo_mode(publisher)

    finally:
        publisher.disconnect()


if __name__ == "__main__":
    main()

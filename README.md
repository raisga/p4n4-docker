# ming-wei

MING (with Edge Impulse)

## Dockerfile

...

## Stack (Edge AI)

- MQTT (message broker)
- InfluxDB (inference storage)
- Node-RED (iot workflows)
- Graphana (data visualization)
- Edge-Impulse (ML inference)

### Additional Components (Gen AI)

- n8n (cloud services)
- letta (agent)
- ollama (llm)
- kokoro (tts)

### Diagram

```
(EdgeAI)    [edge-impulse] --> [mqtt] --> [influxdb] --> [node-red] --> [graphana]
                                 |
                                 |
                                 ^
(GenAI)                        [n8n] --> [letta] --> [ollama]
                                 |
                                 ^
                              [kokoro]
```

## Resources

- [MING Stack with Edge Impulse](https://www.edgeimpulse.com/blog/accelerate-edge-ai-application-development-with-the-ming-stack-edge-impulse/) -- Tech stack architecture and integration guide
- [Edge Impulse Linux SDK (Python)](https://github.com/edgeimpulse/linux-sdk-python) -- Python SDK for on-device inference


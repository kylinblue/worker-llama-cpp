import asyncio
import httpx
import json


class LlamaCppWrapper:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url

    async def generate(self, prompt, max_tokens=50, temperature=0.7, top_p=1.0, stream=True):
        payload = {
            "prompt": prompt,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "top_p": top_p,
            "stream": stream,
        }
        async with httpx.AsyncClient(timeout=None) as client:
            async with client.stream("POST", f"{self.base_url}/completions", json=payload) as response:
                async for line in response.aiter_lines():
                    if line:
                        if line.startswith("data:"):
                            line = line[len("data:"):].strip()
                        if line.strip() == "[DONE]":
                            break
                        try:
                            data = json.loads(line)
                        except Exception:
                            continue
                        yield data

    async def generate_chat(self, messages, max_tokens=50, temperature=0.7, stream=True):
        payload = {
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": stream,
        }
        async with httpx.AsyncClient(timeout=None) as client:
            # Assumes llama.cpp server exposes a chat-style endpoint
            async with client.stream("POST", f"{self.base_url}/chat/completions", json=payload) as response:
                async for line in response.aiter_lines():
                    if line:
                        if line.startswith("data:"):
                            line = line[len("data:"):].strip()
                        if line.strip() == "[DONE]":
                            break
                        try:
                            data = json.loads(line)
                        except Exception:
                            continue
                        yield data

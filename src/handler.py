import asyncio

import runpod

from .wrapper import LlamaCppWrapper


# Initialize the llama.cpp wrapper
llama_wrapper = LlamaCppWrapper()


# JobInput class extracts parameters from the job input.
class JobInput:
    def __init__(self, job):
        inp = job.get("input", {})
        self.messages = inp.get("messages", [{"role": "user", "content": "Hello from llama.cpp!"}])
        self.max_tokens = inp.get("max_tokens", 512)
        self.temperature = inp.get("temperature", 0.7)
        self.top_p = inp.get("top_p", 1.0)
        

async def handler(job):
    job_input = JobInput(job)
    async for chunk in llama_wrapper.generate_chat(
         messages=job_input.messages,
         max_tokens=job_input.max_tokens,
         temperature=job_input.temperature,
         top_p=job_input.top_p,
         stream=True
    ):
         yield chunk

# Start the RunPod serverless handler with the specified configuration.
runpod.serverless.start({
    "handler": handler,
    "return_aggregate_stream": True,
    # Optionally add other options such as a concurrency_modifier if needed.
})

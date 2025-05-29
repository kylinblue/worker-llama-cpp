# ===== Builder Stage =====
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 AS builder

# Set noninteractive mode to speed up installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    git \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Set working directory for building llama.cpp
WORKDIR /build

# Clone llama.cpp repository and build it
RUN git clone https://github.com/ggerganov/llama.cpp.git
WORKDIR /build/llama.cpp
RUN cmake . -DLLAMA_CUBLAS=ON && cmake --build . --config Release


# ===== Final Runtime Stage =====
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Copy the built llama.cpp from the builder stage
COPY --from=builder /build/llama.cpp /llama.cpp

# Ensure CUDA compat libraries are registered
RUN ldconfig /usr/local/cuda/compat/

# Set working directory in the final stage (optional)
WORKDIR /

# Copy and install Python dependencies using BuildKit cache mount for pip
COPY requirements.txt requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install --upgrade -r requirements.txt

# Set build-time arguments for model configuration
ARG MODEL_NAME=""
ARG TOKENIZER_NAME=""
ARG BASE_PATH="/runpod-volume"
ARG QUANTIZATION=""
ARG MODEL_REVISION=""
ARG TOKENIZER_REVISION=""

# Configure environment variables for model paths and cache locations
ENV MODEL_NAME=${MODEL_NAME} \
    MODEL_REVISION=${MODEL_REVISION} \
    TOKENIZER_NAME=${TOKENIZER_NAME} \
    TOKENIZER_REVISION=${TOKENIZER_REVISION} \
    BASE_PATH=${BASE_PATH} \
    QUANTIZATION=${QUANTIZATION} \
    HF_DATASETS_CACHE="${BASE_PATH}/huggingface-cache/datasets" \
    HUGGINGFACE_HUB_CACHE="${BASE_PATH}/huggingface-cache/hub" \
    HF_HOME="${BASE_PATH}/huggingface-cache/hub" \
    HF_HUB_ENABLE_HF_TRANSFER=0

# Set PYTHONPATH as required
ENV PYTHONPATH="/:/llamacpp-workspace"

# Copy your application source code
COPY src /src

# Download the model if MODEL_NAME is provided, using a secret if available.
RUN --mount=type=secret,id=HF_TOKEN,required=false \
    if [ -f /run/secrets/HF_TOKEN ]; then \
      export HF_TOKEN=$(cat /run/secrets/HF_TOKEN); \
    fi && \
    if [ -n "$MODEL_NAME" ]; then \
      python3 /src/download_model.py; \
    fi

# Copy the startup script and ensure it’s executable
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose the port used by the llama.cpp server
EXPOSE 8000

# Start the container by running the startup script
CMD ["/start.sh"]

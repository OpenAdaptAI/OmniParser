# Dockerfile for OmniParser with GPU support and OpenGL libraries
#
# This Dockerfile is intended to create an environment with NVIDIA CUDA
# support and the necessary dependencies to run the OmniParser project.
# The configuration is designed to support applications that rely on
# Python 3.12, OpenCV, Hugging Face transformers, and Gradio. Additionally,
# it includes steps to pull large files from Git LFS and a script to
# convert model weights from .safetensor to .pt format. The container
# runs a Gradio server by default, exposed on port 7861.
#
# Base image: nvidia/cuda:12.3.1-devel-ubuntu22.04
#
# Key features:
# - System dependencies for OpenGL to support graphical libraries.
# - Miniconda for Python 3.12, allowing for environment management.
# - Git Large File Storage (LFS) setup for handling large model files.
# - Requirement file installation, including specific versions of
#   OpenCV and Hugging Face Hub.
# - Entrypoint script execution with Gradio server configuration for
#   external access.

FROM nvidia/cuda:12.3.1-devel-ubuntu22.04

# Install system dependencies with explicit OpenGL libraries
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    git-lfs \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libglu1-mesa \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    python3-opencv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install

# Install Miniconda for Python 3.12
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh
ENV PATH="/opt/conda/bin:$PATH"

# Create and activate Conda environment with Python 3.12, and set it as the default
RUN conda create -n omni python=3.12 && \
    echo "source activate omni" > ~/.bashrc
ENV CONDA_DEFAULT_ENV=omni
ENV PATH="/opt/conda/envs/omni/bin:$PATH"

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy project files and requirements
COPY . .
COPY requirements.txt /usr/src/app/requirements.txt

# Initialize Git LFS and pull LFS files
RUN git lfs install && \
    git lfs pull

# Install dependencies from requirements.txt with specific opencv-python-headless version
RUN . /opt/conda/etc/profile.d/conda.sh && conda activate omni && \
    pip uninstall -y opencv-python opencv-python-headless && \
    pip install --no-cache-dir opencv-python-headless==4.8.1.78 && \
    pip install -r requirements.txt && \
    pip install huggingface_hub

# Run download.py to fetch model weights and convert safetensors to .pt format
RUN . /opt/conda/etc/profile.d/conda.sh && conda activate omni && \
    python download.py && \
    echo "Contents of weights directory:" && \
    ls -lR weights && \
    python weights/convert_safetensor_to_pt.py

# Expose the default Gradio port
EXPOSE 7861

# Configure Gradio to be accessible externally
ENV GRADIO_SERVER_NAME="0.0.0.0"

# Copy and set permissions for entrypoint script
COPY entrypoint.sh /usr/src/app/entrypoint.sh
RUN chmod +x /usr/src/app/entrypoint.sh

# To debug, keep the container running
# CMD ["tail", "-f", "/dev/null"]

# Set the entrypoint
ENTRYPOINT ["/usr/src/app/entrypoint.sh"]

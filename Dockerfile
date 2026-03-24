FROM python:3.12-bookworm

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg curl && \
    rm -rf /var/lib/apt/lists/*

# Install Miniconda
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

RUN curl -LO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b -p $CONDA_DIR && \
    rm Miniconda3-latest-Linux-x86_64.sh && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    conda create -y --name facefusion -c conda-forge python=3.12 pip=25.0 && \
    conda install -n facefusion -y nvidia/label/cuda-12.9.1::cuda-runtime nvidia/label/cudnn-9.10.0::cudnn && \
    conda clean -afy

# Set path to use the Conda environment directly
ENV PATH=$CONDA_DIR/envs/facefusion/bin:$PATH
ENV LD_LIBRARY_PATH=$CONDA_DIR/envs/facefusion/lib:${LD_LIBRARY_PATH:-}

WORKDIR /app/facefusion

# Ensure all RUN commands execute inside the conda environment wrapper
SHELL ["conda", "run", "--no-capture-output", "-n", "facefusion", "/bin/bash", "-c"]

# Pre-cache dependencies from requirements.txt to speed up builds on code changes
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the source code and run the platform-specific installer
COPY . .
RUN python install.py --onnxruntime cuda

# Ensure Gradio binds to the network interface, enabling web access from outside the container
ENV GRADIO_SERVER_NAME=0.0.0.0
EXPOSE 7860

# Set the entrypoint command to execute explicitly inside the activated environment
CMD ["conda", "run", "--no-capture-output", "-n", "facefusion", "python", "facefusion.py", "run"]

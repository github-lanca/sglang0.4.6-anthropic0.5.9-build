# 使用与官方相同的基础镜像
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# 设置环境
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    python3-pip \
    git \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 设置 Python 3.10 为默认
RUN ln -sf /usr/bin/python3.10 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.10 /usr/bin/python

# 升级 pip
RUN pip3 install --upgrade pip

# 安装 PyTorch CUDA 12.1 版本
RUN pip3 install --no-cache-dir \
    torch==2.3.0+cu121 \
    torchvision==0.18.0+cu121 \
    --extra-index-url https://download.pytorch.org/whl/cu121

# 安装 sgl-kernel（CUDA 12.1 版本）
RUN pip3 install --no-cache-dir sgl-kernel -i https://docs.sglang.ai/whl/cu121 || \
    pip3 install --no-cache-dir sgl-kernel

# 复制嫁接代码（包含 Anthropic 支持的 v0.4.6 修改版）
# 注意：需要将代码放在 build 目录下的 sglang-anthropic-cu121 文件夹中
COPY ../sglang /workspace/sglang

# 安装 SGLang（定制版）
WORKDIR /workspace/sglang
RUN pip3 install --no-cache-dir -e ".[all]"

# 创建工作目录
WORKDIR /app

# 暴露端口
EXPOSE 30000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:30000/health || exit 1

# 启动命令
CMD ["python3", "-m", "sglang.launch_server", \
     "--host", "0.0.0.0", \
     "--port", "30000", \
     "--log-level", "info"]

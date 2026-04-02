#!/bin/bash
# 准备完整的离线 Docker 构建包
# 包含源码和所有 Python 依赖

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  SGLang 离线 Docker 构建包准备${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/docker-build-offline"
SOURCE_DIR="${BUILD_DIR}/source"
PACKAGES_DIR="${BUILD_DIR}/packages"

echo -e "${BLUE}构建目录:${NC} ${BUILD_DIR}"
echo ""

# 检查是否在 macOS
SKIP_DOWNLOAD=false
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}注意: 当前是 macOS 系统${NC}"
    echo "由于 PyTorch CUDA 版本是 Linux 专用，在 macOS 上无法直接下载"
    echo ""
    SKIP_DOWNLOAD=true
fi

# 清理并创建目录
echo "创建目录结构..."
rm -rf "${BUILD_DIR}"
mkdir -p "${SOURCE_DIR}"
mkdir -p "${PACKAGES_DIR}"
echo -e "${GREEN}✓${NC} 目录创建完成"
echo ""

# 检查 sglang 源码
echo "检查 SGLang 源码..."
SGLANG_SOURCE="${SCRIPT_DIR}/../sglang"
if [ ! -d "${SGLANG_SOURCE}/python/sglang/srt/entrypoints/anthropic" ]; then
    echo -e "${RED}错误: 未找到已修改的 SGLang 源码${NC}"
    echo -e "请确保在 ${SGLANG_SOURCE} 存在且包含 Anthropic 支持"
    exit 1
fi
echo -e "${GREEN}✓${NC} 找到 SGLang 源码"
echo ""

# 复制源码
echo "复制 SGLang 源码..."
cp -r "${SGLANG_SOURCE}" "${SOURCE_DIR}/sglang-anthropic-cu121"

# 清理源码中的不需要的文件
find "${SOURCE_DIR}/sglang-anthropic-cu121" -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true
find "${SOURCE_DIR}/sglang-anthropic-cu121" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "${SOURCE_DIR}/sglang-anthropic-cu121" -name "*.pyc" -delete 2>/dev/null || true
find "${SOURCE_DIR}/sglang-anthropic-cu121" -name ".DS_Store" -delete 2>/dev/null || true

echo -e "${GREEN}✓${NC} 源码复制完成"
echo ""

# 检查关键文件
echo "检查关键文件..."
if [ ! -f "${SOURCE_DIR}/sglang-anthropic-cu121/python/sglang/srt/entrypoints/anthropic/__init__.py" ]; then
    echo -e "${RED}✗ 缺少 __init__.py${NC}"; exit 1
fi
if [ ! -f "${SOURCE_DIR}/sglang-anthropic-cu121/python/sglang/srt/entrypoints/anthropic/protocol.py" ]; then
    echo -e "${RED}✗ 缺少 protocol.py${NC}"; exit 1
fi
if [ ! -f "${SOURCE_DIR}/sglang-anthropic-cu121/python/sglang/srt/entrypoints/anthropic/serving.py" ]; then
    echo -e "${RED}✗ 缺少 serving.py${NC}"; exit 1
fi
echo -e "${GREEN}✓${NC} __init__.py"
echo -e "${GREEN}✓${NC} protocol.py"
echo -e "${GREEN}✓${NC} serving.py"
echo ""

# 下载 Python 依赖
if [ "$SKIP_DOWNLOAD" = false ]; then
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  开始下载 Python 依赖${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""

    TEMP_VENV=$(mktemp -d)
    echo "创建临时虚拟环境..."
    python3 -m venv "${TEMP_VENV}/venv"
    source "${TEMP_VENV}/venv/bin/activate"
    pip install --upgrade pip -q

    echo "下载 PyTorch..."
    pip download --dest "${PACKAGES_DIR}" --python-version 310 --platform manylinux2014_x86_64 --only-binary=:all: \
        torch==2.3.0+cu121 torchvision==0.18.0+cu121 --extra-index-url https://download.pytorch.org/whl/cu121 2>/dev/null || {
        echo -e "${YELLOW}警告: PyTorch 下载失败${NC}"
    }

    echo "下载 sgl-kernel..."
    pip download --dest "${PACKAGES_DIR}" --python-version 310 --platform manylinux2014_x86_64 --only-binary=:all: \
        sgl-kernel -i https://docs.sglang.ai/whl/cu121 2>/dev/null || {
        pip download --dest "${PACKAGES_DIR}" --python-version 310 --platform manylinux2014_x86_64 --only-binary=:all: sgl-kernel 2>/dev/null || {
            echo -e "${YELLOW}警告: sgl-kernel 下载失败${NC}"
        }
    }

    echo "下载其他依赖..."
    pip download --dest "${PACKAGES_DIR}" --python-version 310 --platform manylinux2014_x86_64 --only-binary=:all: \
        fastapi pydantic numpy tqdm requests aiohttp ipython partial-json-parser orjson uvicorn uvloop pyzmq 2>/dev/null || true

    deactivate
    rm -rf "${TEMP_VENV}"
    echo -e "${GREEN}✓${NC} 依赖下载完成"
    echo ""
else
    echo -e "${YELLOW}跳过依赖下载（macOS 不支持下载 Linux CUDA 包）${NC}"
    echo ""
    echo "请在 Linux 机器上运行 download-packages-linux.sh 下载依赖"
    echo "或参考 OFFLINE_PACKAGES_README.md 手动下载"
    echo ""
fi

# 创建离线 Dockerfile
echo "创建 Dockerfile..."
cat > "${BUILD_DIR}/Dockerfile" << 'DOCKERFILE_EOF'
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y \
    python3.10 python3.10-venv python3.10-dev python3-pip \
    git build-essential curl \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3.10 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.10 /usr/bin/python

RUN pip3 install --upgrade pip

COPY packages/*.whl /tmp/packages/ 2>/dev/null || true

RUN pip3 install --no-index --find-links /tmp/packages \
    torch==2.3.0+cu121 torchvision==0.18.0+cu121 2>/dev/null || \
    pip3 install torch==2.3.0 torchvision==0.18.0 --extra-index-url https://download.pytorch.org/whl/cu121

RUN pip3 install --no-index --find-links /tmp/packages sgl-kernel 2>/dev/null || \
    pip3 install sgl-kernel -i https://docs.sglang.ai/whl/cu121

RUN pip3 install --no-index --find-links /tmp/packages \
    fastapi pydantic numpy tqdm requests aiohttp ipython \
    partial-json-parser orjson uvicorn uvloop pyzmq 2>/dev/null || \
    pip3 install fastapi pydantic numpy tqdm requests aiohttp ipython \
        partial-json-parser orjson uvicorn uvloop pyzmq

COPY source/sglang-anthropic-cu121 /workspace/sglang

WORKDIR /workspace/sglang/python
RUN pip3 install --no-cache-dir -e ".[all]"

WORKDIR /app
EXPOSE 30000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:30000/health || exit 1

CMD ["python3", "-m", "sglang.launch_server", \
     "--host", "0.0.0.0", "--port", "30000", "--log-level", "info"]
DOCKERFILE_EOF

echo -e "${GREEN}✓${NC} Dockerfile 创建完成"
echo ""

# 创建构建脚本
echo "创建构建脚本..."
cat > "${BUILD_DIR}/build.sh" << 'BUILD_EOF'
#!/bin/bash
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "================================"
echo "SGLang 离线 Docker 构建脚本"
echo "================================"
echo ""

cd "$(dirname "$0")"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}错误: Docker 服务未运行${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker 环境正常"
echo ""
echo "开始构建..."
docker build -t sglang:v0.4.6-cu121-anthropic . 2>&1 | tee build.log

echo ""
echo "================================"
echo -e "${GREEN}构建完成！${NC}"
echo "================================"
echo ""
docker images | grep sglang || echo "未找到镜像"
BUILD_EOF

chmod +x "${BUILD_DIR}/build.sh"
echo -e "${GREEN}✓${NC} 构建脚本创建完成"
echo ""

# 创建使用说明
echo "创建使用说明..."
cat > "${BUILD_DIR}/README.md" << 'README_EOF'
# SGLang v0.4.6 + Anthropic API 离线构建包

## 快速开始

```bash
./build.sh
```

## 运行容器

```bash
docker run -d --gpus all \
    -p 30000:30000 \
    -v /path/to/models:/models:ro \
    --name sglang-server \
    sglang:v0.4.6-cu121-anthropic \
    --model-path /models/your-model \
    --host 0.0.0.0 --port 30000
```

## 测试 API

```bash
curl http://localhost:30000/health

curl http://localhost:30000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model": "default", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 100}'
```
README_EOF

echo -e "${GREEN}✓${NC} 使用说明创建完成"
echo ""

# 复制下载脚本
cp "${SCRIPT_DIR}/download-packages-linux.sh" "${BUILD_DIR}/" 2>/dev/null || true
chmod +x "${BUILD_DIR}/download-packages-linux.sh" 2>/dev/null || true

# 统计信息
echo "================================"
echo "构建包统计信息"
echo "================================"
echo ""
echo -e "${BLUE}位置:${NC} ${BUILD_DIR}"
echo -e "${BLUE}源码大小:${NC} $(du -sh "${SOURCE_DIR}" | cut -f1)"
echo -e "${BLUE}依赖包数量:${NC} $(ls -1 "${PACKAGES_DIR}"/*.whl 2>/dev/null | wc -l) 个 whl 文件"
echo -e "${BLUE}依赖包大小:${NC} $(du -sh "${PACKAGES_DIR}" | cut -f1)"
echo ""

# 打包
echo "创建传输压缩包..."
cd "${SCRIPT_DIR}"
tar czf docker-build-offline.tar.gz docker-build-offline/ \
    --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' 2>/dev/null || true

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  离线构建包准备完成!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "传输包: docker-build-offline.tar.gz"
echo "大小: $(du -sh docker-build-offline.tar.gz 2>/dev/null | cut -f1 || echo 'N/A')"
echo ""

if [ "$SKIP_DOWNLOAD" = true ]; then
    echo -e "${YELLOW}注意: 依赖包未下载（macOS 不支持）${NC}"
    echo ""
    echo "下一步操作:"
    echo "1. 阅读 OFFLINE_PACKAGES_README.md 了解如何获取 Linux 依赖"
    echo "2. 将 docker-build-offline 传输到 Linux 机器"
    echo "3. 在 Linux 上运行 ./download-packages-linux.sh 下载依赖"
    echo "4. 然后传输到离线服务器进行构建"
    echo ""
else
    echo "使用方法:"
    echo "1. 将 docker-build-offline.tar.gz 传输到离线服务器"
    echo "2. 解压: tar xzvf docker-build-offline.tar.gz"
    echo "3. 构建: cd docker-build-offline && ./build.sh"
    echo ""
fi

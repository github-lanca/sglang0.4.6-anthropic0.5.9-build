#!/bin/bash
# 准备 Docker 构建包的脚本
# 在联网机器上运行此脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}SGLang Anthropic Docker 构建包准备脚本${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# 设置目录
BUILD_DIR="${HOME}/sglang-docker-build"
SOURCE_DIR="${BUILD_DIR}/source"
PACKAGES_DIR="${BUILD_DIR}/packages"

echo "步骤 1: 创建目录结构..."
mkdir -p "${SOURCE_DIR}"
mkdir -p "${PACKAGES_DIR}"
echo -e "${GREEN}✓${NC} 目录创建完成"
echo ""

# 检查当前目录是否是 sglang 仓库
echo "步骤 2: 检查源码..."
if [ -d "python/sglang/srt/entrypoints/anthropic" ]; then
    echo "发现已修改的 SGLang 源码，正在复制..."

    # 复制源码
    cp -r . "${SOURCE_DIR}/sglang-anthropic-cu121"

    echo -e "${GREEN}✓${NC} 源码复制完成"
else
    echo -e "${YELLOW}警告: 当前目录没有找到已修改的 SGLang 源码${NC}"
    echo "请先确保你在 sglang 仓库根目录，且已完成 Anthropic 代码移植"
    echo ""
    echo "当前目录: $(pwd)"
    echo ""
    exit 1
fi
echo ""

echo "步骤 3: 检查关键文件..."
REQUIRED_FILES=(
    "${SOURCE_DIR}/sglang-anthropic-cu121/python/sglang/srt/entrypoints/anthropic/__init__.py"
    "${SOURCE_DIR}/sglang-anthropic-cu121/python/sglang/srt/entrypoints/anthropic/protocol.py"
    "${SOURCE_DIR}/sglang-anthropic-cu121/python/sglang/srt/entrypoints/anthropic/serving.py"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $(basename $file)"
    else
        echo -e "${RED}✗${NC} 缺少文件: $file"
        exit 1
    fi
done
echo ""

echo "步骤 4: 检查 http_server.py 修改..."
HTTP_SERVER="${SOURCE_DIR}/sglang-anthropic-cu121/python/sglang/srt/entrypoints/http_server.py"
if grep -q "AnthropicServing" "$HTTP_SERVER"; then
    echo -e "${GREEN}✓${NC} http_server.py 已包含 Anthropic 支持"
else
    echo -e "${RED}✗${NC} http_server.py 未包含 Anthropic 支持，请检查修改"
    exit 1
fi
echo ""

echo "步骤 5: 创建 Dockerfile..."
cat > "${BUILD_DIR}/Dockerfile" << 'EOF'
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
COPY source/sglang-anthropic-cu121 /workspace/sglang

# 安装 SGLang（定制版）
WORKDIR /workspace/sglang/python
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
EOF
echo -e "${GREEN}✓${NC} Dockerfile 创建完成"
echo ""

echo "步骤 6: 下载 Python 依赖（可选）..."
echo -e "${YELLOW}注意:${NC} 如果目标服务器有外网访问，可以跳过此步骤"
echo "是否下载依赖包到本地？(y/n)"
read -r download_deps

if [ "$download_deps" = "y" ] || [ "$download_deps" = "Y" ]; then
    echo "正在下载依赖..."

    # 创建临时虚拟环境
    TEMP_VENV=$(mktemp -d)
    python3 -m venv "${TEMP_VENV}/venv"
    source "${TEMP_VENV}/venv/bin/activate"

    pip install --upgrade pip

    # 下载 PyTorch
    echo "下载 PyTorch CUDA 12.1..."
    pip download \
        --dest "${PACKAGES_DIR}" \
        torch==2.3.0+cu121 \
        torchvision==0.18.0+cu121 \
        --extra-index-url https://download.pytorch.org/whl/cu121 || \
        echo -e "${YELLOW}警告:${NC} PyTorch 下载失败，将在构建时在线安装"

    # 下载 sgl-kernel
    echo "下载 sgl-kernel..."
    pip download \
        --dest "${PACKAGES_DIR}" \
        sgl-kernel -i https://docs.sglang.ai/whl/cu121 || \
        pip download --dest "${PACKAGES_DIR}" sgl-kernel || \
        echo -e "${YELLOW}警告:${NC} sgl-kernel 下载失败，将在构建时在线安装"

    # 下载其他依赖
    echo "下载其他依赖..."
    pip download \
        --dest "${PACKAGES_DIR}" \
        fastapi pydantic numpy tqdm requests aiohttp ipython partial-json-parser orjson uvicorn uvloop pyzmq 2>/dev/null || \
        echo -e "${YELLOW}警告:${NC} 部分依赖下载失败，将在构建时在线安装"

    # 清理临时环境
    deactivate
    rm -rf "${TEMP_VENV}"

    echo -e "${GREEN}✓${NC} 依赖下载完成"
    echo "依赖包位置: ${PACKAGES_DIR}"
    ls -lh "${PACKAGES_DIR}"
else
    echo -e "${YELLOW}跳过依赖下载，将在构建时从网络安装${NC}"
fi
echo ""

echo "步骤 7: 创建构建脚本..."
cat > "${BUILD_DIR}/build.sh" << 'EOF'
#!/bin/bash
# 在离线服务器上运行的构建脚本

set -e

echo "================================"
echo "SGLang Anthropic Docker 构建脚本"
echo "================================"
echo ""

cd "$(dirname "$0")"

echo "检查环境..."
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "错误: Docker 服务未运行"
    exit 1
fi

echo "✓ Docker 环境正常"
echo ""

echo "开始构建..."
docker build \
    -t sglang:v0.4.6-cu121-anthropic \
    .

echo ""
echo "================================"
echo "构建完成！"
echo "================================"
echo ""
echo "镜像信息:"
docker images | grep sglang
echo ""
echo "运行命令示例:"
echo "docker run -d --gpus all -p 30000:30000 sglang:v0.4.6-cu121-anthropic --model-path /path/to/model"
EOF

chmod +x "${BUILD_DIR}/build.sh"
echo -e "${GREEN}✓${NC} 构建脚本创建完成"
echo ""

echo "步骤 8: 创建传输包..."
cd "${BUILD_DIR}"

# 创建传输包（排除 .git）
tar czvf sglang-anthropic-build.tar.gz \
    --exclude='.git' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    Dockerfile build.sh packages/ source/

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}准备完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "构建包位置: ${BUILD_DIR}/sglang-anthropic-build.tar.gz"
echo ""
ls -lh "${BUILD_DIR}/sglang-anthropic-build.tar.gz"
echo ""
echo "使用说明:"
echo "1. 将 ${BUILD_DIR}/sglang-anthropic-build.tar.gz 传输到离线服务器"
echo "2. 在离线服务器上解压: tar xzvf sglang-anthropic-build.tar.gz"
echo "3. 进入目录并运行: ./build.sh"
echo ""

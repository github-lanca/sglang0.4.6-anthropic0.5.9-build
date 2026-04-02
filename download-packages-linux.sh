#!/bin/bash
# Linux 专用：下载 Docker 构建所需的 Python 依赖包
# 在 Linux x86_64 机器上运行此脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Linux Python 依赖包下载${NC}"
echo -e "${GREEN}  平台: manylinux2014_x86_64${NC}"
echo -e "${GREEN}  Python: 3.10${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${YELLOW}警告: 当前不是 Linux 系统${NC}"
    echo "此脚本需要在 Linux x86_64 机器上运行以下载正确的二进制包"
    echo ""
fi

PACKAGES_DIR="$(pwd)/packages"
mkdir -p "${PACKAGES_DIR}"

echo -e "${BLUE}下载目录:${NC} ${PACKAGES_DIR}"
echo ""

# 升级 pip
pip3 install --upgrade pip

echo -e "${GREEN}步骤 1/3: 下载 PyTorch + torchvision${NC}"
echo "==========================================="
pip3 download \
    --dest "${PACKAGES_DIR}" \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    --only-binary=:all: \
    torch==2.3.0+cu121 \
    torchvision==0.18.0+cu121 \
    --extra-index-url https://download.pytorch.org/whl/cu121
echo -e "${GREEN}✓${NC} PyTorch 下载完成"
echo ""

echo -e "${GREEN}步骤 2/3: 下载 sgl-kernel${NC}"
echo "==========================="
pip3 download \
    --dest "${PACKAGES_DIR}" \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    --only-binary=:all: \
    sgl-kernel -i https://docs.sglang.ai/whl/cu121 || \
pip3 download \
    --dest "${PACKAGES_DIR}" \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    --only-binary=:all: \
    sgl-kernel
echo -e "${GREEN}✓${NC} sgl-kernel 下载完成"
echo ""

echo -e "${GREEN}步骤 3/3: 下载 SGLang 依赖${NC}"
echo "==========================="

# 创建临时 requirements
REQ_FILE=$(mktemp)
cat > "${REQ_FILE}" << 'EOF'
fastapi>=0.100.0
pydantic>=2.0
numpy<2.0
tqdm
requests>=2.25.0
aiohttp
ipython
partial-json-parser
orjson
uvicorn
uvloop
pyzmq
EOF

# 下载所有依赖及其子依赖
pip3 download \
    --dest "${PACKAGES_DIR}" \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    --no-deps \
    -r "${REQ_FILE}"

# 下载间接依赖（递归）
for pkg in fastapi pydantic numpy tqdm requests aiohttp ipython partial-json-parser orjson uvicorn uvloop pyzmq; do
    pip3 download --dest "${PACKAGES_DIR}" --python-version 310 --platform manylinux2014_x86_64 --no-deps "${pkg}" 2>/dev/null || true
done

rm -f "${REQ_FILE}"

echo -e "${GREEN}✓${NC} 依赖下载完成"
echo ""

echo "================================"
echo "下载结果"
echo "================================"
echo -e "${BLUE}位置:${NC} ${PACKAGES_DIR}"
echo -e "${BLUE}whl 文件数量:${NC} $(ls -1 "${PACKAGES_DIR}"/*.whl 2>/dev/null | wc -l)"
echo -e "${BLUE}总大小:${NC} $(du -sh "${PACKAGES_DIR}" | cut -f1)"
echo ""
echo "关键包:"
ls -lh "${PACKAGES_DIR}"/torch* "${PACKAGES_DIR}"/sgl* 2>/dev/null | awk '{print $9, $5}' || echo "请检查下载结果"
echo ""

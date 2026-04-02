#!/bin/bash
# 下载 Docker 构建所需的 Python 依赖包 (Linux x86_64, Python 3.10)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN} 下载 SGLang Docker 依赖包${NC}"
echo -e "${GREEN} 平台: Linux x86_64 | Python: 3.10${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# 创建下载目录
PACKAGES_DIR="$(pwd)/packages"
mkdir -p "${PACKAGES_DIR}"
echo -e "${BLUE}下载目录:${NC} ${PACKAGES_DIR}"
echo ""

# 检测 Python 版本
PYTHON_VERSION=$(python3 --version 2>/dev/null | cut -d' ' -f2 | cut -d'.' -f1,2 | tr -d '.')
if [ -z "${PYTHON_VERSION}" ]; then
    PYTHON_VERSION="310"
    echo -e "${YELLOW}警告: 无法检测 Python 版本，使用默认版本 3.10${NC}"
fi
echo -e "${BLUE}Python 版本:${NC} ${PYTHON_VERSION}"
echo ""

# 创建临时虚拟环境用于下载
TEMP_VENV=$(mktemp -d)
echo "创建临时虚拟环境..."
python3 -m venv "${TEMP_VENV}/venv"
source "${TEMP_VENV}/venv/bin/activate"

# 升级 pip
pip install --upgrade pip

echo ""
echo -e "${GREEN}步骤 1: 下载 PyTorch (CUDA 12.1)${NC}"
echo "========================================"
pip download \
    --dest "${PACKAGES_DIR}" \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    --only-binary :all: \
    torch==2.3.0+cu121 \
    torchvision==0.18.0+cu121 \
    --extra-index-url https://download.pytorch.org/whl/cu121 || {
    echo -e "${YELLOW}警告: PyTorch 下载失败，将在构建时在线安装${NC}"
}

echo ""
echo -e "${GREEN}步骤 2: 下载 sgl-kernel${NC}"
echo "=========================="
pip download \
    --dest "${PACKAGES_DIR}" \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    sgl-kernel -i https://docs.sglang.ai/whl/cu121 || {
    pip download \
        --dest "${PACKAGES_DIR}" \
        --python-version 310 \
        --platform manylinux2014_x86_64 \
        sgl-kernel || {
        echo -e "${YELLOW}警告: sgl-kernel 下载失败，将在构建时在线安装${NC}"
    }
}

echo ""
echo -e "${GREEN}步骤 3: 下载其他依赖${NC}"
echo "======================"

# 核心依赖列表
DEPS=(
    "fastapi"
    "pydantic>=2.0"
    "numpy"
    "tqdm"
    "requests"
    "aiohttp"
    "ipython"
    "partial-json-parser"
    "orjson"
    "uvicorn"
    "uvloop"
    "pyzmq"
    "zmq"
    "pydantic-core"
    "starlette"
    "typing-extensions"
    "anyio"
    "idna"
    "sniffio"
    "certifi"
    "charset-normalizer"
    "urllib3"
    "frozenlist"
    "multidict"
    "yarl"
    "aiosignal"
    "async-timeout"
    "attrs"
    "wcwidth"
    "traitlets"
    "pygments"
    "matplotlib-inline"
    "stack-data"
    "prompt-toolkit"
    "decorator"
    "pexpect"
    "jedi"
    "pickleshare"
    "backcall"
    "executing"
    "asttokens"
    "pure-eval"
    "ptyprocess"
    "parso"
    "click"
    "h11"
    "MarkupSafe"
    "Jinja2"
    "itsdangerous"
)

# 批量下载依赖
for dep in "${DEPS[@]}"; do
    echo -e "${BLUE}下载:${NC} ${dep}"
    pip download \
        --dest "${PACKAGES_DIR}" \
        --python-version 310 \
        --platform manylinux2014_x86_64 \
        --only-binary :all: \
        "${dep}" 2>/dev/null || {
        # 如果 binary 下载失败，尝试 source
        pip download \
            --dest "${PACKAGES_DIR}" \
            --python-version 310 \
            "${dep}" 2>/dev/null || {
            echo -e "${YELLOW}  警告: ${dep} 下载失败${NC}"
        }
    }
done

# 清理临时环境
deactivate
rm -rf "${TEMP_VENV}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  下载完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}下载包位置:${NC} ${PACKAGES_DIR}"
echo -e "${BLUE}包数量:${NC} $(ls -1 "${PACKAGES_DIR}" | wc -l)"
echo ""
echo "包列表:"
ls -lh "${PACKAGES_DIR}"
echo ""

# 显示重要包
echo "关键包检查:"
echo "-------------"
for pkg in torch torchvision sgl-kernel fastapi pydantic numpy; do
    if ls "${PACKAGES_DIR}/${pkg}"* 1>/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} ${pkg}: $(ls "${PACKAGES_DIR}/${pkg}"* 2>/dev/null | head -1 | xargs basename)"
    else
        echo -e "${YELLOW}⚠${NC} ${pkg}: 未找到"
    fi
done
echo ""

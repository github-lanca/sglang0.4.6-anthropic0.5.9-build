# 离线 Docker 构建包 - 依赖下载指南

## 问题说明

由于 PyTorch 和 sgl-kernel 是平台特定的二进制包（CUDA 版本），必须在 Linux x86_64 机器上下载才能在 Docker 中使用。

macOS 无法直接下载 Linux 平台的 CUDA 版本 whl 包。

## 解决方案

### 方案一：在 Linux 机器上运行下载脚本（推荐）

如果有一台可以联网的 Linux 机器（如 Ubuntu）：

```bash
# 1. 将本目录传输到 Linux 机器
scp -r sglang-anthropic-build user@linux-server:/tmp/

# 2. 在 Linux 机器上运行下载脚本
ssh user@linux-server
cd /tmp/sglang-anthropic-build
chmod +x download-packages-linux.sh
./download-packages-linux.sh

# 3. 将下载的包传回 macOS
scp -r user@linux-server:/tmp/sglang-anthropic-build/packages/* \
      /Users/lanca/AI/github/sglang-anthropic-build/docker-build-offline/packages/
```

### 方案二：手动下载关键包

#### 1. PyTorch (CUDA 12.1)

在 Linux 机器上执行：

```bash
mkdir -p packages
cd packages

# PyTorch + torchvision
pip3 download \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    --only-binary=:all: \
    torch==2.3.0+cu121 \
    torchvision==0.18.0+cu121 \
    --extra-index-url https://download.pytorch.org/whl/cu121
```

或直接下载 whl 文件：

```bash
# PyTorch 2.3.0 + CUDA 12.1
wget https://download.pytorch.org/whl/cu121/torch-2.3.0%2Bcu121-cp310-cp310-linux_x86_64.whl

# TorchVision 0.18.0 + CUDA 12.1
wget https://download.pytorch.org/whl/cu121/torchvision-0.18.0%2Bcu121-cp310-cp310-linux_x86_64.whl
```

#### 2. sgl-kernel

```bash
pip3 download \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    --only-binary=:all: \
    sgl-kernel -i https://docs.sglang.ai/whl/cu121
```

或在有 Docker 的机器上：

```bash
docker run --rm -v $(pwd)/packages:/packages \
    python:3.10-slim \
    pip download --dest /packages --python-version 310 --platform manylinux2014_x86_64 --only-binary=:all: sgl-kernel
```

#### 3. 其他依赖（可选）

其他纯 Python 包可以在 macOS 上下载，也可以省略（Docker 构建时会在线安装）：

```bash
pip3 download \
    --dest packages \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    fastapi pydantic numpy tqdm requests aiohttp
```

### 方案三：在线构建（最简单）

如果服务器有外网访问，可以直接使用在线 Dockerfile：

```bash
# 使用项目根目录的 Dockerfile（会在线下载依赖）
cd /Users/lanca/AI/github/sglang-anthropic-build
docker build -t sglang:v0.4.6-cu121-anthropic .
```

## 完整离线构建流程

### 第一步：准备构建包（macOS）

```bash
cd /Users/lanca/AI/github/sglang-anthropic-build

# 运行准备脚本（只复制源码，不下载依赖）
./prepare-offline-build.sh

# 生成的目录结构：
# docker-build-offline/
# ├── Dockerfile
# ├── build.sh
# ├── packages/          # 空或部分依赖
# └── source/
#     └── sglang-anthropic-cu121/   # 完整源码
```

### 第二步：下载 Linux 依赖包

使用上述任一方案下载 PyTorch 和 sgl-kernel，放入 `packages/` 目录。

### 第三步：打包传输到离线服务器

```bash
# 打包
tar czvf sglang-offline-build.tar.gz docker-build-offline/

# 传输到离线服务器
scp sglang-offline-build.tar.gz user@offline-server:/home/user/
```

### 第四步：在离线服务器构建

```bash
# 在离线服务器上
ssh user@offline-server
tar xzvf sglang-offline-build.tar.gz
cd docker-build-offline
./build.sh
```

## 关键包清单

| 包名 | 版本 | 说明 | 必须 |
|------|------|------|------|
| torch | 2.3.0+cu121 | PyTorch CUDA 12.1 版本 | 是 |
| torchvision | 0.18.0+cu121 | PyTorch Vision | 是 |
| sgl-kernel | latest | SGLang 内核库 | 是 |
| fastapi | >=0.100.0 | Web 框架 | 可选* |
| pydantic | >=2.0 | 数据验证 | 可选* |
| numpy | <2.0 | 数值计算 | 可选* |

*可选：如果服务器完全离线，必须下载；如果有外网，可以在线安装

## 文件列表

下载完成后，`packages/` 目录应包含：

```
packages/
├── torch-2.3.0+cu121-cp310-cp310-linux_x86_64.whl
├── torchvision-0.18.0+cu121-cp310-cp310-linux_x86_64.whl
├── sgl_kernel-xxx-cp310-cp310-manylinux2014_x86_64.whl
├── fastapi-xxx-py3-none-any.whl
├── pydantic-xxx-cp310-cp310-manylinux2014_x86_64.whl
└── ...
```

## 故障排除

### 1. pip download 失败

检查 pip 版本：
```bash
pip3 --version  # 需要 >= 20.0
pip3 install --upgrade pip
```

### 2. 版本找不到

尝试去掉 `--only-binary`：
```bash
pip3 download --python-version 310 --platform manylinux2014_x86_64 torch==2.3.0
```

### 3. CUDA 版本不匹配

根据服务器 CUDA 版本调整：
- CUDA 12.1: `torch==2.3.0+cu121`
- CUDA 12.4: `torch==2.3.0+cu124`
- CUDA 11.8: `torch==2.3.0+cu118`

## 快速检查脚本

在 Linux 机器上下载后，运行以下检查：

```bash
cd packages

# 检查关键包是否存在
echo "检查关键包:"
ls -lh torch-* 2>/dev/null | head -1 || echo "警告: PyTorch 未找到"
ls -lh torchvision-* 2>/dev/null | head -1 || echo "警告: TorchVision 未找到"
ls -lh sgl* 2>/dev/null | head -1 || echo "警告: sgl-kernel 未找到"

# 统计
echo ""
echo "总计 whl 文件: $(ls *.whl 2>/dev/null | wc -l) 个"
echo "总大小: $(du -sh . | cut -f1)"
```

## 下一步

下载完成后，回到 `prepare-offline-build.sh` 脚本，它会自动将 packages 目录打包到最终构建包中。

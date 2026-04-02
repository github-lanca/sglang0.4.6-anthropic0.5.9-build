# SGLang Docker 离线构建完整方案

## 文件清单

已为您准备好以下文件：

| 文件 | 说明 |
|------|------|
| `prepare-offline-build.sh` | 主脚本：准备离线构建包 |
| `download-packages-linux.sh` | Linux 专用：下载 Python 依赖 |
| `OFFLINE_PACKAGES_README.md` | 依赖下载详细指南 |
| `docker-build-offline.tar.gz` | 预生成的构建包（18MB，源码） |

## 快速使用

### 场景 1：服务器有外网访问（最简单）

直接传输构建包，Dockerfile 会自动在线下载依赖：

```bash
# 1. 在 macOS 上生成构建包（已为您生成）
./prepare-offline-build.sh

# 2. 传输到服务器
scp docker-build-offline.tar.gz user@server:/path/

# 3. 在服务器上解压并构建
ssh user@server
tar xzvf docker-build-offline.tar.gz
cd docker-build-offline
./build.sh
```

### 场景 2：服务器完全离线

需要先在 Linux 机器上下载依赖：

```bash
# 1. 传输构建包到 Linux 机器（联网）
scp docker-build-offline.tar.gz user@linux-machine:/tmp/

# 2. 在 Linux 机器上下载依赖
ssh user@linux-machine
tar xzvf docker-build-offline.tar.gz
cd docker-build-offline
./download-packages-linux.sh

# 3. 压缩完整包（包含依赖）
tar czvf sglang-complete.tar.gz docker-build-offline/

# 4. 传输到离线服务器
scp sglang-complete.tar.gz user@offline-server:/path/

# 5. 在离线服务器构建
ssh user@offline-server
tar xzvf sglang-complete.tar.gz
cd docker-build-offline
./build.sh
```

## 当前构建包内容

```
docker-build-offline/
├── Dockerfile                    # Docker 构建文件
├── build.sh                      # 构建脚本
├── download-packages-linux.sh    # Linux 依赖下载脚本
├── packages/                     # 依赖包目录（当前为空）
├── source/
│   └── sglang-anthropic-cu121/  # SGLang 源码（76MB）
└── README.md                     # 使用说明
```

## 需要下载的依赖

**关键依赖**（必须在 Linux x86_64 上下载）：

| 包名 | 版本 | 大小 |
|------|------|------|
| torch | 2.3.0+cu121 | ~2.5GB |
| torchvision | 0.18.0+cu121 | ~50MB |
| sgl-kernel | latest | ~100MB |

**可选依赖**（纯 Python，服务器有网可自动安装）：
- fastapi, pydantic, numpy, tqdm, requests, aiohttp 等

## 下载命令

在 Linux 机器上执行：

```bash
# PyTorch
cd docker-build-offline/packages
pip3 download --python-version 310 --platform manylinux2014_x86_64 --only-binary=:all: \
    torch==2.3.0+cu121 torchvision==0.18.0+cu121 \
    --extra-index-url https://download.pytorch.org/whl/cu121

# sgl-kernel
pip3 download --python-version 310 --platform manylinux2014_x86_64 --only-binary=:all: \
    sgl-kernel -i https://docs.sglang.ai/whl/cu121

# 其他依赖
pip3 download --python-version 310 --platform manylinux2014_x86_64 \
    fastapi pydantic numpy tqdm requests aiohttp ipython \
    partial-json-parser orjson uvicorn uvloop pyzmq
```

## 验证构建包

```bash
# 检查压缩包大小
du -sh docker-build-offline.tar.gz

# 查看内容
tar tzf docker-build-offline.tar.gz | less

# 检查关键文件是否存在
tar tzf docker-build-offline.tar.gz | grep "anthropic/__init__.py"
tar tzf docker-build-offline.tar.gz | grep "anthropic/protocol.py"
tar tzf docker-build-offline.tar.gz | grep "anthropic/serving.py"
```

## Dockerfile 说明

```dockerfile
# 基础镜像
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# Python 3.10
# PyTorch 2.3.0 + CUDA 12.1
# SGLang v0.4.6 + Anthropic API 支持
# 暴露端口 30000
```

## 常见问题

### Q1: macOS 为什么不能下载 Linux 依赖？

PyTorch 的 CUDA 版本是针对特定操作系统和架构编译的二进制包。
macOS 的 pip 无法下载 Linux x86_64 + CUDA 版本的 whl 文件。

### Q2: 构建包大小？

- 仅源码：~18MB
- 完整包（含依赖）：~3GB

### Q3: 能否在 macOS 上测试构建？

不能。此镜像需要 NVIDIA GPU 和 Linux 环境。
macOS 只能准备构建包，无法运行容器。

### Q4: 服务器 CUDA 版本不同怎么办？

修改 Dockerfile 中的 PyTorch 版本：

```dockerfile
# CUDA 12.4
torch==2.3.0+cu124
torchvision==0.18.0+cu124

# CUDA 11.8
torch==2.3.0+cu118
torchvision==0.18.0+cu118
```

## 完整流程图

```
macOS 开发机                    Linux 联网机                    离线服务器
     |                               |                              |
     | 1. 准备源码                   |                              |
     |    ./prepare-offline-build.sh |                              |
     v                               |                              |
docker-build-offline.tar.gz ------> |                              |
     (18MB，无依赖)                  | 2. 下载依赖                  |
     |                               |    ./download-packages-linux.sh
     |                               v                              |
     |                      docker-build-offline/                   |
     |                      (源码 + 依赖，~3GB)                     |
     |                               |                              |
     +------------------------------>+------------------------------>
     |                               | 3. 传输到离线服务器          |
     |                               |                              v
     |                               |                      ./build.sh
     |                               |                              v
     |                               |                      Docker 镜像
```

## 下一步

1. **如果目标服务器有外网**：
   - 直接使用 `docker-build-offline.tar.gz`
   - Dockerfile 会在构建时自动下载依赖

2. **如果目标服务器完全离线**：
   - 将 `docker-build-offline` 传输到 Linux 机器
   - 运行 `./download-packages-linux.sh`
   - 打包后传输到离线服务器

3. **查看详细指南**：
   - 阅读 `OFFLINE_PACKAGES_README.md`

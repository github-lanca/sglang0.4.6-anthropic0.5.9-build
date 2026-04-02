# SGLang v0.4.6 + Anthropic 支持 Docker 离线构建操作手册

## 概述

本手册指导你在离线服务器上构建包含 Anthropic API 支持的 SGLang v0.4.6 Docker 镜像。

## 前提条件

- 离线服务器已有 `nvidia/cuda:12.1.1-devel-ubuntu22.04` 镜像
- 有一台可以联网的电脑用于下载依赖
- 有方式将文件传输到离线服务器（USB、内网传文件等）

---

## 第一部分：在联网机器上准备依赖

### 步骤 1：创建工作目录

```bash
mkdir -p ~/sglang-docker-build/{packages,source}
cd ~/sglang-docker-build
```

### 步骤 2：克隆 SGLang 源码（v0.4.6）并应用修改

```bash
cd ~/sglang-docker-build/source

# 克隆官方仓库
git clone https://github.com/sgl-project/sglang.git sglang-anthropic-cu121
cd sglang-anthropic-cu121

# 切换到 v0.4.6 标签
git checkout v0.4.6

# 创建 anthropic 目录
mkdir -p python/sglang/srt/entrypoints/anthropic

# 创建 __init__.py (空文件)
touch python/sglang/srt/entrypoints/anthropic/__init__.py
```

### 步骤 3：创建 protocol.py

将以下内容保存到 `python/sglang/srt/entrypoints/anthropic/protocol.py`：

```python
"""Pydantic models for Anthropic Messages API protocol"""

import uuid
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field, field_validator


class AnthropicError(BaseModel):
    """Error structure for Anthropic API"""

    type: str
    message: str


class AnthropicErrorResponse(BaseModel):
    """Error response structure for Anthropic API"""

    type: Literal["error"] = "error"
    error: AnthropicError


class AnthropicUsage(BaseModel):
    """Token usage information"""

    input_tokens: int
    output_tokens: int
    cache_creation_input_tokens: Optional[int] = None
    cache_read_input_tokens: Optional[int] = None


class AnthropicContentBlock(BaseModel):
    """Content block in message"""

    type: Literal[
        "text", "image", "tool_use", "tool_result", "thinking", "redacted_thinking"
    ]
    text: Optional[str] = None
    # For image content
    source: Optional[dict[str, Any]] = None
    # For tool use/result
    id: Optional[str] = None
    tool_use_id: Optional[str] = None
    name: Optional[str] = None
    input: Optional[dict[str, Any]] = None
    content: Optional[str | list[dict[str, Any]]] = None
    is_error: Optional[bool] = None
    # For thinking content
    thinking: Optional[str] = None
    signature: Optional[str] = None


class AnthropicMessage(BaseModel):
    """Message structure"""

    role: Literal["user", "assistant"]
    content: str | list[AnthropicContentBlock]


class AnthropicTool(BaseModel):
    """Tool definition"""

    name: str
    description: Optional[str] = None
    input_schema: dict[str, Any]

    @field_validator("input_schema")
    @classmethod
    def validate_input_schema(cls, v):
        if not isinstance(v, dict):
            raise ValueError("input_schema must be a dictionary")
        if "type" not in v:
            v["type"] = "object"
        return v


class AnthropicToolChoice(BaseModel):
    """Tool Choice definition"""

    type: Literal["auto", "any", "tool", "none"]
    name: Optional[str] = None


class AnthropicCountTokensRequest(BaseModel):
    """Anthropic Count Tokens API request"""

    model: str
    messages: list[AnthropicMessage]
    system: Optional[str | list[AnthropicContentBlock]] = None
    tool_choice: Optional[AnthropicToolChoice] = None
    tools: Optional[list[AnthropicTool]] = None


class AnthropicCountTokensResponse(BaseModel):
    """Anthropic Count Tokens API response"""

    input_tokens: int


class AnthropicMessagesRequest(BaseModel):
    """Anthropic Messages API request"""

    model: str
    messages: list[AnthropicMessage]
    max_tokens: int
    metadata: Optional[dict[str, Any]] = None
    stop_sequences: Optional[list[str]] = None
    stream: Optional[bool] = False
    system: Optional[str | list[AnthropicContentBlock]] = None
    temperature: Optional[float] = None
    tool_choice: Optional[AnthropicToolChoice] = None
    tools: Optional[list[AnthropicTool]] = None
    top_k: Optional[int] = None
    top_p: Optional[float] = None

    @field_validator("model")
    @classmethod
    def validate_model(cls, v):
        if not v:
            raise ValueError("Model is required")
        return v

    @field_validator("max_tokens")
    @classmethod
    def validate_max_tokens(cls, v):
        if v <= 0:
            raise ValueError("max_tokens must be positive")
        return v


class AnthropicDelta(BaseModel):
    """Delta for streaming responses"""

    type: Optional[Literal["text_delta", "input_json_delta"]] = None
    text: Optional[str] = None
    partial_json: Optional[str] = None

    # Message delta fields
    stop_reason: Optional[
        Literal["end_turn", "max_tokens", "stop_sequence", "tool_use"]
    ] = None
    stop_sequence: Optional[str] = None


class AnthropicStreamEvent(BaseModel):
    """Streaming event"""

    type: Literal[
        "message_start",
        "message_delta",
        "message_stop",
        "content_block_start",
        "content_block_delta",
        "content_block_stop",
        "ping",
        "error",
    ]
    message: Optional["AnthropicMessagesResponse"] = None
    delta: Optional[AnthropicDelta] = None
    content_block: Optional[AnthropicContentBlock] = None
    index: Optional[int] = None
    error: Optional[AnthropicError] = None
    usage: Optional[AnthropicUsage] = None


class AnthropicMessagesResponse(BaseModel):
    """Anthropic Messages API response"""

    id: str = Field(default_factory=lambda: f"msg_{uuid.uuid4().hex}")
    type: Literal["message"] = "message"
    role: Literal["assistant"] = "assistant"
    content: list[AnthropicContentBlock]
    model: str
    stop_reason: Optional[
        Literal["end_turn", "max_tokens", "stop_sequence", "tool_use"]
    ] = None
    stop_sequence: Optional[str] = None
    usage: Optional[AnthropicUsage] = None
```

### 步骤 4：创建 serving.py

由于文件较长，请在联网机器上执行以下命令直接下载：

```bash
cd ~/sglang-docker-build/source/sglang-anthropic-cu121/python/sglang/srt/entrypoints/anthropic

# 创建 serving.py（内容见附注 1）
cat > serving.py << 'SERVING_EOF'
# 这里放 serving.py 的完整内容
# 请从附注 1 复制内容
SERVING_EOF
```

**注意**：由于 serving.py 文件较长（568行），请在联网机器上使用文本编辑器创建，或从已修改的代码复制。

### 步骤 5：修改 http_server.py

在 `python/sglang/srt/entrypoints/http_server.py` 中进行以下修改：

1. 在文件头部添加导入（约在第 46 行附近）：

```python
from sglang.srt.entrypoints.engine import _launch_subprocesses
from sglang.srt.entrypoints.anthropic.protocol import (
    AnthropicCountTokensRequest,
    AnthropicMessagesRequest,
)
from sglang.srt.entrypoints.anthropic.serving import AnthropicServing
from sglang.srt.function_call_parser import FunctionCallParser
```

2. 在文件末尾、`_create_error_response` 函数之前添加 Anthropic 端点（约在文件末尾）：

```python
##### Anthropic-compatible API endpoints #####


@app.post("/v1/messages")
async def anthropic_v1_messages(
    request: AnthropicMessagesRequest, raw_request: Request
):
    """Anthropic-compatible Messages API endpoint."""
    anthropic_serving = AnthropicServing(_global_state.tokenizer_manager)
    return await anthropic_serving.handle_messages(request, raw_request)


@app.post("/v1/messages/count_tokens")
async def anthropic_v1_count_tokens(
    request: AnthropicCountTokensRequest, raw_request: Request
):
    """Anthropic-compatible token counting endpoint."""
    anthropic_serving = AnthropicServing(_global_state.tokenizer_manager)
    return await anthropic_serving.handle_count_tokens(request, raw_request)


def _create_error_response(e):
```

### 步骤 6：下载 Python 依赖包（whl 格式）

```bash
cd ~/sglang-docker-build/packages

# 创建 requirements 文件
cat > requirements.txt << 'EOF'
torch==2.3.0+cu121
torchvision==0.18.0+cu121
sgl-kernel
fastapi
pydantic
numpy
tqdm
requests
aiohttp
IPython
partial-json-parser
orjson
uvicorn
uvloop
zmq
pyzmq
EOF

# 下载依赖到本地（使用 pip download）
pip3 download \
    --dest . \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    torch==2.3.0+cu121 \
    torchvision==0.18.0+cu121 \
    --extra-index-url https://download.pytorch.org/whl/cu121

# 下载其他依赖
pip3 download \
    --dest . \
    --python-version 310 \
    --platform manylinux2014_x86_64 \
    sgl-kernel fastapi pydantic numpy tqdm requests aiohttp IPython partial-json-parser orjson uvicorn uvloop pyzmq
```

**注意**：如果遇到下载问题，可以尝试去掉 `--platform` 参数，或根据实际架构调整。

### 步骤 7：准备 Dockerfile

```bash
cd ~/sglang-docker-build

cat > Dockerfile << 'EOF'
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

# 复制 Python 依赖包
COPY packages/*.whl /tmp/packages/

# 安装 PyTorch CUDA 12.1 版本
RUN pip3 install --no-cache-dir \
    /tmp/packages/torch-2.3.0+cu121*.whl \
    /tmp/packages/torchvision-0.18.0+cu121*.whl || \
    pip3 install torch==2.3.0 torchvision==0.18.0

# 安装 sgl-kernel
RUN pip3 install --no-cache-dir /tmp/packages/sgl_kernel*.whl || \
    echo "sgl-kernel will be installed later"

# 安装其他依赖
RUN pip3 install --no-cache-dir \
    /tmp/packages/*.whl 2>/dev/null || \
    pip3 install fastapi pydantic numpy tqdm requests aiohttp IPython partial-json-parser orjson uvicorn uvloop pyzmq

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
```

### 步骤 8：打包文件

```bash
cd ~/sglang-docker-build

# 创建传输包
tar czvf sglang-anthropic-build.tar.gz Dockerfile packages/ source/

# 查看包大小
ls -lh sglang-anthropic-build.tar.gz
```

---

## 第二部分：在离线服务器上构建

### 步骤 1：传输文件到离线服务器

将 `sglang-anthropic-build.tar.gz` 传输到离线服务器：

```bash
# 在离线服务器上创建目录
mkdir -p ~/sglang-build
cd ~/sglang-build

# 传输文件（通过 USB、SCP 或其他方式）
# 然后解压
tar xzvf sglang-anthropic-build.tar.gz
```

### 步骤 2：验证文件结构

```bash
cd ~/sglang-build
ls -la

# 应该看到：
# - Dockerfile
# - packages/
# - source/

# 检查 packages 目录
ls packages/

# 检查 source 目录
ls source/sglang-anthropic-cu121/python/sglang/srt/entrypoints/anthropic/
```

### 步骤 3：构建 Docker 镜像

```bash
cd ~/sglang-build

# 使用 buildx 构建（推荐）
docker buildx create --use 2>/dev/null || true

# 构建镜像（仅 AMD64 架构）
docker buildx build \
    --platform linux/amd64 \
    -t sglang:v0.4.6-cu121-anthropic \
    --load \
    .

# 如果 buildx 不可用，使用传统构建
docker build \
    -t sglang:v0.4.6-cu121-anthropic \
    .
```

构建过程可能需要 10-30 分钟，取决于机器性能。

### 步骤 4：验证镜像

```bashn# 查看镜像
docker images | grep sglang

# 检查镜像详情
docker inspect sglang:v0.4.6-cu121-anthropic

# 测试运行（不需要 GPU）
docker run --rm sglang:v0.4.6-cu121-anthropic python3 -c "print('Hello from SGLang')"
```

### 步骤 5：保存镜像（可选）

如果需要在其他离线服务器上使用：

```bash
# 保存镜像为 tar 文件
docker save sglang:v0.4.6-cu121-anthropic | gzip > sglang-v0.4.6-cu121-anthropic.tar.gz

# 查看文件大小
ls -lh sglang-v0.4.6-cu121-anthropic.tar.gz
```

---

## 第三部分：运行容器

### 基本运行命令

```bash
# 运行容器（单 GPU）
docker run -d --gpus all \
    -p 30000:30000 \
    --name sglang-server \
    sglang:v0.4.6-cu121-anthropic \
    --model-path /path/to/model \
    --host 0.0.0.0 \
    --port 30000
```

### 挂载模型目录

```bash
# 假设模型在 /data/models 目录
docker run -d --gpus all \
    -p 30000:30000 \
    -v /data/models:/models:ro \
    --name sglang-server \
    sglang:v0.4.6-cu121-anthropic \
    --model-path /models/your-model \
    --host 0.0.0.0 \
    --port 30000
```

### 多 GPU 运行

```bash
# 使用所有 GPU
docker run -d --gpus all \
    -p 30000:30000 \
    -v /data/models:/models:ro \
    --name sglang-server \
    sglang:v0.4.6-cu121-anthropic \
    --model-path /models/your-model \
    --tp-size 2 \
    --host 0.0.0.0 \
    --port 30000
```

---

## 第四部分：测试 Anthropic API

### 测试健康检查

```bash
curl http://localhost:30000/health
```

### 测试 Anthropic Messages API

```bash
curl http://localhost:30000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "Hello, how are you?"}],
    "max_tokens": 100
  }'
```

### 测试流式响应

```bash
curl http://localhost:30000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100,
    "stream": true
  }'
```

### 测试 Token 计数

```bash
curl http://localhost:30000/v1/messages/count_tokens \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "Hello world"}]
  }'
```

### 测试工具调用

```bash
curl http://localhost:30000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "What is the weather in NYC?"}],
    "max_tokens": 200,
    "tools": [
      {
        "name": "get_weather",
        "description": "Get weather for a location",
        "input_schema": {
          "type": "object",
          "properties": {
            "location": {"type": "string"}
          },
          "required": ["location"]
        }
      }
    ]
  }'
```

---

## 常见问题排查

### 问题 1：构建时 pip 安装失败

**解决方案**：
```bash
# 查看具体错误
docker build --no-cache -t test-build . 2>&1 | tee build.log

# 如果 whl 文件安装失败，修改 Dockerfile 使用 pip 在线安装
# 注释掉本地 whl 安装，使用 pip install
```

### 问题 2：CUDA 版本不匹配

**解决方案**：
```bash
# 检查服务器 CUDA 版本
nvidia-smi

# 如果 CUDA 版本不同，修改 Dockerfile 中的 PyTorch 版本
# 例如 CUDA 12.4：
# torch==2.3.0+cu124
```

### 问题 3：缺少 libcuda.so

**解决方案**：
```bash
# 在 Dockerfile 中添加
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}
```

### 问题 4：内存不足

**解决方案**：
```bash
# 使用 --memory 限制
# 或使用 swap
```

---

## 附注 1：serving.py 完整代码

由于 serving.py 文件较长，请在联网机器上使用以下方式获取：

**方式 1：从已修改的代码复制**

```bash
# 在你的开发机器上（已完成代码修改的机器）
cp /Users/lanca/AI/github/sglang/python/sglang/srt/entrypoints/anthropic/serving.py \
   ~/sglang-docker-build/source/sglang-anthropic-cu121/python/sglang/srt/entrypoints/anthropic/
```

**方式 2：使用 git 导出**

```bash
cd ~/sglang-docker-build/source/sglang-anthropic-cu121

# 创建 anthropic 目录和文件
mkdir -p python/sglang/srt/entrypoints/anthropic

# 使用编辑器创建 serving.py，或从附注中复制内容
```

serving.py 的完整代码请参考项目中的 `python/sglang/srt/entrypoints/anthropic/serving.py` 文件。

---

## 文件清单

离线构建需要以下文件：

```
sglang-anthropic-build/
├── Dockerfile                          # Docker 构建文件
├── packages/                           # Python whl 依赖包
│   ├── torch-2.3.0+cu121-*.whl
│   ├── torchvision-0.18.0+cu121-*.whl
│   ├── sgl_kernel-*.whl
│   └── ... (其他依赖)
└── source/
    └── sglang-anthropic-cu121/         # SGLang 源码（已修改）
        ├── python/
        │   └── sglang/
        │       └── srt/
        │           └── entrypoints/
        │               ├── anthropic/
        │               │   ├── __init__.py
        │               │   ├── protocol.py
        │               │   └── serving.py
        │               └── http_server.py  # 已修改
        └── ... (其他源码文件)
```

---

## 总结

1. **准备阶段**：在联网机器下载依赖、准备代码
2. **传输阶段**：将所有文件传输到离线服务器
3. **构建阶段**：在离线服务器构建 Docker 镜像
4. **运行阶段**：启动容器并测试 Anthropic API

如需帮助，请检查每一步的输出日志，定位具体问题。

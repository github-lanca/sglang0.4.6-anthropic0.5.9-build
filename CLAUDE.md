# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

本项目是 SGLang v0.4.6 的 Docker 构建包，将 v0.5.9+ 中的 Anthropic API 支持移植到 v0.4.6 版本。

**目录结构：**
- `prepare-docker-build.sh` - 构建包准备脚本（需在联网机器运行）
- `Dockerfile` - Docker 镜像构建文件
- `README_DOCKER_BUILD.md` - Docker 构建指南
- `DOCKER_OFFLINE_BUILD_MANUAL.md` - 离线构建详细手册
- `../sglang/` - SGLang 源码目录（父目录）
  - `python/sglang/srt/entrypoints/anthropic/` - Anthropic API 实现
    - `protocol.py` - API 协议模型定义
    - `serving.py` - 请求处理逻辑
  - `python/sglang/srt/entrypoints/http_server.py` - 已添加 Anthropic 端点

## 常用命令

### 准备构建包（联网机器）
```bash
# 在 sglang 仓库根目录运行
cd /Users/lanca/AI/github/sglang
chmod +x prepare-docker-build.sh
./prepare-docker-build.sh
```

构建包将生成在 `~/sglang-docker-build/sglang-anthropic-build.tar.gz`

### Docker 构建（在线/离线）
```bash
# 解压构建包
cd ~/sglang-docker-build

# 构建镜像
./build.sh
```

### 运行容器
```bash
# 单 GPU
docker run -d --gpus all \
    -p 30000:30000 \
    -v /path/to/models:/models:ro \
    sglang:v0.4.6-cu121-anthropic \
    --model-path /models/your-model \
    --host 0.0.0.0 \
    --port 30000

# 多 GPU (TP=2)
docker run -d --gpus all \
    -p 30000:30000 \
    -v /path/to/models:/models:ro \
    sglang:v0.4.6-cu121-anthropic \
    --model-path /models/your-model \
    --tp-size 2 \
    --host 0.0.0.0 \
    --port 30000
```

### 测试 API
```bash
# 健康检查
curl http://localhost:30000/health

# Anthropic Messages API
curl http://localhost:30000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model": "default", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 100}'

# Token 计数
curl http://localhost:30000/v1/messages/count_tokens \
  -H "Content-Type: application/json" \
  -d '{"model": "default", "messages": [{"role": "user", "content": "Hello world"}]}'
```

## Anthropic API 架构

### 核心组件

**1. 协议定义 (`python/sglang/srt/entrypoints/anthropic/protocol.py`)**
- `AnthropicMessagesRequest` - 消息请求模型
- `AnthropicMessagesResponse` - 消息响应模型
- `AnthropicCountTokensRequest/Response` - Token 计数
- `AnthropicStreamEvent` - 流式事件定义
- 支持内容类型：text、image、tool_use、tool_result

**2. 服务处理 (`python/sglang/srt/entrypoints/anthropic/serving.py`)**
- `AnthropicServing` 类 - 核心处理类
- `handle_messages()` - 处理 Messages API 请求
- `handle_count_tokens()` - 处理 Token 计数请求
- 内部使用 `tokenizer_manager` 与 SGLang 运行时交互
- 将 Anthropic 格式转换为 OpenAI 格式后处理

**3. HTTP 端点 (`python/sglang/srt/entrypoints/http_server.py`)**
```python
POST /v1/messages          # Anthropic Messages API
POST /v1/messages/count_tokens  # Token 计数
```

### 关键适配逻辑

由于 v0.4.6 使用函数式 OpenAI API 适配器（v0.5.9+ 使用类方式）：

1. `AnthropicServing` 直接使用 `tokenizer_manager` 而非继承 `OpenAIServingChat`
2. 使用 `v1_chat_generate_request()` 和 `v1_chat_generate_response()` 函数进行格式转换
3. 请求处理流程：
   - Anthropic 格式请求 → 转换为 OpenAI 格式
   - 调用 SGLang 内部生成 API
   - OpenAI 格式响应 → 转换回 Anthropic 格式

### 支持的 API 特性

- ✅ Messages API（非流式/流式）
- ✅ Token Counting API
- ✅ 系统消息（system）
- ✅ 多模态输入（文本 + 图片）
- ✅ 工具调用（tool_use / tool_result）
- ✅ 工具选择（tool_choice）
- ✅ 自定义参数（temperature、top_p、top_k、stop_sequences）
- ✅ SSE 流式事件（message_start、content_block_delta、message_stop 等）

## 镜像信息

| 项目 | 值 |
|------|-----|
| 基础镜像 | nvidia/cuda:12.1.1-devel-ubuntu22.04 |
| Python 版本 | 3.10 |
| PyTorch 版本 | 2.3.0+cu121 |
| SGLang 版本 | v0.4.6 + Anthropic API |
| CUDA 版本 | 12.1 |
| 暴露端口 | 30000 |

## 注意事项

1. **构建前提**：运行 `prepare-docker-build.sh` 前需确保在 sglang 仓库根目录，且已完成代码修改
2. **路径依赖**：Dockerfile 中的 `COPY` 路径基于 `prepare-docker-build.sh` 生成的目录结构
3. **GPU 要求**：需要 NVIDIA GPU 和 nvidia-docker2 支持
4. **离线构建**：如需离线构建，先在联网机器运行准备脚本，然后传输构建包到离线服务器

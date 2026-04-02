# SGLang v0.4.6 + Anthropic API 支持 - Docker 构建指南

## 项目概述

本项目将 SGLang v0.5.9+ 中的 Anthropic API 支持代码移植到 v0.4.6 版本，并提供完整的 Docker 构建方案。

## 已完成的工作

### 代码移植
- ✅ 创建 `python/sglang/srt/entrypoints/anthropic/` 目录
- ✅ 添加 `protocol.py` - Anthropic API 协议模型定义（178行）
- ✅ 添加 `serving.py` - Anthropic API 请求处理逻辑（568行）
- ✅ 修改 `http_server.py` - 添加 Anthropic API 端点（+26行）

### 功能支持
- ✅ Anthropic Messages API (`/v1/messages`)
- ✅ Anthropic Token Counting API (`/v1/messages/count_tokens`)
- ✅ 非流式和流式响应
- ✅ 多模态输入（文本 + 图片）
- ✅ 工具调用（Tool Use / Tool Result）
- ✅ 带图片的 Tool Result（已集成 v0.5.9 的修复）

### 测试验证
- ✅ 依赖检查（6项通过）
- ✅ 单元测试（21/21 通过）
- ✅ 集成测试（10/10 通过）
- ✅ 详细测试（14/14 通过）
- ✅ 端到端测试（15/15 通过）

## 文件清单

```
sglang/
├── python/sglang/srt/entrypoints/
│   ├── anthropic/
│   │   ├── __init__.py      # 空文件
│   │   ├── protocol.py      # Anthropic API 协议模型
│   │   └── serving.py       # 请求处理逻辑
│   └── http_server.py       # 已修改，添加 Anthropic 端点
├── Dockerfile               # Docker 构建文件
├── DOCKER_OFFLINE_BUILD_MANUAL.md  # 详细的离线构建手册
├── prepare-docker-build.sh  # 构建包准备脚本
└── README.md                # 本文件
```

## 快速开始

### 方式一：在线构建（有网络的服务器）

```bash
# 1. 确保你在 sglang 仓库根目录
cd /path/to/sglang

# 2. 运行准备脚本
chmod +x prepare-docker-build.sh
./prepare-docker-build.sh

# 3. 进入构建目录
cd ~/sglang-docker-build

# 4. 构建镜像
./build.sh

# 5. 运行容器
docker run -d --gpus all \
    -p 30000:30000 \
    -v /path/to/models:/models:ro \
    sglang:v0.4.6-cu121-anthropic \
    --model-path /models/your-model \
    --host 0.0.0.0 \
    --port 30000
```

### 方式二：离线构建（无网络的服务器）

请参考 `DOCKER_OFFLINE_BUILD_MANUAL.md` 获取详细的离线构建步骤。

**简要步骤：**

1. **在联网机器上准备：**
   ```bash
   ./prepare-docker-build.sh
   ```

2. **传输到离线服务器：**
   ```bash
   scp ~/sglang-docker-build/sglang-anthropic-build.tar.gz user@offline-server:/home/user/
   ```

3. **在离线服务器上构建：**
   ```bash
   tar xzvf sglang-anthropic-build.tar.gz
   cd sglang-docker-build
   ./build.sh
   ```

## API 使用示例

### 1. 健康检查

```bash
curl http://localhost:30000/health
```

### 2. Anthropic Messages API

```bash
curl http://localhost:30000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

### 3. 流式响应

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

### 4. Token 计数

```bash
curl http://localhost:30000/v1/messages/count_tokens \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "Hello world"}]
  }'
```

### 5. 工具调用

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

## 多 GPU 运行

```bash
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

## 系统要求

- **GPU**: NVIDIA GPU with CUDA 12.1 支持
- **Docker**: 已安装 nvidia-docker2
- **CUDA**: 基础镜像已包含 CUDA 12.1
- **Python**: 3.10
- **PyTorch**: 2.3.0+cu121

## 镜像信息

| 项目 | 值 |
|------|-----|
| 基础镜像 | nvidia/cuda:12.1.1-devel-ubuntu22.04 |
| Python 版本 | 3.10 |
| PyTorch 版本 | 2.3.0+cu121 |
| SGLang 版本 | v0.4.6 + Anthropic API |
| CUDA 版本 | 12.1 |
| 暴露端口 | 30000 |

## 常见问题

### Q1: 如何验证 Anthropic API 是否正常工作？

A: 启动容器后运行测试命令：
```bash
curl http://localhost:30000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model": "default", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 10}'
```

### Q2: 是否支持多模态（图片输入）？

A: 是的，支持 Anthropic 格式的图片输入，会自动转换为 OpenAI 格式处理。

### Q3: 是否支持工具调用？

A: 是的，支持完整的工具调用流程，包括 tool_use 和 tool_result。

### Q4: 流式响应是否正常？

A: 是的，支持 Anthropic 格式的 SSE 流式响应，包括 message_start、content_block_delta、message_stop 等事件。

## 技术细节

### 与 v0.5.9 原版代码的差异

由于 v0.4.6 使用函数式 OpenAI API 适配器，而非 v0.5.9+ 的类方式：

1. `AnthropicServing` 直接使用 `tokenizer_manager` 而非 `OpenAIServingChat`
2. 使用 `v1_chat_generate_request` 和 `v1_chat_generate_response` 函数
3. 集成了第二个 commit 的修复（保留 tool_result 中的图片内容）

### 支持的 Anthropic API 特性

- ✅ Messages API（非流式）
- ✅ Messages API（流式）
- ✅ Token Counting API
- ✅ 系统消息（system）
- ✅ 多模态内容（图片）
- ✅ 工具调用（Tools）
- ✅ 工具选择（Tool Choice）
- ✅ 自定义参数（temperature, top_p, top_k, stop_sequences）

## 贡献和反馈

如发现问题，请检查：
1. 日志输出 (`docker logs sglang-server`)
2. 测试验证 (`python test_anthropic_*.py`)
3. API 响应格式

## 许可证

与原 SGLang 项目相同（Apache 2.0）

---

**版本信息**
- SGLang 基础版本: v0.4.6
- Anthropic 功能来源: v0.5.9 (commit cc451671b)
- 移植日期: 2026-04-02

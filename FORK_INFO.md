# SGLang Anthropic API Fork 关键信息

## Fork 地址
https://github.com/github-lanca/sglang.git

## 关键 Commit
- **Commit ID**: `aafbcebca`
- **提交信息**: 将 SGLang v0.5.9+ 中的 Anthropic API 支持代码移植到 v0.4.6 版本
- **分支名**: `anthropic-api-backport-clean`

## 公司服务器部署步骤

### 1. 克隆 Fork 仓库
```bash
git clone https://github.com/github-lanca/sglang.git
cd sglang
```

### 2. 切换到指定分支（二选一）

**方式A - 使用分支名：**
```bash
git checkout anthropic-api-backport-clean
```

**方式B - 使用 Commit ID（最保险）：**
```bash
git checkout aafbcebca
```

### 3. 验证代码正确性

```bash
# 检查 Anthropic API 文件是否存在
ls python/sglang/srt/entrypoints/anthropic/

# 检查关键文件内容
head -20 python/sglang/srt/entrypoints/anthropic/serving.py
```

## 目录结构

```
sglang/
├── python/sglang/srt/entrypoints/
│   ├── anthropic/
│   │   ├── __init__.py
│   │   ├── protocol.py      # API 协议模型定义
│   │   └── serving.py       # 请求处理逻辑
│   └── http_server.py       # 已添加 Anthropic 端点
├── prepare-docker-build.sh  # 构建包准备脚本
├── Dockerfile               # Docker 镜像构建文件
└── ...
```

## 支持的 API 端点

- `POST /v1/messages` - Anthropic Messages API
- `POST /v1/messages/count_tokens` - Token 计数

## 备注

- 基础版本：SGLang v0.4.6
- 移植功能：v0.5.9+ 的 Anthropic API 支持
- 适配方式：函数式 OpenAI API 适配器

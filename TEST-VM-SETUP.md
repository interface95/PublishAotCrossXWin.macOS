# macOS 虚拟机环境测试指南

本指南用于在全新的 macOS 虚拟机上测试交叉编译环境的安装步骤。

## 📋 测试清单

### 第一步：基础环境检查

```bash
# 检查系统版本
sw_vers

# 检查是否安装了 Homebrew
which brew

# 如果没有 Homebrew，安装它
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

---

## 🪟 测试 Windows 交叉编译环境

### 1. 安装 .NET SDK

```bash
# 下载并安装 .NET 9.0
brew install --cask dotnet-sdk

# 验证安装
dotnet --version
dotnet --list-sdks
```

### 2. 安装 lld-link (LLVM 链接器)

```bash
# 安装 LLVM
brew install lld

# 添加到 PATH
export PATH="$(brew --prefix lld)/bin:$PATH"

# 验证
which lld-link
lld-link --version
```

**✅ 预期输出：**
```
LLD 17.x.x (compatible with GNU linkers)
```

### 3. 安装 Rust 和 xwin

```bash
# 安装 Rust (xwin 需要)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# 验证 Rust
rustc --version
cargo --version

# 安装 xwin
cargo install --locked xwin

# 验证
which xwin
xwin --version
```

### 4. 下载 Windows SDK

```bash
# 创建目录
mkdir -p $HOME/.local/share/xwin-sdk

# 下载 Windows SDK (这一步需要 5-10 分钟)
xwin --accept-license splat --output $HOME/.local/share/xwin-sdk

# 检查是否成功
ls -lh $HOME/.local/share/xwin-sdk
```

**✅ 预期输出：**
应该看到以下目录结构：
```
crt/
sdk/
```

### 5. 测试 Windows 交叉编译

```bash
# 克隆或下载测试项目
git clone https://github.com/interface95/PublishAotCrossXWin.macOS.git
cd PublishAotCrossXWin.macOS/test

# 编译到 Windows x64
dotnet publish -r win-x64 -c Release

# 检查输出
ls -lh bin/Release/net9.0/win-x64/publish/
file bin/Release/net9.0/win-x64/publish/Hello.exe
```

**✅ 预期输出：**
```
Hello.exe: PE32+ executable (console) x86-64, for MS Windows
```

---

## 🐧 测试 Linux 交叉编译环境

### 1. 安装 Zig

```bash
# 安装 Zig
brew install zig

# 验证
zig version
```

**✅ 预期输出：**
```
0.11.x 或更高版本
```

### 2. 测试 Linux x64 交叉编译

```bash
cd PublishAotCrossXWin.macOS/test

# 编译到 Linux x64
dotnet publish -r linux-x64 -c Release /p:StripSymbols=false

# 检查输出
ls -lh bin/Release/net9.0/linux-x64/publish/
file bin/Release/net9.0/linux-x64/publish/Hello
```

**✅ 预期输出：**
```
Hello: ELF 64-bit LSB pie executable, x86-64, dynamically linked
```

### 3. 测试 Linux ARM64 交叉编译

```bash
# 编译到 Linux ARM64
dotnet publish -r linux-arm64 -c Release /p:StripSymbols=false

# 检查输出
file bin/Release/net9.0/linux-arm64/publish/Hello
```

**✅ 预期输出：**
```
Hello: ELF 64-bit LSB pie executable, ARM aarch64, dynamically linked
```

### 4. 测试 Linux musl 交叉编译

```bash
# 编译到 Linux musl x64 (Alpine Linux)
dotnet publish -r linux-musl-x64 -c Release /p:StripSymbols=false

# 检查输出
file bin/Release/net9.0/linux-musl-x64/publish/Hello
```

**✅ 预期输出：**
```
Hello: ELF 64-bit LSB pie executable, x86-64, dynamically linked
```

---

## 📊 完整测试脚本

将以下内容保存为 `test-vm.sh`：

```bash
#!/bin/bash
set -e

echo "=================================="
echo "macOS 虚拟机交叉编译环境测试"
echo "=================================="
echo

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 已安装: $(which $1)"
        return 0
    else
        echo -e "${RED}✗${NC} $1 未安装"
        return 1
    fi
}

echo "=== 基础环境检查 ==="
sw_vers
echo

echo "=== 检查已安装的工具 ==="
check_command brew || echo "  → 运行: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
check_command dotnet || echo "  → 运行: brew install --cask dotnet-sdk"
check_command lld-link || echo "  → 运行: brew install lld && export PATH=\"\$(brew --prefix lld)/bin:\$PATH\""
check_command cargo || echo "  → 运行: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
check_command xwin || echo "  → 运行: cargo install --locked xwin"
check_command zig || echo "  → 运行: brew install zig"
echo

echo "=== 检查 Windows SDK ==="
if [ -d "$HOME/.local/share/xwin-sdk/crt" ]; then
    echo -e "${GREEN}✓${NC} Windows SDK 已下载"
    ls -lh $HOME/.local/share/xwin-sdk
else
    echo -e "${RED}✗${NC} Windows SDK 未下载"
    echo "  → 运行: mkdir -p \$HOME/.local/share/xwin-sdk && xwin --accept-license splat --output \$HOME/.local/share/xwin-sdk"
fi
echo

echo "=== .NET SDK 版本 ==="
if command -v dotnet &> /dev/null; then
    dotnet --version
    dotnet --list-sdks
fi
echo

echo "=== Zig 版本 ==="
if command -v zig &> /dev/null; then
    zig version
fi
echo

echo "=================================="
echo "测试完成！"
echo "=================================="
echo
echo "如果所有工具都已安装，可以继续测试编译："
echo "  1. 克隆项目: git clone https://github.com/interface95/PublishAotCrossXWin.macOS.git"
echo "  2. 进入测试目录: cd PublishAotCrossXWin.macOS/test"
echo "  3. 测试 Windows: dotnet publish -r win-x64 -c Release"
echo "  4. 测试 Linux: dotnet publish -r linux-x64 -c Release /p:StripSymbols=false"
```

---

## 🚀 快速测试步骤

在你的 macOS 虚拟机上运行：

```bash
# 1. 保存测试脚本
curl -o test-vm.sh https://raw.githubusercontent.com/interface95/PublishAotCrossXWin.macOS/main/test-vm.sh

# 2. 添加执行权限
chmod +x test-vm.sh

# 3. 运行测试
./test-vm.sh
```

---

## ⚠️ 常见问题

### 问题 1: Homebrew 安装很慢
**解决方案：** 使用国内镜像
```bash
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
```

### 问题 2: xwin 下载 Windows SDK 很慢
**解决方案：** 这是正常的，第一次下载需要 5-10 分钟

### 问题 3: PATH 设置后仍找不到命令
**解决方案：** 将 PATH 添加到 shell 配置文件
```bash
# 对于 zsh (macOS 默认)
echo 'export PATH="$(brew --prefix lld)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 对于 bash
echo 'export PATH="$(brew --prefix lld)/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
```

---

## 📝 测试记录

记录你的测试结果：

| 步骤 | 命令 | 是否成功 | 备注 |
|------|------|----------|------|
| 安装 Homebrew | `brew --version` | ☐ | |
| 安装 .NET SDK | `dotnet --version` | ☐ | |
| 安装 lld-link | `lld-link --version` | ☐ | |
| 安装 Rust | `cargo --version` | ☐ | |
| 安装 xwin | `xwin --version` | ☐ | |
| 下载 Windows SDK | `ls ~/.local/share/xwin-sdk` | ☐ | |
| 安装 Zig | `zig version` | ☐ | |
| 编译到 Windows | `dotnet publish -r win-x64` | ☐ | |
| 编译到 Linux | `dotnet publish -r linux-x64` | ☐ | |
| 编译到 Linux ARM64 | `dotnet publish -r linux-arm64` | ☐ | |

---

## 💡 预计时间

- **Windows 环境搭建**: 15-20 分钟 (主要是下载 Windows SDK)
- **Linux 环境搭建**: 5 分钟
- **测试编译**: 每个目标 2-3 分钟

**总计**: 约 30-40 分钟


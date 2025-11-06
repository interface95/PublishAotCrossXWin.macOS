#!/bin/bash
set -e

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================================"
echo "  PublishAotCross.macOS - Linux 交叉编译环境安装"
echo "  macOS → Linux"
echo "================================================================"
echo

# 检查是否在 macOS 上运行
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}错误: 此脚本只能在 macOS 上运行${NC}"
    exit 1
fi

echo -e "${BLUE}[1/3]${NC} 检查 Homebrew..."
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}→ 安装 Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # 根据架构添加 Homebrew 到 PATH
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    echo -e "${GREEN}✓ Homebrew 安装完成${NC}"
else
    echo -e "${GREEN}✓ Homebrew 已安装${NC}"
fi
echo

echo -e "${BLUE}[2/3]${NC} 安装 .NET SDK..."
if ! command -v dotnet &> /dev/null; then
    echo -e "${YELLOW}→ 安装 .NET SDK...${NC}"
    brew install --cask dotnet-sdk
    echo -e "${GREEN}✓ .NET SDK 安装完成${NC}"
else
    DOTNET_VERSION=$(dotnet --version)
    echo -e "${GREEN}✓ .NET SDK 已安装 (版本: $DOTNET_VERSION)${NC}"
fi
echo

echo -e "${BLUE}[3/4]${NC} 安装 Zig..."
if ! command -v zig &> /dev/null; then
    echo -e "${YELLOW}→ 安装 Zig...${NC}"
    brew install zig
    echo -e "${GREEN}✓ Zig 安装完成${NC}"
else
    ZIG_VERSION=$(zig version)
    echo -e "${GREEN}✓ Zig 已安装 (版本: $ZIG_VERSION)${NC}"
fi
echo

echo -e "${BLUE}[4/4]${NC} 安装 LLVM (可选，用于符号剥离)..."
if ! command -v llvm-objcopy &> /dev/null; then
    echo -e "${YELLOW}→ 安装 LLVM (包含 llvm-objcopy)...${NC}"
    brew install llvm
    
    # 创建 objcopy 符号链接
    mkdir -p ~/.local/bin
    ln -sf $(brew --prefix llvm)/bin/llvm-objcopy ~/.local/bin/objcopy
    
    # 添加到 PATH
    LLVM_PATH="$(brew --prefix llvm)/bin"
    LOCAL_BIN="$HOME/.local/bin"
    export PATH="$LOCAL_BIN:$LLVM_PATH:$PATH"
    
    # 添加到 shell 配置
    if [[ $SHELL == *"zsh"* ]]; then
        if ! grep -q ".local/bin" ~/.zshrc 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$(brew --prefix llvm)/bin:$PATH"' >> ~/.zshrc
        fi
    else
        if ! grep -q ".local/bin" ~/.bash_profile 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$(brew --prefix llvm)/bin:$PATH"' >> ~/.bash_profile
        fi
    fi
    
    echo -e "${GREEN}✓ LLVM 安装完成${NC}"
else
    echo -e "${GREEN}✓ llvm-objcopy 已安装${NC}"
fi
echo

echo "================================================================"
echo -e "${GREEN}  ✓ Linux 交叉编译环境安装完成！${NC}"
echo "================================================================"
echo

# 显示版本信息
echo "=== 已安装工具 ==="
echo "✓ Homebrew: $(brew --version | head -1)"
echo "✓ .NET SDK: $(dotnet --version)"
echo "✓ Zig: $(zig version)"
if command -v llvm-objcopy &> /dev/null; then
    echo "✓ LLVM objcopy: $(llvm-objcopy --version 2>&1 | head -1 | awk '{print $4}')"
fi
echo

echo "=== 支持的交叉编译目标 ==="
echo "Linux: linux-x64, linux-arm64, linux-musl-x64, linux-musl-arm64"
echo

echo "=== 快速开始 ==="
echo "1. 在你的项目中添加 NuGet 包:"
echo "   dotnet add package PublishAotCross.macOS --version 1.0.2-preview"
echo
echo "2. 编译到 Linux x64 (启用符号剥离，减少 80% 体积):"
echo "   dotnet publish -r linux-x64 -c Release /p:StripSymbols=true"
echo
echo "3. 编译到 Linux ARM64:"
echo "   dotnet publish -r linux-arm64 -c Release /p:StripSymbols=true"
echo
echo "4. 编译到 Alpine Linux (musl):"
echo "   dotnet publish -r linux-musl-x64 -c Release /p:StripSymbols=true"
echo
echo -e "${BLUE}💡 提示: 符号剥离可减少 ~80% 文件大小 (7.4MB → 1.5MB)${NC}"
echo

echo "================================================================"
echo -e "${YELLOW}注意: Linux 二进制文件在运行时可能需要 ICU 库${NC}"
echo "目标系统安装 ICU:"
echo "  Ubuntu/Debian: sudo apt-get install -y libicu-dev"
echo "  CentOS/RHEL:   sudo yum install -y icu"
echo "  Alpine:        apk add --no-cache icu-libs"
echo
echo "或在项目中禁用国际化（无需 ICU）:"
echo "  <InvariantGlobalization>true</InvariantGlobalization>"
echo "================================================================"


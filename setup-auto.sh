#!/bin/bash
set -e

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
PROJECT_NAME="AvaloniaAotCrossDemo"
PROJECT_DIR="$HOME/Desktop/$PROJECT_NAME"

echo "=================================================="
echo "  macOS 交叉编译环境 - 全自动安装"
echo "=================================================="
echo

# 检查是否在 macOS 上运行
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}错误: 此脚本只能在 macOS 上运行${NC}"
    exit 1
fi

echo -e "${BLUE}[1/9]${NC} 检查 Homebrew..."
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}→ 安装 Homebrew...${NC}"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
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

echo -e "${BLUE}[2/9]${NC} 安装 .NET 9 SDK..."
if ! command -v dotnet &> /dev/null; then
    echo -e "${YELLOW}→ 安装 .NET 9 SDK...${NC}"
    brew install --cask dotnet-sdk
    echo -e "${GREEN}✓ .NET SDK 安装完成${NC}"
else
    DOTNET_VERSION=$(dotnet --version)
    echo -e "${GREEN}✓ .NET SDK 已安装 (版本: $DOTNET_VERSION)${NC}"
fi
echo

echo -e "${BLUE}[3/9]${NC} 安装 LLVM (lld-link)..."
if ! command -v lld-link &> /dev/null; then
    echo -e "${YELLOW}→ 安装 LLVM...${NC}"
    brew install lld
    
    # 添加到 PATH
    LLD_PATH="$(brew --prefix lld)/bin"
    export PATH="$LLD_PATH:$PATH"
    
    # 添加到 shell 配置
    if [[ $SHELL == *"zsh"* ]]; then
        if ! grep -q "lld/bin" ~/.zshrc 2>/dev/null; then
            echo 'export PATH="$(brew --prefix lld)/bin:$PATH"' >> ~/.zshrc
        fi
    else
        if ! grep -q "lld/bin" ~/.bash_profile 2>/dev/null; then
            echo 'export PATH="$(brew --prefix lld)/bin:$PATH"' >> ~/.bash_profile
        fi
    fi
    
    echo -e "${GREEN}✓ lld-link 安装完成${NC}"
else
    echo -e "${GREEN}✓ lld-link 已安装${NC}"
fi
echo

echo -e "${BLUE}[4/9]${NC} 安装 Rust..."
if ! command -v cargo &> /dev/null; then
    echo -e "${YELLOW}→ 安装 Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --quiet
    source $HOME/.cargo/env
    echo -e "${GREEN}✓ Rust 安装完成${NC}"
else
    echo -e "${GREEN}✓ Rust 已安装${NC}"
    source $HOME/.cargo/env 2>/dev/null || true
fi
echo

echo -e "${BLUE}[5/9]${NC} 安装 xwin..."
if ! command -v xwin &> /dev/null; then
    echo -e "${YELLOW}→ 安装 xwin...${NC}"
    cargo install --locked xwin --quiet
    echo -e "${GREEN}✓ xwin 安装完成${NC}"
else
    echo -e "${GREEN}✓ xwin 已安装${NC}"
fi
echo

echo -e "${BLUE}[6/9]${NC} 下载 Windows SDK..."
if [ ! -d "$HOME/.local/share/xwin-sdk/crt" ]; then
    echo -e "${YELLOW}→ 下载 Windows SDK (需要 5-10 分钟，请耐心等待)...${NC}"
    mkdir -p $HOME/.local/share/xwin-sdk
    xwin --accept-license splat --output $HOME/.local/share/xwin-sdk
    echo -e "${GREEN}✓ Windows SDK 下载完成${NC}"
    echo "SDK 大小: $(du -sh $HOME/.local/share/xwin-sdk | cut -f1)"
else
    echo -e "${GREEN}✓ Windows SDK 已存在${NC}"
fi
echo

echo -e "${BLUE}[7/9]${NC} 安装 Zig..."
if ! command -v zig &> /dev/null; then
    echo -e "${YELLOW}→ 安装 Zig...${NC}"
    brew install zig
    echo -e "${GREEN}✓ Zig 安装完成${NC}"
else
    ZIG_VERSION=$(zig version)
    echo -e "${GREEN}✓ Zig 已安装 (版本: $ZIG_VERSION)${NC}"
fi
echo

echo -e "${BLUE}[8/9]${NC} 安装 Avalonia 模板..."
if ! dotnet new list 2>/dev/null | grep -q "Avalonia"; then
    echo -e "${YELLOW}→ 安装 Avalonia.Templates...${NC}"
    dotnet new install Avalonia.Templates
    echo -e "${GREEN}✓ Avalonia 模板安装完成${NC}"
else
    echo -e "${GREEN}✓ Avalonia 模板已安装${NC}"
fi
echo

echo -e "${BLUE}[9/9]${NC} 创建测试项目..."
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}→ 项目目录已存在，跳过创建${NC}"
else
    echo -e "${YELLOW}→ 创建 Avalonia 项目: $PROJECT_NAME${NC}"
    dotnet new avalonia.mvvm -o "$PROJECT_DIR" -n "$PROJECT_NAME"
    
    # 修改 .csproj 添加 PublishAotCross.macOS
    CSPROJ_FILE="$PROJECT_DIR/$PROJECT_NAME.csproj"
    
    echo -e "${YELLOW}→ 添加 PublishAotCross.macOS 包...${NC}"
    
    # 备份原文件
    cp "$CSPROJ_FILE" "$CSPROJ_FILE.bak"
    
    # 在 </Project> 之前添加 PackageReference
    sed -i '' '/<\/Project>/i\
\
  <ItemGroup>\
    <PackageReference Include="PublishAotCross.macOS" Version="1.0.0" />\
  </ItemGroup>\
' "$CSPROJ_FILE"
    
    echo -e "${GREEN}✓ 项目创建完成${NC}"
fi
echo

echo "=================================================="
echo -e "${GREEN}  ✓ 安装完成！${NC}"
echo "=================================================="
echo

# 显示版本信息
echo "=== 已安装工具 ==="
echo "✓ Homebrew: $(brew --version | head -1)"
echo "✓ .NET SDK: $(dotnet --version)"
echo "✓ lld-link: $(lld-link --version 2>&1 | head -1)"
echo "✓ Rust: $(rustc --version)"
echo "✓ Cargo: $(cargo --version)"
echo "✓ xwin: $(xwin --version 2>&1 | head -1)"
echo "✓ Zig: $(zig version)"
echo "✓ Avalonia: 已安装"
echo

echo "=== 创建的项目 ==="
echo "项目名称: $PROJECT_NAME"
echo "项目路径: $PROJECT_DIR"
echo

echo "=== 测试编译 ==="
echo
echo "进入项目目录:"
echo "  cd \"$PROJECT_DIR\""
echo
echo "编译到 Windows x64:"
echo "  dotnet publish -r win-x64 -c Release /p:publishAot=true"
echo
echo "编译到 Linux x64:"
echo "  dotnet publish -r linux-x64 -c Release /p:StripSymbols=false /p:publishAot=true"
echo
echo "编译到 Linux ARM64:"
echo "  dotnet publish -r linux-arm64 -c Release /p:StripSymbols=false /p:publishAot=true"
echo

echo "=================================================="
echo -e "${YELLOW}提示: 重新打开终端或运行以下命令使环境变量生效:${NC}"
if [[ $SHELL == *"zsh"* ]]; then
    echo "  source ~/.zshrc"
else
    echo "  source ~/.bash_profile"
fi
echo "=================================================="


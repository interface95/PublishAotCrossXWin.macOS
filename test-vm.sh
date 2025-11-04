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
    echo "SDK 大小:"
    du -sh $HOME/.local/share/xwin-sdk
else
    echo -e "${RED}✗${NC} Windows SDK 未下载"
    echo "  → 运行: mkdir -p \$HOME/.local/share/xwin-sdk && xwin --accept-license splat --output \$HOME/.local/share/xwin-sdk"
fi
echo

echo "=== .NET SDK 版本 ==="
if command -v dotnet &> /dev/null; then
    dotnet --version
    dotnet --list-sdks
else
    echo -e "${RED}✗${NC} .NET SDK 未安装"
fi
echo

echo "=== LLVM/lld-link 版本 ==="
if command -v lld-link &> /dev/null; then
    lld-link --version
else
    echo -e "${RED}✗${NC} lld-link 未安装"
fi
echo

echo "=== Rust/Cargo 版本 ==="
if command -v cargo &> /dev/null; then
    cargo --version
else
    echo -e "${RED}✗${NC} Cargo 未安装"
fi
echo

echo "=== xwin 版本 ==="
if command -v xwin &> /dev/null; then
    xwin --version
else
    echo -e "${RED}✗${NC} xwin 未安装"
fi
echo

echo "=== Zig 版本 ==="
if command -v zig &> /dev/null; then
    zig version
else
    echo -e "${RED}✗${NC} Zig 未安装"
fi
echo

echo "=================================="
echo "环境检查完成！"
echo "=================================="
echo

# 统计
TOTAL=6
INSTALLED=0
command -v brew &> /dev/null && ((INSTALLED++)) || true
command -v dotnet &> /dev/null && ((INSTALLED++)) || true
command -v lld-link &> /dev/null && ((INSTALLED++)) || true
command -v xwin &> /dev/null && ((INSTALLED++)) || true
command -v zig &> /dev/null && ((INSTALLED++)) || true
[ -d "$HOME/.local/share/xwin-sdk/crt" ] && ((INSTALLED++)) || true

echo "进度: $INSTALLED / $TOTAL 完成"
echo

if [ $INSTALLED -eq $TOTAL ]; then
    echo -e "${GREEN}✓ 所有依赖都已安装！${NC}"
    echo
    echo "可以开始测试编译："
    echo "  1. 克隆项目: git clone https://github.com/interface95/PublishAotCrossXWin.macOS.git"
    echo "  2. 进入测试目录: cd PublishAotCrossXWin.macOS/test"
    echo "  3. 测试 Windows: dotnet publish -r win-x64 -c Release"
    echo "  4. 测试 Linux x64: dotnet publish -r linux-x64 -c Release /p:StripSymbols=false"
    echo "  5. 测试 Linux ARM64: dotnet publish -r linux-arm64 -c Release /p:StripSymbols=false"
else
    echo -e "${YELLOW}⚠ 还有一些依赖需要安装${NC}"
    echo
    echo "快速安装命令："
    echo
    
    if ! command -v brew &> /dev/null; then
        echo "# 安装 Homebrew"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo
    fi
    
    if ! command -v dotnet &> /dev/null; then
        echo "# 安装 .NET SDK"
        echo "brew install --cask dotnet-sdk"
        echo
    fi
    
    if ! command -v lld-link &> /dev/null; then
        echo "# 安装 LLVM (lld-link)"
        echo "brew install lld"
        echo 'export PATH="$(brew --prefix lld)/bin:$PATH"'
        echo
    fi
    
    if ! command -v cargo &> /dev/null; then
        echo "# 安装 Rust"
        echo 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh'
        echo 'source $HOME/.cargo/env'
        echo
    fi
    
    if ! command -v xwin &> /dev/null; then
        echo "# 安装 xwin"
        echo "cargo install --locked xwin"
        echo
    fi
    
    if [ ! -d "$HOME/.local/share/xwin-sdk/crt" ]; then
        echo "# 下载 Windows SDK"
        echo "mkdir -p \$HOME/.local/share/xwin-sdk"
        echo "xwin --accept-license splat --output \$HOME/.local/share/xwin-sdk"
        echo
    fi
    
    if ! command -v zig &> /dev/null; then
        echo "# 安装 Zig"
        echo "brew install zig"
        echo
    fi
fi


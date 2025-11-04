# PublishAotCross.macOS

[English](README.md) | [简体中文](README.zh-CN.md)

这是一个包含 MSBuild targets 的 NuGet 包，用于实现从 macOS 到 **Windows 和 Linux** 的 [Native AOT](https://learn.microsoft.com/zh-cn/dotnet/core/deploying/native-aot/) 交叉编译。它可以帮助解决以下错误：

```sh
$ dotnet publish -r win-x64
Microsoft.NETCore.Native.Publish.targets(59,5): error : Cross-OS native compilation is not supported.
```

该包提供两种交叉编译工具链：
- **Windows 目标**：使用 `lld-link` + [xwin](https://github.com/Jake-Shadle/xwin) 提供 Windows SDK
- **Linux 目标**：使用 [Zig](https://ziglang.org/) 作为统一的交叉编译工具链

在 macOS 机器上实现对 win-x64/win-arm64/win-x86 **以及** linux-x64/linux-arm64/linux-musl-* 的交叉编译。

## 快速开始

### Windows 交叉编译

1. **安装 lld-link**（通过 Homebrew）：
   ```bash
   brew install lld
   
   # 添加到 PATH（根据你的 Mac 类型选择）
   # 对于 Apple Silicon（M1/M2/M3）：
   export PATH="/opt/homebrew/opt/lld/bin:$PATH"
   
   # 对于 Intel Mac：
   # export PATH="/usr/local/opt/lld/bin:$PATH"
   
   # 或使用此通用命令：
   export PATH="$(brew --prefix lld)/bin:$PATH"
   ```

2. **安装 xwin**：
   ```bash
   cargo install --locked xwin
   ```

3. **下载 Windows SDK**：
   ```bash
   mkdir -p $HOME/.local/share/xwin-sdk
   xwin --accept-license \
     --cache-dir $HOME/.local/share/xwin-sdk \
     --arch x86_64,aarch64 \
     splat --preserve-ms-arch-notation
   ```
   
   > 💡 **注意**：.NET 9+ 不需要额外的 C/C++ 运行时库，使得设置比 .NET 8 简单得多。

4. **将此包添加到你的 Native AOT 项目**：
   ```xml
   <PackageReference Include="PublishAotCross.macOS" Version="1.0.0" />
   ```

5. **发布到 Windows**：
   ```bash
   # ⚠️ 重要：确保 lld-link 在 PATH 中
   export PATH="$(brew --prefix lld)/bin:$PATH"
   
   # 编译发布
   dotnet publish -r win-x64 -c Release
   ```
   
   > 💡 提示：建议将 `export PATH="$(brew --prefix lld)/bin:$PATH"` 添加到 `~/.zshrc` 或 `~/.bash_profile` 中，这样就不需要每次都手动设置了。

### Linux 交叉编译

1. **安装 Zig**（通过 Homebrew）：
   ```bash
   brew install zig
   ```

2. **将此包添加到你的 Native AOT 项目**（同上）：
   ```xml
   <PackageReference Include="PublishAotCross.macOS" Version="1.0.0" />
   ```

3. **发布到 Linux**：
   
   由于 MSBuild 属性求值顺序的限制，需要通过命令行参数指定链接器选项：
   
   ```bash
   # 基于 glibc（Ubuntu、Debian 等）
   dotnet publish -r linux-x64 -c Release /p:StripSymbols=false
   dotnet publish -r linux-arm64 -c Release /p:StripSymbols=false
   
   # 基于 musl（Alpine Linux）
   dotnet publish -r linux-musl-x64 -c Release /p:StripSymbols=false
   dotnet publish -r linux-musl-arm64 -c Release /p:StripSymbols=false
   ```
   
   > 💡 **注意**：需要 `/p:StripSymbols=false` 参数，因为通常没有安装 `llvm-objcopy`。如果你安装了 LLVM 并添加到 PATH，可以省略此参数。

📖 **详细 Linux 交叉编译指南**：请参阅 [QUICKSTART-LINUX.md](QUICKSTART-LINUX.md)

## 配置

该包使用以下 MSBuild 属性：

- **`XWinCache`**：xwin 下载的 Windows SDK 路径  
  默认值：`$(HOME)/.local/share/xwin-sdk/`

你可以在项目文件中覆盖它：

```xml
<PropertyGroup>
  <XWinCache>/custom/path/to/xwin-sdk/</XWinCache>
</PropertyGroup>
```

> **注意**：高级用户还可以设置 `PublishAotCrossPath` 来使用本地克隆的仓库版本，而不是 NuGet 包中的 targets。这通常不需要。

## 支持的目标平台

### Windows（通过 lld-link + xwin）
- `win-x64`
- `win-arm64`
- `win-x86`

### Linux（通过 Zig）
- `linux-x64`（glibc）
- `linux-arm64`（glibc）
- `linux-musl-x64`（Alpine Linux）
- `linux-musl-arm64`（Alpine Linux）

## 工作原理

此包是 [PublishAotCrossXWin](https://github.com/Windows10CE/PublishAotCrossXWin)（针对 Linux → Windows）的移植版本，适配为 macOS → Windows 交叉编译。

**核心组件：**

1. **lld-link**：LLVM 的跨平台链接器，可以在 macOS 上生成 Windows PE 可执行文件
2. **xwin**：下载 Windows SDK 和 CRT，为交叉编译创建"sysroot"
3. **MSBuild Targets**：挂钩到 Native AOT 构建过程以：
   - 设置 `DisableUnsupportedError=true` 以绕过 .NET 的跨操作系统限制
   - 用 `lld-link` 替换默认链接器
   - 使用 `/vctoolsdir` 和 `/winsdkdir` 标志注入 Windows SDK 路径

**技术流程：**

```
.NET 编译器（macOS）→ IL 代码 → Native AOT 编译器 → 目标文件（.obj）
                                                          ↓
                                         lld-link（macOS 上的 LLVM 链接器）
                                                          ↓
                                        使用 xwin 提供的 SDK/CRT
                                                          ↓
                                        Windows PE 可执行文件（.exe）
```

## 示例项目

请参阅 [test/](test/) 目录中的简单示例。

## 系统要求

- **macOS**（在 Apple Silicon 和 Intel 上测试通过）
- **.NET 9.0 SDK** 或更高版本（支持 .NET 9、10+）
- **Homebrew**（用于安装工具）

### Windows 交叉编译要求
- **LLVM**（`lld-link` 链接器）
- **Rust/Cargo**（用于安装 xwin）
- **约 1.5GB 磁盘空间**用于 Windows SDK

### Linux 交叉编译要求
- **Zig**（约 200MB，包含所有需要的组件）
- **无需额外下载** - Zig 内置了 sysroot！

## 限制

- **仅支持动态链接**：生成的可执行文件需要 Windows 运行时 DLL
- **MSVC ABI**：链接器使用 MSVC 的 ABI，确保与 Windows 兼容
- **不支持 LTCG**：`lld-link` 无法链接 MSVC 的链接时代码生成（LTCG）对象，因此无法与某些库进行完全静态链接

## 故障排除

### `lld-link: command not found`

确保已安装 LLVM 并在 PATH 中：

```bash
brew install lld

# 使用适用于 Intel 和 Apple Silicon 的通用命令
export PATH="$(brew --prefix lld)/bin:$PATH"

# 验证安装
which lld-link
lld-link --version
```

### `xwin: command not found`

通过 Cargo 安装 xwin：

```bash
cargo install --locked xwin
```

### 仍然出现跨操作系统编译错误

确保你的项目包含：

```xml
<PublishAot>true</PublishAot>
<AcceptVSBuildToolsLicense>true</AcceptVSBuildToolsLicense>
```

并且正确引用了该包。

### 找不到 Windows SDK

验证 SDK 是否已下载：

```bash
ls -lh $HOME/.local/share/xwin-sdk/splat/
```

如果为空，重新运行：

```bash
xwin --accept-license \
  --cache-dir $HOME/.local/share/xwin-sdk \
  --arch x86_64,aarch64 \
  splat --preserve-ms-arch-notation
```

### 大小写敏感问题（例如，`could not open 'oleaut32.lib'`）

这是因为 macOS 使用区分大小写的文件系统，但 Windows SDK 使用混合大小写（例如 `OleAut32.Lib`）。

**解决方案**：在 SDK 库目录中创建小写副本：

```bash
cd $HOME/.local/share/xwin-sdk/splat/sdk/lib/um/x64 && \
for f in *.Lib; do 
  lower=$(echo "$f" | tr '[:upper:]' '[:lower:]')
  [ "$f" != "$lower" ] && ln -sf "$f" "$lower"
done
```

## 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE)。

## 致谢

- 原始 [PublishAotCrossXWin](https://github.com/Windows10CE/PublishAotCrossXWin) 由 [@Windows10CE](https://github.com/Windows10CE) 创建
- [xwin](https://github.com/Jake-Shadle/xwin) 由 [@Jake-Shadle](https://github.com/Jake-Shadle) 创建
- [LLVM lld](https://lld.llvm.org/)

## 相关项目

这些项目共同构成了完整的 .NET Native AOT 交叉编译生态系统：

### 交叉编译工具链

- **[PublishAotCross](https://github.com/MichalStrehovsky/PublishAotCross)** - Windows → Linux  
  使用 Zig 作为链接器，支持 linux-x64/arm64 和 musl 变体

- **[PublishAotCrossXWin](https://github.com/Windows10CE/PublishAotCrossXWin)** - Linux → Windows  
  使用 lld-link + xwin，支持 win-x64/arm64/x86

- **PublishAotCross.macOS**（本项目）- macOS → Windows/Linux  
  结合两种方法，实现从 macOS 的全面交叉编译

### 交叉编译矩阵

| 源平台 ↓ / 目标平台 → | Windows | Linux | macOS |
|---------------------|---------|-------|-------|
| **Windows** | 原生 | ✅ PublishAotCross | ❌ |
| **Linux** | ✅ PublishAotCrossXWin | 原生 | ❌ |
| **macOS** | ✅ 本项目 | ✅ 本项目 | 原生 |

> 💡 **macOS 用户拥有两全其美的优势** - 可以从一台机器交叉编译到 Windows 和 Linux！


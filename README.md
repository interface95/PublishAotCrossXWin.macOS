# PublishAotCross.macOS

[English](README.md) | [简体中文](README.zh-CN.md)

This is a NuGet package with MSBuild targets to enable cross-compilation with [Native AOT](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/) from macOS to **both Windows and Linux**. It helps resolve the following error:

```sh
$ dotnet publish -r win-x64
Microsoft.NETCore.Native.Publish.targets(59,5): error : Cross-OS native compilation is not supported.
```

This package provides two cross-compilation toolchains:
- **Windows targets**: Uses `lld-link` + [xwin](https://github.com/Jake-Shadle/xwin) for Windows SDK
- **Linux targets**: Uses [Zig](https://ziglang.org/) as a unified cross-compilation toolchain

Enabling cross-compilation to win-x64/win-arm64/win-x86 **and** linux-x64/linux-arm64/linux-musl-* from a macOS machine.

## Quick Start

### For Windows Cross-compilation

1. **Install lld-link** (via Homebrew):
   ```bash
   brew install lld
   
   # Add to PATH (choose based on your Mac)
   # For Apple Silicon (M1/M2/M3):
   export PATH="/opt/homebrew/opt/lld/bin:$PATH"
   
   # For Intel Mac:
   # export PATH="/usr/local/opt/lld/bin:$PATH"
   
   # Or use this universal command:
   export PATH="$(brew --prefix lld)/bin:$PATH"
   ```

2. **Install xwin**:
   ```bash
   cargo install --locked xwin
   ```

3. **Download Windows SDK**:
   ```bash
   mkdir -p $HOME/.local/share/xwin-sdk
   xwin --accept-license \
     --cache-dir $HOME/.local/share/xwin-sdk \
     --arch x86_64,aarch64 \
     splat --preserve-ms-arch-notation
   ```
   
   > 💡 **Note**: .NET 9+ doesn't require additional C/C++ runtime libraries, making setup much simpler than .NET 8.

4. **Add this package to your Native AOT project**:
   ```xml
   <PackageReference Include="PublishAotCross.macOS" Version="1.0.0" />
   ```

5. **Publish for Windows**:
   ```bash
   # ⚠️ 重要：确保 lld-link 在 PATH 中
   export PATH="$(brew --prefix lld)/bin:$PATH"
   
   # 编译发布
   dotnet publish -r win-x64 -c Release
   ```
   
   > 💡 提示：建议将 `export PATH="$(brew --prefix lld)/bin:$PATH"` 添加到 `~/.zshrc` 或 `~/.bash_profile` 中，这样就不需要每次都手动设置了。

### For Linux Cross-compilation

1. **Install Zig** (via Homebrew):
   ```bash
   brew install zig
   ```

2. **Add this package to your Native AOT project** (same as above):
   ```xml
   <PackageReference Include="PublishAotCross.macOS" Version="1.0.0" />
   ```

3. **Publish for Linux**:
   
   Due to MSBuild property evaluation order, you need to specify the linker via command line:
   
   ```bash
   # glibc-based (Ubuntu, Debian, etc.)
   dotnet publish -r linux-x64 -c Release /p:StripSymbols=false
   dotnet publish -r linux-arm64 -c Release /p:StripSymbols=false
   
   # musl-based (Alpine Linux)
   dotnet publish -r linux-musl-x64 -c Release /p:StripSymbols=false
   dotnet publish -r linux-musl-arm64 -c Release /p:StripSymbols=false
   ```
   
   > 💡 **Note**: The `/p:StripSymbols=false` parameter is required because `llvm-objcopy` is typically not installed. If you install LLVM and add it to PATH, you can omit this parameter.

📖 **Detailed Linux cross-compilation guide**: See [QUICKSTART-LINUX.md](QUICKSTART-LINUX.md)

## Configuration

The package uses the following MSBuild properties:

- **`XWinCache`**: Path to the Windows SDK downloaded by xwin  
  Default: `$(HOME)/.local/share/xwin-sdk/`

You can override it in your project file:

```xml
<PropertyGroup>
  <XWinCache>/custom/path/to/xwin-sdk/</XWinCache>
</PropertyGroup>
```

> **Note**: Advanced users can also set `PublishAotCrossPath` to use a locally cloned version of the repository instead of the NuGet-bundled targets. This is usually not needed.

## Supported Targets

### Windows (via lld-link + xwin)
- `win-x64`
- `win-arm64`
- `win-x86`

### Linux (via Zig)
- `linux-x64` (glibc)
- `linux-arm64` (glibc)
- `linux-musl-x64` (Alpine Linux)
- `linux-musl-arm64` (Alpine Linux)

## How It Works

This package is a port of [PublishAotCrossXWin](https://github.com/Windows10CE/PublishAotCrossXWin) (which targets Linux → Windows) adapted for macOS → Windows cross-compilation.

**Key components:**

1. **lld-link**: A cross-platform linker from LLVM that can generate Windows PE executables on macOS
2. **xwin**: Downloads the Windows SDK and CRT, creating a "sysroot" for cross-compilation
3. **MSBuild Targets**: Hooks into the Native AOT build process to:
   - Set `DisableUnsupportedError=true` to bypass .NET's cross-OS restriction
   - Replace the default linker with `lld-link`
   - Inject Windows SDK paths using `/vctoolsdir` and `/winsdkdir` flags

**Technical flow:**

```
.NET Compiler (macOS) → IL Code → Native AOT Compiler → Object Files (.obj)
                                                              ↓
                                             lld-link (LLVM Linker on macOS)
                                                              ↓
                                            Uses xwin-provided SDK/CRT
                                                              ↓
                                            Windows PE Executable (.exe)
```

## Example Project

See the [test/](test/) directory for a simple example.

## Requirements

- **macOS** (tested on Apple Silicon and Intel)
- **.NET 9.0 SDK** or later (.NET 9, 10+ supported)
- **Homebrew** (for installing tools)

### For Windows Cross-compilation
- **LLVM** (`lld-link` linker)
- **Rust/Cargo** (for installing xwin)
- **~1.5GB disk space** for Windows SDK

### For Linux Cross-compilation
- **Zig** (~200MB, includes everything needed)
- **No additional downloads** - Zig includes built-in sysroot!

## Limitations

- **Dynamic linking only**: The generated executable requires Windows runtime DLLs
- **MSVC ABI**: The linker uses MSVC's ABI, ensuring compatibility with Windows
- **No LTCG support**: `lld-link` cannot link MSVC's Link-Time Code Generation (LTCG) objects, so full static linking with some libraries is not possible

## Troubleshooting

### `lld-link: command not found`

Ensure LLVM is installed and in your PATH:

```bash
brew install lld

# Use universal command that works for both Intel and Apple Silicon
export PATH="$(brew --prefix lld)/bin:$PATH"

# Verify installation
which lld-link
lld-link --version
```

### `xwin: command not found`

Install xwin via Cargo:

```bash
cargo install --locked xwin
```

### Cross-OS compilation error still appears

Make sure your project has:

```xml
<PublishAot>true</PublishAot>
<AcceptVSBuildToolsLicense>true</AcceptVSBuildToolsLicense>
```

And that the package is properly referenced.

### Windows SDK not found

Verify the SDK was downloaded:

```bash
ls -lh $HOME/.local/share/xwin-sdk/splat/
```

If empty, re-run:

```bash
xwin --accept-license \
  --cache-dir $HOME/.local/share/xwin-sdk \
  --arch x86_64,aarch64 \
  splat --preserve-ms-arch-notation
```

### Case-sensitivity issues (e.g., `could not open 'oleaut32.lib'`)

This happens because macOS has a case-sensitive file system, but Windows SDK uses mixed case (e.g., `OleAut32.Lib`).

**Solution**: Create lowercase copies in the SDK library directory:

```bash
cd $HOME/.local/share/xwin-sdk/splat/sdk/lib/um/x64 && \
for f in *.Lib; do 
  lower=$(echo "$f" | tr '[:upper:]' '[:lower:]')
  [ "$f" != "$lower" ] && ln -sf "$f" "$lower"
done
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- Original [PublishAotCrossXWin](https://github.com/Windows10CE/PublishAotCrossXWin) by [@Windows10CE](https://github.com/Windows10CE)
- [xwin](https://github.com/Jake-Shadle/xwin) by [@Jake-Shadle](https://github.com/Jake-Shadle)
- [LLVM lld](https://lld.llvm.org/)

## Related Projects

These projects together form a complete .NET Native AOT cross-compilation ecosystem:

### Cross-compilation Toolchains

- **[PublishAotCross](https://github.com/MichalStrehovsky/PublishAotCross)** - Windows → Linux  
  Uses Zig as linker, supports linux-x64/arm64 and musl variants

- **[PublishAotCrossXWin](https://github.com/Windows10CE/PublishAotCrossXWin)** - Linux → Windows  
  Uses lld-link + xwin, supports win-x64/arm64/x86

- **PublishAotCross.macOS** (this project) - macOS → Windows/Linux  
  Combines both approaches for comprehensive cross-compilation from macOS

### Cross-compilation Matrix

| Source ↓ / Target → | Windows | Linux | macOS |
|---------------------|---------|-------|-------|
| **Windows** | Native | ✅ PublishAotCross | ❌ |
| **Linux** | ✅ PublishAotCrossXWin | Native | ❌ |
| **macOS** | ✅ This project | ✅ This project | Native |

> 💡 **macOS users get the best of both worlds** - cross-compile to both Windows and Linux from a single machine!

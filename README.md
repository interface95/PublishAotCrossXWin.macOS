# PublishAotCrossXWin.macOS

This is a NuGet package with MSBuild targets to enable cross-compilation with [Native AOT](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/) from macOS to Windows. It helps resolve the following error:

```sh
$ dotnet publish -r win-x64
Microsoft.NETCore.Native.Publish.targets(59,5): error : Cross-OS native compilation is not supported.
```

This package allows using `lld-link` as the linker and [xwin](https://github.com/Jake-Shadle/xwin) to provide the Windows SDK sysroot, enabling cross-compilation to win-x64/win-arm64/win-x86 from a macOS machine.

## Quick Start

1. **Install lld-link** (via Homebrew):
   ```bash
   brew install llvm
   export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
   ```

2. **Install xwin**:
   ```bash
   cargo install --locked xwin
   ```

3. **Download Windows SDK**:
   ```bash
   mkdir -p $HOME/.local/share/xwin-sdk
   xwin --accept-license splat --output $HOME/.local/share/xwin-sdk
   ```

4. **Add this package to your Native AOT project**:
   ```xml
   <PackageReference Include="PublishAotCrossXWin.macOS" Version="1.0.0" />
   ```

5. **Publish for Windows**:
   ```bash
   # ⚠️ 重要：确保 lld-link 在 PATH 中
   export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
   
   # 编译发布
   dotnet publish -r win-x64 -c Release
   ```
   
   > 💡 提示：建议将 `export PATH="/opt/homebrew/opt/llvm/bin:$PATH"` 添加到 `~/.zshrc` 或 `~/.bash_profile` 中，这样就不需要每次都手动设置了。

## Configuration

The package uses the following MSBuild properties:

- **`XWinCache`**: Path to the Windows SDK downloaded by xwin  
  Default: `$(HOME)/.local/share/xwin-sdk/`

- **`PublishAotCrossPath`**: Path to the cloned PublishAotCrossXWin repository  
  Default: `$(HOME)/.local/share/PublishAotCrossXWin`

You can override these in your project file:

```xml
<PropertyGroup>
  <XWinCache>/custom/path/to/xwin-sdk/</XWinCache>
</PropertyGroup>
```

## Supported Targets

- `win-x64`
- `win-arm64`
- `win-x86`

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
- **.NET 9.0 SDK** or later
- **Homebrew** (for installing LLVM)
- **Rust/Cargo** (for installing xwin)
- **~1.5GB disk space** for Windows SDK

## Limitations

- **Dynamic linking only**: The generated executable requires Windows runtime DLLs
- **MSVC ABI**: The linker uses MSVC's ABI, ensuring compatibility with Windows
- **No LTCG support**: `lld-link` cannot link MSVC's Link-Time Code Generation (LTCG) objects, so full static linking with some libraries is not possible

## Troubleshooting

### `lld-link: command not found`

Ensure LLVM is installed and in your PATH:

```bash
brew install llvm
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
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
xwin --accept-license splat --output $HOME/.local/share/xwin-sdk
```

### Library not found errors (e.g., `could not open 'oleaut32.lib'`)

This happens because macOS has a case-sensitive file system, but the linker expects lowercase library names while Windows SDK uses mixed case (e.g., `OleAut32.Lib`).

**Good news**: Since version 1.0.0, this package **automatically creates symbolic links** during the build process! You don't need to do anything manually.

If you still encounter this issue, it means the automatic symlink creation failed. You can create them manually:

```bash
cd $HOME/.local/share/xwin-sdk/splat && \
(cd sdk/lib/um/x64 && for f in *.Lib; do lower=$(echo "$f" | tr '[:upper:]' '[:lower:]'); [ "$f" != "$lower" ] && ln -sf "$f" "$lower"; done) && \
(cd crt/lib/x64 && ln -sf libcmt.lib LIBCMT.lib && ln -sf oldnames.lib OLDNAMES.lib)
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- Original [PublishAotCrossXWin](https://github.com/Windows10CE/PublishAotCrossXWin) by [@Windows10CE](https://github.com/Windows10CE)
- [xwin](https://github.com/Jake-Shadle/xwin) by [@Jake-Shadle](https://github.com/Jake-Shadle)
- [LLVM lld](https://lld.llvm.org/)

## Related Projects

- [PublishAotCross](https://github.com/MichalStrehovsky/PublishAotCross) - Cross-compile from Windows to Linux
- [PublishAotCrossXWin](https://github.com/Windows10CE/PublishAotCrossXWin) - Cross-compile from Linux to Windows

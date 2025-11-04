# Quick Start Guide

**PublishAotCross.macOS** - Cross-compile .NET Native AOT from macOS to Windows and Linux

## Choose Your Target Platform

### 🪟 Windows Cross-compilation

**Prerequisites:**
```bash
# 1. Install lld (LLVM linker)
brew install lld

# 2. Install xwin (requires Rust/Cargo)
cargo install --locked xwin

# 3. Download Windows SDK
xwin --accept-license --cache-dir "$HOME/.local/share/xwin-sdk/" \
  --arch x86_64,aarch64 --sdk-version 10.0.22621 \
  splat --preserve-ms-arch-notation
```

**Add to your project:**
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <PublishAot>true</PublishAot>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PublishAotCross.macOS" Version="1.0.0" />
  </ItemGroup>
</Project>
```

**Build:**
```bash
export PATH="$(brew --prefix lld)/bin:$PATH"
dotnet publish -r win-x64 -c Release
```

**Output:** `bin/Release/net9.0/win-x64/publish/YourApp.exe`

---

### 🐧 Linux Cross-compilation

**Prerequisites:**
```bash
# Install Zig
brew install zig

# Optional: Install LLVM for smaller binaries
brew install llvm
export PATH="$(brew --prefix llvm)/bin:$PATH"
```

**Add to your project:**
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <PublishAot>true</PublishAot>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PublishAotCross.macOS" Version="1.0.0" />
  </ItemGroup>
</Project>
```

**Build:**
```bash
# glibc-based (Ubuntu, Debian, etc.)
dotnet publish -r linux-x64 -c Release /p:StripSymbols=false
dotnet publish -r linux-arm64 -c Release /p:StripSymbols=false

# musl-based (Alpine Linux)
dotnet publish -r linux-musl-x64 -c Release /p:StripSymbols=false
dotnet publish -r linux-musl-arm64 -c Release /p:StripSymbols=false
```

**Output:** `bin/Release/net9.0/linux-x64/publish/YourApp`

> 💡 **Note**: `/p:StripSymbols=false` is required unless you've installed LLVM. Binaries will be larger but fully functional.

---

## Troubleshooting

### Windows

| Error | Solution |
|-------|----------|
| `lld-link: command not found` | Add to PATH: `export PATH="$(brew --prefix lld)/bin:$PATH"` |
| `xwin: command not found` | Install: `cargo install --locked xwin` |
| Windows SDK not found | Run xwin splat command (see prerequisites) |

### Linux

| Error | Solution |
|-------|----------|
| `zig: command not found` | Install: `brew install zig` |
| `Symbol stripping tool not found` | Add `/p:StripSymbols=false` or install LLVM |

---

## Documentation

- **[README.md](README.md)** - Full documentation
- **[README.zh-CN.md](README.zh-CN.md)** - 中文文档
- **[QUICKSTART-LINUX.md](QUICKSTART-LINUX.md)** - Detailed Linux guide
- **[test/Hello.csproj](test/Hello.csproj)** - Working example

## Related Projects

- **[PublishAotCross](https://github.com/MichalStrehovsky/PublishAotCross)** - Windows → Linux
- **[PublishAotCrossXWin](https://github.com/Windows10CE/PublishAotCrossXWin)** - Linux → Windows
- **PublishAotCross.macOS** (this project) - macOS → Windows/Linux

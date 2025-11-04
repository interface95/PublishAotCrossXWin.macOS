# Quick Start: Cross-compile to Linux from macOS

This package now supports cross-compiling .NET Native AOT applications from macOS to **both Windows and Linux** targets!

## Prerequisites for Linux Cross-compilation

1. **Install Zig** (via Homebrew):
   ```bash
   brew install zig
   
   # Verify installation
   zig version
   ```

2. **Optional: Install LLVM for smaller binaries**:
   ```bash
   brew install llvm
   
   # Add llvm-objcopy to PATH
   export PATH="$(brew --prefix llvm)/bin:$PATH"
   ```
   
   > 💡 **Note**: Without `llvm-objcopy`, symbol stripping is automatically disabled. Binaries will be larger but fully functional.

3. **Add this package to your Native AOT project**:
   ```xml
   <PackageReference Include="PublishAotCross.macOS" Version="1.0.0" />
   ```

## Publish for Linux

```bash
# Publish for Linux x64 (glibc)
dotnet publish -r linux-x64 -c Release

# Publish for Linux ARM64 (glibc)
dotnet publish -r linux-arm64 -c Release

# Publish for Linux x64 (musl - Alpine Linux)
dotnet publish -r linux-musl-x64 -c Release

# Publish for Linux ARM64 (musl)
dotnet publish -r linux-musl-arm64 -c Release
```

## Supported Target Platforms

### Windows Targets (via lld-link + xwin)
- `win-x64`
- `win-arm64`
- `win-x86`

### Linux Targets (via Zig)
- `linux-x64` (glibc)
- `linux-arm64` (glibc)
- `linux-musl-x64` (Alpine Linux)
- `linux-musl-arm64` (Alpine Linux)

## Deploying to Linux

### Runtime Dependencies

.NET Native AOT binaries on Linux require the **ICU library** (International Components for Unicode) for globalization support.

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y libicu-dev
# Or specific version: libicu70, libicu74, etc.
```

#### CentOS/RHEL/Fedora
```bash
sudo yum install -y icu
# Or: sudo dnf install -y icu
```

#### Alpine Linux (musl)
```bash
apk add --no-cache icu-libs
```

#### Docker Deployment

**Ubuntu-based:**
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y libicu-dev
COPY YourApp /app/
WORKDIR /app
CMD ["./YourApp"]
```

**Alpine-based:**
```dockerfile
FROM alpine:latest
RUN apk add --no-cache icu-libs
COPY YourApp /app/
WORKDIR /app
CMD ["./YourApp"]
```

### Optional: Globalization Invariant Mode

If you don't need internationalization support, you can disable ICU dependency:

```xml
<PropertyGroup>
  <InvariantGlobalization>true</InvariantGlobalization>
</PropertyGroup>
```

**Note:** This removes the ICU dependency but disables culture-specific formatting and locale-aware operations.

## How It Works

The package automatically detects your target platform:

- **Windows targets** → Uses `lld-link` with `xwin` for Windows SDK
- **Linux targets** → Uses `Zig` as the cross-compilation toolchain

Zig provides:
- Cross-platform linker
- Built-in sysroot for glibc and musl
- No need to download separate SDKs for Linux

## Requirements

### For Windows Cross-compilation
- `lld` (from LLVM)
- `xwin` (Rust tool)
- ~1.5GB disk space for Windows SDK

### For Linux Cross-compilation
- `zig` (single tool, ~200MB)
- No additional downloads needed!

## Example: Build for Multiple Platforms

```bash
# Build for Windows
export PATH="$(brew --prefix lld)/bin:$PATH"
dotnet publish -r win-x64 -c Release

# Build for Linux (same machine!)
dotnet publish -r linux-x64 -c Release
dotnet publish -r linux-arm64 -c Release
```

## Testing Your Linux Binaries

You can test the generated Linux binaries using:

1. **Docker**:
   ```bash
   # For glibc-based distributions (Ubuntu, Debian, etc.)
   docker run --rm -v $(pwd)/bin/Release/net9.0/linux-x64/publish:/app ubuntu:22.04 /app/YourApp
   
   # For musl-based distributions (Alpine)
   docker run --rm -v $(pwd)/bin/Release/net9.0/linux-musl-x64/publish:/app alpine:latest /app/YourApp
   ```

2. **Lima** (lightweight VM):
   ```bash
   brew install lima
   limactl start
   lima ./bin/Release/net9.0/linux-x64/publish/YourApp
   ```

3. **Multipass** (Ubuntu VM):
   ```bash
   brew install multipass
   multipass launch --name test-vm
   multipass transfer ./bin/Release/net9.0/linux-x64/publish/YourApp test-vm:
   multipass exec test-vm -- ./YourApp
   ```

## Troubleshooting

### `zig: command not found`

Install Zig via Homebrew:

```bash
brew install zig
zig version
```

### Warning: "llvm-objcopy not found. Symbol stripping is disabled."

This is **not an error** - your build will succeed but produce larger binaries. To enable symbol stripping for smaller binaries:

```bash
brew install llvm
export PATH="$(brew --prefix llvm)/bin:$PATH"
```

Or if you prefer to keep it disabled, you can explicitly set:

```xml
<PropertyGroup>
  <StripSymbols>false</StripSymbols>
</PropertyGroup>
```

### Build errors with Linux targets

Make sure your project has Native AOT enabled:

```xml
<PropertyGroup>
  <PublishAot>true</PublishAot>
</PropertyGroup>
```

## Technical Details

The Zig toolchain provides a complete cross-compilation environment:

```
.NET Compiler → IL Code → Native AOT → Object Files (.o)
                                           ↓
                            Zig cc (cross-compiler + linker)
                                           ↓
                          Linux ELF Executable (native)
```

Zig's `cc` command is a drop-in replacement for GCC/Clang that includes:
- Cross-compilation support for all targets
- Built-in sysroots (glibc, musl)
- LLVM-based lld linker
- No external dependencies needed

This makes Linux cross-compilation much simpler than Windows!


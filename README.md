# ledger-dist

Official distribution repository for CodeAtlas **ledger** CLI.

## Quick Install (Recommended)

```bash
# Install latest version to /usr/local/bin
curl -fsSL https://raw.githubusercontent.com/mauricecarrier7/ledger-dist/main/install.sh | bash
```

### Install Options

```bash
# Specific version
curl -fsSL .../install.sh | bash -s -- --version 0.8.2

# Custom directory (e.g., project-local)
curl -fsSL .../install.sh | bash -s -- --dir ./tools/bin

# Both
curl -fsSL .../install.sh | bash -s -- --version 0.8.2 --dir ./tools/bin
```

## Manual Installation

If you prefer not to use the install script:

```bash
# 1. Download the binary
curl -fsSL -o ledger \
  https://github.com/mauricecarrier7/ledger-dist/releases/download/v0.8.2/ledger-macos-arm64

# 2. CRITICAL: Clear macOS quarantine (prevents binary from hanging!)
xattr -cr ledger

# 3. Make executable
chmod +x ledger

# 4. Move to your PATH
mv ledger ./tools/bin/  # or /usr/local/bin/
```

> **Warning**: Skipping the `xattr -cr` step on macOS will cause the binary to hang indefinitely when executed.

## CI/CD Integration

### GitHub Actions

```yaml
name: CodeAtlas Analysis
on: [push, pull_request]

jobs:
  analyze:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install ledger
        run: |
          curl -fsSL https://raw.githubusercontent.com/mauricecarrier7/ledger-dist/main/install.sh \
            | bash -s -- --version 0.8.2 --dir ./tools/bin
          
      - name: Run analysis
        run: |
          ./tools/bin/ledger observe --domains arch,a11y,qa --output artifacts/ledger
          
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ledger-analysis
          path: artifacts/ledger/
```

### Version Pinning

**Always pin to a specific version in CI.** Don't use `latest` in production pipelines.

```bash
# Good - pinned version
curl -fsSL .../install.sh | bash -s -- --version 0.8.2

# Bad - unpredictable in CI
curl -fsSL .../install.sh | bash
```

## Available Platforms

| Platform | Architecture | Binary Name |
|----------|--------------|-------------|
| macOS | Apple Silicon (M1/M2/M3) | `ledger-macos-arm64` |

## Troubleshooting

### Binary hangs on execution (macOS)

**Symptom:** `ledger --version` hangs forever, or shows "UE" (uninterruptible sleep) in `ps`.

**Cause:** macOS quarantine attributes on downloaded binaries.

**Fix:**
```bash
xattr -cr /path/to/ledger
```

The install script does this automatically, but if you downloaded manually, you must run this.

### "Operation not permitted" on xattr

Try with sudo, or move the binary to a non-protected location first:
```bash
mv ledger /tmp/ledger
xattr -cr /tmp/ledger
mv /tmp/ledger ./tools/bin/ledger
```

### Checksum mismatch

1. Re-download (network corruption)
2. Check for corporate proxy interference
3. Verify you're downloading the correct version

### Command not found after install

Add the install directory to your PATH:
```bash
# For ./tools/bin installs
export PATH="./tools/bin:$PATH"

# For /usr/local/bin (usually already in PATH)
export PATH="/usr/local/bin:$PATH"
```

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 0.8.2 | 2026-02-02 | QAAtlas preset detection for iOS/Swift |
| 0.8.1 | 2026-02-02 | AccessLint & QAAtlas binary integration |
| 0.8.0 | 2026-02-02 | Unified `observe` command for CI |
| 0.7.0 | 2026-02-02 | Platform presets, onboarding wizard |
| 0.6.0 | 2026-02-02 | SwiftUI flow detection |

Full version details in [`versions.json`](./versions.json).

## Verifying Checksums

All binaries have SHA256 checksums in `versions.json`:

```bash
# Check manually
shasum -a 256 ledger
# Compare with sha256 field in versions.json
```

## Source Repository

Built from: https://github.com/mauricecarrier7/CodeAtlas

## License

Same license as CodeAtlas source repository.

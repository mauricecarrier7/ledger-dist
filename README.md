# ledger-dist

Official distribution repository for CodeAtlas **ledger** CLI.

## Quick Install

```bash
# Download install script
curl -fsSL https://raw.githubusercontent.com/mauricecarrier7/ledger-dist/main/scripts/install_ledger.sh -o install_ledger.sh
chmod +x install_ledger.sh

# Install specific version (required - no "latest" in CI)
./install_ledger.sh --version 0.1.0
```

## Version Pinning (Required for CI)

**Never use "latest" in CI/CD pipelines.** Always pin to a specific version.

### Option 1: Version file (recommended)

```bash
# Create version file
echo "0.1.0" > ledger_version.txt

# Install from version file
./install_ledger.sh --version "$(cat ledger_version.txt)"
```

### Option 2: Environment variable

```bash
export LEDGER_VERSION=0.1.0
./install_ledger.sh
```

### Option 3: Direct argument

```bash
./install_ledger.sh --version 0.1.0
```

## CI/CD Integration

### GitHub Actions

```yaml
jobs:
  analyze:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install ledger CLI
        run: |
          curl -fsSL https://raw.githubusercontent.com/mauricecarrier7/ledger-dist/main/scripts/install_ledger.sh -o install_ledger.sh
          chmod +x install_ledger.sh
          ./install_ledger.sh --version "$(cat tools/ledger/ledger_version.txt)" --install-dir ./tools/bin

      - name: Run analysis
        run: |
          ./tools/bin/ledger analyze --repo . --domains arch,reach --output artifacts/ledger
          ./tools/bin/ledger spec build --requirements docs/requirements.md --output artifacts/ledger/spec

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ledger-analysis
          path: artifacts/ledger/
```

## Available Platforms

| Platform | Architecture | Artifact |
|----------|--------------|----------|
| macOS | arm64 (Apple Silicon) | `ledger-macos-arm64` |
| macOS | x64 (Intel) | `ledger-macos-x64` |

## Manifest Format

The `versions.json` file contains all available versions:

```json
{
  "tool": "ledger",
  "latest": "0.1.0",
  "minimum_supported": "0.1.0",
  "versions": [
    {
      "version": "0.1.0",
      "release_date": "2026-02-01T00:00:00Z",
      "source_commit": "abc1234",
      "artifacts": {
        "macos-arm64": {
          "url": "https://github.com/.../ledger-macos-arm64",
          "sha256": "abc123..."
        }
      }
    }
  ]
}
```

## Security

### SHA256 Verification

Every binary is verified against its SHA256 checksum before execution:

1. Install script downloads the binary to a temp file
2. Computes SHA256 of downloaded file
3. Compares against manifest checksum
4. **Aborts with exit code 3 if mismatch**

```bash
# Manual verification
curl -fsSL <binary-url> -o ledger
expected_sha256=$(curl -fsSL <manifest-url> | jq -r '.versions[] | select(.version == "0.1.0") | .artifacts["macos-arm64"].sha256')
actual_sha256=$(shasum -a 256 ledger | awk '{print $1}')
[[ "$actual_sha256" == "$expected_sha256" ]] && echo "OK" || echo "MISMATCH"
```

### No "curl | bash"

This distribution does **not** support piping curl to bash:

```bash
# WRONG - not supported
curl -fsSL ... | bash

# CORRECT - download, verify, then execute
curl -fsSL ... -o install_ledger.sh
chmod +x install_ledger.sh
./install_ledger.sh --version 0.1.0
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Version not found |
| 3 | Checksum verification failed |
| 4 | Download failed |
| 5 | Missing dependencies |

## Upgrading

To upgrade to a new version:

1. Update your version pin:
   ```bash
   echo "0.2.0" > tools/ledger/ledger_version.txt
   ```

2. Re-run the install script:
   ```bash
   ./install_ledger.sh --version "$(cat tools/ledger/ledger_version.txt)"
   ```

3. Verify:
   ```bash
   ./tools/bin/ledger --version
   ```

## Troubleshooting

### "Version not found"

```
[ERROR] Version '0.1.0' not found in manifest
[INFO] Available versions:
  - 0.1.0
  - 0.0.1
```

Check that your version string matches exactly (no `v` prefix).

### "Checksum verification FAILED"

```
[ERROR] Checksum verification FAILED!
  Expected: abc123...
  Actual:   def456...
```

This indicates a corrupted download or tampered binary. **Do not proceed.**

1. Retry the download
2. If persistent, report to maintainers
3. Check network for MITM proxies

### "Missing dependencies"

```
[ERROR] Missing required dependencies: jq
```

Install the missing tool:
- macOS: `brew install jq`
- Ubuntu: `apt-get install jq`

## Source Repository

Ledger CLI is built from: https://github.com/mauricecarrier7/CodeAtlas

## License

Same license as CodeAtlas source repository.

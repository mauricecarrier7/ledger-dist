# Ledger Distribution - Bootstrap Guide

## Initial Setup Commands

### 1. Create the ledger-dist Repository on GitHub

```bash
# Create the repo (one-time)
gh repo create mauricecarrier7/ledger-dist --public --description "Distribution repository for CodeAtlas ledger CLI"

# Initialize and push
cd /Users/mauricework/CodeAtlasProject/ledger-dist
git init
git add .
git commit -m "Initial distribution repo setup"
git branch -M main
git remote add origin https://github.com/mauricecarrier7/ledger-dist.git
git push -u origin main
```

### 2. Create First GitHub Release

```bash
# Create the v0.1.0 release with binaries
cd /Users/mauricework/CodeAtlasProject/ledger-dist

gh release create v0.1.0 \
  --title "Ledger CLI v0.1.0" \
  --notes "Initial release with requirements tracking and spec generation" \
  artifacts/ledger/ledger-macos-arm64 \
  artifacts/ledger/ledger-macos-arm64.sha256
```

### 3. Configure CodeAtlas Source Repo

```bash
cd /Users/mauricework/CodeAtlasProject/CodeAtlas

# Add the release workflow (already created)
git add .github/workflows/release.yml
git commit -m "Add release workflow for ledger distribution"
git push

# Create a GitHub secret for dist repo access
# Go to: Settings > Secrets > Actions > New repository secret
# Name: DIST_REPO_TOKEN
# Value: <personal access token with repo scope>
```

### 4. Trigger a Release

```bash
# Option A: Tag-based release
git tag v0.1.0
git push origin v0.1.0

# Option B: Manual workflow dispatch
gh workflow run release.yml -f version=0.1.0
```

## Validation Checklist

### Test 1: Clean Install
```bash
# On a clean machine without ledger
mkdir /tmp/test-install && cd /tmp/test-install
curl -fsSL https://raw.githubusercontent.com/mauricecarrier7/ledger-dist/main/scripts/install_ledger.sh -o install_ledger.sh
chmod +x install_ledger.sh
./install_ledger.sh --version 0.1.0 --install-dir ./bin
./bin/ledger --version
# Expected: 0.1.0
```

### Test 2: Checksum Mismatch
```bash
# Tamper with manifest checksum and verify rejection
# The script should exit with code 3
```

### Test 3: Version Not Found
```bash
./install_ledger.sh --version 9.9.9
# Expected: Exit code 2, message "Version '9.9.9' not found in manifest"
```

### Test 4: Upgrade Process
```bash
echo "0.1.0" > ledger_version.txt
./install_ledger.sh --version "$(cat ledger_version.txt)"
# Upgrade to 0.2.0 when released
echo "0.2.0" > ledger_version.txt
./install_ledger.sh --version "$(cat ledger_version.txt)"
```

## File Inventory

### ledger-dist Repository
```
ledger-dist/
├── README.md                    # User documentation
├── BOOTSTRAP.md                 # This file
├── versions.json                # Version manifest
├── versions.schema.json         # JSON schema for validation
├── scripts/
│   └── install_ledger.sh        # Install script
├── artifacts/
│   └── ledger/
│       ├── ledger-macos-arm64
│       └── ledger-macos-arm64.sha256
└── .github/
    └── workflows/               # (empty - releases via CodeAtlas)
```

### CodeAtlas Source Repository
```
CodeAtlas/
└── .github/
    └── workflows/
        └── release.yml          # Build and publish workflow
```

### Palace Repository (Integration)
```
Palace/
├── tools/
│   ├── bin/
│   │   └── ledger              # (gitignored, created by install)
│   └── ledger/
│       ├── install_ledger.sh   # Palace-specific install script
│       ├── ledger_version.txt  # Pinned version
│       └── README.md           # Usage documentation
└── .github/
    └── workflows/
        └── ledger-analysis.yml # CI workflow using ledger
```

## Security Model

1. **No curl|bash** - Scripts must be downloaded and verified before execution
2. **SHA256 verification** - Every binary verified against manifest checksum
3. **Pinned versions** - No "latest" installs in CI
4. **Deterministic manifests** - versions.json is the source of truth
5. **Exit code 3** - Checksum failures abort immediately

## Release Process

1. Developer pushes tag `v0.2.0` to CodeAtlas repo
2. GitHub Actions runs tests
3. GitHub Actions builds arm64 and x64 binaries
4. GitHub Actions computes SHA256 checksums
5. GitHub Actions creates GitHub Release with binaries
6. GitHub Actions updates versions.json in ledger-dist
7. Users update their pinned version and re-run install script

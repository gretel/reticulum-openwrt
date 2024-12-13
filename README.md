# OpenWrt Reticulum Package Builder 📡

GitHub workflow for cross-compiling [Reticulum Network Stack (RNS)](https://github.com/markqvist/Reticulum) packages for OpenWrt. Based on [openwrt/gh-action-sdk](https://github.com/openwrt/gh-action-sdk).

> **Note**: This is an experimental project currently under active development. The build process and package structure are still being refined and may change significantly. Not recommended for production use yet!

## Overview 📖

This repository provides GitHub Actions workflows for building OpenWrt packages defined in the [feed-reticulum](https://github.com/gretel/feed-reticulum) repository. While the feed contains the package definitions (Makefiles, patches, and configurations), this workflow handles the automated cross-compilation process.

### Repository Relationship
- **feed-reticulum**: Contains OpenWrt package definitions for RNS
- **This repository**: Provides automation to build those packages for different architectures

## Features ✨

- Cross-compiles RNS packages for OpenWrt targets
- Uses official OpenWrt SDK containers
- Build artifact collection and release management
- Package signing support

## How it Works 🔄

1. The workflow fetches the official OpenWrt SDK container for each target architecture
2. It adds our custom feed (`feed-reticulum`) to the SDK
3. The packages (`rns` and `lxmf`) are then built using the SDK
4. Built packages are collected and published as artifacts

## Supported Platforms 🎯

This workflow builds `rns` and `lxmf` packages for:

| Architecture | Example Devices |
|--------------|----------------|
| `aarch64_cortex-a53` | GL.iNet MT3000 (Beryl AX), Raspberry Pi 4/Zero 2, MediaTek MT7981/MT7622 |
| `arm_arm1176jzf-s_vfp` | Raspberry Pi Zero (1st gen) |
| `mips_24kc` | GL.iNet AR750S (Slate), GL.iNet AR300M, Most Atheros AR71xx/AR72xx/AR93xx |
| `x86_64` | Generic x86_64 devices, Virtual Machines |

## Usage 🚀

Create a workflow file (e.g. `.github/workflows/build.yml`):

```yaml
name: Build OpenWrt Packages

on:
  push:
    branches: [ main ]
    tags: ["[0-9]+.[0-9]+.[0-9]+*"]
  pull_request:
  workflow_dispatch:

env:
  PACKAGES: rns lxmf
  EXTRA_FEEDS: >-
    src-git|reticulum|https://github.com/gretel/feed-reticulum.git

jobs:
  build:
    # ... rest of workflow configuration
```

## Configuration ⚙️

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PACKAGES` | Space-separated list (`rns lxmf`) | Required |
| `EXTRA_FEEDS` | Feed URL (`src-git\|reticulum\|url`) | Required |
| `V` | Build verbosity ('', 's', 'sc') | '' |
| `PRIVATE_KEY` | Package signing key | Repository Secret |
| `INDEX` | Generate package index (0/1) | 0 |

## Artifacts 📦

The workflow produces:
- Built packages
- Package index (if enabled)

All artifacts are:
- Collected from `/artifacts` directory
- Uploaded to GitHub Actions artifacts
- Published to GitHub Releases for tagged commits

## Requirements 📋

- GitHub Actions runner with Docker support
- OpenWrt-compatible package source code
- Valid package Makefiles in feed
- Package signing key (optional)

## Development Setup 🛠️

For local development and testing, refer to the [feed-reticulum](https://github.com/gretel/feed-reticulum) repository, which contains detailed instructions for:
- Setting up the OpenWrt build environment
- Installing required dependencies
- Building packages locally
- Configuration and usage guides

## Credits 🙏

- Mark Qvist - Creator of [Reticulum Network Stack](https://github.com/markqvist/Reticulum)
- OpenWrt team - [SDK action](https://github.com/openwrt/gh-action-sdk)

## License ⚖️

MIT
# Dockage: mooring of Dockerfiles 🐳

Welcome to Dockage, a collection of Dockerfiles designed for bioinformatic workflows. Built images can be converted to Singularity format and deployed on HPC clusters.

## Installation

### Prerequisites

**Required:**
| Tool | Needed for | Notes |
|------|-----------|-------|
| **bash** ≥ 4.0 | Runtime | ✅ Preinstalled on all Linux/macOS |
| **Docker** | Building images | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |

**Optional:**
| Tool | Needed for | Install |
|------|-----------|---------|
| **Singularity/Apptainer** | Converting images to `.sif` for HPC | [apptainer.org](https://apptainer.org/) |
| **whiptail** | Interactive TUI *(Phase 2 — planned)* | `apt install whiptail` |
| **bats** | Running unit tests | `apt install bats` |

### Clone & setup

```bash
git clone https://github.com/sergiolitwiniuk85/dockage_plus.git
cd dockage_plus/scripts
chmod +x dockage.sh libs/*.sh

# Check your setup and optionally install extras
bash install.sh
```

The CLI works with Docker alone. Singularity is only needed if you deploy to HPC.

The installer asks if you want a **Simple** setup (just check Docker) or **Full** (also install whiptail for the planned TUI and bats for running tests). **Full** is the default. You can also pass the mode directly:

```bash
bash install.sh simple   # skip optional deps
bash install.sh full     # install whiptail + bats
```

## Quick Start

```bash
cd scripts/

# Validate a Dockerfile follows repo conventions
./dockage.sh validate cellpose

# Build an image (auto-runs validation first)
./dockage.sh build cellpose

# Build with a specific version
./dockage.sh build cellpose v4.1.1

# Scaffold a new tool (Python, R, GPU, or generic)
./dockage.sh init python mytool 1.0.0

# Convert a built Docker image to Singularity
./dockage.sh convert cellpose 4.1.1

# Strict mode — fail on any convention violation
./dockage.sh validate stcancer --strict
```

## dockage CLI

The `scripts/dockage.sh` tool automates builds, validation, scaffolding, and Singularity conversion.

### Commands

| Command | Description |
|---------|-------------|
| `build <tool> [version]` | Validate conventions, then build Docker image. Auto-detects available versions. |
| `validate <tool> [version]` | Check a Dockerfile against repo conventions. Use `--strict` to enforce rules. |
| `init <type> <name> <version>` | Scaffold a new tool directory with a standardized Dockerfile + README. |
| `convert <tool> <version>` | Convert a built Docker image to Singularity `.sif` format. |

### Options

| Flag | Applies to | Effect |
|------|-----------|--------|
| `--strict` | `validate`, `build` | Escalate warnings to errors (exit 1) |
| `--dry-run` | `build` | Print commands without executing them |
| `--skip-validate` | `build` | Skip pre-build validation |
| `--help` | any | Show usage |
| `--version` | any | Show version |

### Validation Rules

The validator runs automatically before every build (unless `--skip-validate` is used):

| Rule | Severity | What it checks |
|------|----------|----------------|
| Conda usage | ⚠️ Warning | Detects `conda install`, `miniconda`, `mamba` |
| COPY Dockerfile | ⚠️ Warning | Ensures `COPY Dockerfile /docker/` + `RUN chmod` are present |
| Base image (R) | ⚠️ Warning | R tools should use `rocker/rstudio` (Jupyter IRkernel compat) |
| Base image (GPU) | ⚠️ Warning | GPU images should match `nvidia/cuda:12.1.1-*` |
| Naming convention | ⚠️ Warning | Files should be `Dockerfile` or `Dockerfile.vX.Y.Z` |

All checks produce warnings by default. Use `--strict` to enforce them.

### Scaffolder Templates

```bash
./dockage.sh init <type> <name> <version>
```

| Type | Base Image | Package Manager |
|------|-----------|-----------------|
| `python` | `python:3.11-slim` | `uv` (includes jupyterlab + ipykernel + papermill) |
| `r` | `rocker/rstudio:4.4.0` | — |
| `gpu` | `nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04` | — |
| `generic` | `ubuntu:22.04` | — |

Generates `<name>/Dockerfile.v<version>` + `<name>/README.md` with a standard template.

## Repository Structure

```
dockage/
│
├── tool1/
│   ├── Dockerfile            # Latest version
│   ├── Dockerfile.vX.Y.Z     # Specific versions (standard convention)
│   └── additional-files/     # Optional: supplementary scripts or dependencies
│...
├── scripts/
│   ├── dockage.sh            # 🔧 CLI entry point (build, validate, init, convert)
│   ├── convert.sh            # Wrapper for dockage.sh convert
│   ├── libs/
│   │   ├── validator.sh      # Dockerfile convention checks
│   │   ├── builder.sh        # Docker build + Singularity conversion
│   │   ├── scaffolder.sh     # Template generator
│   │   └── ui.sh             # Interactive menu stubs (TUI planned)
│   └── tests/
│       ├── fixtures/         # Test Dockerfile samples
│       ├── test_validator.bats
│       ├── test_builder.bats
│       ├── test_scaffolder.bats
│       └── test_integration.sh
│
└── README.md
```

## Building Docker Images (manual)

Each subdirectory contains a Dockerfile for a specific tool. To build manually:

```bash
cd toolName/
docker build -t toolName:version -f Dockerfile.version .
singularity build toolName-version.sif docker-daemon://toolName:version
```

> **Tip**: Use `scripts/dockage.sh build` instead — it handles version detection, validation, and optional Singularity conversion automatically.

## Considerations when creating images

### 🏷️ Naming Convention
Standardize on `Dockerfile` for the latest version and `Dockerfile.vX.Y.Z` for specific versions (e.g., `Dockerfile.v1.2.3`). The scaffolder follows this convention automatically, and the validator warns on non-standard names.

### 🐍 Python-based images
Use `python:3.11-slim` as base and install with `uv`:
```dockerfile
RUN pip install uv && uv pip install jupyterlab ipykernel papermill
```

### 🐘 R-based images
Use [rocker/rstudio](https://hub.docker.com/r/rocker/rstudio) as the base image for Jupyter IRkernel compatibility.

### 📄 Dockerfile in docker image
Add these as the last two lines of your Dockerfile:
```dockerfile
COPY Dockerfile /docker/
RUN chmod -R 755 /docker
```

### 🚀 GPU-base image
For driver compatibility on HPC clusters:
```dockerfile
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04
```

### ⚠️ No conda
Do **not** use conda, miniconda, or mamba when creating containers. Prefer `pip` or `uv`.

## Running Tests

```bash
cd scripts/tests/
bash test_integration.sh          # Integration smoke tests
bats test_validator.bats          # Validator unit tests
bats test_builder.bats            # Builder unit tests
bats test_scaffolder.bats         # Scaffolder unit tests
```

## Contributing

We welcome contributions! If you have improvements to existing Dockerfiles or want to add support for more bioinformatics tools, please open a pull request.

New tools can be bootstrapped with:
```bash
cd scripts/
./dockage.sh init python mytool 1.0.0
# Edit mytool/Dockerfile.v1.0.0 and mytool/README.md
```


# Bitbucket → AWS CodeBuild ARM64 Image Builder

## Problem

Bitbucket Pipelines **does not offer ARM64 runners**. Building ARM64 Docker images via QEMU emulation is **~10x slower** than native builds. This project solves that by delegating the build to AWS CodeBuild running on **Graviton (ARM64 native)** instances.

## Architecture

![Pipeline Architecture](docs/architecture.svg)

### How It Works

1. **Developer** pushes code to Bitbucket
2. **Bitbucket Pipeline** (x86 runner) triggers AWS CodeBuild via `aws codebuild start-build`
3. **AWS CodeBuild** (Graviton ARM64) runs the Docker build natively — no emulation
4. **CodeBuild** pushes the ARM64 image to **Amazon ECR**
5. **Bitbucket Pipeline** polls CodeBuild status every 10 seconds until `SUCCEEDED`
6. Pipeline completes ✅

### Key Insight

The Bitbucket pipeline acts as an **orchestrator only** — it doesn't build anything. The actual compilation happens on AWS Graviton hardware, giving native ARM64 performance.

## Infrastructure

![Infrastructure Diagram](docs/infra.svg)

All infrastructure is managed with **Terraform** (`infra/`):

| Resource | Purpose |
|----------|---------|
| **ECR Repository** (`arm64-demo`) | Stores the built ARM64 Docker images |
| **CodeBuild Project** (`arm64-image-builder`) | Runs builds on `ARM_CONTAINER` (Graviton) |
| **IAM Role + Policy** (CodeBuild) | Grants CodeBuild access to ECR push + CloudWatch logs |
| **OIDC Provider** (Bitbucket) | Enables keyless auth from Bitbucket Pipelines |
| **IAM Role** (Bitbucket) | Allows Bitbucket to trigger CodeBuild via OIDC |
| **OIDC Provider** (GitHub) | Enables keyless auth from GitHub Actions |
| **IAM Role** (GitHub Actions) | Allows GitHub Actions to run Terraform deployments |

### Authentication

Both CI/CD platforms use **OIDC federation** — no static AWS access keys stored anywhere:
- **Bitbucket** → assumes `bitbucket-arm64-codebuild-role` to trigger CodeBuild
- **GitHub Actions** → assumes `github-arm64-codebuild-deploy-role` to deploy Terraform

### CodeBuild Configuration

- **Compute**: `BUILD_GENERAL1_SMALL` (ARM64)
- **Image**: `aws/codebuild/amazonlinux2-aarch64-standard:3.0`
- **Type**: `ARM_CONTAINER` → runs on Graviton instances
- **Privileged mode**: enabled (required for `docker build`)

## CI/CD

### GitHub Actions (Infrastructure)

The workflow `.github/workflows/deploy.yml` automatically deploys Terraform changes:
- **Trigger**: push to `main` (files in `infra/`) or manual dispatch
- **Auth**: GitHub OIDC → AWS IAM Role (no secrets needed beyond role ARN)

### Bitbucket Pipelines (ARM64 Build)

The custom pipeline `arm64-build-poc` in the target repo:
- **Trigger**: manual (Run pipeline → select `arm64-build-poc`)
- **Auth**: Bitbucket OIDC → AWS IAM Role

## File Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml             # GitHub Actions: Terraform deploy
├── Dockerfile                     # ARM64 Python demo image
├── README.md                      # This file
├── app.py                         # Simple hello world app
├── bitbucket-pipelines.yml        # Orchestrator: trigger CodeBuild + poll
├── buildspec.yml                  # CodeBuild instructions: build + push ECR
├── docs/
│   ├── architecture.svg           # Pipeline flow diagram
│   └── infra.svg                  # Infrastructure diagram
└── infra/
    ├── codebuild.tf               # Terraform: ECR + CodeBuild + IAM
    ├── oidc.tf                    # Terraform: Bitbucket OIDC + IAM Role
    ├── github-oidc.tf             # Terraform: GitHub OIDC + IAM Role
    ├── terraform.tfvars.example   # Template for required variables
    └── terraform.tfvars           # (gitignored) actual values
```

## Quick Start

### 1. Configure

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit with your values
vi terraform.tfvars
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform apply
```

Or push to `main` — GitHub Actions deploys automatically.

### 3. Configure Bitbucket Pipeline

In your target repo's `bitbucket-pipelines.yml`, add a custom pipeline step with `oidc: true` that triggers the CodeBuild project. Set the repository variable `AWS_ARM64_ROLE_ARN` to the Bitbucket role ARN output by Terraform.

### 4. Run

Trigger the custom pipeline manually from Bitbucket, or push to a branch that runs it automatically.

## Why This Approach?

| Approach | Build Time | Cost | Complexity |
|----------|-----------|------|------------|
| QEMU emulation on Bitbucket | ~10 min | $$$ (runner time) | Low |
| **CodeBuild Graviton (this)** | **~1 min** | **$** (pay per build-minute) | Medium |
| Self-hosted ARM64 runner | ~1 min | $$$ (EC2 24/7) | High |

CodeBuild Graviton gives **native ARM64 speed** with **pay-per-use pricing** and **zero maintenance** of runner infrastructure.

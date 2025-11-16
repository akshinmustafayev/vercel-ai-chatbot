# Reusable AWS Deployment Pipeline — App Runner + CodePipeline + Supabase
test for auto trigger new change
This repository contains a reusable, modular AWS deployment pattern designed to support multiple application projects with minimal changes. It implements:

- **CI/CD with AWS CodePipeline + CodeBuild**
- **Automatic deployments on push to the `deploy_dev` branch**
- **Secure secrets handling via AWS Secrets Manager**
- **Deployment of containerized applications to AWS App Runner**
- **Runtime secret injection into the application container**
- **GitHub auto-tagging after successful deployment**
- **Fully reproducible IaC-based architecture using Terraform**

This solution is built to be a **template** that can be reused across many projects with minor adjustments.

---

## 🚀 Architecture Overview

### Components
| Component | Purpose |
|----------|---------|
| **AWS CodePipeline** | Detects changes on GitHub (`deploy_dev`), orchestrates CI/CD |
| **AWS CodeBuild** | Builds the Docker image, pushes to ECR, calls GitHub tagging API |
| **AWS App Runner (ECR deployment)** | Runs the container and retrieves secrets at runtime |
| **AWS Secrets Manager** | Secure storage for Supabase + application environment variables |
| **Terraform module (`modules/cicd-apprunner`)** | Reusable CI/CD + App Runner infrastructure |
| **Dockerfile (custom)** | Production build with explicit env injection support |
| **GitHub auto-tagging** | Tags successful deployments automatically |

---

## 📦 High-Level Flow

```
GitHub push → deploy_dev branch
↓
AWS CodePipeline
↓
AWS CodeBuild
• Builds Docker image
• Fetches Secrets Manager values
• Pushes image to ECR
• Creates GitHub deployment tag
↓
AWS App Runner updates service
↓
Application becomes publicly available
```

---

## 🔐 Secrets Management (AWS Secrets Manager)

All sensitive values (Supabase keys, URLs, app configs) are stored in **AWS Secrets Manager**.

Variables:
```bash
  "OPENAI_API_KEY": "...",
  "NEXT_PUBLIC_SUPABASE_URL": "...",
  "NEXT_PUBLIC_SUPABASE_ANON_KEY": "...",
  "NEXT_PUBLIC_AUTH_GITHUB": "dev",
  "github-tagging-pat": "dev"
```

The App Runner service injects these values at runtime.

---

## 🛠 Important feature Fix Implemented

The original application (vercel-ai-chatbot) did not have Dockerfile configuration and even after creating it could not read env vars correctly when injected by App Runner.

Solution:
- Built a custom Dockerfile
- Ensured environment variables are forwarded properly at runtime
- Validated Supabase connectivity successfully

## 📂 Repository Structure

```
/
├── buildspec.yml
├── Dockerfile
├── main.tf
├── terraform.tfvars
├── modules/
│   └── cicd-apprunner/
│       ├── main.tf
│       └── variables.tf
└── README.md
```

Reusable Module: modules/cicd-apprunner

The module provisions:
- AWS App Runner service (ECR-based)
- CodePipeline + CodeBuild (+buildspec.yaml) + GitHub triggers
- ECR repository
- IAM roles & permissions
- Secret injection configuration

To reuse:

```yaml
module "app_cicd" {
  source = "./modules/cicd-apprunner"

  # App Configuration
  app_name                  = local.app_name
  aws_region                = var.aws_region
  
  # GitHub Source Configuration
  github_owner              = var.github_owner
  github_repo               = var.github_repo
  github_branch             = "deploy_dev"
  github_connection_arn     = var.github_connection_arn

  # Secrets Configuration
  openai_api_arn            = aws_secretsmanager_secret.openai_api.arn
  supabase_url_arn          = aws_secretsmanager_secret.supabase_url.arn
  supabase_anon_key_arn     = aws_secretsmanager_secret.supabase_anon_key.arn
  public_auth_github_arn    = aws_secretsmanager_secret.public_auth_github.arn
  github_pat_secret_arn     = aws_secretsmanager_secret.github_pat.arn
  
  # Build Configuration (Content of the buildspec.yml)
  
  buildspec_content = file("buildspec.yml")
}
```

## 🛠 Deployment Instructions

1. Configure Terraform

Edit terraform.tfvars:
```yaml
openai_api_key				  = "xxxxxxxxx"
next_public_supabase_url      = "some url"
next_public_supabase_anon_key = "some key"
next_public_auth_github           = "false"
github_token           = "github_pat_api_key"
```

2. Deploy Infrastructure

```bash
terraform init
terraform apply --auto-approve
```

3. Trigger the Pipeline

```bash
git push origin deploy_dev
```

## 🔁 Reusability Strategy

This pipeline is designed to support many future projects with minimal changes.

### Standardized Across Projects

- CI/CD pipeline definition
- CodeBuild buildspec
- App Runner deployment
- IAM roles
- Secret injection
- GitHub tagging

### App-Specific Inputs

- Repository name / branch
- Container build rules (Dockerfile)
- Supabase / app-specific environment variables
- App Runner scaling settings

This separation keeps the pattern clean, modular, and reusable.

*It would also be a best practice to configure terraform infrastructure provisioning using CodeBuild and CodePipeline using templates, modules and injection, but is out of scope for this task and would take longer time configure.*

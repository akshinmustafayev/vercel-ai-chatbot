terraform {
 required_providers {
   aws = {
     source  = "hashicorp/aws"
   }
 }
}

provider "aws" {
  region = "us-east-1"
  access_key = "value from secrets manager"
  secret_key = "value from secrets manager"
}

# -----------------------------------------------------------------------------
# 2. Application-Specific Variables (The inputs for a new app)
# -----------------------------------------------------------------------------
locals {
  app_name = "vercel-ai-chatbot"
}

variable "github_owner" {
  description = "GitHub repository owner."
  type        = string
  default     = "akshinmustafayev" # Change to your fork owner for deployment
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = "vercel-ai-chatbot"
}

variable "github_connection_arn" {
  description = "ARN of the AWS CodeStar Connection to GitHub (Manual Pre-Req)."
  type        = string
  default = "github_connection_arn_specific for account" 
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# -----------------------------------------------------------------------------
# 3. Secure Secrets Provisioning (Supabase & GitHub Tagging PAT)
# -----------------------------------------------------------------------------
# Resource for the secret's metadata (Name and Description)

resource "aws_secretsmanager_secret" "openai_api" {
  name        = "OPENAI_API_KEY"
  description = "OpenAI API key"
}

resource "aws_secretsmanager_secret_version" "openai_api_value" {
  secret_id     = aws_secretsmanager_secret.openai_api.id
  secret_string = var.openai_api_key
}

resource "aws_secretsmanager_secret" "supabase_url" {
  name        = "NEXT_PUBLIC_SUPABASE_URL"
  description = "Supabase URL"
}

resource "aws_secretsmanager_secret_version" "supabase_url_value" {
  secret_id     = aws_secretsmanager_secret.supabase_url.id
  secret_string = var.next_public_supabase_url
}

resource "aws_secretsmanager_secret" "supabase_anon_key" {
  name        = "NEXT_PUBLIC_SUPABASE_ANON_KEY"
  description = "Supabase anon key"
}

resource "aws_secretsmanager_secret_version" "supabase_anon_key_value" {
  secret_id     = aws_secretsmanager_secret.supabase_anon_key.id
  secret_string = var.next_public_supabase_anon_key
}

resource "aws_secretsmanager_secret" "public_auth_github" {
  name        = "NEXT_PUBLIC_AUTH_GITHUB"
  description = "GitHub OAuth redirect URL"
}

resource "aws_secretsmanager_secret_version" "public_auth_github_value" {
  secret_id     = aws_secretsmanager_secret.public_auth_github.id
  secret_string = var.next_public_auth_github
}

resource "aws_secretsmanager_secret" "github_pat" {
  name        = "tacticaledgeai/github-tagging-pat"
  description = "PAT for CodeBuild to auto-tag deployments."
}

# Resource for the secret's value (The raw token string)
resource "aws_secretsmanager_secret_version" "github_pat_version" {
  # Links the value to the metadata resource
  secret_id = aws_secretsmanager_secret.github_pat.id 
  
  secret_string = var.github_token
}

# -----------------------------------------------------------------------------
# 4. Call the Reusable CI/CD Module
# -----------------------------------------------------------------------------
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

output "app_runner_url" {
  description = "The URL of the deployed App Runner service."
  value       = module.app_cicd.app_runner_url
}

###############
# VARIABLES
###############

variable "openai_api_key" {}
variable "next_public_supabase_url" {}
variable "next_public_supabase_anon_key" {}
variable "next_public_auth_github" {}
variable "github_token" {}

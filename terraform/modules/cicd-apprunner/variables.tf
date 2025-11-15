# -----------------------------------------------------------------------------
# App Configuration
# -----------------------------------------------------------------------------
variable "app_name" {
  description = "The name of the application, used for naming all AWS resources."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where resources should be deployed."
  type        = string
}

# -----------------------------------------------------------------------------
# GitHub Source Configuration
# -----------------------------------------------------------------------------
variable "github_owner" {
  description = "GitHub repository owner."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_branch" {
  description = "The branch name to trigger the pipeline (must be 'deploy_dev')."
  type        = string
}

variable "github_connection_arn" {
  description = "ARN of the AWS CodeStar Connection to GitHub."
  type        = string
}

# -----------------------------------------------------------------------------
# Secrets Configuration
# -----------------------------------------------------------------------------

variable "openai_api_arn" {
  description = "ARN of the openai api"
  type        = string
}

variable "supabase_url_arn" {
  description = "ARN of the supabase url"
  type        = string
}

variable "supabase_anon_key_arn" {
  description = "ARN of the supabase anon key"
  type        = string
}

variable "public_auth_github_arn" {
  description = "ARN of the github enable arn"
  type        = string
}


variable "github_pat_secret_arn" {
  description = "ARN of the GitHub Personal Access Token secret for auto-tagging."
  type        = string
}

# -----------------------------------------------------------------------------
# Build Configuration
# -----------------------------------------------------------------------------
variable "buildspec_content" {
  description = "The content of the buildspec.yml file."
  type        = string
}
# modules/cicd-apprunner/main.tf

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# 1B. App Runner Service Access Role (For pulling ECR images)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "apprunner_service_role" {
  name = "${var.app_name}-apprunner-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_service_attach" {
  role       = aws_iam_role.apprunner_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# -----------------------------------------------------------------------------
# 1. IAM Roles (Standardized Service Roles)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "apprunner_instance_role" {
  name = "${var.app_name}-apprunner-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_policy" "apprunner_secrets_policy" {
  name   = "${var.app_name}-apprunner-secrets-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret" 
        ]
		Resource = [
          var.openai_api_arn,
          var.supabase_url_arn,
          var.supabase_anon_key_arn,
          var.public_auth_github_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_secrets_attach" {
  role       = aws_iam_role.apprunner_instance_role.name
  policy_arn = aws_iam_policy.apprunner_secrets_policy.arn
}

resource "aws_iam_role" "codebuild_role" {
  name = "${var.app_name}-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_admin_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# CodePipeline Service Role
# -----------------------------------------------------------------------------
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.app_name}-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_admin_attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# 2. ECR Repository
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.app_name}-repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# -----------------------------------------------------------------------------
# 3. AWS App Runner Service
# -----------------------------------------------------------------------------
resource "aws_apprunner_service" "app_service" {
  service_name = "${var.app_name}-service"

  source_configuration {
	authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_service_role.arn
    }
	
    image_repository {
	  image_identifier      = "${aws_ecr_repository.app_repo.repository_url}:latest"
      image_repository_type = "ECR"
	  
      image_configuration {
        port = "3000" # Default port for the suggested app
        runtime_environment_secrets = {
		  OPENAI_API_KEY    = var.openai_api_arn
          NEXT_PUBLIC_SUPABASE_URL = var.supabase_url_arn
          NEXT_PUBLIC_SUPABASE_ANON_KEY = var.supabase_anon_key_arn
          NEXT_PUBLIC_AUTH_GITHUB = var.public_auth_github_arn
	    }
      }
    }
    auto_deployments_enabled = false
  }
  
  # During initial commit
  #source_configuration {
  #
  #  image_repository {
  #  image_identifier      = "public.ecr.aws/aws-containers/hello-app-runner:latest"
  #    image_repository_type = "ECR_PUBLIC"
  #    image_configuration {
  #      port = "3000" # Default port for the suggested app
  #      runtime_environment_secrets = {
  #        OPENAI_API_KEY    = var.openai_api_arn
  #        NEXT_PUBLIC_SUPABASE_URL = var.supabase_url_arn
  #        NEXT_PUBLIC_SUPABASE_ANON_KEY = var.supabase_anon_key_arn
  #        NEXT_PUBLIC_AUTH_GITHUB = var.public_auth_github_arn
  #      }
  #    }
  #  }
  #  auto_deployments_enabled = false
  #}

  instance_configuration {
    instance_role_arn = aws_iam_role.apprunner_instance_role.arn
  }
  
  lifecycle {
    ignore_changes = [
      source_configuration[0].image_repository[0].image_identifier
    ]
  }
}

# -----------------------------------------------------------------------------
# 4. AWS CodePipeline & CodeBuild
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.app_name}-pipeline-artifacts-${data.aws_caller_identity.current.account_id}" # Removed ${var.aws_region}
  
  tags = {
    Name = "${var.app_name}-pipeline-artifacts"
  }
}

resource "aws_s3_bucket_public_access_block" "codepipeline_artifacts_block" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_codebuild_project" "app_build" {
  name           = "${var.app_name}-build"
  description    = "Build project for ${var.app_name}"
  service_role   = aws_iam_role.codebuild_role.arn
  build_timeout  = "20"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true # Required for Docker builds

    environment_variable {
      name  = "ECR_REPO_URI"
      value = aws_ecr_repository.app_repo.repository_url
    }
    environment_variable {
      name  = "APP_RUNNER_SERVICE_ARN"
      value = aws_apprunner_service.app_service.arn
    }
    environment_variable {
      name  = "GITHUB_PAT_SECRET_ARN"
      value = var.github_pat_secret_arn
    }
    environment_variable {
      name  = "GITHUB_REPO"
      value = var.github_repo
    }
    environment_variable {
      name  = "GITHUB_OWNER"
      value = var.github_owner
    }
    environment_variable {
      name  = "OPENAI_API_KEY"
      value = var.openai_api_arn
    }
    environment_variable {
      name  = "NEXT_PUBLIC_SUPABASE_URL"
      value = var.supabase_url_arn
    }
    environment_variable {
      name  = "NEXT_PUBLIC_SUPABASE_ANON_KEY"
      value = var.supabase_anon_key_arn
    }
    environment_variable {
      name  = "NEXT_PUBLIC_AUTH_GITHUB"
      value = var.public_auth_github_arn
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_content # Takes the buildspec.yml content from the root
  }
}


resource "aws_codepipeline" "app_pipeline" {
  name     = "${var.app_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  # Source Stage
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_artifact"]

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch # 'deploy_dev'
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "BuildAndDeploy"
    action {
      name             = "BuildAndDeploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_artifact"]
      output_artifacts = ["build_artifact"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.app_build.name
      }
    }
  }
}

# -----------------------------------------------------------------------------
# 5. Outputs
# -----------------------------------------------------------------------------
output "app_runner_url" {
  description = "The URL of the deployed App Runner service."
  value       = aws_apprunner_service.app_service.service_url
}

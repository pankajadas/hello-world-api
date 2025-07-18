provider "aws" {
  region = var.aws_region
}

# Define variables
variable "aws_region" {
  description = "deployed on ap south"
  type        = string
  default     = "ap-south-1"
}

variable "app_name" {
  description = "deploying helloworld application."
  type        = string
  default     = "HelloWorldApi"
}

# -----------------------------------------------------------------------------
# ECR Repository
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.app_name}-repo"
  image_tag_mutability = "MUTABLE" # Allows overwriting tags like 'latest'

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.app_name}-repo"
    Environment = "production"
  }
}

# -----------------------------------------------------------------------------
# IAM Role for Lambda
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.app_name}-LambdaExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-LambdaExecutionRole"
    Environment = "production"
  }
}

# Attach the AWSLambdaBasicExecutionRole policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "app_lambda" {
  function_name = "${var.app_name}-Function"
  role          = aws_iam_role.lambda_exec_role.arn
  package_type  = "Image" # Specify that the Lambda uses a Docker image

  # This image_uri will be updated by the CI/CD pipeline
  # For initial deployment, it needs a placeholder.
  # The GitHub Actions workflow will build and push the image, then update this Lambda.
  image_uri     = "${aws_ecr_repository.app_repo.repository_url}:latest" # Placeholder, updated by CI/CD

  timeout       = 30 # seconds
  memory_size   = 128 # MB

  environment {
    variables = {
      # You can add environment variables here, e.g., JWT_SECRET
      NODE_ENV = "Testing"
    }
  }

  tags = {
    Name        = "${var.app_name}-Function"
    Environment = "Testing"
  }
}

# -----------------------------------------------------------------------------
# API Gateway
# -----------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "${var.app_name}-API"
  description = "API Gateway for the Hello World Node.js Lambda"

  tags = {
    Name        = "${var.app_name}-API"
    Environment = "Testing"
  }
}

# Define a resource for the root path (/)
resource "aws_api_gateway_resource" "api_gateway_root_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "{proxy+}" # Catch-all path for Express routes
}

# Define the ANY method for the root resource
resource "aws_api_gateway_method" "api_gateway_proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_gateway_root_resource.id
  http_method   = "ANY" # Allows all HTTP methods (GET, POST, PUT, DELETE, etc.)
  authorization = "NONE" # No authorization at API Gateway level, handled by Lambda
}

# Define the integration between API Gateway and Lambda
resource "aws_api_gateway_integration" "api_gateway_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.api_gateway_root_resource.id
  http_method             = aws_api_gateway_method.api_gateway_proxy_method.http_method
  integration_http_method = "POST" # Lambda proxy integration always uses POST
  type                    = "AWS_PROXY" # Use Lambda proxy integration
  uri                     = aws_lambda_function.app_lambda.invoke_arn
}

# Deploy the API Gateway
resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  # Trigger redeployment on changes to methods or integrations
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.api_gateway_proxy_method.id,
      aws_api_gateway_integration.api_gateway_lambda_integration.id,
    ]))
  }

  # NOTE: The description is required for a new deployment to be created.
  # If you change the description, a new deployment will be created.
  description = "Deployment for ${var.app_name} API"

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore changes to the description to prevent unnecessary redeployments
      description,
    ]
  }
}

# Create a stage for the API Gateway deployment
resource "aws_api_gateway_stage" "api_gateway_stage" {
  deployment_id = aws_api_gateway_deployment.api_gateway_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  stage_name    = "prod" # Production stage
}

# -----------------------------------------------------------------------------
# Lambda Permission for API Gateway to invoke Lambda
# -----------------------------------------------------------------------------
resource "aws_lambda_permission" "api_gateway_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* part is crucial for {proxy+} integration
  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "api_gateway_url" {
  description = "The URL of the deployed API Gateway endpoint."
  value       = "${aws_api_gateway_stage.api_gateway_stage.invoke_url}"
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository."
  value       = aws_ecr_repository.app_repo.repository_url
}

output "lambda_function_name" {
  description = "The name of the Lambda function."
  value       = aws_lambda_function.app_lambda.function_name
}

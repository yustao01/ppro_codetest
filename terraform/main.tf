provider "aws" {
  region = "us-east-1"
}

# 1. SNS Topic for Notifications
resource "aws_sns_topic" "alert_topic" {
  name = "pacerpro-alerts"
}

# 2. EC2 Instance to be Managed
resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 (verify for your region)
  instance_type = "t2.micro"
  tags = {
    Name = "PacerPro-Web-Server"
  }
}

# 3. IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "pacerpro_lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# 4. IAM Policy for EC2 Reboot and SNS Publish (Least Privilege)
resource "aws_iam_role_policy" "lambda_policy" {
  name = "pacerpro_lambda_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ec2:RebootInstances", "ec2:DescribeInstances"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.alert_topic.arn
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# 5. Lambda Function Deployment
resource "aws_lambda_function" "restart_ec2_lambda" {
  filename      = "lambda_function_payload.zip" # Ensure your python code is zipped
  function_name = "RestartEC2Instance"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      INSTANCE_ID   = aws_instance.web_server.id
      SNS_TOPIC_ARN = aws_sns_topic.alert_topic.arn
    }
  }
}

# 6. Allow Sumo Logic to Trigger Lambda (via URL or API Gateway if needed)
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromSumoLogic"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.restart_ec2_lambda.function_name
  principal     = "lambda.amazonaws.com" # Adjust based on Sumo Logic trigger method
}

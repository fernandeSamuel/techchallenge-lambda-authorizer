resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "lambda-code-bucket-cpf-validator-${random_string.suffix.result}"

  tags = {
    Name = "LambdaCodeBucket"
  }
}

resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "cpf-validator.zip"
  source = "cpf-validator.zip"
}

resource "aws_s3_bucket_policy" "lambda_bucket_policy" {
  bucket = aws_s3_bucket.lambda_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowLambdaRead",
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.lambda_bucket.arn}/*"
      }
    ]
  })
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

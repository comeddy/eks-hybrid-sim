output "role_arn" {
  description = "생성된 IAM Role ARN"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "생성된 IAM Role 이름"
  value       = aws_iam_role.this.name
}

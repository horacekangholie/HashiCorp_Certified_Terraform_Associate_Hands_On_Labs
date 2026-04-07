# Output values for the Terraform configuration
output "region_id" {
  description = "Output the ID for the region"
  value       = data.aws_region.current.id
}

output "vpc_id" {
  description = "Output the ID for the primary VPC"
  value       = aws_vpc.vpc.id
}

output "public_url" {
  description = "Public URL for our Web Server"
  value       = "https://${aws_instance.web_server.private_ip}:8080/index.html"
}
output "vpc_information" {
  description = "VPC Information about Environment"
  value       = "Your ${aws_vpc.vpc.tags.Environment} VPC has an ID of ${aws_vpc.vpc.id}"
}
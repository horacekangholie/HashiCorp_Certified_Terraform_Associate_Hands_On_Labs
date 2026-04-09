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
  # value       = "https://${aws_instance.web_server.private_ip}:8080/index.html"
  value = module.server.public_dns # reference the public DNS output from the server module
}
output "vpc_information" {
  description = "VPC Information about Environment"
  value       = "Your ${aws_vpc.vpc.tags.Environment} VPC has an ID of ${aws_vpc.vpc.id}"
}

output "public_key" {
  description = "Public key generated from the private key to be used to register as key pair in AWS"
  value       = tls_private_key.generated.public_key_openssh
}

output "public_ip" {
  # value = aws_instance.web_server.public_ip
  value = module.server.public_ip # reference the public IP output from the server module
}

output "public_ip_subnet_2" {
  # value = aws_instance.web_server.public_ip
  value = module.server_subnet_2.public_ip # reference the public IP output from the server module
}


output "local_private_key" {
  value = local_file.private_key_pem.filename
}

# output "my_ip" {
#   description = "Your public IP address"
#   value = data.http.my_ip.response_body
# }
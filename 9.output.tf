
output "bastion_public_ip" {
  description = "The Bastion Instance Public IP"
  value       = aws_instance.ansible_controller.public_ip
}
output "client_server_private_ips" {
  description = "Private IP addresses of the client-server instances"
  value       = aws_instance.client-server[*].private_ip
}

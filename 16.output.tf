
output "bastion_public_ip" {
  description = "The ansible_controller Instance Public IP"
  value       = aws_instance.ansible_controller.public_ip
}

output "ansible_client_public_ips" {
  description = "Public IPs of the Ansible client instances"
  value       = aws_instance.ansible_client[*].public_ip
}
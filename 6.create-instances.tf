resource "aws_instance" "ansible_controller" {
  ami                  = var.instance_ami_type
  instance_type        = var.instance_type_controller
  key_name             = "testing-dev-1"
  subnet_id            = aws_subnet.dev_subnet_public_1.id
  iam_instance_profile = data.aws_iam_instance_profile.ansible_controller_role.name
  vpc_security_group_ids = [
    aws_security_group.combined_sg.id,
    aws_security_group.haproxy_sg.id,
  ]
  user_data = file("user-script-bastion.sh")

  tags = {
    "Name"                             = "ansible_controller"
    "Environment"                      = "Development"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Introduce a delay of 90 seconds after ansible_controller is created
resource "null_resource" "pause_after_ansible_controller" {
  provisioner "local-exec" {
    command = "sleep 90"
  }
  depends_on = [aws_instance.ansible_controller]
}

resource "aws_instance" "client-server" {
  count                = var.client_instance_count
  ami                  = var.instance_ami_type
  instance_type        = var.instance_type_client
  key_name             = "testing-dev-1"
  subnet_id            = aws_subnet.dev_subnet_public_1.id
  iam_instance_profile = data.aws_iam_instance_profile.ansible_controller_role.name
  vpc_security_group_ids = [
    aws_security_group.combined_sg.id,
    aws_security_group.haproxy_sg.id,
  ]
  user_data = file("user-script-node.sh")

  tags = {
    "Name"                             = "ansible_client_${count.index + 1}"
    "Environment"                      = "Development"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }

  depends_on = [null_resource.pause_after_ansible_controller]
}

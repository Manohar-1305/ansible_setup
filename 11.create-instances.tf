resource "aws_instance" "ansible_controller" {
  ami                  = var.instance_ami_type
  instance_type        = var.instance_type_bastion
  key_name             = "testing-dev-1"
  subnet_id            = aws_subnet.dev_subnet_public_1.id
  iam_instance_profile = data.aws_iam_instance_profile.bucket-policy.name
  vpc_security_group_ids = [
    aws_security_group.ssh_web_traffic_sg.id,
  ]
  user_data = file("user-script-controller.sh")

  tags = {
    "Name"       = "ansible_controller"
    "Environment" = "Development"
  }
}

resource "time_sleep" "wait_before_clients" {
  depends_on = [aws_instance.ansible_controller]

  create_duration = "90s"  # Waits for 90 seconds after the controller is created
}

resource "aws_instance" "ansible_client" {
  count                = var.master_instance_count
  ami                  = var.instance_ami_type
  instance_type        = var.instance_type_master
  key_name             = "testing-dev-1"
  subnet_id            = aws_subnet.dev_subnet_public_1.id
  iam_instance_profile = data.aws_iam_instance_profile.bucket-policy.name
  vpc_security_group_ids = [
    aws_security_group.ssh_web_traffic_sg.id,
  ]
  user_data = file("user-script-client.sh")

  tags = {
    "Name" = "ansible_client${count.index + 1}"
  }

  depends_on = [time_sleep.wait_before_clients]  # Ensures the delay happens before creating clients
}

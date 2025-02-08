resource "aws_security_group" "combined_sg" {
  name        = "Combined-Security-Group"
  description = "Combined security group for SSH, HTTP, HTTPS, Kubernetes, NAT Gateway, HAProxy, NodePort, NFS, etc."
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

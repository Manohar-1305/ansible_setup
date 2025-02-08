
variable "instance_ami_type" {
  description = "The Image ID to be used"
  type        = string
  default     = "ami-03bb6d83c60fc5f7c"
}
variable "region" {
  description = "The regions used"
  type        = string
  default     = "ap-south-1"
}
variable "instance_type_controller" {
  description = "Instance type for the dev instance"
  type        = string
  default     = "t2.medium"
}
variable "instance_type_client" {
  description = "Instance type for the dev instance"
  type        = string
  default     = "t2.medium"
}
variable "client_instance_count" {
  type        = number
  default     = 3
  description = "Number of Client instances to create"
}


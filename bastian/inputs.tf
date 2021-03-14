variable "private_key_path" {
  description = "path to private key to inject into the instances to allow ssh"
  default     = "./ssh/id_rsa"
}

variable "public_key_path" {
  description = "path to public key to inject into the instances to allow ssh"
  default     = "./ssh/id_rsa.pub"
}

variable "key_name" {
  description = "master key for the bastian"
  default     = "bastian-key"
}

variable "name" {
  description = "A name to be applied to make everything unique and personal"
}

variable "aws_region" {
  description = "Europe"
  default     = "eu-west-1"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "project" {
  description = "project name"
  default     = "shiro-bastian-lab"
}

variable "owner" {
  description = "owner name"
  default     = "shiro"
}





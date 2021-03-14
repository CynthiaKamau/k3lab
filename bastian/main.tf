module "tags_bastian" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git"
  namespace   = var.name
  environment = "dev"
  name        = "bastian-chaosengineers"
  delimiter   = "_"

  tags = {
    owner = var.name
    project = var.project
    env = "dev"
    workspace = "shiro-labs"
    comments  = "bastian"
  }
}

module "tags_control_plane" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git"
  namespace   = var.name
  environment = "dev"
  name        = "control-plane-chaosengineers"
  delimiter   = "_"

  tags = {
    owner = var.name
    project = var.project
    env = "dev"
    workspace = "shiro-labs"
    comments  = "control_plane"
  }
}

module "tags_workers" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git"
  namespace   = var.name
  environment = "dev"
  name        = "workers-chaosengineers"
  delimiter   = "_"

  tags = {
    owner = var.name
    project = var.project
    env = "dev"
    workspace = "shiro-labs"
    comments  = "workers"
  }
}

resource "aws_vpc" "k8s_lab" {
  cidr_block           = "10.0.0.0/16"
  tags                 = module.tags_bastian.tags
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "lab_gateway" {
  vpc_id = aws_vpc.k8s_lab.id
  tags   = module.tags_bastian.tags
}

resource "aws_route" "lab_internet_access" {
  route_table_id         = aws_vpc.k8s_lab.main_route_table_id
  gateway_id             = aws_internet_gateway.lab_gateway.id
  destination_cidr_block = "0.0.0.0/0"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "bastian" {
  vpc_id                  = aws_vpc.k8s_lab.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags                    = module.tags_bastian.tags
}

resource "aws_subnet" "control_plane" {
  vpc_id                  = aws_vpc.k8s_lab.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags                    = module.tags_control_plane.tags
}

resource "aws_subnet" "workers" {
  vpc_id                  = aws_vpc.k8s_lab.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags                    = module.tags_workers.tags
}

variable "ing" {
  type = list(any)
  default = [
    { from = 80, to = 80 },
    { from = 8080, to = 8080 },
    { from = 443, to = 443 },
    { from = 22, to = 22 },
  ]
}

resource "aws_security_group" "bastian" {
  vpc_id = aws_vpc.k8s_lab.id
  tags   = module.tags_bastian.tags

  dynamic "ingress" {
    for_each = var.ing
    content {
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = ingress.value.from
      to_port     = ingress.value.to
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "control_plane" {
  vpc_id = aws_vpc.k8s_lab.id
  tags   = module.tags_control_plane.tags

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    security_groups = [aws_security_group.bastian.id]
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    security_groups = [aws_security_group.bastian.id]
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    security_groups = [aws_security_group.bastian.id]
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 6443
    to_port     = 6443
    security_groups = [aws_security_group.workers.id]
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 10250
    to_port     = 10250
    security_groups = [aws_security_group.workers.id]
  }

  ingress {
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8472
    to_port     = 8472
    security_groups = [aws_security_group.workers.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "workers" {
  vpc_id = aws_vpc.k8s_lab.id
  tags   = module.tags_workers.tags

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    security_groups = [aws_security_group.bastian.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "bastian" {
  key_name   = format("%s%s", var.name, "_keypair_bastian")
  public_key = file(var.public_key_path)
}

resource "aws_key_pair" "control_plane" {
  key_name   = format("%s%s", var.name, "_keypair_control_plane")
  public_key = file(var.public_key_path)
}

resource "aws_key_pair" "workers" {
  key_name   = format("%s%s", var.name, "_keypair_workers")
  public_key = file(var.public_key_path)
}

data "aws_ami" "latest_bastian" {
  most_recent = true
  owners      = ["self"]
  name_regex  = "^${var.name}-sandbox-\\d*$"

  filter {
    name   = "name"
    values = ["${var.name}-sandbox-*"]
  }
}

data "aws_ami" "latest_control_plane" {
  most_recent = true
  owners      = ["self"]
  name_regex  = "^${var.name}-sandbox-\\d*$"

  filter {
    name   = "name"
    values = ["${var.name}-sandbox-*"]
  }
}

data "aws_ami" "latest_workers" {
  most_recent = true
  owners      = ["self"]
  name_regex  = "^${var.name}-sandbox-\\d*$"

  filter {
    name   = "name"
    values = ["${var.name}-sandbox-*"]
  }
}

resource "aws_instance" "bastian" {
  ami                    = data.aws_ami.latest_bastian.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.bastian.id
  vpc_security_group_ids = [aws_security_group.bastian.id]
  key_name               = aws_key_pair.bastian.id

  root_block_device {
    volume_size = 100
    volume_type = "gp2"
  }

  tags = module.tags_bastian.tags
}

resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.latest_control_plane.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.control_plane.id
  vpc_security_group_ids = [aws_security_group.control_plane.id]
  key_name               = aws_key_pair.control_plane.id

  root_block_device {
    volume_size = 100
    volume_type = "gp2"
  }

  tags = module.tags_control_plane.tags
}

resource "aws_route53_zone" "main" {
  name = "k3s.lab"
}

resource "aws_route53_record" "control_plane" {
  zone_id = aws_route53_zone.main.zone_id
  name    = format("%s.%s", "control_plane", aws_route53_zone.main.zone_id)
  type    = "A"
  ttl     = "300"
  records = [aws_instance.control_plane.private_ip]
}

resource "aws_launch_configuration" "workers" {
  name            = "workers"
  image_id        = data.aws_ami.latest_workers.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.workers.id]
}  

resource "aws_autoscaling_group" "workers" {
  name                      = "workers"
  max_size                  = 5
  min_size                  = 3
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 3
  force_delete              = true
  vpc_zone_identifier       = [aws_subnet.workers.id]
  launch_configuration      = aws_launch_configuration.workers.name

  tag {
    key = "owner"
    value = var.owner
    propagate_at_launch = true
  }

  tag {
    key = "name"
    value = var.name
    propagate_at_launch = true
  }

  tag {
    key = "project"
    value = var.project
    propagate_at_launch = true
  }

  tag {
    key = "env"
    value = "dev"
    propagate_at_launch = true
  }

  tag {
    key = "workspace"
    value = "shiro-labs"
    propagate_at_launch = true
  }

  tag {
    key = "comments"
    value = "worker"
    propagate_at_launch = true
  }

}


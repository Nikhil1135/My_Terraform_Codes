provider "aws" {
  region = "us-east-1"
}


# Data block generally allows you to fetch information about existing infracture in your Acccount

# Adding a default VPC form your Account
data "aws_vpc" "default" {
  default = true
}

# Generates Default subnet in AZ 
data "aws_subnets" "default" {
  filter {
    name   = "default-for-az"
    values = ["true"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
}


# to use one of the subnet ID
locals {
  default_subnet_ids = data.aws_subnets.default.ids
}

# Security Groups for Web Servers
resource "aws_security_group" "web_sg" {
  vpc_id = data.aws_vpc.default.id

ingress {
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = [ "0.0.0.0/0" ]
}
egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = [ "0.0.0.0/0" ]

}
}

# Creating a Launch Template for the EC2 Template
resource "aws_launch_template" "webapp" {
name_prefix = "webapp-lt"
image_id = "ami-0f88e80871fd81e91"
instance_type = "t2.micro"

user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install nginx1 -y
    systemctl start nginx
    systemctl enable nginx
  EOF
  )
  vpc_security_group_ids = [ aws_security_group.web_sg.id ]

}

# Now we need to create an Application load balancer
resource "aws_lb" "alb" {
  name = "webapp-alb"
  load_balancer_type = "application"
  security_groups = [ aws_security_group.web_sg.id]
  subnets = local.default_subnet_ids
}

# We need to create a target group now
resource "aws_lb_target_group" "tg" {
  name = "webapp-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

 health_check {
   path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
 }
}

# Now Attach the Target group to Load balancer via a Listerner
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn

  }
  
}

# Creating an ASG now
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity = 2
  min_size = 1
  max_size = 3
  vpc_zone_identifier = local.default_subnet_ids
  target_group_arns = [ aws_lb_target_group.tg.arn ]
  launch_template {
    id = aws_launch_template.webapp.id
    version = "$Latest"
  }

  health_check_type = "ELB"
  force_delete = "true"
  wait_for_capacity_timeout = "0"
}


output "default_subnet_ids" {
  value = local.default_subnet_ids
}



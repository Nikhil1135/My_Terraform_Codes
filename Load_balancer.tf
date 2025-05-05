provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-allow-alb"
  description = "Allow HTTP from ALB"
  vpc_id      = "vpc-0b481d5e95f20bc36"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["sg-0e3fdc5ae1ef0deae"] # ALB's SG
  }
    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_instance" "name" {
  count         = 2

  instance_type = "t2.micro"
  ami           = "ami-0f88e80871fd81e91"
  tags = {
    Name = "InstanceLB-${count.index + 1}"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo yum install -y httpd
              echo "Hello from EC2 instance 1" > /var/www/html/index.html
              sudo systemctl start httpd
              sudo systemctl enable httpd
              EOF

  vpc_security_group_ids = [ aws_security_group.ec2_sg.id ]
}

resource "aws_lb" "name" {
  name               = "Load-balancer-new"
  load_balancer_type = "application"
  security_groups    = ["sg-0e3fdc5ae1ef0deae"]
  subnets            = ["subnet-0351f6a265b614393", "subnet-08de5db284572d81d", "subnet-0f705a1bbbe9695d7"]
}

resource "aws_lb_target_group" "name" {
  name     = "target-group-2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-0b481d5e95f20bc36"

    health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

}


resource "aws_lb_target_group_attachment" "name" {
  count            = length(aws_instance.name)
  target_group_arn = aws_lb_target_group.name.arn
  target_id        = aws_instance.name[count.index].id
  port             = 80
}

resource "aws_lb_listener" "name" {
  load_balancer_arn = aws_lb.name.arn
  port = "80"
  protocol = "HTTP"
  

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.name.arn
  }
}

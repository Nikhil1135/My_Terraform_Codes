provider "aws" {
  region = "us-east-1"
}

resource "aws_launch_template" "template1" {
  name_prefix   = "cloudinstitution"
  image_id      =  var.ami_id # "ami-0e449927258d45bc4"
  instance_type =  "t2.micro"

}

variable "ami_id" {
  type =string
  default  = "ami-0e449927258d45bc4"

}

resource "aws_autoscaling_group" "asg1" {
  name                =  "${"local.common_name"}-asg1"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4
  vpc_zone_identifier = ["subnet-0351f6a265b614393", "subnet-08de5db284572d81d"]
  launch_template {
    id      = aws_launch_template.template1.id
    version = "$Latest"
  }
}

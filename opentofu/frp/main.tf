module "tag" {
  source = "github.com/harik8/tofu-modules//modules/tag?ref=main"

  description = var.tags.description
  utilization = var.tags.utilization
  workload    = var.tags.workload
  owner       = var.tags.owner
}

resource "aws_instance" "frp" {
  ami                         = data.aws_ami.main.id
  instance_type               = "t4g.nano"
  subnet_id                   = data.terraform_remote_state.vpc.outputs.vpc["public_subnets"][0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.frp.id]
  source_dest_check           = false

  user_data = file("user_data.tpl")

  root_block_device {
    volume_type = "gp3"
    encrypted   = true

    tags = module.tag.default_tags
  }

  iam_instance_profile = aws_iam_instance_profile.frp.name

  tags = module.tag.default_tags
}

resource "aws_iam_role" "frp" {
  name = module.tag.default_tags["Name"]

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [aws_iam_policy.assume_route53.arn, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]

  tags = module.tag.default_tags
}

resource "aws_iam_policy" "assume_route53" {
  name = "${module.tag.default_tags["Name"]}-assume-route53"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "sts:AssumeRole"
        Effect   = "Allow"
        Resource = "arn:aws:iam::212104571535:role/service-role/r53-role-g7qf0ica"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "frp" {
  name = module.tag.default_tags["Name"]
  role = aws_iam_role.frp.name
}

resource "aws_security_group" "frp" {
  name   = module.tag.default_tags["Name"]
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc["vpc_id"]

  tags = module.tag.default_tags
}

resource "aws_security_group_rule" "http" {
  type              = "ingress"
  security_group_id = aws_security_group.frp.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
}

resource "aws_security_group_rule" "https" {
  type              = "ingress"
  security_group_id = aws_security_group.frp.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
}

resource "aws_security_group_rule" "frps" {
  type              = "ingress"
  security_group_id = aws_security_group.frp.id
  cidr_blocks       = ["188.89.69.73/32"]
  from_port         = 7000
  to_port           = 7000
  protocol          = "TCP"
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  security_group_id = aws_security_group.frp.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}
resource "aws_autoscaling_group" "this" {
  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  name = var.tags.name

  vpc_zone_identifier = var.subnet_ids

  min_size         = 1
  desired_capacity = 1
  max_size         = 2

  health_check_grace_period = 60
  # terminate and replace instances in small batches
  instance_refresh {
    strategy = "Rolling"
  }

  enabled_metrics = [
    "GroupInServiceInstances",
    "GroupTotalInstances",
  ]

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}


locals {
  cloud_config_template_variables = {
    packages = [],
    runcmds  = [
      "echo Associating eipalloc ${aws_eip.this.id} with myself..",
      "aws ec2 associate-address --instance-id $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --allocation-id ${aws_eip.this.id} --region ${data.aws_region.this.name}",

      # TODO fix this to use IMDSv2. cloud-init fails with "failed to shellify" (see /var/run/cloud-init/result.json)
      # "TOKEN=`curl -X PUT \"http://169.254.169.254/latest/api/token\" -H \"X-aws-ec2-metadata-token-ttl-seconds: 21600\"`",
      # "INSTANCE_ID=`curl -H \"X-aws-ec2-metadata-token: $TOKEN\" -v http://169.254.169.254/latest/meta-data/instance-id`",
      # "aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${aws_eip.this.id} --region ${data.aws_region.this.name}",
    ],
    users = var.users
  }
}
# render the cloud-init template
data "cloudinit_config" "config" {
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/cloud-init.yml", local.cloud_config_template_variables)
  }
}


resource "aws_launch_template" "this" {
  credit_specification {
    cpu_credits = "standard"
  }

  name          = var.tags.name
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  update_default_version = true
  instance_initiated_shutdown_behavior = "terminate"

  monitoring {
    enabled = true
  }

  network_interfaces {
    security_groups             = concat([aws_security_group.this.id], var.additional_security_group_ids)
    associate_public_ip_address = true
    delete_on_termination       = true
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }

  user_data = data.cloudinit_config.config.rendered
}
# elastic IP
resource "aws_eip" "this" {
  tags = merge({ Purpose = "ssh" }, var.tags)
}

resource "aws_security_group" "this" {
  vpc_id      = var.vpc_id
  name        = "${var.tags.name}-instances"
  description = "${var.tags.name} instances"

  tags = var.tags
}
# egress 443 needed by SSM
resource "aws_security_group_rule" "egress_by_default" {
  for_each = {
    http : 80
    https : 443
  }

  security_group_id = aws_security_group.this.id
  description       = "rules allowing to reach aws APIs and apt repos"

  type      = "egress"
  protocol  = "tcp"
  from_port = each.value
  to_port   = each.value

  cidr_blocks = [
    "0.0.0.0/0",
  ]
}

# TODO:
#resource "aws_security_group_rule" "egress_to_db" {
#  count = var.allow_egress_to_security_group_ids_and_port_count
#
#  security_group_id = aws_security_group.this.id
#
#  type      = "egress"
#  protocol  = "tcp"
#  from_port = values(var.allow_egress_to_security_group_ids_and_port)[count.index]
#  to_port   = values(var.allow_egress_to_security_group_ids_and_port)[count.index]
#
#  source_security_group_id = keys(var.allow_egress_to_security_group_ids_and_port)[count.index]
#}

resource "aws_security_group_rule" "ingress" {
  count = length(var.source_ip_cidrs) > 0 ? 1:0

  security_group_id = aws_security_group.this.id
  description       = "allow extra ingress cidr ranges"

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = var.source_ip_cidrs
}

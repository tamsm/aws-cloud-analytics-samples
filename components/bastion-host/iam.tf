resource "aws_iam_instance_profile" "this" {
  name = "${var.tags.name}-${data.aws_region.this.name}"
  role = aws_iam_role.this.id
}

resource "aws_iam_role" "this" {
  name               = "${var.tags.name}-${data.aws_region.this.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    sid     = "assumeEC2Role"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "eip" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.eip.arn
}

resource "aws_iam_policy" "eip" {
  name   = "${var.tags.name}-${data.aws_region.this.name}-eip"
  policy = data.aws_iam_policy_document.eip.json
}

data "aws_iam_policy_document" "eip" {
  statement {
    resources = ["*"]
    actions = [
      "ec2:AssociateAddress"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


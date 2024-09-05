
resource "aws_kms_key" "this" {
  description             = "instance default customer master key"
  is_enabled = true
}


resource "aws_kms_alias" "this" {
  name          = "alias/${var.tags.stage}-${var.tags.instance}-key"
  target_key_id = aws_kms_key.this.key_id
}



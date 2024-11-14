output "security_group_id" {
  value = aws_security_group.this.id
}

output "elastic_ip" {
  value = aws_eip.this.public_ip
}

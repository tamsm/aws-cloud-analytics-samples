################################################################################
# Cluster
################################################################################

output "aws_redshiftserverless_namespace_id" {
  description = "The Redshift cluster ARN"
  value       = try(aws_redshiftserverless_namespace.serverless.id, null)
}

output "aws_redshiftserverless_namespace_arn" {
  description = "The Redshift cluster ARN"
  value       = try(aws_redshiftserverless_namespace.serverless.arn, null)
}


#output "cluster_hostname" {
#  description = "The hostname of the Redshift cluster"
#  value = replace(
#  try(aws_redshift_cluster.this[0].endpoint, ""),
#  format(":%s", try(aws_redshift_cluster.this[0].port, "")),
#  "",
#  )
#}

output "aws_redshiftserverless_workgroup_id" {
  description = "Id of the Redshift Serverless Workgroup."
  value       = try(aws_redshiftserverless_workgroup.serverless.id, null)
}

output "aws_redshiftserverless_workgroup_arn" {
  description = "ARN of the Redshift Serverless Workgroup."
  value       = try(aws_redshiftserverless_workgroup.serverless.arn, null)
}

output "aws_redshiftserverless_client_sg" {
  description = "Id of the Redshift Serverless Workgroup."
  value       = try(aws_security_group.redshift_client.id, null)
}

output "aws_redshiftserverless_client_sg_arn" {
  description = "ARN of the Redshift Serverless Workgroup."
  value       = try(aws_security_group.redshift_client.arn, null)
}

output "aws_redshiftserverless_server_sg" {
  description = "Id of the Redshift Serverless Workgroup."
  value       = try(aws_security_group.redshift_server.id, null)
}

# Output the Redshift Serverless endpoint
output "redshift_serverless_endpoint" {
  value = aws_redshiftserverless_endpoint_access.serverless.endpoint_name
}

output "redshift_serverless_cluster_id" {
  value = aws_redshiftserverless_workgroup.serverless.workgroup_name
}

output "redshift_serverless_hostname" {
  value = aws_redshiftserverless_endpoint_access.serverless.address
}

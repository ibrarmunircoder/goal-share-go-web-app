output "ecs_node_sg_id" {
  value = aws_security_group.ecs_node_sg.id
}

output "task_definition_family" {
  value = aws_ecs_task_definition.this.family
}

output "migration_task_definition_family" {
  value = aws_ecs_task_definition.run_migration.family
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.this.name
}
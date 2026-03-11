output "task_definition_family" {
  value = module.cluser.task_definition_family
}
output "migration_task_definition_family" {
  value = module.cluser.migration_task_definition_family
}

output "cluster_name" {
  value = module.cluser.cluster_name
}

output "container_name" {
  value = module.cluser.container_name
}

output "service_name" {
  value = module.cluser.service_name
}
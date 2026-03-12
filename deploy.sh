#!/bin/bash
set -euo pipefail

cat > overrides.txt <<EOF
{
  "containerOverrides": [
    {
      "name": "${CONTAINER_NAME}",
      "command": ["goose", "-dir", "migrations", "up"]
    }
  ]
}
EOF

TASK_ARN=$(aws ecs run-task \
	--cluster "${CLUSTER_NAME}" \
	--launch-type EC2 \
	--overrides file://overrides.txt \
	--task-definition "${MIGRATION_TASK_DEFINITION_FAMILY}" | jq -r '.tasks[0].taskArn')

echo "Running task: ${TASK_ARN}"

aws ecs wait tasks-stopped \
    --cluster "${CLUSTER_NAME}" \
    --tasks "${TASK_ARN}"

EXIT_CODE=$(aws ecs describe-tasks \
    --cluster "${CLUSTER_NAME}" \
    --tasks "${TASK_ARN}" | jq -r '.tasks[0].containers[0].exitCode')

if [ "$EXIT_CODE" -ne 0 ]; then
    echo "Task failed with exit code: $EXIT_CODE"
    exit 1
fi

echo "Task completed successfully with exit code: $EXIT_CODE"

rm -f overrides.txt exit_code.txt

echo "Updating ECS service to use the latest task definition..."



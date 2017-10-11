#!/bin/sh -e

# register task-definition
aws ecs register-task-definition --cli-input-json file://td-teamcity-server.json > REGISTERED_TASKDEF.json
TASKDEFINITION_ARN=$( < REGISTERED_TASKDEF.json jq .taskDefinition.taskDefinitionArn )

# create or update service
sed "s,@@TASKDEFINITION_ARN@@,$TASKDEFINITION_ARN," <service-$1-teamcity-server.json >SERVICEDEF.json
aws ecs $1-service --cli-input-json file://SERVICEDEF.json | tee SERVICE.json

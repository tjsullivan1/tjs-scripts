#!/bin/bash
# 
# Copyright (c) Tim Sullivan. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.
# 
# Creates a series of linked tasks for creating a new ARM template and maps them to a user story.
# User story must conform to the name "Create ARM Template for <arm_resource>" for the story name variable to work correctly. 

# Print a message if user fails to input an argument.  
: ${1?"Usage: $0 ARGUMENT"} 

# """ <- For some reason my code syntax highlighter is not liking line 5... this is a bad workaround to that. 
# Set variables for this project.
story_id=$1
organization_url='https://dev.azure.com/<YOUR_ORGANIZATION_NAME>/'
project_name=<YOUR_PROJECT_NAME>

# Get the name of the ARM Template we are currently building.
story_name=`az boards work-item show --org $organization_url --id $story_id | jq '.fields."System.Title"' | awk -F'for ' '{print $2}' | sed 's/\"//'`

# Create the known tasks for an ARM template creation
arm_id=`az boards work-item create --project $project_name --org $organization_url --type 'Task' --title "Create ARM Template for $story_name" | jq .id`
params_id=`az boards work-item create --project $project_name --org $organization_url --type 'Task' --title "Create Params File for $story_name" | jq .id`
pipeline_id=`az boards work-item create --project $project_name --org $organization_url --type 'Task' --title "Add $story_name to Pipeline " | jq .id`
pester_id=`az boards work-item create --project $project_name --org $organization_url --type 'Task' --title "Add Pester Tests for templates for $story_name" | jq .id`

# Create the links between these items. They should all be children of the story with dependence built between them.
az boards work-item relation add --org $organization_url --id $story_id --relation-type child --target-id $arm_id,$params_id,$pipeline_id,$pester_id
az boards work-item relation add --org $organization_url --id $arm_id --relation-type successor --target-id $params_id
az boards work-item relation add --org $organization_url --id $params_id --relation-type successor --target-id $pipeline_id
az boards work-item relation add --org $organization_url --id $pipeline_id --relation-type successor --target-id $pester_id

#!/bin/bash

# Get All Tasks
curl -X GET http://146.190.199.15:31000/get/api/tasks

# Get Task (ID = 1)
curl -X GET http://146.190.199.15:31000/get/api/tasks/1

# Create Task
curl -X POST http://146.190.199.15:31000/post/api/tasks \
     -H "Content-Type: application/json" \
     -d '{
           "title": "Sacar la basura",
           "description": "Sacar la basura",
           "status": "IN_PROGRESS"
         }'

# Update Task (ID = 1)
curl -X PATCH http://146.190.199.15:31000/patch/api/tasks/1 \
     -H "Content-Type: application/json" \
     -d '{
           "title": "Sacar la basura otra vez",
           "description": "Sacar la basura",
           "status": "IN_PROGRESS"
         }'

# Delete Task (ID = 1)
curl -X DELETE http://146.190.199.15:31000/delete/api/tasks/1

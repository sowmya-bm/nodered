!/bin/bash

# API endpoint URL
base_url="http://127.0.0.1:1880/auth/token"
flow_url="http://127.0.0.1:1880/flow/5552519538b25231"

# Load env
. ./environment

# Function to get token
getToken() {
    data=$(
    cat << EOF
        {
        "username": "${NODE_RED_USER}",
        "password": "${NODE_RED_PASSWORD}",
        "client_id": "node-red-admin",
        "grant_type": "password",
        "scope": "*"
        }
EOF
    )

    local access_token_response=$(curl -X POST -H "Content-Type: application/json" -d "$data" "$base_url")
    access_token=$(echo "$access_token_response" | jq -r '.access_token')
}

# Function to get initial data
getInitialData() {
    local response=$(curl -s -H "Authorization: Bearer $access_token" "$flow_url")
    initial_data="$response"
}

# Function to update json
# Enables the HTTP nodes &
# set the auth token
updateNodes() {
    ALERT_TOKEN="$DJANGO_AUTH_TOKEN"
    updated_nodes=$(echo "$initial_data" | jq --arg auth_token "$ALERT_TOKEN" --argjson alert_names "$(printf '%s\n' "$@" | jq -R . | jq -s .)" '
        .nodes |= map(
            if .name | IN($alert_names[]) then
                del(.d)
                | .credentials = {"password": $auth_token}
            else
                .
            end
        )
    ')
}

# Function to make PUT request to Node-Red API
putData() {
    local put_response=$(curl -X PUT \
                -H "Authorization: Bearer $access_token" \
                -H "Content-Type: application/json" \
                -d "$updated_nodes" \
                "$flow_url"
            )
    echo "putData: $put_response"
}

# Main script execution
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <ALERT_NAME>..."
    exit 1
fi

# Get token & Initial Data
getToken
getInitialData

# Update nodes with provided alert names
updateNodes "$@"

# Put data
putData

# Display the API response
echo "Node-Red deployment successful"




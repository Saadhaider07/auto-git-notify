#!/bin/bash

# Load configuration
source config.cfg

# Function to calculate checksum
calculate_checksum() {
    find "$MONITOR_PATH" -type f -exec sha256sum {} \; | sha256sum
}

# Get initial checksum
prev_checksum=$(calculate_checksum)

echo "Monitoring directory: $MONITOR_PATH"

while true; do
    sleep 10  # Adjust polling interval if needed
    new_checksum=$(calculate_checksum)
    
    if [ "$prev_checksum" != "$new_checksum" ]; then
        echo "Changes detected! Committing and pushing changes..."
        prev_checksum=$new_checksum
        
        # Add, commit, and push changes
        cd "$REPO_PATH" || exit
        git add "$MONITOR_PATH"
        git commit -m "Auto-commit: Changes detected in $(basename "$MONITOR_PATH")"
        git push "$GIT_REMOTE" "$GIT_BRANCH"
        
        # Send email notification
        curl --request POST --url https://api.sendgrid.com/v3/mail/send \
            --header "Authorization: Bearer $SENDGRID_API_KEY" \
            --header "Content-Type: application/json" \
            --data '{
                "personalizations": [{
                    "to": [ {"email": "'"$COLLABORATORS"'"} ],
                    "subject": "Repository Update Notification"
                }],
                "from": {"email": "'"$SENDER_EMAIL"'"},
                "content": [{"type": "text/plain", "value": "Changes have been pushed to the repository."}]
            }'
    fi
done

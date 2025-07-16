#!/bin/bash

down() {
    local yml_files=($(find "$(pwd)" -maxdepth 2 -name "*.yaml"))

    # Check if any YAML files are found in the current folder.
    if [ ${#yml_files[@]} -eq 0 ]; then
        echo "No yml files found in the current folder."
        exit 1
    fi

    local output=""
    for file in "${yml_files[@]}"; do
        output=$(docker-compose -f "$file" down 2>&1)
        if [[ $output == *"No resource found to remove"* ]]; then
            echo "No compose files are running for $file."
        else
            echo "All compose-related containers are removed for $file."
        fi
    done
}

down

#!/bin/bash

# Remote Setup Script for AI Skills Depot
# Fetches skills directly from GitHub without needing to clone the repo.

set -e

# Configuration
REPO_OWNER="zidquocviet1"
REPO_NAME="ai-skills-depot"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH"
API_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/trees/$BRANCH?recursive=1"

# Colors for better UI
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${BLUE}===============================================${NC}"
echo -e "${GREEN}      🤖 AI Skills Depot Setup Script         ${NC}"
echo -e "${BLUE}===============================================${NC}"

# 1. Fetching skill list from GitHub API
echo -e "\n${BLUE}Step 1: Fetching available skills from GitHub...${NC}"
SKILL_PATHS=$(curl -s "$API_URL" | grep -o "roles/[^\"]*/SKILL.md")

if [ -z "$SKILL_PATHS" ]; then
    echo -e "${RED}Error: Could not fetch skill list from GitHub.${NC}"
    echo "Check your internet connection or repository permissions."
    exit 1
fi

# 2. Select Platform
echo -e "\n${BLUE}Step 2: Select your AI Platform${NC}"
platforms=("Antigravity (.agent/skills/)" "Cursor (.agent/skills/)" "Claude Code (.claude/skills/)" "Quit")
select platform in "${platforms[@]}"; do
    case $platform in
        "Antigravity (.agent/skills/)" | "Cursor (.agent/skills/)")
            target_base=".agent/skills"
            break ;;
        "Claude Code (.claude/skills/)")
            target_base=".claude/skills"
            break ;;
        "Quit")
            exit 0 ;;
        *) echo "Invalid option $REPLY" ;;
    esac
done

# 3. Select Role
echo -e "\n${BLUE}Step 3: Select Role(s) to install${NC}"
available_roles=$(echo "$SKILL_PATHS" | cut -d'/' -f2 | sort -u)
role_options=("All Roles" "Back")
for r in $available_roles; do role_options+=("$r"); done

select role_choice in "${role_options[@]}"; do
    if [ "$role_choice" == "Back" ]; then
        exec bash -c "$(curl -fsSL $BASE_URL/install.sh)" # Re-run from remote
    elif [ -n "$role_choice" ]; then
        break
    else
        echo "Invalid option $REPLY"
    fi
done

# 4. Resolve Skills
filtered_skills=()
if [ "$role_choice" == "All Roles" ]; then
    filtered_skills=($SKILL_PATHS)
else
    for path in $SKILL_PATHS; do
        if [[ $path == roles/$role_choice/* ]]; then
            filtered_skills+=("$path")
        fi
    done
fi

echo -e "\nFound ${GREEN}${#filtered_skills[@]}${NC} skills to install."

# 5. Perform Installation
for remote_path in "${filtered_skills[@]}"; do
    # Extract info
    role_path=${remote_path#roles/}      # e.g., backend/java/solid-principles/SKILL.md
    skill_dir=$(dirname "$role_path")    # e.g., backend/java/solid-principles
    skill_name=$(basename "$skill_dir")
    
    url="$BASE_URL/$remote_path"
    dest_dir="$target_base/$skill_dir"
    
    echo "Downloading $skill_name to ./$dest_dir/..."
    mkdir -p "$dest_dir"
    curl -sSL "$url" -o "$dest_dir/SKILL.md"
    
    # Check if there is a README in the remote directory
    # We can try to guess its existence by downloading it, silenty failing if 404
    readme_url="${url%SKILL.md}README.md"
    curl -sSL -f "$readme_url" -o "$dest_dir/README.md" 2>/dev/null || true
done

echo -e "\n${GREEN}Success!${NC} Skills installed to ${YELLOW}./$target_base${NC}"
echo "Happy coding! 🚀"

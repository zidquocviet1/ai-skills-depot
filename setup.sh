#!/bin/bash

# ai-skills-depot Setup Script
# Helps users install fine-tuned skills into their projects.

set -e

# Colors for better UI
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===============================================${NC}"
echo -e "${GREEN}      🤖 AI Skills Depot Setup Script         ${NC}"
echo -e "${BLUE}===============================================${NC}"

# Check if we are in the right directory
if [ ! -d "roles" ]; then
    echo -e "${RED}Error: 'roles' directory not found in current path.${NC}"
    echo "Please run this script from the root of the ai-skills-depot repository."
    exit 1
fi

# 1. Select Platform
echo -e "\n${BLUE}Step 1: Select your AI Platform${NC}"
platforms=("Antigravity (.agent/skills/)" "Cursor (.agent/skills/)" "Claude Code (.claude/skills/)" "Custom/Manual" "Quit")
select platform in "${platforms[@]}"; do
    case $platform in
        "Antigravity (.agent/skills/)")
            target_type="folder"
            target_base=".agent/skills"
            break
            ;;
        "Cursor (.agent/skills/)")
            # For Cursor, we'll use the .agent/skills path as requested
            target_type="folder"
            target_base=".agent/skills"
            break
            ;;
        "Claude Code (.claude/skills/)")
            target_type="folder"
            target_base=".claude/skills"
            break
            ;;
        "Custom/Manual")
            read -p "Enter target base path: " target_base
            target_type="folder"
            break
            ;;
        "Quit")
            exit 0
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done

# 2. Select Roles
echo -e "\n${BLUE}Step 2: Select Role(s) to install${NC}"
available_roles=$(find roles -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
role_options=("All Roles" "Back")
for r in $available_roles; do role_options+=("$r"); done

select role_choice in "${role_options[@]}"; do
    if [ "$role_choice" == "Back" ]; then
        exec bash "$0" # Restart script
    elif [ -n "$role_choice" ]; then
        break
    else
        echo "Invalid option $REPLY"
    fi
done

# 3. Destination Directory
echo -e "\n${BLUE}Step 3: Enter Target Project Directory${NC}"
read -p "Path to your project (default: .): " target_path
target_path=${target_path:-"."}

if [ ! -d "$target_path" ]; then
    echo -e "${YELLOW}Directory $target_path does not exist. Create it? (y/n)${NC}"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        mkdir -p "$target_path"
    else
        echo "Installation cancelled."
        exit 1
    fi
fi

# 4. Resolve Skills to Install
skills_to_install=()
if [ "$role_choice" == "All Roles" ]; then
    echo "Collecting all available skills..."
    while IFS= read -r skill_file; do
        skills_to_install+=("$skill_file")
    done < <(find roles -name "SKILL.md")
else
    echo "Collecting skills for role: $role_choice..."
    while IFS= read -r skill_file; do
        skills_to_install+=("$skill_file")
    done < <(find "roles/$role_choice" -name "SKILL.md")
fi

if [ ${#skills_to_install[@]} -eq 0 ]; then
    echo -e "${RED}No skills found for selection: $role_choice${NC}"
    exit 1
fi

echo -e "\nFound ${GREEN}${#skills_to_install[@]}${NC} skills to install."

# 5. Perform Installation
install_skill() {
    local source_file=$1
    local skill_dir=$(dirname "$source_file")
    local skill_name=$(basename "$skill_dir")
    local role_path=${skill_dir#roles/} # Remove 'roles/' prefix
    
    # Generic folder installation for all requested paths
    local dest_dir="$target_path/$target_base/$role_path"
    echo "Installing $skill_name to $dest_dir/..."
    mkdir -p "$dest_dir"
    cp -r "$skill_dir/"* "$dest_dir/"
}

for skill in "${skills_to_install[@]}"; do
    install_skill "$skill"
done

echo -e "\n${GREEN}Success!${NC} Skills installed to ${YELLOW}$target_path/${target_base}${NC}"
echo "Note: You might need to reload your editor or AI agent to apply changes."
echo "Happy coding! 🚀"

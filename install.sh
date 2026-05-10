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
GITMODULES_URL="$BASE_URL/.gitmodules"

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
SKILL_PATHS=$(curl -s "$API_URL" | grep -o "roles/[^\"]*/SKILL.md" || true)

if [ -z "$SKILL_PATHS" ]; then
    echo -e "${RED}Error: Could not fetch skill list from GitHub.${NC}"
    echo "Check your internet connection or repository permissions."
    exit 1
fi

fetch_submodules() {
    local gitmodules
    gitmodules=$(curl -sSL "$GITMODULES_URL" 2>/dev/null || true)

    submodule_names=()
    submodule_paths=()
    submodule_urls=()

    if [ -z "$gitmodules" ]; then
        return
    fi

    local current_name=""
    local current_path=""
    local current_url=""

    while IFS= read -r line; do
        case "$line" in
            \[submodule*)
                current_name=$(printf '%s' "$line" | sed -E 's/^\[submodule "([^"]+)"\]$/\1/')
                current_path=""
                current_url=""
                ;;
            *path\ =\ *)
                current_path=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*path = //')
                ;;
            *url\ =\ *)
                current_url=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*url = //')
                if [ -n "$current_path" ] && [ -n "$current_url" ]; then
                    submodule_names+=("${current_name:-$current_path}")
                    submodule_paths+=("$current_path")
                    submodule_urls+=("$current_url")
                fi
                ;;
        esac
    done <<< "$gitmodules"
}

github_owner_repo_from_url() {
    local url=$1
    local owner_repo
    owner_repo=$(printf '%s' "$url" | sed -E 's#.*github.com[:/]([^/]+/.+)$#\1#')
    owner_repo=${owner_repo%.git}
    printf '%s' "$owner_repo"
}

github_default_branch() {
    local owner_repo=$1
    local branch
    branch=$(curl -s "https://api.github.com/repos/$owner_repo" | grep -o '"default_branch"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed -E 's/.*"([^"]+)"/\1/' || true)
    printf '%s' "${branch:-main}"
}

github_skill_paths() {
    local owner_repo=$1
    local branch=$2
    curl -s "https://api.github.com/repos/$owner_repo/git/trees/$branch?recursive=1" \
        | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*/\?SKILL.md"' \
        | sed -E 's/.*"path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
        || true
}

select_submodules() {
    selected_submodule_indexes=()

    if [ ${#submodule_names[@]} -eq 0 ]; then
        echo -e "${YELLOW}No git submodules found in this repository.${NC}"
        return
    fi

    echo -e "\nAvailable skill submodules:"
    for i in "${!submodule_names[@]}"; do
        printf "  %d) %s (%s)\n" "$((i + 1))" "${submodule_names[$i]}" "${submodule_urls[$i]}"
    done

    echo -e "${YELLOW}Enter submodule numbers separated by spaces, or 'a' for all:${NC}"
    read -r module_choices

    if [[ "$module_choices" =~ ^[Aa]$ ]]; then
        for i in "${!submodule_names[@]}"; do
            selected_submodule_indexes+=("$i")
        done
        return
    fi

    for choice in $module_choices; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#submodule_names[@]}" ]; then
            selected_submodule_indexes+=("$((choice - 1))")
        else
            echo -e "${YELLOW}Skipping invalid submodule selection: $choice${NC}"
        fi
    done
}

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

# 4. Select Submodule Skill Collections
fetch_submodules
install_submodule_skills="n"
selected_submodule_indexes=()

if [ ${#submodule_names[@]} -gt 0 ]; then
    echo -e "\n${BLUE}Step 4: Install skills from git submodules?${NC}"
    echo -e "Found ${GREEN}${#submodule_names[@]}${NC} skill submodule collection(s)."
    read -p "Do you want to install skills from submodules too? (y/n): " install_submodule_skills

    if [[ "$install_submodule_skills" =~ ^[Yy]$ ]]; then
        select_submodules
    fi
fi

# 5. Resolve Skills
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

submodule_skills=()
if [[ "$install_submodule_skills" =~ ^[Yy]$ ]] && [ ${#selected_submodule_indexes[@]} -gt 0 ]; then
    echo -e "\n${BLUE}Scanning selected submodules for SKILL.md files...${NC}"

    for module_index in "${selected_submodule_indexes[@]}"; do
        module_name="${submodule_names[$module_index]}"
        module_path="${submodule_paths[$module_index]}"
        module_slug=$(basename "$module_path")
        module_url="${submodule_urls[$module_index]}"
        owner_repo=$(github_owner_repo_from_url "$module_url")

        if [[ ! "$owner_repo" =~ ^[^/]+/[^/]+$ ]]; then
            echo -e "${YELLOW}Skipping $module_name: only GitHub submodule URLs are supported by the remote installer.${NC}"
            continue
        fi

        module_branch=$(github_default_branch "$owner_repo")
        module_skill_paths=$(github_skill_paths "$owner_repo" "$module_branch")

        if [ -z "$module_skill_paths" ]; then
            echo -e "${YELLOW}No SKILL.md files found in $module_name.${NC}"
            continue
        fi

        while IFS= read -r skill_path; do
            submodule_skills+=("$module_slug|$owner_repo|$module_branch|$skill_path")
        done <<< "$module_skill_paths"

        echo -e "Found ${GREEN}$(printf '%s\n' "$module_skill_paths" | sed '/^$/d' | wc -l | tr -d ' ')${NC} skills in $module_name."
    done
fi

echo -e "\nFound ${GREEN}${#filtered_skills[@]}${NC} repo skills to install."
if [ ${#submodule_skills[@]} -gt 0 ]; then
    echo -e "Found ${GREEN}${#submodule_skills[@]}${NC} submodule skills to install."
fi

# 6. Perform Installation
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

for skill_spec in "${submodule_skills[@]}"; do
    IFS='|' read -r module_name owner_repo module_branch remote_path <<< "$skill_spec"
    skill_dir=$(dirname "$remote_path")
    skill_name=$(basename "$skill_dir")

    if [ "$skill_dir" == "." ]; then
        install_path="$module_name"
        skill_name="$module_name"
    else
        install_path=${skill_dir#skills/}
        install_path="$module_name/$install_path"
    fi

    url="https://raw.githubusercontent.com/$owner_repo/$module_branch/$remote_path"
    dest_dir="$target_base/$install_path"

    echo "Downloading $module_name/$skill_name to ./$dest_dir/..."
    mkdir -p "$dest_dir"
    curl -sSL "$url" -o "$dest_dir/SKILL.md"

    readme_url="${url%SKILL.md}README.md"
    curl -sSL -f "$readme_url" -o "$dest_dir/README.md" 2>/dev/null || true
done

echo -e "\n${GREEN}Success!${NC} Skills installed to ${YELLOW}./$target_base${NC}"
echo "Happy coding! 🚀"

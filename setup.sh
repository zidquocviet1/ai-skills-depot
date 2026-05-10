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

load_skill_aliases() {
    skill_aliases_json=""

    if [ -f "skill-aliases.json" ]; then
        skill_aliases_json=$(cat skill-aliases.json)
    fi
}

submodule_alias_for() {
    local module_path=$1
    local module_slug
    module_slug=$(basename "$module_path")

    if [ -z "$skill_aliases_json" ]; then
        printf '%s' "$module_slug"
        return
    fi

    local alias
    alias=$(printf '%s\n' "$skill_aliases_json" \
        | awk -v key="$module_path" '
            $0 ~ "^[[:space:]]*\"" key "\"[[:space:]]*:" {
                sub(/^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*"/, "")
                sub(/".*$/, "")
                print
                exit
            }
        ')

    if [ -z "$alias" ]; then
        alias=$(printf '%s\n' "$skill_aliases_json" \
            | awk -v key="$module_slug" '
                $0 ~ "^[[:space:]]*\"" key "\"[[:space:]]*:" {
                    sub(/^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*"/, "")
                    sub(/".*$/, "")
                    print
                    exit
                }
            ')
    fi

    printf '%s' "${alias:-$module_slug}"
}

prefix_skill_name_in_file() {
    local skill_file=$1
    local alias=$2

    if [ -z "$alias" ] || [ ! -f "$skill_file" ]; then
        return
    fi

    local tmp_file="${skill_file}.tmp"
    awk -v alias="$alias" '
        BEGIN { in_frontmatter = 0; updated = 0 }
        NR == 1 && $0 == "---" { in_frontmatter = 1 }
        in_frontmatter && !updated && /^name:[[:space:]]*/ {
            name = $0
            sub(/^name:[[:space:]]*/, "", name)
            gsub(/^"|"$/, "", name)
            gsub(/^'\''|'\''$/, "", name)
            if (name !~ "^" alias ":") {
                print "name: " alias ":" name
                updated = 1
                next
            }
        }
        in_frontmatter && NR > 1 && $0 == "---" { in_frontmatter = 0 }
        { print }
    ' "$skill_file" > "$tmp_file"
    mv "$tmp_file" "$skill_file"
}

load_submodules() {
    submodule_names=()
    submodule_paths=()

    if [ ! -f ".gitmodules" ]; then
        return
    fi

    local current_name=""
    local current_path=""

    while IFS= read -r line; do
        case "$line" in
            \[submodule*)
                current_name=$(printf '%s' "$line" | sed -E 's/^\[submodule "([^"]+)"\]$/\1/')
                current_path=""
                ;;
            *path\ =\ *)
                current_path=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*path = //')
                if [ -n "$current_path" ]; then
                    submodule_names+=("${current_name:-$current_path}")
                    submodule_paths+=("$current_path")
                fi
                ;;
        esac
    done < ".gitmodules"
}

select_submodules() {
    selected_submodule_indexes=()

    if [ ${#submodule_names[@]} -eq 0 ]; then
        echo -e "${YELLOW}No git submodules found in this repository.${NC}"
        return
    fi

    echo -e "\nAvailable skill submodules:"
    for i in "${!submodule_names[@]}"; do
        printf "  %d) %s\n" "$((i + 1))" "${submodule_names[$i]}"
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

# 3. Select Submodule Skill Collections
load_skill_aliases
load_submodules
install_submodule_skills="n"
selected_submodule_indexes=()

if [ ${#submodule_names[@]} -gt 0 ]; then
    echo -e "\n${BLUE}Step 3: Install skills from git submodules?${NC}"
    echo -e "Found ${GREEN}${#submodule_names[@]}${NC} skill submodule collection(s)."
    read -p "Do you want to install skills from submodules too? (y/n): " install_submodule_skills

    if [[ "$install_submodule_skills" =~ ^[Yy]$ ]]; then
        select_submodules
    fi
fi

# 4. Destination Directory
echo -e "\n${BLUE}Step 4: Enter Target Project Directory${NC}"
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

# 5. Resolve Skills to Install
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

submodule_skills_to_install=()
if [[ "$install_submodule_skills" =~ ^[Yy]$ ]] && [ ${#selected_submodule_indexes[@]} -gt 0 ]; then
    echo "Scanning selected submodules for SKILL.md files..."

    for module_index in "${selected_submodule_indexes[@]}"; do
        module_path="${submodule_paths[$module_index]}"

        if [ ! -d "$module_path" ]; then
            echo -e "${YELLOW}Skipping ${submodule_names[$module_index]}: directory $module_path is not initialized.${NC}"
            echo "Run: git submodule update --init --recursive $module_path"
            continue
        fi

        while IFS= read -r skill_file; do
            submodule_skills_to_install+=("$module_path|$skill_file")
        done < <(find "$module_path" -name "SKILL.md")
    done
fi

if [ ${#skills_to_install[@]} -eq 0 ] && [ ${#submodule_skills_to_install[@]} -eq 0 ]; then
    echo -e "${RED}No skills found for selection: $role_choice${NC}"
    exit 1
fi

echo -e "\nFound ${GREEN}${#skills_to_install[@]}${NC} repo skills to install."
if [ ${#submodule_skills_to_install[@]} -gt 0 ]; then
    echo -e "Found ${GREEN}${#submodule_skills_to_install[@]}${NC} submodule skills to install."
fi

# 6. Perform Installation
install_skill() {
    local source_file=$1
    local skill_dir=$(dirname "$source_file")
    local skill_name=$(basename "$skill_dir")
    
    local dest_dir="$target_path/$target_base/$skill_name"
    echo "Installing $skill_name to $dest_dir/..."
    mkdir -p "$dest_dir"
    cp -r "$skill_dir/"* "$dest_dir/"
}

install_submodule_skill() {
    local module_path=$1
    local source_file=$2
    local module_alias
    module_alias=$(submodule_alias_for "$module_path")
    local skill_dir=$(dirname "$source_file")
    local skill_name=$(basename "$skill_dir")

    if [ "$skill_dir" == "$module_path" ]; then
        skill_name=$(basename "$module_path")
    fi

    local dest_dir="$target_path/$target_base/$module_alias:$skill_name"

    echo "Installing $module_alias:$skill_name to $dest_dir/..."
    mkdir -p "$dest_dir"
    cp -r "$skill_dir/"* "$dest_dir/"
    prefix_skill_name_in_file "$dest_dir/SKILL.md" "$module_alias"
}

for skill in "${skills_to_install[@]}"; do
    install_skill "$skill"
done

for skill_spec in "${submodule_skills_to_install[@]}"; do
    IFS='|' read -r module_path skill_file <<< "$skill_spec"
    install_submodule_skill "$module_path" "$skill_file"
done

echo -e "\n${GREEN}Success!${NC} Skills installed to ${YELLOW}$target_path/${target_base}${NC}"
echo "Note: You might need to reload your editor or AI agent to apply changes."
echo "Happy coding! 🚀"

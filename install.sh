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
ALIASES_URL="$BASE_URL/skill-aliases.json"

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

fetch_skill_aliases() {
    skill_aliases_json=$(curl -sSL "$ALIASES_URL" 2>/dev/null || true)
}

submodule_alias_for() {
    local module_path=$1
    local module_slug
    module_slug=$(basename "$module_path")

    if [ -z "$skill_aliases_json" ]; then
        default_submodule_alias_for "$module_path"
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

    if [ -n "$alias" ]; then
        printf '%s' "$alias"
    else
        default_submodule_alias_for "$module_path"
    fi
}

default_submodule_alias_for() {
    local module_path=$1
    local module_slug
    module_slug=$(basename "$module_path")

    case "$module_path" in
        "collected/garrytan-gstack" | "garrytan-gstack")
            printf '%s' "gstack"
            ;;
        "collected/mattocock-skills" | "mattocock-skills")
            printf '%s' "mott"
            ;;
        *)
            printf '%s' "$module_slug"
            ;;
    esac
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

github_blob_paths_under() {
    local owner_repo=$1
    local branch=$2
    local source_dir=$3

    curl -s "https://api.github.com/repos/$owner_repo/git/trees/$branch?recursive=1" \
        | awk -v prefix="$source_dir/" '
            /"path"[[:space:]]*:/ {
                path = $0
                sub(/.*"path"[[:space:]]*:[[:space:]]*"/, "", path)
                sub(/".*/, "", path)
            }
            /"type"[[:space:]]*:[[:space:]]*"blob"/ {
                if (index(path, prefix) == 1) {
                    print path
                }
            }
        ' \
        || true
}

download_github_directory() {
    local owner_repo=$1
    local branch=$2
    local source_dir=$3
    local dest_dir=$4
    local raw_base="https://raw.githubusercontent.com/$owner_repo/$branch"
    local file_paths

    if [ "$source_dir" == "." ]; then
        mkdir -p "$dest_dir"
        curl -sSL "$raw_base/SKILL.md" -o "$dest_dir/SKILL.md"
        curl -sSL -f "$raw_base/README.md" -o "$dest_dir/README.md" 2>/dev/null || true
        return
    fi

    file_paths=$(github_blob_paths_under "$owner_repo" "$branch" "$source_dir")

    if [ -z "$file_paths" ]; then
        echo -e "${YELLOW}No files found under $source_dir in $owner_repo.${NC}"
        return
    fi

    mkdir -p "$dest_dir"

    while IFS= read -r file_path; do
        local relative_path=${file_path#"$source_dir"/}
        local dest_file="$dest_dir/$relative_path"

        mkdir -p "$(dirname "$dest_file")"
        curl -sSL "$raw_base/$file_path" -o "$dest_file"
    done <<< "$file_paths"
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
fetch_skill_aliases
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
        module_alias=$(submodule_alias_for "$module_path")
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
            submodule_skills+=("$module_alias|$owner_repo|$module_branch|$skill_path")
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
    skill_dir=$(dirname "$remote_path")    # e.g., roles/backend/java/solid-principles
    skill_name=$(basename "$skill_dir")
    dest_dir="$target_base/$skill_name"
    
    echo "Downloading $skill_name to ./$dest_dir/..."
    download_github_directory "$REPO_OWNER/$REPO_NAME" "$BRANCH" "$skill_dir" "$dest_dir"
done

for skill_spec in "${submodule_skills[@]}"; do
    IFS='|' read -r module_alias owner_repo module_branch remote_path <<< "$skill_spec"
    skill_dir=$(dirname "$remote_path")
    skill_name=$(basename "$skill_dir")

    if [ "$skill_dir" == "." ]; then
        skill_name=$(basename "$owner_repo")
    fi

    dest_dir="$target_base/$module_alias:$skill_name"

    echo "Downloading $module_alias:$skill_name to ./$dest_dir/..."
    download_github_directory "$owner_repo" "$module_branch" "$skill_dir" "$dest_dir"
    prefix_skill_name_in_file "$dest_dir/SKILL.md" "$module_alias"
done

echo -e "\n${GREEN}Success!${NC} Skills installed to ${YELLOW}./$target_base${NC}"
echo "Happy coding! 🚀"

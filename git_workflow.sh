#!/bin/bash

# Git Workflow Helper Script
# ---------------------------
# I created this because I got tired of having to type in repetitive steps and commands.
# This script streamlines common Git operations by providing an interactive menu to:
# 1. Create and push to new branches.
# 2. Update existing branches.
# 3. Push minor changes directly to the main branch.
# 4. Automatically manage SSH authentication for GitHub.
# 
# Features:
# - Handles multiple remotes and prompts for selection.
# - Ensures uncommitted changes are staged and committed before switching branches.
# - Adds color-coded output for better readability.
# - Checks for SSH key availability and starts the agent as needed.
#
# Perfect for developers working on multi-machine setups or large collaborative projects.

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Global variable for SSH key path
SSH_KEY_PATH=~/.ssh/github_key_virgil  # Replace this with your actual SSH key name

# Function to ensure SSH key is set up for GitHub
function setup_ssh_for_github() {
  if [[ -f "$SSH_KEY_PATH" ]]; then
    echo -e "${GREEN}[INFO] GitHub SSH key found: $SSH_KEY_PATH${NC}"
    if [[ -z "$SSH_AUTH_SOCK" ]]; then
      echo -e "${CYAN}[INFO] Starting the SSH agent...${NC}"
      eval "$(ssh-agent -s)" >/dev/null
    fi
    echo -e "${CYAN}[INFO] Adding the GitHub SSH key to the agent...${NC}"
    ssh-add "$SSH_KEY_PATH" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}[SUCCESS] SSH key added to the agent.${NC}"
    else
      echo -e "${RED}[ERROR] Failed to add SSH key to the agent.${NC}"
      exit 1
    fi
  else
    echo -e "${RED}[ERROR] No GitHub SSH key found at $SSH_KEY_PATH.${NC}"
    echo -e "${YELLOW}[INFO] Please create an SSH key for GitHub and place it at $SSH_KEY_PATH.${NC}"
    exit 1
  fi
}

# Ensure script is running inside a valid Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo -e "${RED}[ERROR]${NC} This script must be run inside a Git repository."
  exit 1
fi

# Run SSH setup at the start of the script
setup_ssh_for_github

# Function to select a remote if multiple remotes exist
function select_remote() {
  local remotes
  remotes=$(git remote)
  remotes_count=$(echo "$remotes" | wc -l)

  if [[ $remotes_count -gt 1 ]]; then
    echo -e "${CYAN}[INFO] Multiple remotes detected. Please select a remote:${NC}"
    PS3=$(echo -e "${CYAN}Select a remote: ${NC}")
    select remote in $remotes; do
      if [[ -n "$remote" ]]; then
        echo -e "${GREEN}[SUCCESS] Selected remote: $remote${NC}"
        selected_remote="$remote"
        break
      else
        echo -e "${RED}[ERROR] Invalid selection. Please try again.${NC}"
      fi
    done
  else
    selected_remote=$(git remote)
    echo -e "${GREEN}[INFO] Using the only remote detected: $selected_remote${NC}"
  fi
}

# Remaining script logic stays the same...


# Function to validate branch names
function validate_branch_name() {
  local branch_name="$1"
  if [[ ! "$branch_name" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
    echo -e "${RED}[ERROR] Invalid branch name '$branch_name'. Use only alphanumeric characters, '.', '_', '/', and '-'.${NC}"
    exit 1
  fi
}

# Function to check for unresolved merge conflicts
function check_for_conflicts() {
  local conflicts
  conflicts=$(git diff --name-only --diff-filter=U)
  if [[ -n "$conflicts" ]]; then
    echo -e "${RED}[ERROR] Unresolved merge conflicts detected in the following files:${NC}"
    echo "$conflicts"
    echo -e "${YELLOW}[WARNING] Please resolve the conflicts and try again.${NC}"
    exit 1
  fi
}

# Function to check for uncommitted changes
function check_clean_working_directory() {
  if [[ -n $(git status --porcelain) ]]; then
    echo -e "${YELLOW}[WARNING] Uncommitted changes detected. Staging and committing them now...${NC}"
    git add .
    git commit -m "Auto-save changes before switching branches" --quiet
    echo -e "${GREEN}[INFO] Changes committed.${NC}"
  fi
}

# Function to fetch and update the main branch
function update_main_branch() {
  echo -e "${CYAN}[INFO] Fetching the latest main branch...${NC}"
  git fetch "$selected_remote" main >/dev/null 2>&1
  git checkout main >/dev/null 2>&1 || git checkout -b main "$selected_remote"/main >/dev/null 2>&1
  git pull "$selected_remote" main --quiet
  echo -e "${GREEN}[INFO] Main branch updated.${NC}"
}

# Function to create a new branch
function create_new_branch() {
  read -p "Enter the name for the new branch: " branch_name
  validate_branch_name "$branch_name"
  git checkout -b "$branch_name" main >/dev/null 2>&1
  echo -e "${GREEN}[SUCCESS] New branch '$branch_name' created based on main.${NC}"
}

# Function to update an existing branch
function update_existing_branch() {
  echo -e "${CYAN}[INFO] Available branches:${NC}"
  git branch -r | grep "$selected_remote" | sed "s|$selected_remote/||" | sort | uniq
  read -p "Enter the name of the branch you want to update: " branch_name
  validate_branch_name "$branch_name"
  git checkout "$branch_name" >/dev/null 2>&1 || git checkout -b "$branch_name" "$selected_remote/$branch_name" >/dev/null 2>&1
  git pull "$selected_remote" "$branch_name" --quiet
  echo -e "${GREEN}[SUCCESS] Updated branch '$branch_name' with the latest changes.${NC}"
}

# Function to push changes to a branch
function push_changes_to_branch() {
  local branch_name
  branch_name=$(git rev-parse --abbrev-ref HEAD)
  git push "$selected_remote" "$branch_name" --quiet
  echo -e "${GREEN}[SUCCESS] Pushed changes to branch '$branch_name'.${NC}"
}

# Function to push changes directly to main
function push_directly_to_main() {
  git checkout main >/dev/null 2>&1
  git pull "$selected_remote" main --quiet
  echo -e "${YELLOW}[WARNING] You are about to push changes directly to main.${NC}"
  read -p "Do you want to continue? (y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    git add .
    git commit -m "Direct update to main" --quiet
    git push "$selected_remote" main --quiet
    echo -e "${GREEN}[SUCCESS] Changes pushed to main.${NC}"
  else
    echo -e "${CYAN}[INFO] Aborted direct push to main.${NC}"
  fi
}

# Main menu
function main_menu() {
  echo -e "${GREEN}Git Workflow Helper Script!${NC}"
  echo -e "${CYAN}--------------------------------------------------------${NC}"
  echo -e "${CYAN}1) Create and push to a new branch${NC}   ${CYAN}3) Push changes directly to main${NC}"
  echo -e "${CYAN}2) Update an existing branch${NC}         ${CYAN}4) Exit${NC}"
  echo -e "${CYAN}--------------------------------------------------------${NC}"
}

# Main script logic
select_remote

while true; do
  main_menu
  PS3=$(echo -e "${CYAN}Please select an option: ${NC}")
  options=("Create and push to a new branch" "Update an existing branch" "Push changes directly to main" "Exit")
  select opt in "${options[@]}"; do
    case $REPLY in
      1)
        check_for_conflicts
        check_clean_working_directory
        update_main_branch
        create_new_branch
        push_changes_to_branch
        break
        ;;
      2)
        check_for_conflicts
        check_clean_working_directory
        update_main_branch
        update_existing_branch
        push_changes_to_branch
        break
        ;;
      3)
        check_for_conflicts
        check_clean_working_directory
        push_directly_to_main
        break
        ;;
      4)
        echo -e "${GREEN}[INFO] Exiting Git Workflow Helper Script. Goodbye!${NC}"
        exit 0
        ;;
      *)
        echo -e "${RED}[ERROR] Invalid option. Please try again.${NC}"
        ;;
    esac
  done
done

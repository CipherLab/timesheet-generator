#!/bin/bash

# Default repository path (adjust if needed)
DEFAULT_REPO_PATH="/home/mnewport/repos/wyffels/Sales-App"
# On WSL, you might need the Linux path directly like above,
# or translate the Windows path if running Bash outside WSL directly:
# DEFAULT_REPO_PATH="/mnt/c/path/to/your/repo"

# --- Argument Parsing ---
FORCE_FETCH=false
SHOW_HELP=false
day_offset_param=""
author_index_param=""

# Process command line options
while getopts "fhr:d:a:" opt; do
  case ${opt} in
    f ) # Force fetch
      FORCE_FETCH=true
      ;;
    r ) # Custom repo path
      custom_repo_path=$OPTARG
      ;;
    h ) # Help
      SHOW_HELP=true
      ;;
    d ) # Day offset
      day_offset_param=$OPTARG
      ;;
    a ) # Author index
      author_index_param=$OPTARG
      ;;
    \? )
      echo "Usage: $0 [-f] [-r repo_path] [-d day_offset] [-a author_index] [-h]"
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# Remains of the debug function - now just a void where error messages go to die
# (No functions needed here now)

# --- Global Helper Function: Animation ---
show_animation() {
    local pid=$1
    local initial_message=$2
    local frames=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
    # Generic messages suitable for various waiting periods
    local messages=(
        "Still waiting..."
        "Processing data..."
        "Fetching information..."
        "Thinking really hard..."
        "Almost there..."
        "Checking the archives..."
        "Consulting the git gods..."
        "Wrangling bits and bytes..."
    )
    local count=0
    local message="$initial_message" # Start with the initial message

    echo # Newline before animation starts

    while ps -p $pid > /dev/null; do
        frame=${frames[count % ${#frames[@]}]}

        # Change message every ~5 seconds (15 * 0.3s)
        if [ $((count % 15)) -eq 0 ] && [ $count -ne 0 ]; then
            message=${messages[$((RANDOM % ${#messages[@]}))]}
        fi

        printf "\r\033[K  %s  %s" "$frame" "$message"
        sleep 0.3
        count=$((count+1))
    done
    printf "\r\033[K" # Clear the animation line
    echo # Newline after animation finishes
}

# First positional parameter as repo path if provided and -r not used
if [ -z "$custom_repo_path" ] && [ $# -gt 0 ]; then
  custom_repo_path="$1"
fi

# Show help if requested
if [ "$SHOW_HELP" = true ]; then
    cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║      GIT ARCHAEOLOGY & ACCOUNTABILITY DISTRIBUTION         ║
╚════════════════════════════════════════════════════════════╝

USAGE: ./git_commits.sh [-f] [-r repo_path] [-d day_offset] [-a author_index] [-h]

OPTIONS:

  -f            Force branch fetching (ignores cache)
                For when you need to refresh your list of
                things to never look at

  -r repo_path  Specify a repository path
                Because pointing fingers at other directories
                should be easier

  -d day_offset Specify date offset (0 today, -1 yesterday, etc.)
                Skip the date prompt

  -a index      Specify author index (1 for first author, etc.)
                Skip the author selection prompt

  -h            Show this help
                The closest you'll get to actual documentation

This script answers the age-old question: "What did I actually
do today that I can talk about in standup tomorrow?" by providing
a clean, timesheet-ready output.

It also calculates the total time you spent committing, which
bears no relation to the time you spent actually working.

Note: No git branches were harmed in the execution of this script,
      though several were thoroughly judged.
EOF
    exit 0
fi

# Repository path handling
repo_path="${custom_repo_path:-$DEFAULT_REPO_PATH}"

# --- Basic Validation ---
if [ ! -d "$repo_path" ]; then
    echo "Error: Repository directory not found: $repo_path" >&2
    exit 1
fi

# Change to the repository directory
cd "$repo_path" || { echo "Error: Could not change directory to $repo_path" >&2; exit 1; }

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not a valid Git repository: $repo_path" >&2
    exit 1
fi

# --- Cache Remote Branches Analysis ---
cache_remote_branches() {
    local cache_path="/tmp/git_remote_branches_cache_$(basename $(git rev-parse --show-toplevel))"
    local cache_timeout=86400 # 24 hours in seconds

    # Check if cache exists and is recent
    if [ -f "$cache_path" ]; then
        local cache_time=$(stat -c %Y "$cache_path" 2>/dev/null || stat -f %m "$cache_path" 2>/dev/null) # Added error suppression for stat -f
        local current_time=$(date +%s)
        local cache_age=$((current_time - cache_time))

        if [ "$cache_age" -lt "$cache_timeout" ] && [ "$FORCE_FETCH" = false ]; then
            echo "🧠 Using cached branch data (Cache is $((cache_age / 60)) minutes old). Use -f to force fetch."
            return 0
        elif [ "$FORCE_FETCH" = true ]; then
            echo "🔥 Force fetch enabled! Ignoring cache."
            rm -f "$cache_path"
        else
            echo "⏰ Cache expired. Fetching fresh data."
            rm -f "$cache_path"
        fi
    fi

    echo "🔄 Fetching ALL branches from ALL remotes..."
    { # Run fetch in background to show animation for it too
        git fetch --all --prune
    } &
    local fetch_pid=$!
    show_animation $fetch_pid "Fetching remote objects..."
    wait $fetch_pid

    echo "🌱 Creating local tracking branches (if needed)..."
    # Run the branch creation process in the background and create cache
    {
        # Write remote branches to cache first
        # Ensure color codes are stripped even if git config changes
        git branch -r --no-color | grep -v '\->' > "$cache_path"

        # Create the local tracking branches based on the cache file
        while IFS= read -r remote; do
            # Trim whitespace
            remote=$(echo "$remote" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -z "$remote" ]; then continue; fi

            # Extract the base branch name (strip remote name like 'origin/')
            # Assuming remote format is 'origin/branch-name'
            if [[ "$remote" == *"/"* ]]; then
                 local_branch="${remote#*/}"
            else
                 # Handle cases where remote might not have a slash (unlikely for standard setups)
                 local_branch="$remote"
            fi

             if [ -z "$local_branch" ]; then continue; fi # Skip empty lines if any

            # Check if local branch *already exists* before trying to create it
            if ! git show-ref --verify --quiet refs/heads/"$local_branch"; then
                # Attempt to track; suppress stderr for "already exists" which can happen in races
                 git branch --track "$local_branch" "$remote" >/dev/null 2>&1
            fi
        done < "$cache_path"

        # Update cache timestamp only after successfully processing
        touch "$cache_path"
    } & # End background process block

    local branch_pid=$!
    show_animation $branch_pid "Syncing local branches..." # Pass PID and initial message
    wait $branch_pid # Wait for the background branch creation to finish

    echo "✅ Branch collection complete."
    echo "🧠 Branches cached for future script runs."
    echo
}

# --- Fetch ALL Remote Branches ---
cache_remote_branches

# --- Date Input ---
if [ -n "$day_offset_param" ]; then
    day_offset="$day_offset_param"
else
    echo "Enter the date (0 today, -1 yesterday, etc.) to filter commits:"
    read -r day_offset
    # Default to 0 if empty
    day_offset="${day_offset:-0}"
fi

# Validate numeric input
if ! [[ "$day_offset" =~ ^-?[0-9]+$ ]]; then
   echo "Error: Invalid offset. Please enter an integer." >&2; exit 1
fi

# Calculate target date (YYYY-MM-DD) - Assumes GNU date
target_date=$(date -d "$day_offset days" '+%Y-%m-%d')
if [ $? -ne 0 ]; then
    # Fallback for non-GNU date (macOS) - less reliable for negative offsets
    target_date=$(date -v"${day_offset}d" '+%Y-%m-%d' 2>/dev/null)
    if [ $? -ne 0 ]; then
      echo "Error: Could not calculate date. Ensure 'date' command supports relative dates." >&2; exit 1
    fi
fi

echo "Filtering for date: $target_date"

# Define start and end timestamps for the target date
start_date="${target_date}T00:00:00"
end_date="${target_date}T23:59:59"

# --- Author Filtering ---
echo -e "\nFetching authors..."
mapfile -t author_lines < <(git log --all --no-merges --format='%an' | sort | uniq -c | sort -nr) # Use --all instead of --branches

if [ ${#author_lines[@]} -eq 0 ]; then
    echo "No authors found in the repository."
    exit 0
fi

echo -e "\nUnique authors in the repository:"
authors=()
declare -A author_map # Map index to name
for i in "${!author_lines[@]}"; do
    line="${author_lines[$i]}"
    # Robust parsing for names potentially containing numbers
    count=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | sed -e 's/^[[:space:]]*[0-9]*[[:space:]]*//') # Remove leading count and space
    authors+=("$name")
    author_map[$((i+1))]="$name"
    printf "%d. %s - Commits: %d\n" "$((i+1))" "$name" "$count"
done

if [ -n "$author_index_param" ]; then
    author_index="$author_index_param"
else
    echo -e "\nEnter the number corresponding to the author (default 1):"
    read -r author_index
    author_index="${author_index:-1}"
fi

if ! [[ "$author_index" =~ ^[0-9]+$ ]] || [ "$author_index" -lt 1 ] || [ "$author_index" -gt ${#authors[@]} ]; then
   echo "Error: Invalid author number." >&2; exit 1
fi
selected_author="${author_map[$author_index]}"
echo "Selected author: $selected_author"

# --- Commit Retrieval & Processing ---
echo -e "\nFetching commits for $selected_author on $target_date..."

# Use a character that should NEVER appear in git commit messages
# Record Separator (ASCII 30) is ideal for this purpose
SEP=$'\036'
commit_details=() # Initialize empty array
commit_output_file="/tmp/git_commits_output_$$" # Use $$ for better uniqueness
# Use EXIT trap for robust cleanup
trap 'rm -f "$commit_output_file"' EXIT

# Run git log in the background
{
    # Use --all to search all refs (local branches, remote branches, tags)
    # Protect against SEP in messages (though highly unlikely)
    git log --all --no-merges --author="$selected_author" --after="$start_date" --before="$end_date" --date=iso --format="%at${SEP}%H${SEP}%ai${SEP}%s${SEP}%b" --reverse > "$commit_output_file"
    git_status=$? # Capture exit status inside the subshell
    exit $git_status # Exit subshell with git log's status
} &
commit_pid=$!

# Show animation while git log runs
show_animation $commit_pid "Digging through commit history..."

# Wait for git log to finish and capture its exit status
wait $commit_pid
git_log_exit_status=$?

# Check if the command failed
if [ $git_log_exit_status -ne 0 ]; then
    echo "Error: git log command failed while fetching commits (Exit code: $git_log_exit_status)." >&2
    # Optionally print stderr from git log if captured, but it wasn't here.
    exit 1
fi

# Read the results from the temporary file if it has content
if [ -s "$commit_output_file" ]; then
    # Use safe mapfile/read loop approach
    while IFS= read -r line || [[ -n "$line" ]]; do # Process last line even if no trailing newline
        if [ -n "$line" ]; then  # Skip empty lines
            commit_details+=("$line")
        fi
    done < "$commit_output_file"
else
    # Handle case where git log ran successfully but produced no output
    commit_details=()
fi

# --- Process Commits ---
if [ ${#commit_details[@]} -eq 0 ]; then
    echo "No commits found for '$selected_author' on $target_date."
    # Print the final clean footer even if no commits
    echo -e "\n╔═════════════════════════════════════════════════════════╗"
    echo -e "║ COMMITS FOR TIMESHEET: $target_date                     "
    echo -e "╚═════════════════════════════════════════════════════════╝"
    echo "* Branches: N/A"
    printf "\n* Time logged: 00:00\n"
    echo -e "╔═════════════════════════════════════════════════════════╗"
    echo -e "║ END TIMESHEET DATA                                      "
    echo -e "╚═════════════════════════════════════════════════════════╝"
    exit 0
fi

# Always print the clean header
echo -e "\n╔═════════════════════════════════════════════════════════╗"
echo -e "║ COMMITS FOR TIMESHEET: $target_date                       "
echo -e "╚═════════════════════════════════════════════════════════╝"

declare -A branch_commits # Associative array: branch -> list of commit details strings (newline separated)
declare -A branch_first_commit_time # Associative array: branch -> earliest timestamp
declare -A branch_last_segment_set # Use keys for uniqueness of last segments

first_commit_timestamp=""
last_commit_timestamp=""

echo "Associating commits with branches..." # Add progress indicator

# Process each commit detail line to find its branches
processed_count=0
total_commits=${#commit_details[@]}

for details in "${commit_details[@]}"; do
    # Use a safer field splitting approach with read
    IFS="$SEP" read -r timestamp sha datetime subject body_rest <<< "$details"

    # Skip commits with "Squashed" in the subject or body
    if [[ "$subject" == *"Squashed"* ]] || [[ "$body_rest" == *"Squashed"* ]]; then
        processed_count=$((processed_count + 1))
        printf "\rProcessed %d / %d commits..." "$processed_count" "$total_commits"
        continue # Skip to next commit
    fi

    # Validate SHA exists - CRITICAL CHECK
    if [ -z "$sha" ]; then
        #echo "Skip: Missing SHA in line: $details" >&2 # More informative warning
        #processed_count=$((processed_count + 1))
        printf "\rProcessed %d / %d commits..." "$processed_count" "$total_commits"
        continue # Skip to next commit
    fi

    # Validate timestamp is a number to avoid comparison errors
    if [[ "$timestamp" =~ ^[0-9]+$ ]]; then
        # Update overall first/last timestamps
        if [ -z "$first_commit_timestamp" ] || [ "$timestamp" -lt "$first_commit_timestamp" ]; then
            first_commit_timestamp="$timestamp"
        fi
        if [ -z "$last_commit_timestamp" ] || [ "$timestamp" -gt "$last_commit_timestamp" ]; then
            last_commit_timestamp="$timestamp"
        fi
    else
        echo "WARNING: Invalid timestamp for commit ${sha:0:8}: '$timestamp'" >&2
        # Try to recover timestamp from datetime if possible
         new_timestamp=$(date -d "$(echo "$datetime" | cut -d' ' -f1,2)" +%s 2>/dev/null)
         if [[ "$new_timestamp" =~ ^[0-9]+$ ]]; then
             timestamp="$new_timestamp"
             # Re-run timestamp comparison logic with recovered value
             if [ -z "$first_commit_timestamp" ] || [ "$timestamp" -lt "$first_commit_timestamp" ]; then first_commit_timestamp="$timestamp"; fi
             if [ -z "$last_commit_timestamp" ] || [ "$timestamp" -gt "$last_commit_timestamp" ]; then last_commit_timestamp="$timestamp"; fi
         else
             # Fallback if recovery fails
             if [ -n "$first_commit_timestamp" ]; then timestamp="$first_commit_timestamp"; else timestamp=$(date +%s); fi
         fi
    fi

    # Safely get branches containing this commit (local and remote)
    # Use --all to get local and remote branches directly
    # Use --no-color to prevent issues
    # Remove 'remotes/origin/' prefix commonly added by --all
    mapfile -t branches < <(git branch --all --no-color --contains "$sha" --format='%(refname:short)' 2>/dev/null | sed 's|^remotes/origin/|origin/|' | sed 's|^origin/||') # Strip origin/ prefix

    # Filter out branches starting with "release"
    branches_filtered=()
    for branch in "${branches[@]}"; do
        # Skip branches starting with "release"
        if [[ "$branch" != release* ]]; then
            branches_filtered+=("$branch")
        fi
    done
    branches=("${branches_filtered[@]}")

    # Last resort fallback
    if [ ${#branches[@]} -eq 0 ]; then
        branches=("(no associated branch found)")
    fi

    # Store commit in each branch's commit list
    for branch_name in "${branches[@]}"; do
         # Trim potential whitespace from branch names
         branch_name=$(echo "$branch_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
         effective_branch_name="${branch_name:-"(unknown branch)"}"

         # IMPORTANT: Use a newline separator for commit records within a branch
         # Ensure the 'details' variable itself doesn't end with newline if IFS trimming removed it
         # Safest to reconstruct the line if needed, or just append newline.
         branch_commits["$effective_branch_name"]+="${details}"$'\n'

         # Track earliest commit per branch for sorting
         if [ -z "${branch_first_commit_time[$effective_branch_name]}" ] ||
            [ "$timestamp" -lt "${branch_first_commit_time[$effective_branch_name]}" ]; then
             branch_first_commit_time["$effective_branch_name"]="$timestamp"
         fi

         # Track branch name last segments for summary
         last_segment=$(basename "$effective_branch_name" 2>/dev/null || echo "$effective_branch_name")
         # Don't add empty or special names or release branches to segments
         if [[ -n "$last_segment" && "$last_segment" != "(no associated branch found)" && "$last_segment" != "(unknown branch)" && "$last_segment" != release* ]]; then
             branch_last_segment_set["$last_segment"]=1
         fi
    done

    processed_count=$((processed_count + 1))
    # Simple progress indicator without animation
    printf "\rProcessed %d / %d commits..." "$processed_count" "$total_commits"
done
printf "\r\033[K" # Clear progress line

echo "Sorting and formatting results..."

# --- Sort Branches by First Commit Time ---
if [ ${#branch_first_commit_time[@]} -gt 0 ]; then
    mapfile -t sorted_branch_names < <(
        for branch in "${!branch_first_commit_time[@]}"; do
            printf "%s\t%s\n" "${branch_first_commit_time[$branch]}" "$branch"
        done | sort -n | cut -f2-
    )
else
    # No branches found - rare but possible
    sorted_branch_names=()
fi

# --- Output Commits Grouped by Branch (with De-duplication) ---
declare -A seen_commits # Track SHAs that have already been printed

for branch_name in "${sorted_branch_names[@]}"; do
    # Get commit details for the branch, ensuring trailing newline for readarray
    branch_content="${branch_commits[$branch_name]}"
    if [ -z "$branch_content" ]; then
        continue # Skip empty branch content
    fi

    # Create temporary array of sorted commits for this branch using process substitution
    # Sort lines numerically based on the first field (timestamp)
    mapfile -t commits_for_branch < <(echo -n "$branch_content" | sort -t"$SEP" -k1,1n)

    branch_header_printed=0

    for commit_line in "${commits_for_branch[@]}"; do
        if [ -z "$commit_line" ]; then continue; fi

        # Split fields safely
        IFS="$SEP" read -r timestamp sha datetime subject body <<< "$commit_line"

        # Validate SHA before proceeding
        if [ -z "$sha" ]; then
            echo "WARNING: Skipping display for commit with missing SHA in final output." >&2
            continue
        fi

        # De-duplication check
        if [[ -n "${seen_commits["$sha"]}" ]]; then
            continue # Skip already printed commit
        fi

        # Parse time for display (handle ISO 8601 format from %ai)
        # Example: 2025-04-02 09:40:15 -0500
        time_str=$(echo "$datetime" | awk '{print $2}' | cut -d: -f1,2 2>/dev/null || echo "??:??")

        # Skip invalid entries
        if [ -z "$time_str" ] || [ "$time_str" = "??:??" ]; then
            echo "Skipping commit with invalid time: ${sha:0:8} ($datetime)" >&2
            continue
        fi
        # Ensure subject is not just whitespace
        trimmed_subject=$(echo "$subject" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -z "$trimmed_subject" ]; then
            echo "Skipping commit with empty subject: ${sha:0:8}" >&2
            continue
        fi

        # Print branch header if first valid commit in branch
        if [ "$branch_header_printed" -eq 0 ]; then
             echo -e "\n╭─────────────────────────────────────────────────────╮"
             printf "│ %-51s \n" "BRANCH: $branch_name"
             echo -e "╰─────────────────────────────────────────────────────╯"
             branch_header_printed=1
        fi

        # Mark commit as seen
        seen_commits["$sha"]=1

        # Print the commit
        printf -- "  - [%s] %s\n" "$time_str" "$subject" # Use original subject

        # Print first line of body if it looks like a proper comment
        if [ -n "$body" ]; then
           # Read the first line without external commands
           IFS= read -r first_line <<< "$body"
           trimmed_first_line=$(echo "$first_line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
           # Check if it's non-empty and doesn't look like commit metadata or separator line
           if [[ -n "$trimmed_first_line" ]] && ! [[ "$trimmed_first_line" =~ ^(Signed-off-by:|Co-authored-by:|Change-Id:|Fixes:|See-also:|---|Merge:|\*\ ) ]]; then
               printf "    %s\n" "$first_line"
           fi
        fi
    done
done

# --- Print Distinct Branch Last Segments (Clean Format) ---
if [ ${#branch_last_segment_set[@]} -gt 0 ]; then
    mapfile -t sorted_last_segments < <(printf "%s\n" "${!branch_last_segment_set[@]}" | sort)
    distinct_segments_str=$(printf "%s, " "${sorted_last_segments[@]}")
    distinct_segments_str=${distinct_segments_str%, } # Remove trailing comma and space
else
    distinct_segments_str="N/A"
fi

echo -e "\n* Branches: ${distinct_segments_str}" # Added newline for spacing



echo -e "╔═════════════════════════════════════════════════════════╗"
echo -e "║ END TIMESHEET DATA                                      "
echo -e "╚═════════════════════════════════════════════════════════╝"


# --- Calculate and Print Total Time Span (Clean Format) ---
if [ -n "$first_commit_timestamp" ] && [ -n "$last_commit_timestamp" ] && [[ "$last_commit_timestamp" =~ ^[0-9]+$ ]] && [[ "$first_commit_timestamp" =~ ^[0-9]+$ ]] && [ "$last_commit_timestamp" -ge "$first_commit_timestamp" ]; then
    total_seconds=$((last_commit_timestamp - first_commit_timestamp))
    total_hours=$((total_seconds / 3600))
    total_minutes=$(((total_seconds % 3600) / 60))

    printf "\n* Time logged: %02d:%02d\n " "$total_hours" "$total_minutes"
else
    # Handle cases where timestamps were invalid or missing
    echo "Could not calculate time span due to missing or invalid timestamps." >&2
    printf "\n* Time logged: 00:00\n"
fi
exit 0
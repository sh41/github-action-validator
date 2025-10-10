#!/bin/bash

# Enable globstar for recursive matching (**)
shopt -s globstar

# Get the directory of the script
SCRIPT_DIR="$(dirname "$0")"
RUST_SCRIPT="$SCRIPT_DIR/parse_errors.rs"

# Ensure action-validator is installed
if ! command -v action-validator >/dev/null; then
  echo "❌ action-validator is not installed."
  echo "🔗 Installation instructions: https://github.com/mpalmer/action-validator"
  exit 1
fi

# Ensure rust-script is installed (only if missing)
if ! command -v rust-script &> /dev/null; then
    echo "⚙️ Installing rust-script..."
    cargo install rust-script
fi

# Determine the workflow file path
INPUT_PATH_TO_WORKFLOWS="${1:-'.github/workflows/*.yml'}"

echo "🔍 Running GitHub Actions validation with action-validator..."
echo "📂 Validating workflow patterns:"
echo "$INPUT_PATH_TO_WORKFLOWS"

scan_count=0
error_count=0
files_to_validate=()

# The input can be a multi-line string (from a YAML array). Read each line into a pattern.
# The `read` command automatically trims leading/trailing whitespace from each line.
while IFS= read -r pattern; do
  # Skip empty lines
  if [ -z "$pattern" ]; then
    continue
  fi

  # Expand the pattern and add all matching files to the array.
  # This correctly handles filenames with spaces.
  for file in $pattern; do
    files_to_validate+=("$file")
  done
done <<< "$INPUT_PATH_TO_WORKFLOWS"

for action in "${files_to_validate[@]}"; do
  OUTPUT_FILE=$(mktemp)

  # Validate the action file
  if action-validator "$action" > "$OUTPUT_FILE" 2>&1; then
    echo "✅ $action - No issues found."
  else
    echo "❌ $action - Issues detected."
    rust-script "$RUST_SCRIPT" "$OUTPUT_FILE"
    error_count=$((error_count+1))
  fi
  scan_count=$((scan_count+1))
  rm "$OUTPUT_FILE"
done

if [[ $error_count -gt 0 ]]; then
  echo "❌ action-validator found $error_count errors in GitHub Actions files."
  exit 1
else
  echo "✅ action-validator scanned $scan_count GitHub Actions files and found no errors!"
fi

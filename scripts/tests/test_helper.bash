TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/.." && pwd)"

for lib in "$PROJECT_DIR/libs/"*.sh; do
  . "$lib"
done

assert_output_contains() {
  local needle="$1"
  if [[ "$output" != *"$needle"* ]]; then
    echo "Expected output to contain: $needle"
    echo "Actual output: $output"
    return 1
  fi
}

assert_output_not_contains() {
  local needle="$1"
  if [[ "$output" == *"$needle"* ]]; then
    echo "Expected output NOT to contain: $needle"
    echo "Actual output: $output"
    return 1
  fi
}

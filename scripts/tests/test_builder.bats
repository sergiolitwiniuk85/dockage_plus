load test_helper

setup_file() {
  BATS_TMPDIR="$(mktemp -d)"
  export BATS_TMPDIR
}

teardown_file() {
  rm -rf "$BATS_TMPDIR"
}

@test "builder::detect_versions on dir with single Dockerfile -> latest" {
  touch "$BATS_TMPDIR/Dockerfile"
  run builder::detect_versions "$BATS_TMPDIR"
  [ "$status" -eq 0 ]
  [ "$output" = "latest" ]
}

@test "builder::detect_versions with Dockerfile + Dockerfile.v1.2.3 -> lists both" {
  touch "$BATS_TMPDIR/Dockerfile" "$BATS_TMPDIR/Dockerfile.v1.2.3"
  result=$(echo "1" | builder::detect_versions "$BATS_TMPDIR" 2>/dev/null)
  [ "$result" = "latest" ]
}

@test "builder::find_dockerfile for 'latest' -> finds Dockerfile" {
  touch "$BATS_TMPDIR/Dockerfile"
  run builder::find_dockerfile "$BATS_TMPDIR" "latest"
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TMPDIR/Dockerfile" ]
}

@test "builder::find_dockerfile for '1.2.3' -> finds Dockerfile.v1.2.3" {
  touch "$BATS_TMPDIR/Dockerfile.v1.2.3"
  run builder::find_dockerfile "$BATS_TMPDIR" "1.2.3"
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TMPDIR/Dockerfile.v1.2.3" ]
}

@test "builder::determine_tag 'mytool' '1.0' -> 'mytool:1.0'" {
  run builder::determine_tag "mytool" "1.0"
  [ "$status" -eq 0 ]
  [ "$output" = "mytool:1.0" ]
}

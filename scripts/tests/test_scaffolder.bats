load test_helper

setup_file() {
  BATS_TMPDIR="$(mktemp -d)"
  export BATS_TMPDIR
}

teardown_file() {
  rm -rf "$BATS_TMPDIR"
}

@test "scaffolder::generate python mytool 1.0 -> creates with FROM python:3.11-slim" {
  cd "$BATS_TMPDIR"
  run scaffolder::generate python mytool 1.0
  [ "$status" -eq 0 ]
  [ -f "mytool/Dockerfile.v1.0" ]
  grep -q "FROM python:3.11-slim" "mytool/Dockerfile.v1.0"
  [ -f "mytool/README.md" ]
}

@test "scaffolder::generate r mytool 2.0 -> creates with FROM rocker/rstudio:4.4.0" {
  cd "$BATS_TMPDIR"
  run scaffolder::generate r mytool 2.0
  [ "$status" -eq 0 ]
  [ -f "mytool/Dockerfile.v2.0" ]
  grep -q "FROM rocker/rstudio:4.4.0" "mytool/Dockerfile.v2.0"
}

@test "scaffolder::generate gpu mytool 3.0 -> creates with FROM nvidia/cuda:12.1.1" {
  cd "$BATS_TMPDIR"
  run scaffolder::generate gpu mytool 3.0
  [ "$status" -eq 0 ]
  [ -f "mytool/Dockerfile.v3.0" ]
  grep -q "FROM nvidia/cuda:12.1.1" "mytool/Dockerfile.v3.0"
}

@test "scaffolder::generate generic mytool 1.0 -> creates with FROM ubuntu:22.04" {
  cd "$BATS_TMPDIR"
  run scaffolder::generate generic mytool 1.0
  [ "$status" -eq 0 ]
  [ -f "mytool/Dockerfile.v1.0" ]
  grep -q "FROM ubuntu:22.04" "mytool/Dockerfile.v1.0"
}

@test "scaffolder::generate with invalid type -> error message" {
  cd "$BATS_TMPDIR"
  run scaffolder::generate bogus mytool 1.0
  [ "$status" -eq 1 ]
  assert_output_contains "unknown template type"
}

load test_helper

@test "validate::check_conda on good Dockerfile -> OK (0 warnings)" {
  run validate::check_conda "$TEST_DIR/fixtures/Dockerfile.good"
  [ "$status" -eq 0 ]
  assert_output_contains "[OK]"
  assert_output_not_contains "[WARNING]"
}

@test "validate::check_conda on conda Dockerfile -> WARNING" {
  run validate::check_conda "$TEST_DIR/fixtures/Dockerfile.conda"
  [ "$status" -eq 0 ]
  assert_output_contains "[WARNING]"
  assert_output_contains "conda install"
}

@test "validate::check_copyfile on good Dockerfile -> OK" {
  run validate::check_copyfile "$TEST_DIR/fixtures/Dockerfile.good"
  [ "$status" -eq 0 ]
  assert_output_contains "[OK]"
}

@test "validate::check_copyfile on nocopy Dockerfile -> WARNING" {
  run validate::check_copyfile "$TEST_DIR/fixtures/Dockerfile.nocopy"
  [ "$status" -eq 0 ]
  assert_output_contains "[WARNING]"
}

@test "validate::check_naming on basename 'Dockerfile' -> OK" {
  run validate::check_naming "/some/path/Dockerfile"
  [ "$status" -eq 0 ]
  assert_output_contains "[OK]"
}

@test "validate::check_naming on basename 'Dockerfile_v1.2.3' -> WARNING" {
  run validate::check_naming "/some/path/Dockerfile_v1.2.3"
  [ "$status" -eq 0 ]
  assert_output_contains "[WARNING]"
}

@test "validate::run_all --strict on conda Dockerfile -> exit 1" {
  local tmp
  tmp=$(mktemp /tmp/dockage-test-XXXXXX)
  cp "$TEST_DIR/fixtures/Dockerfile.conda" "$tmp"
  run validate::run_all "$tmp" --strict
  [ "$status" -eq 1 ]
  assert_output_contains "warning(s)"
  rm -f "$tmp"
}

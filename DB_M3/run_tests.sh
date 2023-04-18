#!/bin/bash

# Arrays to store passed and failed tests
passed_tests=()
failed_tests=()

# Run a single test test*.sh
run_test() {
  local TEST_NUM=$1
  local TEST_SCRIPT="./test${TEST_NUM}.sh"
  local OUTPUT_FILE="./output/test${TEST_NUM}.out"
  local EXPECTED_FILE="./expected/test${TEST_NUM}.out"

  # Run receive.py in the background, redirecting its output to /output/test*.out
  ./receive.py > "${OUTPUT_FILE}" &
  local RECEIVE_PID=$!

  # Wait for receive.py to start
  sleep 1

  # Run test script test*.sh
  ./"${TEST_SCRIPT}"

  # Wait for the test to finish
  sleep 1

  # Kill receive.py process
  kill "${RECEIVE_PID}"

  # Compare test output with expected output ./expected/test*.out 
  # and print the result
  # Since the order of execution in s3 and s1/s2 is indeterminate, 
  # we will compared the sorted output
  if diff -q -b -B <(sort "${OUTPUT_FILE}") <(sort "${EXPECTED_FILE}") >/dev/null; then
    passed_tests+=("test${TEST_NUM}")
    echo "---------------------------------------------------------------------"
    echo -e "Test${TEST_NUM} passed\n"
  else
    failed_tests+=("test${TEST_NUM}")
    echo "---------------------------------------------------------------------"
    echo -e "Test${TEST_NUM} failed. Difference against expected output is found:\n"
    diff -b -B "${OUTPUT_FILE}" "${EXPECTED_FILE}"
  fi
}

# Run all tests
for i in {1..2}; do
  echo "---------------------------TEST $i BEGINS-----------------------------"
  run_test $i
done

# Print summary
echo "======================================"
echo "            Test Summary"
echo "======================================"
echo "Total tests: 2"
echo "Passed tests: ${#passed_tests[@]}"
for passed_test in "${passed_tests[@]}"; do
  echo "  - ${passed_test} passed"
done
echo "Failed tests: ${#failed_tests[@]}"
for failed_test in "${failed_tests[@]}"; do
  echo "  - ${failed_test} failed"
done
echo "======================================"
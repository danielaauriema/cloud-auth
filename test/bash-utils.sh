#!/bin/false
set -e

# ----------------------------------------------------------------------------------------------------------------------
# PRINT UTILS
# ----------------------------------------------------------------------------------------------------------------------

PRINT_MARGIN=3

printf_(){
  local margin="${2:-$PRINT_MARGIN}"
  printf " %.0s%s" "$(seq 1 "${margin}")" "${1}"
}

print_(){
  local margin="${2:-$PRINT_MARGIN}"
  if [ "$margin" -gt 0 ]; then
    printf "%${margin}s" " "
  fi
  echo "$1"
}

print_line(){
  local char="$1"
  local length="$2"
  local margin="${3:-$PRINT_MARGIN}"
  local line=""
  for ((i=1; i<=length; i++)); do line+="${char}"; done
  print_ "${line}" "${margin}"
}

print_box(){
  local text="*   $1   *"
  local n=${#text}
  local margin="${2:-$PRINT_MARGIN}"

  print_line "*" "${n}" "${margin}"
  print_ "${text}" "${margin}"
  print_line "*" "${n}" "${margin}"
}

print_header(){
  local text="$1"
  local margin="${2:-1}"
  echo ""
  print_box "$(printf "%-50s" "${text}")" "${margin}"
  echo ""
}

print_section(){
  echo "*** $1 ***"
}

# ----------------------------------------------------------------------------------------------------------------------
# WAIT UTILS
# ----------------------------------------------------------------------------------------------------------------------

WAIT_COUNTER=10
WAIT_INTERVAL=1

wait_config(){
  WAIT_COUNTER="${2:-10}"
  WAIT_INTERVAL="${3:-1}"
}

wait_for(){
  local counter="${WAIT_COUNTER}"
  until (( counter <= 0 )) || eval "$*"; do
      sleep "${WAIT_INTERVAL}"
      (( counter-- ))
  done
  if [[ "$counter" -le 0 ]]; then
    echo ">>> timeout waiting for condition!" >&2
    false
  fi
}

wait_for_curl(){
  local host="${1}"
  wait_for "curl --fail -s \"${host}\" > /dev/null"
}

wait_for_curl_text(){
  local host="${1}"
  local text="${2}"
  wait_for "curl --fail -s \"${host}\" | grep -q \"${text}\""
}

# ----------------------------------------------------------------------------------------------------------------------
# TEST UTILS
# ----------------------------------------------------------------------------------------------------------------------

test_label(){
  TEST_LABEL="$*"
  TEST_SOURCE="${BASH_SOURCE[1]}:${BASH_LINENO[0]}"
  printf "    %-5s %s\r" "EXEC" "${TEST_LABEL}"
}

test_result(){
  local status="${1}"
  local text="${2}"
  print_ "$(printf "\033[K%-5s %s" "${status}" "${text}")" 4
}

test_assert(){
    if eval "$*" > /dev/null 2> /tmp/~error.log; then
      test_result "OK" "${TEST_LABEL}"
    else
      test_result "ERROR" "${TEST_LABEL}"
      print_ "   file: ${TEST_SOURCE}"
      >&2 cat /tmp/~error.log
      false
    fi
}

test_wait_for(){
  test_assert "wait_for \"$*\""
}

test_wait_for_file(){
  test_wait_for "[ -f \"${1}\" ]"
}

test_file(){
  test_label "Check file: ${1}"
  test_assert [ -f "${1}" ]
}

test_files(){
  for file in "$@"
  do
      test_file "$file"
  done
}
#!/bin/bash
set -e

SCRIPT_PATH=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

CACHE_PATH="${SCRIPT_PATH}/.cache"
BASH_UTILS="${CACHE_PATH}/bash-utils.sh"
if [ ! -f "$BASH_UTILS" ]; then
  mkdir -p "${CACHE_PATH}"
  curl -s "https://raw.githubusercontent.com/danielaauriema/cloud-utils/refs/heads/main/bash/src/bash-utils.sh" > "${BASH_UTILS}"
fi
# shellcheck disable=SC1090
. "${BASH_UTILS}"

. .env

print_header "Cloud Auth Integration Test"

#-----------------------------------------------------------------------------------------------------------------------
# BUILD IMAGES
#-----------------------------------------------------------------------------------------------------------------------

print_header "Build Images"

print_section "pull and build Docker Compose images"
docker compose pull
docker compose build --no-cache

print_section "start containers"
docker compose up -d

#-----------------------------------------------------------------------------------------------------------------------
# TEST OPEN LDAP FROM LOCALHOST
#-----------------------------------------------------------------------------------------------------------------------

print_header "OpenLdap :: test ldap from localhost"

test_label "Wait for configuration"
test_wait_for docker exec -t test_openldap test -f /openldap/init

test_label "OpenLdap :: Who Am I with LDAPI :: admin"
test_assert docker exec -t test_openldap ldapwhoami -H ldapi:/// -D "cn=admin,${LDAP_BASE_DN}" -w adm1234

test_label "OpenLdap :: Who Am I with LDAPI :: bind"
test_assert docker exec -t test_openldap ldapwhoami -H ldapi:/// -D "cn=bind,${LDAP_BASE_DN}" -w bind1234

test_label "OpenLdap :: Who Am I with LDAPI :: test"
test_assert docker exec -t test_openldap ldapwhoami -H ldapi:/// -D "cn=test,ou=users,${LDAP_BASE_DN}" -w password

#-----------------------------------------------------------------------------------------------------------------------
# TEST OPEN LDAP FROM CLIENT
#-----------------------------------------------------------------------------------------------------------------------

print_header "OpenLdap :: LDAP :: test ldap from client"

test_label "OpenLdap :: Who Am I with LDAP :: admin"
test_assert docker exec -t test_client ldapwhoami -H ldap://test_openldap/ -D "cn=admin,${LDAP_BASE_DN}" -w adm1234

#-----------------------------------------------------------------------------------------------------------------------
# TEAR DOWN
#-----------------------------------------------------------------------------------------------------------------------

print_header "Stopping containers"
docker compose down

print_header "Tests finished successfully"

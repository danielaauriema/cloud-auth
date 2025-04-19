#!/bin/bash

echo "*** Starting Open LDAP entrypoint.."

if [ $# -gt 0 ]; then
    eval "$@"
else
  if [ ! -f "${LDAP_ROOT_PATH}/logs/init" ] && (! ./config.sh) ; then
    echo "*** Open LDAP CONFIGURATION ERROR"
    exit 1
  fi

  declare -a LDAP_HOSTS=()
  if $LDAP_LDAP_ENABLED; then LDAP_HOSTS+=("ldap://"); fi
  if $LDAP_LDAPS_ENABLED; then LDAP_HOSTS+=("ldaps://"); fi
  if $LDAP_LDAPI_ENABLED; then LDAP_HOSTS+=("ldapi://"); fi

  HOSTS="${LDAP_HOSTS[*]}"
  /usr/sbin/slapd -4 -d "${LDAP_LOG_LEVEL}" -h "${HOSTS}" -F "${LDAP_CONF_PATH}"
fi
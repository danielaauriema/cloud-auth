#!/bin/bash
set -e

_log(){
  echo "*** openldap-config :: $1"
}
_log "starting..."
_log "LDAP_DOMAIN...: ${LDAP_DOMAIN}"
_log "LDAP_BASE_DN..: ${LDAP_BASE_DN}"

. /app/bash-wait.sh

cat <<EOF | debconf-set-selections
slapd slapd/internal/generated_adminpw password ${LDAP_ADMIN_PASSWORD}
slapd slapd/internal/adminpw password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANIZATION}
slapd slapd/backend string ${LDAP_BACKEND^^}
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF

dpkg-reconfigure -f noninteractive slapd

mkdir -p "${LDAP_ROOT_PATH}/logs"
chmod -R ugo+rw "${LDAP_ROOT_PATH}"

mkdir -p "${LDAP_DATA_PATH}"
cp /var/lib/ldap/** "${LDAP_DATA_PATH}"
chmod -R ugo+rw "${LDAP_DATA_PATH}"

_log "change LDAP config and data paths"

cp -R "/etc/ldap/slapd.d/" "${LDAP_CONF_PATH}"

slapmodify -b "cn=config" -F "${LDAP_CONF_PATH}" <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcDbDirectory
olcDbDirectory: ${LDAP_DATA_PATH}
EOF

_log "starting Open LDAP..."
slapd -h "ldapi:///" -F "${LDAP_CONF_PATH}"

_log "waiting for LDAP to start..."
bash_wait_for "ldapsearch -H \"ldapi://\" -Y EXTERNAL -b \"${LDAP_BASE_DN}\" > /dev/null  2>/dev/null"

_log "adding Open LDAP modules..."
ldapmodify -Y EXTERNAL -H "ldapi:///" -Q -v <<EOF
dn: cn=module{0},cn=config
add: olcmoduleload
olcModuleLoad: memberof
-
add: olcmoduleload
olcModuleLoad: refint

dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: -1
EOF

_log "enable Open LDAP member of..."
ldapadd -Y EXTERNAL -H "ldapi:///" -Q -v <<EOF
dn: olcOverlay=memberof,olcDatabase={1}${LDAP_BACKEND},cn=config
objectClass: olcOverlayConfig
objectClass: olcMemberOf
olcOverlay: memberof
olcMemberOfDangling: ignore
olcMemberOfRefint: TRUE

dn: olcOverlay={1}refint,olcDatabase={1}${LDAP_BACKEND},cn=config
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcRefintConfig
objectClass: top
olcOverlay: refint
olcRefintAttribute: memberof
olcRefintAttribute: member
olcRefintAttribute: manager
olcRefintAttribute: owner
EOF

ldapmodify -Y EXTERNAL -H "ldapi:///" -Q -v <<EOF
dn: olcDatabase={1}${LDAP_BACKEND},cn=config
changetype:  modify
replace: olcDbIndex
olcDbIndex: uid eq
olcDbIndex: memberOf eq
olcDbIndex: objectClass eq
EOF

_log "config Open LDAP access..."
ldapmodify -Y EXTERNAL -H "ldapi:///" -Q -v <<EOF
dn: olcDatabase={1}${LDAP_BACKEND},cn=config
changetype: modify
delete: olcAccess
-
add: olcAccess
olcAccess: to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break
olcAccess: to attrs=userPassword,shadowLastChange by self write by dn="cn=admin,${LDAP_BASE_DN}" write by anonymous auth by * none
olcAccess: to * by self read by dn="cn=admin,${LDAP_BASE_DN}" write by dn="cn=${LDAP_BIND_USERNAME},${LDAP_BASE_DN}" read by * none
EOF

_log "adding custom groups and users..."
ldapadd -H "ldapi:///" -x -D "cn=${LDAP_ADMIN_USERNAME},${LDAP_BASE_DN}" -w "$LDAP_ADMIN_PASSWORD" -v <<EOF
dn: ou=groups,${LDAP_BASE_DN}
objectClass: top
objectClass: organizationalUnit

dn: ou=users,${LDAP_BASE_DN}
objectClass: top
objectClass: organizationalUnit

dn: cn=users,ou=groups,${LDAP_BASE_DN}
objectClass: top
objectClass: posixGroup
gidNumber: 1000

dn: cn=${LDAP_BIND_USERNAME},${LDAP_BASE_DN}
objectClass: top
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: ${LDAP_BIND_USERNAME}
userPassword: $(slappasswd -n -s "${LDAP_BIND_PASSWORD}")

dn: cn=${LDAP_DEFAULT_USERNAME},ou=users,${LDAP_BASE_DN}
objectClass: top
objectClass: simpleSecurityObject
objectClass: organizationalRole
objectClass: posixAccount
cn: ${LDAP_DEFAULT_USERNAME}
uid: ${LDAP_DEFAULT_USERNAME}
uidNumber: 1001
gidNumber: 1001
homeDirectory: /home/${LDAP_DEFAULT_USERNAME}
userPassword: $(slappasswd -n -s "${LDAP_DEFAULT_PASSWORD}")

dn: cn=admin,ou=groups,${LDAP_BASE_DN}
objectClass: groupOfNames
cn: admin
member: cn=${LDAP_DEFAULT_USERNAME},ou=users,${LDAP_BASE_DN}
EOF

_log "stopping Open LDAP..."
pkill slapd

_log "config script finished successful!"
touch "${LDAP_ROOT_PATH}/init"

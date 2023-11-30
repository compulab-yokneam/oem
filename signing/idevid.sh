#!/bin/bash -x

function get_dev_id() {
	local _DEV_ID=$(cat /sys/devices/virtual/dmi/id/product_serial 2>/dev/null)
	[[ ${_DEV_ID:-""} != "N/A" ]] || _DEV_ID=$(uuidgen --time)
	[[ -n ${_DEV_ID:-""} ]] || _DEV_ID=$(uuidgen --time)
	echo ${_DEV_ID}
}
DEV_ID=${DEV_ID:=$(get_dev_id)}

COMPULAB_CRED="user:oI8whITojdjZDJCJsmiv"
COMPULAB_CACERTS="https://compulab-idevid.est.edge.globalsign.com:443/.well-known/est/cacerts"
COMPULAB_SENROLM="https://compulab-idevid.est.edge.globalsign.com:443/.well-known/est/simpleenroll"
WORK_DIR=$(mktemp --directory)
ROOT=${ROOT:=$(pwd)}

pushd ${WORK_DIR}

# Retrieve the GlobalSign demo root CA certificate with curl and convert it to PEM format using openssl.
# This certificate serves as the common root of trust between IoT Edge, GlobalSign, and DPS (and thus IoT Hub).
curl ${COMPULAB_CACERTS}| openssl base64 -d | openssl pkcs7 -inform DER -outform PEM -print_certs | openssl x509 -out globalsign-root.cert.pem

# Use openssl to create a new private key and certificate signing request (CSR).
openssl req -nodes -new -subj /CN=${DEV_ID} -sha256 -keyout IDevID.key.pem -out IDevID.csr

# Send the CSR to GlobalSign's simple enroll EST endpoint using curl, to obtain the IDevID certificate that is signed with the root CA and paired with the private key created earlier.
curl -X POST --data-binary "@IDevID.csr" -H "Content-Transfer-Encoding:base64" -u ${COMPULAB_CRED} -H "Content-Type:application/pkcs10" ${COMPULAB_SENROLM} | openssl base64 -d | openssl pkcs7 -inform DER -outform PEM -print_certs | openssl x509 -out IDevID.cert.pem

mkdir -p ${ROOT}/var/aziot/{certs,secrets,ek}

mv *cert.pem ${ROOT}/var/aziot/certs
mv *key.pem ${ROOT}/var/aziot/secrets
mv IDevID.csr ${ROOT}/var/aziot/ek

chown aziotcs:aziotcs ${ROOT}/var/aziot/certs/*.cert.pem 2>/dev/null
chmod 644 ${ROOT}/var/aziot/certs/*.cert.pem
chown aziotks:aziotks ${ROOT}/var/aziot/secrets/*.key.pem 2>/dev/null
chmod 600 ${ROOT}/var/aziot/secrets/*.key.pem
chown aziotcs:aziotcs ${ROOT}/var/aziot/certs 2>/dev/null
chmod 755 ${ROOT}/var/aziot/certs
chown aziotks:aziotks ${ROOT}/var/aziot/secrets 2>/dev/null
chmod 700 ${ROOT}/var/aziot/secrets

popd

rm -rf ${WORK_DIR}

ln -fs ${ROOT}/var/aziot/certs/IDevID.cert.pem
ln -fs ${ROOT}/var/aziot/certs/globalsign-root.cert.pem

tree ${ROOT}

# show IDevID.cert.pem
openssl x509 -in ${ROOT}/var/aziot/certs/IDevID.cert.pem -text -noout

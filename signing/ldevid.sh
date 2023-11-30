#!/bin/bash -ex

FILES=${FILES:=$(pwd)/ldevid/files}
SCRIPTS=${SCRIPTS:=$(pwd)/ldevid/scripts}

tpm_command=""
enroll_command=""

function init_data() {
local _file=${SCRIPTS}/00.tpm_create_persist_ek.cmd
cat << eof > ${_file}
#!/bin/bash -xe
cat << _eof > ${FILES}/ek_template.json
{
	"type": "TPM2_ALG_RSA",
	"name_alg": "TPM2_ALG_SHA256",
	"attributes": [
		"TPMA_OBJECT_RESTRICTED",
		"TPMA_OBJECT_ADMINWITHPOLICY",
		"TPMA_OBJECT_DECRYPT",
		"TPMA_OBJECT_FIXEDTPM",
		"TPMA_OBJECT_FIXEDPARENT",
		"TPMA_OBJECT_SENSITIVEDATAORIGIN"
	],
	"auth_policy": "g3GXZ0SEs/gakMyNRqXXJP1S124GUgtk8qHaGzMUaao=",
	"rsa": {
	"symmetric": {
		"algorithm": "TPM2_ALG_AES",
		"key_bits": 128,
		"mode": "TPM2_ALG_CFB"
	},
	"scheme": {
		"algorithm": "TPM2_ALG_NULL"
	},
	"key_bits": 2048,
	"exponent": 0,
	"modulus": 0
	}
}
_eof
tpmtool evict -handle 0x81010001 || true
tpmtool createprimary -endorsement -template ${FILES}/ek_template.json -persistent 0x81010001
eof
tpm_command+=" ${_file}"

_file=${SCRIPTS}/01.tpm_create_parent_ldevid.cmd
cat << eof > ${_file}
#!/bin/bash -xe
cat << _eof > ${FILES}/srk_template.json
{
	"type": "TPM2_ALG_RSA",
	"name_alg": "TPM2_ALG_SHA256",
	"attributes": [
		"TPMA_OBJECT_RESTRICTED",
		"TPMA_OBJECT_USERWITHAUTH",
		"TPMA_OBJECT_DECRYPT",
		"TPMA_OBJECT_FIXEDTPM",
		"TPMA_OBJECT_FIXEDPARENT",
		"TPMA_OBJECT_SENSITIVEDATAORIGIN"
	],
	"rsa": {
		"symmetric": {
			"algorithm": "TPM2_ALG_AES",
			"key_bits": 128,
			"mode": "TPM2_ALG_CFB"
		},
		"key_bits": 2048,
		"exponent": 65537
	}
}
_eof
tpmtool evict -handle 0x81000001 || true
tpmtool createprimary -template ${FILES}/srk_template.json -persistent 0x81000001
eof
tpm_command+=" ${_file}"

_file=${SCRIPTS}/02.tpm_create_private_key_ldevid.cmd
cat << eof > ${_file}
#!/bin/bash -xe
cat << _eof > ${FILES}/rsa_template.json
{
	"type": "TPM2_ALG_RSA",
	"name_alg": "TPM2_ALG_SHA256",
	"attributes": [
		"TPMA_OBJECT_USERWITHAUTH",
		"TPMA_OBJECT_SIGN_ENCRYPT",
		"TPMA_OBJECT_FIXEDTPM",
		"TPMA_OBJECT_FIXEDPARENT",
		"TPMA_OBJECT_SENSITIVEDATAORIGIN"
	],
	"rsa": {
		"key_bits": 2048,
		"exponent": 0
	}
}
_eof
tpmtool evict -handle 0x81020000 || true
tpmtool create -template ${FILES}/rsa_template.json -persistent 0x81020000 -parent 0x81000001
eof
tpm_command+=" ${_file}"

_file=${SCRIPTS}/03.enroll.cmd
cat << eof > ${_file}
#!/bin/bash -xe
cat << _eof > ${FILES}/client.cfg
{
	"server": "compulab-ldevid.est.edge.globalsign.com:443",
		"private_key": {
		"tpm": {
			"device": "/dev/tpmrm0",
			"persistent_handle": 2164391936,
			"storage_handle": 2164260865,
			"ek_handle": 2164326401,
			"ek_certs": "${FILES}/combined.pem"
		}
	}
}
_eof
estclient tpmenroll -config ${FILES}/client.cfg -cn ${DEV_ID}
eof
enroll_command+=" ${_file}"
}

function clear_data() {
	tpmtool evict -handle 0x81010001 || true
	tpmtool evict -handle 0x81000001 || true
	tpmtool evict -handle 0x81020000 || true
}

function _create_combined_pem() {
	# it is up to the caller to place all input pem files into the working folder
	tpmtool nvread -handle 0x1c00002 | openssl x509 -inform der -out ${FILES}/tpmcert.pem
	INTER_URI=$(openssl x509 -in ${FILES}/tpmcert.pem -text -noout | awk -F"URI:" '/CA Issuers/&&($0=$2)')
	curl ${INTER_URI}| openssl x509 -inform der -out ${FILES}/inter.pem
	ROOT_URI=$(openssl x509 -in ${FILES}/inter.pem -text -noout | awk -F"URI:" '/CA Issuers/&&($0=$2)')
	curl ${ROOT_URI}| openssl x509 -inform der -out ${FILES}/root.pem
	cat ${FILES}/tpmcert.pem ${FILES}/inter.pem ${FILES}/root.pem > ${FILES}/combined.pem
}

function _issue_tpm_command() {
	for _tpm_command in ${tpm_command};do
		bash -x ${_tpm_command}
	done
}

function _issue_enroll() {
	for _enroll_command in ${enroll_command};do
		bash -x ${_enroll_command}
	done
}

function issue_enroll() {
	_create_combined_pem
	_issue_tpm_command
	_issue_enroll
}

function get_dev_id() {
	local _DEV_ID=$(cat /sys/devices/virtual/dmi/id/product_serial 2>/dev/null)
	[[ ${_DEV_ID:-""} != "N/A" ]] || _DEV_ID=$(uuidgen --time)
	[[ -n ${_DEV_ID:-""} ]] || _DEV_ID=$(uuidgen --time)
	echo ${_DEV_ID}
}

mkdir -p ${FILES} ${SCRIPTS}
DEV_ID=${DEV_ID:=$(get_dev_id)}

clear_data
init_data
issue_enroll

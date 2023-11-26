#!/bin/bash -ex

function init_data() {
cat << eof > .00.tpm_create_persist_ek.cmd
#!/bin/bash -xe
cat << _eof > ek_template.json
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
tpmtool createprimary -endorsement -template ek_template.json -persistent 0x81010001
eof
tpm_command+=" .00.tpm_create_persist_ek.cmd"

cat << eof > .01.tpm_create_parent_ldevid.cmd
#!/bin/bash -xe
cat << _eof > srk_template.json
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
tpmtool createprimary -template srk_template.json -persistent 0x81000001
eof
tpm_command+=" .01.tpm_create_parent_ldevid.cmd"

cat << eof > .02.tpm_create_private_key_ldevid.cmd
#!/bin/bash -xe
cat << _eof > rsa_template.json
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
tpmtool create -template rsa_template.json -persistent 0x81020000 -parent 0x81000001
eof
tpm_command+=" .02.tpm_create_private_key_ldevid.cmd"

cat << eof > .03.enroll.cmd
#!/bin/bash -xe
cat << _eof > client.cfg
{
	"server": "compulab-ldevid.est.edge.dev.globalsign.com:443",
		"private_key": {
		"tpm": {
			"device": "/dev/tpmrm0",
			"persistent_handle": 2164391936,
			"storage_handle": 2164260865,
			"ek_handle": 2164326401,
			"ek_certs": "combined.pem"
		}
	}
}
_eof
estclient tpmenroll -config client.cfg
eof
enroll_command+=" .03.enroll.cmd"
}

function clear_data() {
	tpmtool evict -handle 0x81010001 || true
	tpmtool evict -handle 0x81000001 || true
	tpmtool evict -handle 0x81020000 || true
}

function _create_combined_pem() {
# it is up to the caller to place all input pem files into the working folder
	tpmtool nvread -handle 0x1c00002 | openssl x509 -inform der -out tpmcert.pem
	cat IDevID.cert.pem globalsign-root.cert.pem tpmcert.pem  > combined.pem
}

function _issue_tpm_command() {
for _tpm_command in ${tpm_command};do
	bash -x $(pwd)/${_tpm_command}
done
if [ "" ];then
	tpmtool createprimary -endorsement -template ek_template.json -persistent 0x81010001
	tpmtool createprimary -template srk_template.json -persistent 0x81000001
	tpmtool create -template rsa_template.json -persistent 0x81020000 -parent 0x81000001
fi
}

function _issue_enroll() {
for _enroll_command in ${enroll_command};do
	bash -x $(pwd)/${_enroll_command}
done
if [ "" ];then
	estclient tpmenroll -config client.cfg
fi
}

function issue_enroll() {
	_create_combined_pem
	_issue_tpm_command
	_issue_enroll
}

tpm_command=""
enroll_command=""
clear_data
init_data
issue_enroll
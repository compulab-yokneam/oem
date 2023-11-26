# oem

## IDevID
Based on: https://techcommunity.microsoft.com/t5/internet-of-things-blog/automatic-iot-edge-certificate-management-with-globalsign-est/ba-p/3739767
* Public
```
DEV_ID="1231121-00001" bash <(curl -L https://raw.githubusercontent.com/compulab-yokneam/oem/master/signing/idevid.sh)
```
* Private
```
DEV_ID="1231121-00001" bash <(curl -L https://raw.githubusercontent.com/compulab-yokneam/oem/master/signing/idevid.sh?token=GHSAT0AAAAAACKPY6BLZUR3VEGC2OSBTI5CZLDMV4Q)
```

## LDevID
Based on: https://iot.globalsign.com/intranet/documents/58/135/GlobalSign%20LDevID%20Enrollment%20with%20IoT%20Edge%20Enroll%20and%20Infineon%20TPM%2011.9.20s.pdf

* Public
```
bash <(curl -L https://raw.githubusercontent.com/compulab-yokneam/oem/master/signing/ldevid.sh)
```

* Private
```
bash <(curl -L https://raw.githubusercontent.com/compulab-yokneam/oem/master/signing/ldevid.sh)
```

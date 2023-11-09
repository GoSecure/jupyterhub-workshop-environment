#!/bin/bash

TF_STATE_FILE=terraform.tfstate

echo Extracting SSH key from terraform state
jq -r '.outputs.instance_private_key.value' $TF_STATE_FILE > tmp_sshkey
chmod u=rw,go= tmp_sshkey

IP=$(jq -r '.outputs.jupyterhub_public_ip.value' $TF_STATE_FILE)

echo "Connecting with ssh ($IP)"
set -x
ssh -i tmp_sshkey root@$IP

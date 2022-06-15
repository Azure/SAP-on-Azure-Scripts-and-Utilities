#!/bin/bash

retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd="$@"
    local -i attempt_num=0
    local -i resultcode=0

    while  true;  do
        $cmd
        resultcode=$?
        if [[ $resultcode == 0 ]]
        then
          return 0
        fi

        if (( attempt_num == max_attempts ))
        then
            echo "Attempt $attempt_num failed and there are no more attempts left!"
            return 1
        else
            echo "Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
            sleep $(( attempt_num++ ))
        fi
    done
}

export ANSIBLE_HOST_KEY_CHECKING=False
terraform init
terraform plan -out main.tfplan
terraform apply "main.tfplan"
terraform output -raw tls_private_key >pkey.out
chmod 600 pkey.out
az vm show -d -g scaResourceGroup -n scaVM --query publicIps -o tsv > scaIP.txt
SCAIP=`cat scaIP.txt`
SEDCMD="s/20.83.123.73/$SCAIP/g"
cat inventory.ini.sample | sed $SEDCMD > inventory.ini
#before running the ansible playbook, wait just a bit
retry 5 "ansible-playbook -i ./inventory.ini sca.yml"
resultcode=$?
echo $?

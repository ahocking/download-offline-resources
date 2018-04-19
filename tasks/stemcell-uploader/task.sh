#!/bin/bash

if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi

SC_VERSION=`cat ./pivnet-product/metadata.json | jq -r '.Dependencies[] | select(.Release.Product.Name | contains("Stemcells")) | .Release.Version' | head -1`

STEMCELL_NAME=bosh-stemcell-$SC_VERSION-$IAAS_TYPE-esxi-ubuntu-trusty-go_agent.tgz

DIAGNOSTIC_REPORT=$(om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k curl -p /api/v0/diagnostic_report)
STEMCELL_EXISTS=$(echo $DIAGNOSTIC_REPORT | jq -r --arg STEMCELL_NAME $STEMCELL_NAME '.stemcells | contains([$STEMCELL_NAME])')

if $STEMCELL_EXISTS ; then
  echo "Stemcell already exists with Ops Manager, hence skipping this step"
else
  echo "Uploading stemcell $SC_VERSION"


  SC_FILE_PATH=`find ./stemcells -name *.tgz`

  om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k upload-stemcell -s $SC_FILE_PATH


fi
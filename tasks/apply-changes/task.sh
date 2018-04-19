#!/bin/bash

if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi

om-linux -t https://$OPS_MGR_HOST -k -u $OPS_MGR_USR -p $OPS_MGR_PWD apply-changes  --ignore-warnings true

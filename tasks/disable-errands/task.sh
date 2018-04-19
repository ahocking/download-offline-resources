#!/bin/bash

if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi


if [[ ! -z "$ERRANDS" ]]; then
  echo "Errands to disable are " $ERRANDS
  for i in $(echo $ERRANDS | sed "s/,/ /g")
  do
    echo "$i"
    set +e
    ERRAND_EXISTS=`om-linux -t https://$OPS_MGR_HOST -k -u $OPS_MGR_USR -p $OPS_MGR_PWD -f json errands \
      -p $PRODUCT_IDENTIFIER | jq -r --arg errand $i '.[] | select(.name==$errand) | .name'`

    set -e
    echo $ERRAND_EXISTS

    if [[ ! -z "$ERRAND_EXISTS" ]]; then
      echo $i " errand found... and disabling..."
      om-linux -t https://$OPS_MGR_HOST -k -u $OPS_MGR_USR -p $OPS_MGR_PWD \
        set-errand-state -p $PRODUCT_IDENTIFIER -e $i --post-deploy-state disabled
    else
      echo $i " errand not found... skipping..."
    fi
  done
else
  echo "No errands to disable"
fi

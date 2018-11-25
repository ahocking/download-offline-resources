#!/bin/bash

set -eux

export CWD=$PWD
export DOWNLOAD_PRODUCT_DIR="${CWD}/pivnet-products"
export DOWNLOAD_STEMCELL_DIR="${CWD}/stemcell"

function abort() {
  echo "$1"
  exit 1
}

# function download_pivnet_stemcell() {
#   #downloads the stemcells associated with the pivnet product
# }

function download_pivnet_product() {
  #pivnet dlpf -p, --product-slug' and `-r, --release-version' -g Glob to match product name e.g. *aws*
  pivnet-cli dlpf -p $1 -r $2 -g *${3}* -d $DOWNLOAD_PRODUCT_DIR --accept-eula
}

# function clear_dirs() {
#   #clears the pivnet-product directory after each download
# }

# function tar_pivnet_product() {
#   #tars up the pivnet-product directory and place it in output directory

# }

function s3_upload() {
  echo "Using s3 endpoint: ${S3_ENDPOINT}"
  aws s3 --endpoint-url ${S3_ENDPOINT} cp ${DOWNLOAD_PRODUCT_DIR}/* "s3://${S3_BUCKET_NAME}/${1}/"
}


function main() {
  if [ -z "$API_TOKEN" ]; then abort "The required env var API_TOKEN was not set for pivnet"; fi
  if [ -z "$IAAS_TYPE" ]; then abort "The required env var IAAS_TYPE was not set"; fi
  if [ -z "$PRODUCT_SLUG"]; then abort "The required env var PRODUCT_SLUG was not set"; fi
  
  if [[ -z "${AWS_ACCESS_KEY_ID}" ]]; then abort "The required env var AWS_ACCESS_KEY_ID was not set"; fi
  if [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then abort "The required env var AWS_SECRET_ACCESS_KEY was not set"; fi
  if [[ -z "${S3_BUCKET_NAME}" ]]; then abort "The required env var S3_BUCKET_NAME was not set"; fi
  if [[ -z "${S3_ENDPOINT}" ]]; then
    S3_ENDPOINT=https://s3.amazonaws.com
  fi

  pivnet-cli login --api-token="$API_TOKEN"
  pivnet-cli eula --eula-slug=pivotal_software_eula >/dev/null 

  pivnet-cli releases -p $PRODUCT_SLUG --format=json | jq --raw-output --arg v "$TARGET_VERSION" '.[] | select (.version <= $v) | .version' > $DOWNLOAD_PRODUCT_DIR/releases.json


  local versions=($(head -${REVISIONS} ${DOWNLOAD_PRODUCT_DIR}/releases.json))

  #loop through all the releases and download the product
  if [ $PRODUCT_SLUG = "ops-manager" ]
    for ver in "${versions[@]}"; do
      echo $ver
      download_pivnet_product ${PRODUCT_SLUG} ${ver} ${IAAS_TYPE}
    done
    
    echo "upload all opsman to s3"
    s3_upload "OPSMAN"

  fi
}

main
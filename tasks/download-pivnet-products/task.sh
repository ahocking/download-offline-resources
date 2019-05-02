#!/bin/bash

set -eu

export CWD=$PWD
export DOWNLOAD_PRODUCT_DIR="${CWD}/pivnet-products"
export DOWNLOAD_STEMCELL_DIR="${CWD}/stemcells"

function abort() {
  echo "$1"
  exit 1
}

function download_pivnet_stemcell() {
  #create directories for local download
  mkdir $DOWNLOAD_STEMCELL_DIR/trusty
  mkdir $DOWNLOAD_STEMCELL_DIR/xenial

  #downloads the stemcells associated with the pivnet product
  echo "download trusty stemcells"
  local versions=($( uniq $DOWNLOAD_STEMCELL_DIR/trusty.stemcell.versions))
  if [ -z "$versions" ]; then
    echo "nothing to download for trusty"
  else
    for ver in "${versions[@]}"; do
      echo "downloading stemcell: " $ver
      pivnet-cli dlpf -p "stemcells" -r ${ver} -g *${IAAS_TYPE}* -d $DOWNLOAD_STEMCELL_DIR/trusty --accept-eula
    done
  fi

  echo "download xenial stemcells"
  local versions=($( uniq $DOWNLOAD_STEMCELL_DIR/xenial.stemcell.versions))
  if [ -z "$versions" ]; then
    echo "nothing to download for xenial"
  else
    for ver in "${versions[@]}"; do
      echo "downloading stemcell: " $ver
      pivnet-cli dlpf -p "stemcells-ubuntu-xenial" -r ${ver} -g *${IAAS_TYPE}* -d $DOWNLOAD_STEMCELL_DIR/xenial --accept-eula
    done
  fi
}

function download_pivnet_product() {
  #pivnet dlpf -p, --product-slug' and `-r, --release-version' -g Glob to match product name e.g. *aws*
  pivnet-cli dlpf -p $1 -r $2 -g *${3}* -d $DOWNLOAD_PRODUCT_DIR --accept-eula
}

function s3_product_upload() {
  echo "Using s3 endpoint: ${S3_ENDPOINT}"
  aws s3 sync ${DOWNLOAD_PRODUCT_DIR}/ "s3://${S3_BUCKET_NAME}/${1}/"  --exclude "releases.json"
}

function s3_stemcell_upload() {
  echo "Using s3 endpoint: ${S3_ENDPOINT}"
  aws s3 sync ${DOWNLOAD_STEMCELL_DIR}/ "s3://${S3_BUCKET_NAME}/${1}/" --exclude "stemcell.versions"
}

function find_stemcells() {
  touch $DOWNLOAD_STEMCELL_DIR/trusty.stemcell.versions
  touch $DOWNLOAD_STEMCELL_DIR/xenial.stemcell.versions
  #find stemcells for trusty
  pivnet-cli release-dependencies  -p $1 -r $2 --format=json | jq --raw-output '.[]| select (.release.product.slug == "stemcells") | .release.version' | head -1 >> $DOWNLOAD_STEMCELL_DIR/trusty.stemcell.versions

  #find stemcells for xenial
  pivnet-cli release-dependencies  -p $1 -r $2 --format=json | jq --raw-output '.[]| select (.release.product.slug == "stemcells-ubuntu-xenial") | .release.version' | head -1 >> $DOWNLOAD_STEMCELL_DIR/xenial.stemcell.versions  
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

  pivnet-cli releases -p $PRODUCT_SLUG --format=json | jq --raw-output --arg v "$TARGET_VERSION" '.[] | select (.version <= $v and (.version|contains("-")| not) ) | .version' > $DOWNLOAD_PRODUCT_DIR/releases.json


  local versions=($(head -${REVISIONS} ${DOWNLOAD_PRODUCT_DIR}/releases.json))

  #loop through all the releases and download the product
  if [ $PRODUCT_SLUG = "ops-manager" ]; 
  then
    for ver in "${versions[@]}"; do
      echo $ver
      download_pivnet_product ${PRODUCT_SLUG} ${ver} ${IAAS_TYPE}
    done
    echo "upload all opsman to s3"
    s3_product_upload $PRODUCT_SLUG
  elif [ $PRODUCT_SLUG = "elastic-runtime" ]; 
  then
    local glob="cf*.pivotal"
    if [ $SRT = "true" ]; then glob="srt*.pivotal"; fi
    for ver in "${versions[@]}"; do
      echo $ver
      download_pivnet_product ${PRODUCT_SLUG} ${ver} $glob
      find_stemcells ${PRODUCT_SLUG} ${ver}
    done
    download_pivnet_stemcell
    s3_product_upload  $PRODUCT_SLUG
    s3_stemcell_upload "stemcells"
  elif [ $PRODUCT_SLUG = "p-concourse" ]; 
  then
    local glob="*.tgz"
    for ver in "${versions[@]}"; do
      echo $ver
      download_pivnet_product ${PRODUCT_SLUG} ${ver} $glob
    done
    s3_product_upload  $PRODUCT_SLUG
  else
    for ver in "${versions[@]}"; do
      echo $ver
      download_pivnet_product ${PRODUCT_SLUG} ${ver} ".pivotal"
      find_stemcells ${PRODUCT_SLUG} ${ver}
    done
    download_pivnet_stemcell
    s3_product_upload  $PRODUCT_SLUG
    s3_stemcell_upload "stemcells"
  fi
}

main
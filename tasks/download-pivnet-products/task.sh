#!/bin/bash

set -eu

export CWD=$PWD
export DOWNLOAD_PRODUCT_DIR="${CWD}/pivnet-product"
export DOWNLOAD_STEMCELL_DIR="${CWD}/stemcell"

function abort() {
  echo "$1"
  exit 1
}

function download_pivnet_stemcell() {
  #downloads the stemcells associated with the pivnet product
}

function download_pivnet_product() {
  #pivnet dlpf -p, --product-slug' and `-r, --release-version' -g Glob to match product name e.g. *aws*
  pivnet dlpf -p $1 -r $2 -g *$3* -d $DOWNLOAD_PRODUCT_DIR --accept-eula
}

function clear_dirs() {
  #clears the pivnet-product directory after each download
}

function tar_pivnet_product() {
  #tars up the pivnet-product directory and place it in output directory

}

function main {
  if [ -z "$API_TOKEN" ]; then abort "The required env var API_TOKEN was not set for pivnet"; fi
  if [ -z "$IAAS_TYPE" ]; then abort "The required env var IAAS_TYPE was not set"; fi
  if [ -z "$PRODUCT_SLUG"]; then abort 

  pivnet-cli login --api-token="$API_TOKEN"
  pivnet-cli eula --eula-slug=pivotal_software_eula >/dev/null 

  #loop through all the releases and download the product
  local version=2.3.5
  download_pivnet_product $PRODUCT_SLUG $version $IAAS_TYPE
}

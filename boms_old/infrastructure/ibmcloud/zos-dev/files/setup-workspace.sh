#!/bin/bash

TEMPLATE_FLAVOR="zdev"
REF_ARCH=""

Usage()
{
   echo "Creates a workspace folder and populates it with architectures."
   echo
   echo "Usage: setup-workspace.sh -a REF_ARCH"
   echo "  options:"
   #echo "  t     the template to use for the deployment (small or full)"
   echo "  a     the reference architecture to deploy (vpc or ocp or existing)"
   echo "  h     Print this help"
   echo
}

# Get the options
while getopts ":a:t:" option; do
   case $option in
      h) # display Help
         Usage
         exit 1;;
#      t) # Enter a name
#         TEMPLATE_FLAVOR=$OPTARG;;
      a) # Enter a name
         REF_ARCH=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         Usage
         exit 1;;
   esac
done

if [[ -z "${TEMPLATE_FLAVOR}" ]] || [[ ! "${TEMPLATE_FLAVOR}" =~ small|full|zdev ]] || [[ -z "${REF_ARCH}" ]] || [[ ! "${REF_ARCH}" =~ ocp|vpc|existing ]]; then
  Usage
  exit 1
fi

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
WORKSPACES_DIR="${SCRIPT_DIR}/../workspaces"
WORKSPACE_DIR="${WORKSPACES_DIR}/current"

if [[ -d "${WORKSPACE_DIR}" ]]; then
  DATE=$(date "+%Y%m%d%H%M")
  mv "${WORKSPACE_DIR}" "${WORKSPACES_DIR}/workspace-${DATE}"
fi

mkdir -p "${WORKSPACE_DIR}"
cd "${WORKSPACE_DIR}"

echo "Setting up workspace in '${WORKSPACE_DIR}'"
echo "*****"
if [[ "${REF_ARCH}" != "existing" ]]; then
  ${SCRIPT_DIR}/create-ssh-keys.sh
fi

cp "${SCRIPT_DIR}/terraform.tfvars.template-${TEMPLATE_FLAVOR}" ./terraform.tfvars

# append random string into suffix variable in tfvars  to prevent name collisions in object storage buckets
if command -v openssl &> /dev/null
then
    printf "\n\nsuffix=\"$(openssl rand -hex 4)\"\n" >> "${WORKSPACE_DIR}"/terraform.tfvars
fi


# Help Scripts for applying and destroying
cp "${SCRIPT_DIR}/apply-all.sh" "${WORKSPACE_DIR}/apply-all.sh"
cp "${SCRIPT_DIR}/destroy-all.sh" "${WORKSPACE_DIR}/destroy-all.sh"

ALL_ARCH="000|100|110|120|160"

echo "Setting up workspace from '${TEMPLATE_FLAVOR}' template"
echo "*****"

WORKSPACE_DIR=$(cd "${WORKSPACE_DIR}"; pwd -P)

VPC_ARCH="000|100|110"
OCP_ARCH="000|100|120|160"
EXISTING_ARCH="165"

echo "Setting up automation  ${WORKSPACE_DIR}"

find ${SCRIPT_DIR}/. -type d -maxdepth 1 | grep -vE "[.][.]/[.].*" | grep -v workspace | sort | \
  while read dir;
do

  name=$(echo "$dir" | sed -E "s/.*\///")

  if [[ ! -d "${SCRIPT_DIR}/${name}/terraform" ]]; then
    continue
  fi

  if [[ "${REF_ARCH}" == "ocp" ]] && [[ ! "${name}" =~ ${OCP_ARCH} ]]; then
    continue
  fi

  if [[ "${REF_ARCH}" == "vpc" ]] && [[ ! "${name}" =~ ${VPC_ARCH} ]]; then
    continue
  fi

  if [[ "${REF_ARCH}" == "existing" ]] && [[ ! "${name}" =~ ${EXISTING_ARCH} ]]; then
    continue
  fi

  echo "Setting up current/${name} from ${name}"

  mkdir -p ${name}
  cd "${name}"

  cp -R "${SCRIPT_DIR}/${name}/bom.yaml" .
  cp -R "${SCRIPT_DIR}/${name}/terraform/"* .
  ln -s "${WORKSPACE_DIR}"/terraform.tfvars ./terraform.tfvars
  if [[ "${REF_ARCH}" != "existing" ]]; then
    ln -s "${WORKSPACE_DIR}"/ssh-* .
  fi
  ln -s "${SCRIPT_DIR}/apply.sh" ./apply.sh
  ln -s "${SCRIPT_DIR}/destroy.sh" ./destroy.sh

  cd - > /dev/null
done

echo "move to ${WORKSPACE_DIR} this is where your automation is configured"

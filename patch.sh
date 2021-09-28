#!/bin/bash
# Description:
# Podspec auto patching script for React Native projects.
# It download, patches the podspec and updating Podfile
# based on the PodName@Version.patch files convention.
#
# Author: Kalashnikov Max (max@comm.app)
# Created for: Comm.app
#
# Usage:
# Run it as npx or bash script from the 'native' directory
# of the ReactNative project.
set -e

# Constants
## Paths relatively to the 'native/ios' directory
readonly PATCHES_DIR="patches"
readonly PODFILE_PATH="Podfile"

# Console output functions
readonly CRED=$(tput setaf 1)
readonly CGREEN=$(tput setaf 2)
readonly CYELLOW=$(tput setaf 3)
readonly CRESET=$(tput sgr0)

# Console logging
# Usage: LOG SKIP|INFO|SUCCESS|ERROR "Message text"
function LOG() {
    case $1 in
    SKIP) echo "[skip] $2" ;;
    INFO) echo "${CYELLOW}[info] $2${CRESET}" ;;
    SUCCESS) echo "${CGREEN}[success] $2${CRESET}" ;;
    ERROR) echo "${CRED}[error] $2${CRESET}" && exit 1 ;;
    *) echo "[log] $2" ;;
    esac
}

# Patching function
# Usage: MAKE_PATCH $POD_NAME $POD_VERSION
function MAKE_PATCH() {
    local readonly POD_NAME=$1
    local readonly POD_VERSION=$2
    # Read the version of the Pod from the Podfile
    local POD_VERSION_PODFILE=$(cat ./ios/${PODFILE_PATH} | grep "pod '${POD_NAME}'" | awk '{print $3}' | tr -d "'")
    if [[ $POD_VERSION_PODFILE =~ ^[0-9]+(\.[0-9]+){2,3}$ ]]; then
        LOG INFO "${POD_NAME} has ${POD_VERSION_PODFILE} version in the Podfile"
        # Error if Podfile version not equal with the patch version
        if [ $POD_VERSION_PODFILE != $POD_VERSION ]; then
            LOG ERROR "Podfile version ${POD_VERSION_PODFILE} not equal to patch version ${POD_VERSION}"
        fi
    elif [[ $POD_VERSION_PODFILE =~ .*podspec.* ]]; then
        LOG SKIP "${POD_NAME} pod seems already patched and has a :podspec property"
        return
    else
        LOG ERROR "Wrong ${POD_NAME} pod version ${POD_VERSION_PODFILE} in the Podfile"
    fi

    # Getting Cocoapods github Spec url from the local path of the Pod
    SPEC_PATH=$(pod spec which ${POD_NAME})
    SPEC_PATH=${SPEC_PATH##*/trunk}
    SPEC_PATH=${SPEC_PATH%/*}
    SPEC_PATH=${SPEC_PATH%/*}
    local GITHUB_SPEC_URL="https://raw.githubusercontent.com/CocoaPods/Specs/master${SPEC_PATH}/${POD_VERSION}/${POD_NAME}.podspec.json"

    # Check if we have a patch file to patch the Pod's podspec
    local PATCH_FILE="${PATCHES_DIR}/${POD_NAME}@${POD_VERSION}.patch"
    if [ ! -f "./ios/$PATCH_FILE" ]; then
        LOG ERROR "Patch file ${PATCH_FILE} for ${POD_NAME} does not exist, nothing to patch."
    fi

    local PATCHED_PODSPEC_PATCH="${PATCHES_DIR}/${POD_NAME}/${POD_VERSION}/${POD_NAME}.podspec.json"
    rm -f "./ios/${PATCHED_PODSPEC_PATCH}"
    mkdir -p "./ios/${PATCHES_DIR}/${POD_NAME}/${POD_VERSION}"

    # Download the podspec file for the pod
    local CODE=$(curl -sSL -w '%{http_code}' --output "./ios/${PATCHED_PODSPEC_PATCH}" "${GITHUB_SPEC_URL}")
    if [[ "$CODE" =~ ^2 ]]; then
        LOG INFO "Podspec downloaded"
    elif [[ "$CODE" == 404 ]]; then
        LOG ERROR "Got 404 error from: ${GITHUB_SPEC_URL}"
    else
        LOG ERROR "ERROR: server returned HTTP code $CODE when downloading from ${GITHUB_SPEC_URL}"
    fi

    # Patch the downloaded podspec file and replace the Pod
    # in Podfile with the local podspec path
    patch "./ios/${PATCHED_PODSPEC_PATCH}" "./ios/${PATCH_FILE}"
    sed -i -e "s|.*pod.*'${POD_NAME}'.*|  pod '${POD_NAME}', :podspec => './${PATCHED_PODSPEC_PATCH}'|" ./ios/${PODFILE_PATH}

    LOG SUCCESS "Podfile updated with the ${POD_NAME} patched Pod"
}

# Read the directory with the .patch files
# and extract the pod name and version from
# the filename
for TO_PATCH_FILE in "./ios/${PATCHES_DIR}"/*.patch; do
    if [ -f "$TO_PATCH_FILE" ]; then
        TO_PATCH_FILE=$(basename $TO_PATCH_FILE | awk '{print $1}')
        POD_NAME="${TO_PATCH_FILE%%@*}"
        POD_VERSION=$(echo $TO_PATCH_FILE | awk -F "@" '{print $2}' | awk -F ".patch" '{print $1}')
        LOG INFO "Found ${POD_NAME} Pod patch for ${POD_VERSION} version"

        # Patching Pod with the certain version
        MAKE_PATCH $POD_NAME $POD_VERSION
    fi
done

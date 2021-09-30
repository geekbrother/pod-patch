#!/bin/bash
# Description:
# Podspec auto patching script for React Native projects.
# It download, patches the podspec and updating Podfile
# based on the PodName@Version.patch files convention.
#
# Author: Max Kalashnikov (max@comm.app)
# Created for: Comm.app
#
# Usage: npx pod-patch [-h Usage] [-v Version] [-d <path/Podfile> Podfile path ] [-p <path> .patch files directory]
# Run it as npx or bash script from the 'native' directory of
# the ReactNative project.
readonly SCRIPT_VERSION='0.0.8'
set -e

# Default parameters
## Directory relatively to the ReactNative '/native' directory where the .patch files are.
PATCHES_DIR="./ios/pod-patch"
## Cocoapods Podfile path
PODFILE_PATH="./ios/Podfile"
## Where the patched files will be placed
readonly PATCHED_SUBDIR=".patched"

# Parsing CLI arguments
while getopts ":hvp:d:" opt; do
    case ${opt} in
    h)
        echo "pod-patch is a Podspec files patching tool based on the .patch files."
        echo "Run it as npx or bash script from the 'native' directory of the ReactNative project."
        echo "Version: ${SCRIPT_VERSION}"
        echo "Usage: npx pod-patch [-h Usage] [-v Version] [-d <path/Podfile> Podfile path ] [-p <path> .patch files directory]"
        exit 0
        ;;
    v)
        echo "pod-patch version: ${SCRIPT_VERSION}"
        exit 0
        ;;
    p)
        PATCHES_DIR=${OPTARG}
        ;;
    d)
        PODFILE_PATH=${OPTARG}
        ;;
    esac
done
shift $((OPTIND - 1))

# Console logging
# Usage: LOG SKIP|INFO|SUCCESS|ERROR "Message text"
function LOG() {
    # Console colors
    local CRED=$(tput setaf 1)
    local CGREEN=$(tput setaf 2)
    local CYELLOW=$(tput setaf 3)
    local CRESET=$(tput sgr0)

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
    # Arguments
    local readonly POD_NAME=$1
    local POD_VERSION=$2

    if [ -z "$POD_VERSION" ]; then
        local PATCH_FILE="${PATCHES_DIR}/${POD_NAME}.patch"
    else
        local PATCH_FILE="${PATCHES_DIR}/${POD_NAME}@${POD_VERSION}.patch"
    fi

    # Read the version of the Pod from the Podfile
    local POD_VERSION_PODFILE=$(cat ${PODFILE_PATH} | grep "pod '${POD_NAME}'" | awk '{print $3}' | tr -d "'")
    if [[ $POD_VERSION_PODFILE =~ ^[0-9]+(\.[0-9]+){2,3}$ ]]; then
        LOG INFO "${POD_NAME} has ${POD_VERSION_PODFILE} version in the Podfile"
        # If POD_VERSION is empty we have a .patch file without version, go with the
        # version from the Podfile
        if [ -z "$POD_VERSION" ]; then
            POD_VERSION=$POD_VERSION_PODFILE
        fi
        # Error if Podfile version not equal with the .patch version
        if [ $POD_VERSION_PODFILE != $POD_VERSION ]; then
            LOG ERROR "Podfile version ${POD_VERSION_PODFILE} not equal to patch version ${POD_VERSION}"
        fi
    elif [[ $POD_VERSION_PODFILE =~ .*podspec.* ]]; then
        # If already patched and have a ':podspec =>' we need to check if the patched podspec file exists
        # in case of this is a git copy with the .patched directory in .gitignore
        local PODSPEC_PODFILE=$(cat ${PODFILE_PATH} | grep "pod '${POD_NAME}'" | awk '{print $5}' | tr -d "'")
        if [[ -f "./ios/${PODSPEC_PODFILE##./}" ]]; then
            LOG SKIP "${POD_NAME} podspec already patched and has a local podspec file in a Podfile"
            return
        else
            LOG INFO "Patched podspec file not found, creating a new one"
        fi
    else
        LOG ERROR "Wrong ${POD_NAME} pod version ${POD_VERSION_PODFILE} in the Podfile"
    fi

    # Getting Cocoapods github Spec url from the local path of the Pod
    SPEC_PATH=$(pod spec which ${POD_NAME})
    SPEC_PATH=${SPEC_PATH##*/trunk}
    SPEC_PATH=${SPEC_PATH%/*}
    SPEC_PATH=${SPEC_PATH%/*}
    local GITHUB_SPEC_URL="https://raw.githubusercontent.com/CocoaPods/Specs/master${SPEC_PATH}/${POD_VERSION}/${POD_NAME}.podspec.json"

    local PATCHED_PODSPEC_PATCH="${PATCHES_DIR}/${PATCHED_SUBDIR}/${POD_NAME}/${POD_VERSION}/${POD_NAME}.podspec.json"
    rm -f "${PATCHED_PODSPEC_PATCH}"
    mkdir -p "${PATCHES_DIR}/${PATCHED_SUBDIR}/${POD_NAME}/${POD_VERSION}"

    # Download the podspec file for the pod
    local CODE=$(curl -sSL -w '%{http_code}' --output "${PATCHED_PODSPEC_PATCH}" "${GITHUB_SPEC_URL}")
    if [[ "$CODE" =~ ^2 ]]; then
        LOG INFO "Podspec downloaded"
    elif [[ "$CODE" == 404 ]]; then
        LOG ERROR "Got 404 error from: ${GITHUB_SPEC_URL}"
    else
        LOG ERROR "ERROR: server returned HTTP code $CODE when downloading from ${GITHUB_SPEC_URL}"
    fi

    # Patch the downloaded podspec file and replace the Pod
    # in Podfile with the local podspec path
    patch "${PATCHED_PODSPEC_PATCH}" "${PATCH_FILE}"
    sed -i '' -e "s|.*pod.*'${POD_NAME}'.*|  pod '${POD_NAME}', :podspec => './${PATCHED_PODSPEC_PATCH#"./ios/"}'|" ${PODFILE_PATH}

    LOG SUCCESS "Podfile updated with the ${POD_NAME} patched pod"
}

# Check if the directory with the .patch files exists
if [[ ! -d $PATCHES_DIR ]]; then
    LOG ERROR "Directory with .patch files doesn't exist: ${PATCHES_DIR}"
fi
# Check if the Podfile exists
if [[ ! -f $PODFILE_PATH ]]; then
    LOG ERROR "Podfile not found: ${PODFILE_PATH}"
fi

# Read the directory with the .patch files
# and extract the Pod name and version from
# the .patch filename
# We can have a two types of the .patch files:
# - podName@Version.patch: With the patch for the specific version of the Pod.
# - podName.patch: Without specific version. It will be applied to all versions.
for TO_PATCH_FILE in "${PATCHES_DIR}"/*.patch; do
    if [ -f "$TO_PATCH_FILE" ]; then
        TO_PATCH_FILE=$(basename $TO_PATCH_FILE | awk '{print $1}')
        # If the .patch file with the specific version:
        if [[ $TO_PATCH_FILE =~ "@" ]]; then
            POD_NAME="${TO_PATCH_FILE%%@*}"
            POD_VERSION=$(echo $TO_PATCH_FILE | awk -F "@" '{print $2}' | awk -F ".patch" '{print $1}')
            LOG INFO "Found ${POD_NAME} pod patch for @${POD_VERSION} version"
        else
            # If the .patch file without version
            POD_NAME="${TO_PATCH_FILE%".patch"}"
            POD_VERSION=""
            LOG INFO "Found ${POD_NAME} pod patch for all versions"
        fi
        # Patching Pod with the certain version
        MAKE_PATCH $POD_NAME $POD_VERSION
    fi
done

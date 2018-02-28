#!/bin/sh -eu

REPO_PATH="$(pwd)"
export REPO_PATH
echo "REPO_PATH: ${REPO_PATH}"

if ! [ -d "${REPO_PATH}/auto-test/bin" ]; then
    echo "ERROR: Please execute the below command from 'test-definitions' DIR"
    echo "    . ./auto-test/bin/setenv.sh"
    exit 1
fi

PATH="${REPO_PATH}/auto-test/bin:${PATH}"
export PATH
echo "BIN_PATH: ${PATH}"

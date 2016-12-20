#!/bin/bash
set -e
# Description: Create test data.

RAR_DATA_DIR=rar-data
mkdir -p "${RAR_DATA_DIR}"
RAR_DATA_DIR=$(readlink -ev "${RAR_DATA_DIR}")

RAR_FILE=${RAR_DATA_DIR}/data-rar-no-password
echo "${RAR_FILE}" > "${RAR_FILE}.txt"
rar a "${RAR_FILE}.rar" "${RAR_FILE}.txt"

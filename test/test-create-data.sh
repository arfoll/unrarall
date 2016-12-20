#!/bin/bash
set -e
# Description: Create test data.

RAR_DATA_DIR=rar-data
rm -rf "${RAR_DATA_DIR}"
mkdir -p "${RAR_DATA_DIR}"
RAR_DATA_DIR=$(readlink -ev "${RAR_DATA_DIR}")

# Case: No password rar.
(
  cd "${RAR_DATA_DIR}"
	RAR_FILE=data-rar-no-password
	echo "${RAR_FILE}" > "${RAR_FILE}.txt"
	rar a "${RAR_FILE}.rar" "${RAR_FILE}.txt"
	rm -f "${RAR_FILE}.txt"
)

PASSWORD=test

# Case: Encrypted rar.
(
  cd "${RAR_DATA_DIR}"
	RAR_FILE=data-rar-with-password
	echo "${RAR_FILE}" > "${RAR_FILE}.txt"
	rar a -p${PASSWORD} "${RAR_FILE}.rar" "${RAR_FILE}.txt"
	rm -f "${RAR_FILE}.txt"
)


# Case: Header and files encrypted rar.
(
  cd "${RAR_DATA_DIR}"
	RAR_FILE=data-rar-header-files-encrypted
	echo "${RAR_FILE}" > "${RAR_FILE}.txt"
	rar a -hp${PASSWORD} "${RAR_FILE}.rar" "${RAR_FILE}.txt"
	rm -f "${RAR_FILE}.txt"
)
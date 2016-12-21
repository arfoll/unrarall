

# Create test data.
./test-create-data.sh

# Create list of passwords.
PASSWORD=test
echo "${PASSWORD}" > "${HOME}/.unrar_passwords"

\cp -a ../unrarall /usr/local/bin

# Extract
RESULT_DIR=results
mkdir -p "${RESULT_DIR}"
unrarall --clean=rar -o "${RESULT_DIR}" ./


# Expectations.
echo "============= Expectations ============="
echo "- All RAR files are deleted from ./rar-data/"
echo "- 3 files are in  ./results/"
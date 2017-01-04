#!/bin/bash
# Utility script to invert the exit code
"$@"
SUCCESS=$?
if [ "${SUCCESS}" -eq 0 ]; then
  exit 1
else
  exit 0
fi

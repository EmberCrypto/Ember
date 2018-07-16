#!/bin/bash

# Because `nimble test` runs nim with the --noNimblePath option

cd ..
for file in tests/t*.nim; do
  echo
  echo "Running test $file"
  echo
  nim c -r $file || break
done

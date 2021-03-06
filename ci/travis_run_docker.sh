#!/bin/bash
set -e #Exit on failure.
echo "travis_run_docker.sh:"

# Take ownership of the home directory
# Otherwise docker folder mapping can fuck things up
sudo chown -R "$(id -u -n)": ~/
sudo chmod -R a+rw .

conan user

./build.sh


if [[ "$COVERALLS" == 'true' ]]; then
  pwd
  echo "*******  See coverage **************"
  lcov --list coverage.info # debug before upload

  echo "******* Uploading to coveralls **************"
  coveralls-lcov "--repo-token=${COVERALLS_TOKEN}" coverage.info # uploads to coveralls

  #kcov --coveralls-id=$TRAVIS_JOB_ID --exclude-pattern=/.cargo target/kcov target/debug/<<<MY_PROJECT_NAME>>>-*

fi

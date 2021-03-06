#!/bin/bash

set -e
set -x

cd ..

cd c_components
conan remove imageflow_c/* -f
conan export imazen/testing

cd ../imageflow_core

conan install --build missing # Will build imageflow package with your current settings
cargo test

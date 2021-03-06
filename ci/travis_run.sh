#!/bin/bash
set -e

echo "travis_run.sh:"

## REQUIRED ALWAYS
# TRAVIS_BUILD_DIR (root copy of repo, with .git folder present)
# DOCKER_IMAGE Ex. imazen/build_if_gcc48 imazen/build_if_gcc54 
# CI=true

## REQUIRED FOR SIMULATION
# SIM_CI=True
# SIM_OPEN_BASH=False
# SIM_DOCKER_CACHE_VARS=("-v" "mapping:to")


## For artifacts to be created
# TRAVIS_PULL_REQUEST=false
# TRAVIS_PULL_REQUEST_SHA=
# UPLOAD_BUILD=True
# PACKAGE_SUFFIX=  Ex. x86_64-linux-gcc48-eglibc219 x86_64-linux-gcc54-glibc223 x86_64-mac-osx10_11
# TRAVIS_BUILD_NUMBER=[integer]
# TRAVIS_BRANCH= (closest relevant - optional if  `git symbolic-ref --short HEAD` works

## For docs
# UPLOAD_DOCS=True or False

## For tagged releases
# TRAVIS_TAG= (optional)

## For artifact-by-commit
# FETCH_COMMIT_SUFFIX=mac64, linux64

## CONFIGURATION
# VALGRIND=True or False
# 
## MOST LIKELY TO GET POLLUTED
# GIT_* vars
# BUILD_RELEASE
# TEST_C
# TEST_C_DEBUG_BUILD
# TEST_RUST
# CLEAN_RUST_TARGETS
# IMAGEFLOW_SERVER
# COVERAGE
# COVERALLS
# COVERALLS_TOKEN



if [ -n "${TRAVIS_BUILD_DIR}" ]; then
  cd "${TRAVIS_BUILD_DIR}"
fi

STAMP="+[%H:%M:%S]"
date "$STAMP"

#Export CI stuff
export CI_SEQUENTIAL_BUILD_NUMBER="${TRAVIS_BUILD_NUMBER}"
export CI_BUILD_URL="https://travis-ci.org/${TRAVIS_REPO_SLUG}/builds/${TRAVIS_BUILD_ID}"
export CI_JOB_URL="https://travis-ci.org/${TRAVIS_REPO_SLUG}/jobs/${TRAVIS_JOB_ID}"
export CI_JOB_TITLE="Travis ${TRAVIS_JOB_NUMBER} ${TRAVIS_OS_NAME}"
export CI_STRING="name:Travis job_id:${TRAVIS_JOB_ID} build_id:${TRAVIS_BUILD_ID} travis_commit:${TRAVIS_COMMIT} build_number:${TRAVIS_BUILD_NUMBER} job_number: ${TRAVIS_JOB_NUMBER} repo_slug:${TRAVIS_REPO_SLUG} tag:${TRAVIS_TAG} branch:${TRAVIS_BRANCH} is_pull_request:${TRAVIS_PULL_REQUEST}"
export CI_PULL_REQUEST_INFO="${TRAVIS_PULL_REQUEST_SHA}"
export CI_TAG="${TRAVIS_TAG}"
export CI_RELATED_BRANCH="${TRAVIS_BRANCH}"
if [[ -z "$CI_PULL_REQUEST_INFO" ]]; then
	export GIT_OPTIONAL_BRANCH="${CI_RELATED_BRANCH}"
fi
export UPLOAD_URL="https://s3-us-west-1.amazonaws.com/imageflow-nightlies"

############ GIT VALUES ##################

echo "Querying git for version and branch information"
export GIT_COMMIT
GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse HEAD)}"
GIT_COMMIT="${GIT_COMMIT:-unknown-commit}"
export GIT_COMMIT_SHORT
GIT_COMMIT_SHORT="${GIT_COMMIT_SHORT:-$(git rev-parse --short HEAD)}"
GIT_COMMIT_SHORT="${GIT_COMMIT_SHORT:-unknown-commit}"
export GIT_OPTIONAL_TAG
if git describe --exact-match --tags; then
	GIT_OPTIONAL_TAG="${GIT_OPTIONAL_TAG:-$(git describe --exact-match --tags)}"
fi
export GIT_DESCRIBE_ALWAYS
GIT_DESCRIBE_ALWAYS="${GIT_DESCRIBE_ALWAYS:-$(git describe --always --tags)}"
export GIT_DESCRIBE_ALWAYS_LONG
GIT_DESCRIBE_ALWAYS_LONG="${GIT_DESCRIBE_ALWAYS_LONG:-$(git describe --always --tags --long)}"
export GIT_DESCRIBE_AAL
GIT_DESCRIBE_AAL="${GIT_DESCRIBE_AAL:-$(git describe --always --all --long)}"

# But let others override GIT_OPTIONAL_BRANCH, as HEAD might not have a symbolic ref, and it could crash
# I.e, provide GIT_OPTIONAL_BRANCH to this script in Travis - but NOT For 
export GIT_OPTIONAL_BRANCH
if git symbolic-ref --short HEAD; then 
	GIT_OPTIONAL_BRANCH="${GIT_OPTIONAL_BRANCH:-$(git symbolic-ref --short HEAD)}"
fi 
echo "Naming things... (using TRAVIS_TAG=${TRAVIS_TAG}, GIT_OPTIONAL_BRANCH=${GIT_OPTIONAL_BRANCH}, PACKAGE_SUFFIX=${PACKAGE_SUFFIX}, GIT_DESCRIBE_ALWAYS_LONG=${GIT_DESCRIBE_ALWAYS_LONG}, CI_SEQUENTIAL_BUILD_NUMBER=${CI_SEQUENTIAL_BUILD_NUMBER}, GIT_COMMIT_SHORT=$GIT_COMMIT_SHORT, GIT_COMMIT=$GIT_COMMIT, FETCH_COMMIT_SUFFIX=${FETCH_COMMIT_SUFFIX})"
################## NAMING THINGS ####################

export DELETE_UPLOAD_FOLDER="${DELETE_UPLOAD_FOLDER:-True}"

if [ "${TRAVIS_PULL_REQUEST}" == "false" ]; then

	if [ "${UPLOAD_BUILD}" == "True" ]; then


		#Put tagged commits in their own folder instead of using the branch name
		if [ -n "${TRAVIS_TAG}" ]; then
			export UPLOAD_DIR="releases/${TRAVIS_TAG}"
			export ARTIFACT_UPLOAD_PATH="${UPLOAD_DIR}/imageflow-${TRAVIS_TAG}-${GIT_COMMIT_SHORT}-${PACKAGE_SUFFIX}"
			export DOCS_UPLOAD_DIR="${UPLOAD_DIR}/doc"
			export ESTIMATED_DOCS_URL="${UPLOAD_URL}/${DOCS_UPLOAD_DIR}"
		else
			if [ -n "${GIT_OPTIONAL_BRANCH}" ]; then
				export ARTIFACT_UPLOAD_PATH="${GIT_OPTIONAL_BRANCH}/imageflow-nightly-${CI_SEQUENTIAL_BUILD_NUMBER}-${GIT_DESCRIBE_ALWAYS_LONG}-${PACKAGE_SUFFIX}"
			fi
		fi

		export ESTIMATED_ARTIFACT_URL="${UPLOAD_URL}/${ARTIFACT_UPLOAD_PATH}.tar.gz"

		if [ -n "${GIT_OPTIONAL_BRANCH}" ]; then
			export ARTIFACT_UPLOAD_PATH_2="${GIT_OPTIONAL_BRANCH}/imageflow-nightly-${PACKAGE_SUFFIX}"
			export ESTIMATED_ARTIFACT_URL_2="${UPLOAD_URL}/${ARTIFACT_UPLOAD_PATH_2}.tar.gz"

			export DOCS_UPLOAD_DIR_2="${GIT_OPTIONAL_BRANCH}/doc"
			export ESTIMATED_DOCS_URL_2="${UPLOAD_URL}/${DOCS_UPLOAD_DIR_2}"
			export ESTIMATED_DOCS_URL="${ESTIMATED_DOCS_URL:-${ESTIMATED_DOCS_URL_2}}"
		fi

		if [ -n "${FETCH_COMMIT_SUFFIX}" ]; then
			#Always upload by commit ID
			export ARTIFACT_UPLOAD_PATH_3="commits/${GIT_COMMIT}/${FETCH_COMMIT_SUFFIX}"
			export ESTIMATED_ARTIFACT_URL_3="${UPLOAD_URL}/${ARTIFACT_UPLOAD_PATH_3}.tar.gz"
		fi

		export DELETE_UPLOAD_FOLDER="False"

		export RUNTIME_REQUIREMENTS_FILE="./ci/packaging_extras/requirements/${PACKAGE_SUFFIX}.txt"
		if [ -f "$RUNTIME_REQUIREMENTS_FILE" ]; then
			echo "Using runtime requirements file ${RUNTIME_REQUIREMENTS_FILE}"
		else
			echo "Failed to locate a runtime requirements file for build variation ${PACKAGE_SUFFIX}"
			exit 1
		fi
	fi
	if [ "${UPLOAD_DOCS}" != "True" ]; then
		export ESTIMATED_DOCS_URL_2=
		export ESTIMATED_DOCS_URL=
	fi


fi
if [ "${DELETE_UPLOAD_FOLDER}" == "True" ]; then
	printf "\nSKIPPING UPLOAD\n"
else
	printf "\nUPLOAD_BUILD=%s, UPLOAD_DOCS=%s" "${UPLOAD_BUILD}" "${UPLOAD_DOCS}"
fi


printf "\n=================================================\n"
printf "\nEstimated upload URLs:\n\n%s\n\n%s\n\n" "${ESTIMATED_ARTIFACT_URL}" "${ESTIMATED_ARTIFACT_URL_2}" "${ESTIMATED_ARTIFACT_URL_3}"
printf "\nEstimated docs URLs:\n\n%s\n\n%s\n\n" "${ESTIMATED_DOCS_URL}" "${DOCS_UPLOAD_DIR_2}"
printf "\n=================================================\n"




########## Travis defaults ###################
export COVERAGE="${COVERAGE:-False}"
export VALGRIND="${VALGRIND:-False}"
export CLEAN_RUST_TARGETS="${CLEAN_RUST_TARGETS:-True}"

######################################################
#### Parameters passed through docker to build.sh (or used by travis_*.sh) ####

# Build docs; build release mode binaries (separate pass from testing); populate ./artifacts folder
export BUILD_RELEASE="${BUILD_RELEASE:-True}"
# Run all tests (both C and Rust) under Valgrind
export VALGRIND="${VALGRIND:-False}"
# Compile and run C tests
export TEST_C="${TEST_C:-True}"
# Build C Tests in debug mode for clearer valgrind output
export TEST_C_DEBUG_BUILD="${TEST_C_DEBUG_BUILD:${VALGRIND}}"
# Run Rust tests
export TEST_RUST="${TEST_RUST:-True}"
# Enables generated coverage information for the C portion of the code. 
# Also forces C tests to build in debug mode
export COVERAGE="${COVERAGE:-False}"
# travis_run_docker.sh uploads Coverage information when true
export COVERALLS="${COVERALLS}"
export COVERALLS_TOKEN="${COVERALLS_TOKEN}"

if [ -n "${TRAVIS_BUILD_DIR}" ]; then
  cd "${TRAVIS_BUILD_DIR}"
fi


DOCKER_ENV_VARS=(
  "-e"
	 "CI=${CI}"
	"-e"
	 "BUILD_RELEASE=${BUILD_RELEASE}"
	"-e"
	 "VALGRIND=${VALGRIND}" 
	"-e"
	 "TEST_C=${TEST_C}"
	"-e"
	 "TEST_C_DEBUG_BUILD=${TEST_C_DEBUG_BUILD}"
	"-e"
	 "TEST_RUST=${TEST_RUST}"
	"-e"
	 "CLEAN_RUST_TARGETS=${CLEAN_RUST_TARGETS}"
	"-e"
	 "IMAGEFLOW_SERVER=${IMAGEFLOW_SERVER}"
	"-e"
	 "COVERAGE=${COVERAGE}" 
	"-e"
	 "COVERALLS=${COVERALLS}" 
	"-e"
	 "COVERALLS_TOKEN=${COVERALLS_TOKEN}"
	"-e"
	 "DOCS_UPLOAD_DIR=${DOCS_UPLOAD_DIR}" 
	"-e"
	 "DOCS_UPLOAD_DIR_2=${DOCS_UPLOAD_DIR}" 
	"-e"
	 "ARTIFACT_UPLOAD_PATH=${ARTIFACT_UPLOAD_PATH}"  
	"-e"
	 "ARTIFACT_UPLOAD_PATH_2=${ARTIFACT_UPLOAD_PATH_2}" 
	"-e"
	 "ARTIFACT_UPLOAD_PATH_3=${ARTIFACT_UPLOAD_PATH_3}" 
    "-e"
	 "GIT_COMMIT=${GIT_COMMIT}" 
	"-e"
	 "GIT_COMMIT_SHORT=${GIT_COMMIT_SHORT}" 
	"-e"
	 "GIT_OPTIONAL_TAG=${GIT_OPTIONAL_TAG}" 
	"-e"
	 "GIT_DESCRIBE_ALWAYS=${GIT_DESCRIBE_ALWAYS}" 
	"-e"
	 "GIT_DESCRIBE_ALWAYS_LONG=${GIT_DESCRIBE_ALWAYS_LONG}" 
	 "-e"
	 "RUNTIME_REQUIREMENTS_FILE=${RUNTIME_REQUIREMENTS_FILE}"
	"-e"
	 "GIT_DESCRIBE_AAL=${GIT_DESCRIBE_AAL}" 
	"-e"
	 "GIT_OPTIONAL_BRANCH=${GIT_OPTIONAL_BRANCH}" 
	"-e"
	 "ESTIMATED_ARTIFACT_URL=${ESTIMATED_ARTIFACT_URL}" 
	"-e"
	 "ESTIMATED_DOCS_URL=${ESTIMATED_DOCS_URL}" 
	"-e"
	 "CI_SEQUENTIAL_BUILD_NUMBER=${CI_SEQUENTIAL_BUILD_NUMBER}" 
	"-e"
	 "CI_BUILD_URL=${CI_BUILD_URL}" 
	"-e"
	 "CI_JOB_URL=${CI_JOB_URL}" 
	"-e"
	 "CI_JOB_TITLE=${CI_JOB_TITLE}" 
	"-e"
	 "CI_STRING=${CI_STRING}" 
	"-e"
	 "CI_PULL_REQUEST_INFO=${CI_PULL_REQUEST_INFO}" 
	"-e"
	 "CI_TAG=${CI_TAG}" 
	"-e"
	 "CI_RELATED_BRANCH=${CI_RELATED_BRANCH}" 
)


echo 
echo "========================================================="
echo "Relevant dockered ENV VARS for build.sh: ${DOCKER_ENV_VARS[*]}"
echo "========================================================="
echo 
##############################


if [[ "$(uname -s)" == 'Darwin' && -z "$SIM_CI" ]]; then
	./ci/travis_run_osx.sh
else
	echo "===================================================================== [travis_run.sh]"
	echo "Launching docker SIM_CI=${SIM_CI}"
	echo

	DOCKER_COMMAND=(
			/bin/bash -c "./ci/travis_run_docker.sh"  
			)
	DOCKER_CACHE_VARS=(
		-v 
		"$HOME/.ccache:/home/conan/.ccache"
		-v 
		"$HOME/.conan/data:/home/conan/.conan/data"
	)
	DOCKER_INVOCATION=(docker run "--rm")

	if [[ "$SIM_CI" == 'True' ]]; then
		if [[ "$SIM_OPEN_BASH" == 'True' ]]; then
			DOCKER_COMMAND=(
			/bin/bash
			)
		fi
		DOCKER_CACHE_VARS=("${SIM_DOCKER_CACHE_VARS[@]}")

		export DOCKER_TTY_FLAG=
		if [[ -t 1 ]]; then
		  export DOCKER_TTY_FLAG="--tty"
		fi

		DOCKER_INVOCATION=(docker run "--interactive" "$DOCKER_TTY_FLAG" "--rm")
	fi

	set -x
	"${DOCKER_INVOCATION[@]}" -v "${TRAVIS_BUILD_DIR}:/home/conan/imageflow" "${DOCKER_CACHE_VARS[@]}" "${DOCKER_ENV_VARS[@]}" "${DOCKER_IMAGE}" "${DOCKER_COMMAND[@]}" 
	set +x
fi

if [[ "$DELETE_UPLOAD_FOLDER" == 'True' ]]; then
	echo -e "\nRemvoing all files scheduled for upload to s3\n\n"
	rm -rf ./artifacts/upload
	mkdir -p ./artifacts/upload
else
	echo -e "\nListing files scheduled for upload to s3\n\n"
	ls -R ./artifacts/upload/*
fi

#!/bin/sh
# Linux kernel self test

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOGFILE="${OUTPUT}/kselftest.txt"
TESTPROG="kselftest_armhf.tar.gz"
KSELFTEST_PATH="/opt/kselftests/mainline/"

SCRIPT="$(readlink -f "${0}")"
SCRIPTPATH="$(dirname "${SCRIPT}")"
# List of known unsupported test cases to be skipped
SKIPFILE=""
SKIPLIST=""
TESTPROG_URL=""

if [ "$(uname -m)" = "aarch64" ]
then
    TESTPROG="kselftest_aarch64.tar.gz"
fi

usage() {
    echo "Usage: $0 [-t kselftest_aarch64.tar.gz | kselftest_armhf.tar.gz]
                    [-s True|False]
                    [-u url]
                    [-p path]
                    [-L List of skip test cases]
                    [-S kselftest-skipfile]" 1>&2
    exit 1
}

while getopts "t:s:u:p:L:S:h" opt; do
    case "${opt}" in
        t) TESTPROG="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        # Download kselftest tarball from given URL
        u) TESTPROG_URL="${OPTARG}" ;;
        # List of known unsupported test cases to be skipped
        L) SKIPLIST="${OPTARG}" ;;
        p) KSELFTEST_PATH="${OPTARG}" ;;
        S)
           OPT=$(echo "${OPTARG}" | grep "http")
           if [ -z "${OPT}" ] ; then
           # kselftest skipfile
             SKIPFILE="${SCRIPTPATH}/${OPTARG}"
           else
           # Download kselftest skipfile from speficied URL
             wget "${OPTARG}" -O "skipfile"
             SKIPFILE="skipfile"
             SKIPFILE="${SCRIPTPATH}/${SKIPFILE}"
           fi
           ;;
        h|*) usage ;;
    esac
done

parse_output() {
    grep "selftests:" "${LOGFILE}" > "${RESULT_FILE}"
    sed -i -e 's/: /-/g' "${RESULT_FILE}"
    sed -i -e 's/\[//g' "${RESULT_FILE}"
    sed -i -e 's/]//g' "${RESULT_FILE}"
    sed -i -e 's/selftests-//g' "${RESULT_FILE}"
}

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
        debian|ubuntu) install_deps "sed wget xz-utils" "${SKIP_INSTALL}" ;;
        centos|fedora) install_deps "sed wget xz" "${SKIP_INSTALL}" ;;
        unknown) warn_msg "Unsupported distro: package install skipped" ;;
    esac
}

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"
# shellcheck disable=SC2164
cd "${OUTPUT}"

install

if [ -d "${KSELFTEST_PATH}" ]; then
    echo "kselftests found on rootfs"
    # shellcheck disable=SC2164
    cd "${KSELFTEST_PATH}"
else
    if [ -n "${TESTPROG_URL}" ]; then
      # Download kselftest tarball from given URL
      wget "${TESTPROG_URL}" -O kselftest.tar.gz
    elif [ -n "${TESTPROG}" ]; then
      # Download and extract kselftest tarball.
      wget http://testdata.validation.linaro.org/tests/kselftest/"${TESTPROG}" -O kselftest.tar.gz
    fi
    tar xf "kselftest.tar.gz"
    # shellcheck disable=SC2164
    cd "kselftest"
fi

if [ -n "${SKIPLIST}" ]; then
    # shellcheck disable=SC2086
    for test_name in ${SKIPLIST}; do
        # shellcheck disable=SC2086
        sed -i "/.\/${test_name}/c\echo \"selftests: ${test_name} [SKIP]\"" run_kselftest.sh
    done
fi

# Ignore SKIPFILE when SKIPLIST provided
if [ -f "${SKIPFILE}" ] &&  [ -z "${SKIPLIST}" ]; then
    while read -r test_name; do
        case "${test_name}" in \#*) continue ;; esac
        # shellcheck disable=SC2086
        sed -i "/.\/${test_name}/c\echo \"selftests: ${test_name} [SKIP]\"" run_kselftest.sh
    done < "${SKIPFILE}"
fi

# run_kselftest.sh file generated by kselftest Makefile and included in tarball
./run_kselftest.sh 2>&1 | tee "${LOGFILE}"
parse_output

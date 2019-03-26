#!/bin/bash

set -euo pipefail

echo "--- Pre-setup :bazel:"

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     platform="linux";;
    Darwin*)    platform="mac";;
    *)          exit 1
esac

if [[ "linux" == $platform ]]; then
  apt-get update -yy
  apt-get install -yy pkg-config zip g++ zlib1g-dev unzip python ruby
  CONFIG_OPTS="--config=buildfarm-sanitized-linux"
elif [[ "mac" == $platform ]]; then
  CONFIG_OPTS="--config=buildfarm-sanitized-mac"
fi

echo will run with $CONFIG_OPTS

git checkout .bazelrc
rm -f bazel-*
mkdir -p /usr/local/var/bazelcache/output-bases/test-pr /usr/local/var/bazelcache/build /usr/local/var/bazelcache/repos
echo 'common --curses=no --color=yes' >> .bazelrc
echo 'startup --output_base=/usr/local/var/bazelcache/output-bases/test-pr' >> .bazelrc
echo 'build  --disk_cache=/usr/local/var/bazelcache/build --repository_cache=/usr/local/var/bazelcache/repos' >> .bazelrc
echo 'test   --disk_cache=/usr/local/var/bazelcache/build --repository_cache=/usr/local/var/bazelcache/repos' >> .bazelrc

./bazel version

echo "--- compilation"
./bazel build //... $CONFIG_OPTS

echo "+++ tests"

err=0
./bazel test //... $CONFIG_OPTS || err=$?

rm -rf _out_
mkdir -p _out_/log/junit/

./bazel query 'tests(//...) except attr("tags", "manual", //...)' | while read -r line; do
    path="${line/://}"
    path="${path#//}"
    cp "bazel-testlogs/$path/test.xml" _out_/log/junit/"${path//\//_}-${BUILDKITE_JOB_ID}.xml"
done

if [ "$err" -ne 0 ]; then
    exit "$err"
fi

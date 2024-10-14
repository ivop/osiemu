#! /bin/sh

# RUN ME FROM THE ROOT DIRECTORY OF THE POJECT, LIKE:
#
# deploy/build.sh

set -e

DATE=$(date "+%Y%m%d")
VERSION=$(grep VERSION_STRING version.h | cut -d\" -f2 | cut -d' ' -f2)
BASE=$(pwd)
DEPLOY="$BASE/deploy"
COLLECT="$DEPLOY/osiemu-$VERSION"

printf "\nBUILDING OSIEMU\n\n"
printf "version: $VERSION\n\n"

make clean
make -j`nproc` release

printf "\nCOLLECTING FILES FOR DISTRIBUTION\n\n"
printf "Target directory: $COLLECT\n\n"

rm -rf "$COLLECT"
mkdir -p "$COLLECT"

cp -v osiemu.exe "$COLLECT"

cp -va basic config cpm65 kernel disks fonts icons launcher/settings "$COLLECT"
mkdir -p "$COLLECT/tapes" "$COLLECT/tests"
cp -va tapes/*.lod tapes/*.bas "$COLLECT/tapes"
cp -va tests/*.lod "$COLLECT/tests"

printf "\nCOLLECTING DLLs\n\n"

"$DEPLOY/collect-libs.sh" "$COLLECT/osiemu.exe" "$COLLECT"

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

printf "\nBUILDING OSIEMU-LAUNCHER\n\n"
printf "version: $VERSION\n\n"

make clean
make -j`nproc` osiemu-launcher.exe

printf "\nCOLLECTING FILES FOR DISTRIBUTION\n\n"
printf "Target directory: $COLLECT\n\n"

mkdir -p "$COLLECT"

cp -v osiemu-launcher.exe "$COLLECT"

printf "\nCOLLECTING DLLs\n\n"

"$DEPLOY/collect-libs.sh" "$COLLECT/osiemu-launcher.exe" "$COLLECT"
cd "$COLLECT"
windeployqt --no-translations --no-system-d3d-compiler --no-virtualkeyboard --no-webkit2 osiemu-launcher.exe
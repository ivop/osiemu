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
make -j`nproc` osiemu-launcher

printf "\nCOLLECTING FILES FOR DISTRIBUTION\n\n"
printf "Target directory: $COLLECT\n\n"

rm -rf "$COLLECT"
mkdir -p "$COLLECT"

cp -v osiemu "$COLLECT/osiemu.bin"
cp -v osiemu-launcher "$COLLECT/osiemu-launcher.bin"
cp -v "$DEPLOY/osiemu.sh" "$COLLECT/osiemu"
cp -v "$DEPLOY/osiemu-launcher.sh" "$COLLECT/osiemu-launcher"

cp -va basic config cpm65 kernel disks fonts icons launcher/settings "$COLLECT"
mkdir -p "$COLLECT/tapes" "$COLLECT/tests"
cp -va tapes/*.lod tapes/*.bas "$COLLECT/tapes"
cp -va tests/*.lod "$COLLECT/tests"

printf "\nCOLLECTING SHARED OBJECTS\n\n"

mkdir -p "$COLLECT/lib"

"$DEPLOY/collect-libs.sh" "$COLLECT/osiemu.bin" "$COLLECT/lib"
"$DEPLOY/collect-libs.sh" "$COLLECT/osiemu-launcher.bin" "$COLLECT/lib"

printf "\nCREATING TARBALLS\n\n"

tar cvzf osiemu-$VERSION.tar.gz -C "$DEPLOY" "$(basename "$COLLECT")"
tar cvjf osiemu-$VERSION.tar.bz2 -C "$DEPLOY" "$(basename "$COLLECT")"
tar cvJf osiemu-$VERSION.tar.xz -C "$DEPLOY" "$(basename "$COLLECT")"

rm -rf "$COLLECT"

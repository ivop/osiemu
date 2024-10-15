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

cp -v osiemu "$COLLECT"
cp -v osiemu-launcher "$COLLECT"

cp -va basic config cpm65 kernel disks fonts icons launcher/settings "$COLLECT"
mkdir -p "$COLLECT/tapes" "$COLLECT/tests"
cp -va tapes/*.lod tapes/*.bas "$COLLECT/tapes"
cp -va tests/*.lod "$COLLECT/tests"
cp -va LICENSE "$COLLECT"

printf "\nCOLLECTING SHARED OBJECTS\n\n"

mkdir -p "$COLLECT/lib"

# Path inside docker containter
LINUXDEPLOYQT=/linuxdeployqt/build/tools/linuxdeployqt/linuxdeployqt

cd "$COLLECT"
"$LINUXDEPLOYQT" osiemu -bundle-non-qt-libs \
                        -no-translations \
                        -no-copy-copyright-files
"$LINUXDEPLOYQT" osiemu-launcher -bundle-non-qt-libs \
                                 -no-translations \
                                 -no-copy-copyright-files
rm -f AppRun

printf "\nFORCING RPATH\n\n"

patchelf --force-rpath --set-rpath '$ORIGIN/lib' "$COLLECT/osiemu"
patchelf --force-rpath --set-rpath '$ORIGIN/lib' "$COLLECT/osiemu-launcher"

printf "\nCREATING TARBALLS\n\n"

cd "$BASE"
tar cvzf osiemu-$VERSION.tar.gz -C "$DEPLOY" "$(basename "$COLLECT")"
tar cvjf osiemu-$VERSION.tar.bz2 -C "$DEPLOY" "$(basename "$COLLECT")"
tar cvJf osiemu-$VERSION.tar.xz -C "$DEPLOY" "$(basename "$COLLECT")"

rm -rf "$COLLECT"

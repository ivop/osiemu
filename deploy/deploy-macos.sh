#! /bin/sh

# RUN ME FROM THE ROOT DIRECTORY OF THE POJECT, LIKE:
#
# deploy/deploy-macos.sh

set -e

PATH_TO_QT=~/Qt/5.15.2
PATH_TO_QT_BIN="$PATH_TO_QT/clang_64/bin"
PATH_TO_QT_LIB="$PATH_TO_QT/clang_64/lib"
PATH_TO_QT_PLUGINS="$PATH_TO_QT/clang_64/plugins"

MACPORTS=/opt/local

DATE=$(date "+%Y%m%d")
VERSION=$(grep VERSION_STRING version.h | cut -d\" -f2 | cut -d' ' -f2)
BASE=$(pwd)
DEPLOY="$BASE/deploy"
COLLECT="$DEPLOY/osiemu-$VERSION"

printf "\nBUILDING OSIEMU\n\n"
printf "version: $VERSION\n\n"

make clean
make -j`sysctl -n hw.ncpu` release

printf "\nBUILDING OSIEMU-LAUNCHER\n\n"

make -j`sysctl -n hw.ncpu` osiemu-launcher.app QMAKE="$PATH_TO_QT_BIN/qmake"

printf "\nCOLLECTING FILES FOR DISTRIBUTION\n\n"
printf "Target directory: $COLLECT\n\n"

rm -rf "$COLLECT"
mkdir -p "$COLLECT"

printf "*** run macdeployqt on launcher\n"

"$PATH_TO_QT_BIN/macdeployqt" "launcher/build/launcher.app"

printf "*** copy deployed app\n"

cp -a "launcher/build/launcher.app/Contents" "$COLLECT"

printf "*** copy osiemu\n"

MACOSDIR="$COLLECT/Contents/MacOS"

cp -v osiemu "$MACOSDIR"

cp -va basic config cpm65 kernel disks fonts icons launcher/settings "$MACOSDIR"
mkdir -p "$MACOSDIR/tapes" "$MACOSDIR/tests"
cp -va tapes/*.lod tapes/*.bas "$MACOSDIR/tapes"
cp -va tests/*.lod "$MACOSDIR/tests"
cp -va LICENSE "$COLLECT"

mkdir -p "$MACOSDIR/lib"

printf "*** copy osiemu dependencies\n"

for i in $(deploy/collect-libs-macos.py "$MACOSDIR/osiemu" "$MACPORTS/lib") ; do
    cp -aL "$i" "$MACOSDIR/lib"
done

printf "*** fix references in osiemu\n"

for i in $(otool -L "$MACOSDIR/osiemu" | grep "$MACPORTS" | awk '{ print $1 }') ; do
    j=$(basename "$i")
    install_name_tool -change "$i" "@executable_path/lib/x$j" "$MACOSDIR/osiemu"
done

printf "*** fix references in libraries\n"

# add x prefix to avoid confusion if MacPorts is
# installed, too, on the target machine

for i in "$MACOSDIR/lib"/* ; do
    for j in $(otool -L "$i" | grep "$MACPORTS" | awk '{ print $1 }') ; do
        k=$(basename "$j")
        install_name_tool -change "$j" "@loader_path/x$k" "$i"
    done
    k=$(basename "$i")
    install_name_tool -id "@loader_path/x$k" "$i"
    ( cd "$MACOSDIR/lib"; mv "$k" "x$k" )
done

printf "\nCREATING DMG IMAGE\n\n"

cd "$BASE"
hdiutil create osiemu-$VERSION.dmg -ov -volname "osiemu-$VERSION" -fs HFS+ -srcfolder "$COLLECT"

rm -rf "$COLLECT"

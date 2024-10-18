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

cp -v osiemu "$COLLECT"
cp -v osiemu-launcher.app "$COLLECT/osiemu-launcher"

cp -va basic config cpm65 kernel disks fonts icons launcher/settings "$COLLECT"
mkdir -p "$COLLECT/tapes" "$COLLECT/tests"
cp -va tapes/*.lod tapes/*.bas "$COLLECT/tapes"
cp -va tests/*.lod "$COLLECT/tests"
cp -va LICENSE "$COLLECT"

printf "\nCOLLECTING SHARED OBJECTS\n\n"

mkdir -p "$COLLECT/lib"

printf "*** copy osiemu dependencies\n"

for i in $(deploy/collect-libs-macos.py "$COLLECT/osiemu" "$MACPORTS/lib") ; do
    cp -aL "$i" "$COLLECT/lib"
done

printf "*** fix references in osiemu\n"

for i in $(otool -L "$COLLECT/osiemu" | grep "$MACPORTS" | awk '{ print $1 }') ; do
    j=$(basename "$i")
    install_name_tool -change "$i" "@executable_path/lib/x$j" "$COLLECT/osiemu"
done

printf "*** fix references in libraries\n"

# add x prefix to avoid confusion if MacPorts is
# installed, too, on the target machine

for i in "$COLLECT/lib"/* ; do
    for j in $(otool -L "$i" | grep "$MACPORTS" | awk '{ print $1 }') ; do
        k=$(basename "$j")
        install_name_tool -change "$j" "@loader_path/x$k" "$i"
    done
    k=$(basename "$i")
    install_name_tool -id "@loader_path/x$k" "$i"
    ( cd "$COLLECT/lib"; mv "$k" "x$k" )
done

printf "*** run macdeployqt\n"

"$PATH_TO_QT_BIN/macdeployqt" "launcher/build/launcher.app"

printf "*** copy deployed app\n"

cp -a "launcher/build/launcher.app/Contents" "$COLLECT/lib"
rm -rf "$COLLECT/lib/Contents/MacOS"

printf "*** fix rpath\n"

install_name_tool -delete_rpath "@executable_path/../Frameworks" osiemu-launcher.app
install_name_tool -add_rpath "@executable_path/lib/Contents/Frameworks" osiemu-launcher.app
cp osiemu-launcher.app "$COLLECT/osiemu-launcher"

#printf "*** copy qt.conf\n"
#cp "$DEPLOY/qt.conf" "$COLLECT"

exit 0

printf "\nCREATING TARBALLS\n\n"

cd "$BASE"
tar cvzf osiemu-$VERSION.tar.gz -C "$DEPLOY" "$(basename "$COLLECT")"
tar cvjf osiemu-$VERSION.tar.bz2 -C "$DEPLOY" "$(basename "$COLLECT")"
tar cvJf osiemu-$VERSION.tar.xz -C "$DEPLOY" "$(basename "$COLLECT")"

rm -rf "$COLLECT"

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

printf "\nCREATING ZIP-ARCHIVE\n\n"

cd "$COLLECT"
zip -9r "$BASE/osiemu-$VERSION.zip" *

cd "$BASE"
rm -rf "$COLLECT"

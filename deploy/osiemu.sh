#! /bin/sh

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd "$SCRIPTPATH"
LD_LIBRARY_PATH="$SCRIPTPATH/lib" "$SCRIPTPATH/osiemu.bin" "$@"

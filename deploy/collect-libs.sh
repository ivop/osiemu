#! /bin/sh

if [ "$#" != "2" ] ; then
    echo "usage: $0 <osiemu-binary> <destination-lib-directory>"
    exit 1
fi

if [ ! -x "$1" ] ; then
    echo "$0: argument 1 is not an executable"
    exit 1
fi

if [ ! -d "$2" ] ; then
    echo "$0: argument 2 is not a directory"
    exit 1
fi

for i in `ldd "$1" | grep = | cut -d'>' -f2 | cut -d'(' -f1 | grep -vi windows` ; do
    cp -vL "$i" "$2"
done

for i in `cat deploy/excludelist.txt` ; do
    rm -f "$2/$i"
done

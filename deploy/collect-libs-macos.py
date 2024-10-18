#! /usr/bin/python

import subprocess
import os
import sys

if len(sys.argv) != 3:
    print "\nusage: {} <executable> <rpath>\n".format(sys.argv[0])
    print "\tex. rpath=/opt/local/lib or rpath=/Users/user/Qt/5.15.2/clang_64/lib\n"
    sys.exit(1)

rpath=sys.argv[2]

def otool(s):
    o = subprocess.Popen(['/usr/bin/otool', '-L', s], stdout=subprocess.PIPE)
    for l in o.stdout:
        if l[0] == '\t':
            path = l.split(' ', 1)[0][1:]
            if "/System/Library" in path:
                continue
            if "/usr/lib" in path:
                continue
            if "@executable_path" in path:
                continue
            if "@loader_path" in path:
                continue
            if "@rpath" in path:
                path = path.replace("@rpath",rpath)
            yield path

need = set([sys.argv[1]])
done = set()

while need:
    needed = set(need)
    need = set()
    for f in needed:
        need.update(otool(f))
    done.update(needed)
    need.difference_update(done)

for f in sorted(done):
    if f != sys.argv[1]:
        print f

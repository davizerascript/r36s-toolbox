#!/usr/bin/env python3
import io
import tarfile
import sys

with tarfile.open(sys.argv[1], "w:gz") as archive:
    data = b"unsafe test\n"
    info = tarfile.TarInfo("../fora-do-root")
    info.size = len(data)
    archive.addfile(info, io.BytesIO(data))

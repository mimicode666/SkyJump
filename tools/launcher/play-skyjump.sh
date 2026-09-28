#!/bin/sh
set -eu
cd -- "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if [ ! -x ./SkyJump ]; then chmod u+x ./SkyJump; fi
exec ./SkyJump "$@"

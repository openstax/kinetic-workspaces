#!/usr/bin/env bash

set -e

SCRIPT_SRC='SCRIPT_XXXX_SCRIPT'
PAYLOAD='PAYLOAD_XXXX_PAYLOAD'

aws s3 cp $SCRIPT_SRC /tmp/build.js

export NODE_PATH=/usr/lib/node_modules

node /tmp/build.js "${PAYLOAD}"

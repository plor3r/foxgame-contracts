#!/bin/bash
set -x

sui move build --skip-fetch-latest-git-deps
sui client publish . --gas-budget 2000000000

sui client upgrade --gas-budget 2000000000 --upgrade-capability 0xb60989900d254ead4ba30af58a3f4e9c950900538f2eeb460d3b65868828fae4

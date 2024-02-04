#!/bin/bash
set -x

sui move build
sui client publish . --gas-budget 2000000000

# sui client upgrade --gas-budget 2000000000 --upgrade-capability 0x04149b81b172f900bb895b72496a428dce6d856936ff0c95d56abc50fd5892da

#!/bin/bash
set -x

sui move build
sui client publish . --gas-budget 30000

#export fox_game=0x5ba90c698ef2a3e3217c39cb8d70a1c8c9a93594
#sui client call --function mint --module fox --package ${fox_game} --args 0x2e2e79bc48525b91ac92b2ca99f642c58f57cdc5 --gas-budget 100000

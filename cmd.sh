#!/bin/bash
set -x

sui move build
sui client publish . --gas-budget 30000

export fox_game=0x50f62c80e711d9b55f70470ab9b81dc7ae9fcd4e
export global=0x5a531f9b3dd6b012c528fa256cc304f0b20ba96d
export egg_treasury=0x9807f522a48f6e53f83fead739c9c37ca3bf5981
sui client call --function mint --module fox --package ${fox_game} --args ${global} ${egg_treasury} \"2\" false --gas-budget 100000

export item=0x30cfc24cb8bd80211a2c0bef3b668f2d4923089d

sui client call --function add_many_to_barn_and_pack --module fox --package ${fox_game} --args ${global} \[${item}\] --gas-budget 100000
sui client call --function claim_many_to_barn_and_pack --module fox --package ${fox_game} --args ${global} ${item} --gas-budget 100000

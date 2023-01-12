#!/bin/bash
set -x

sui move build
sui client publish . --gas-budget 30000

export fox_game=0x274b29d86237c7634abef405d0a9b6c4309b7e91
export global=0x389d8913b016b7d34fdf9481bf6dd65f78bed63d
export egg_treasury=0x6dba1d1c4def1c33d11eaf7d55a80123ec1f9483
sui client call --function mint --module fox --package ${fox_game} --args ${global} ${egg_treasury} \"2\" false --gas-budget 100000

export item=0x8ec9a85831db6112017db5c1954725a2e3183fe0

sui client call --function add_many_to_barn_and_pack --module fox --package ${fox_game} --args ${global} \[${item}\] --gas-budget 100000
sui client call --function claim_many_from_barn_and_pack --module fox --package ${fox_game} --args ${global} '["${item}"]' --gas-budget 100000
sui client call --function claim_one_from_barn_and_pack --module fox --package ${fox_game} --args ${global} ${item} --gas-budget 100000


sui client call --function add_many_to_barn_and_pack --module fox --package ${fox_game} --args ${global} \[0x8ec9a85831db6112017db5c1954725a2e3183fe0,0x945f7f5b733a61df06aae3298f445c13e4db0944\] --gas-budget 100000

sui client call --function claim_many_from_barn_and_pack --module fox --package ${fox_game} --args ${global} '["0x8ec9a85831db6112017db5c1954725a2e3183fe0","0x945f7f5b733a61df06aae3298f445c13e4db0944"]' --gas-budget 100000

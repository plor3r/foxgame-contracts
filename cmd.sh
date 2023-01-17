#!/bin/bash
set -x

sui move build
sui client publish . --gas-budget 30000

export fox_game=0x41dc21b83f71008ce6e48c06eaafbc1c794e717b
export global=0xe91eabff018b5da868a9ae145b87fca906d88250
export egg_treasury=0x3137a7279d1a79fc3988e4d141547813989dd0de
sui client call --function mint --module fox --package ${fox_game} --args ${global} \"2\" false \[\] --gas-budget 100000
sui client call --function mint --module fox --package ${fox_game} --args ${global} ${egg_treasury} \"2\" false \[\] --gas-budget 100000

export item=0xa80bab2d68b2d70d1b1657de13333405e5a1f26f

sui client call --function add_many_to_barn_and_pack --module fox --package ${fox_game} --args ${global} \[${item}\] --gas-budget 100000
sui client call --function claim_many_from_barn_and_pack --module fox --package ${fox_game} --args ${global} '["${item}"]' false --gas-budget 100000
sui client call --function claim_one_from_barn_and_pack --module fox --package ${fox_game} --args ${global} ${item} false --gas-budget 100000


sui client call --function add_many_to_barn_and_pack --module fox --package ${fox_game} --args ${global} \[0x8ec9a85831db6112017db5c1954725a2e3183fe0,0x945f7f5b733a61df06aae3298f445c13e4db0944\] --gas-budget 100000

sui client call --function claim_many_from_barn_and_pack --module fox --package ${fox_game} --args ${global} '["0x8ec9a85831db6112017db5c1954725a2e3183fe0","0x945f7f5b733a61df06aae3298f445c13e4db0944"]' --gas-budget 100000

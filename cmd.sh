#!/bin/bash
set -x

sui move build
sui client publish . --gas-budget 30000

export fox_game=0x6958392f6f7e6d69fe0c611e89b30598df3c7638
export global=0xfe39b6e814134b1f63a0ee1af853f0250e4decb8
export egg_treasury=0x722f34f66b6b769baea00a7fb97030f8aa8a2b30
sui client call --function mint --module fox --package ${fox_game} --args ${global} ${egg_treasury} \"2\" false --gas-budget 100000

export item=0x4a8152b4e449350e59f5bed3d874730a1a18c135

sui client call --function add_many_to_barn_and_pack --module fox --package ${fox_game} --args ${global} \[${item}\] --gas-budget 100000
sui client call --function claim_many_from_barn_and_pack --module fox --package ${fox_game} --args ${global} \[${item}\] --gas-budget 100000
sui client call --function claim_many --module fox --package ${fox_game} --args ${global} \[${item}\] --gas-budget 100000
sui client call --function claim_one_from_barn_and_pack --module fox --package ${fox_game} --args ${global} ${item} --gas-budget 100000

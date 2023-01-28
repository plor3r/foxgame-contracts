#!/bin/bash
set -x

sui move build
sui client publish . --gas-budget 300000

export fox_game=0x59a85fbef4bc17cd73f8ff89d227fdcd6226c885
export global=0xe4ffefc480e20129ff7893d7fd550b17fda0ab0f
export egg_treasury=0x17db4feb4652b8b5ce9ebf6dc7d29463b08e234e
export time_cap=0xe364474bd00b7544b9393f0a2b0af2dbea143fd3

sui client call --function set_timestamp --module fox --package ${fox_game} --args ${time_cap} ${global} \"$(date +%s)\" --gas-budget 30000
sui client call --function mint --module fox --package ${fox_game} --args ${global} ${egg_treasury} \"1\" false \[0x3cd2bb1e03326e5141203cc008e6d2eb44a0df05\] \[\] --gas-budget 100000

export item=0x84fe8e597bcb9387b2911b5ef39b90bb111e71a2

sui client call --function add_many_to_barn_and_pack --module fox --package ${fox_game} --args ${global} \[${item}\] --gas-budget 100000
sui client call --function claim_many_from_barn_and_pack --module fox --package ${fox_game} --args ${global} ${egg_treasury} '["${item}"]' false --gas-budget 100000

#!/bin/bash
set -x

sui move build --skip-fetch-latest-git-deps
sui client publish . --gas-budget 2000000000

export fox_game=0xf825805fcdfa0e31acd55a393a5567c60eabcefeabf9049aa137156d6af6898b
export global=0x164dc95f9e781f74c0b26bfc5c83a32085667928a927168c9d462edc5716ebfd
export egg_treasury=0x8b6f8740d78d0661811bd40f5f088ba6b6a5603cbb07048aca109d3d4b918b41
export clock=0x0000000000000000000000000000000000000000000000000000000000000006

sui client call --function mint --module fox --package ${fox_game} --args ${global} ${egg_treasury} ${clock} \"1\" false \[0x07bb583f727e743b577ae1190c02eaeec3c08eba57732cf50491ad90b1324679\] \[\] --gas-budget 100000

export item=0x84fe8e597bcb9387b2911b5ef39b90bb111e71a2

sui client call --function add_many_to_barn_and_pack --module fox --package ${fox_game} --args ${global} \[${item}\] --gas-budget 100000
sui client call --function claim_many_from_barn_and_pack --module fox --package ${fox_game} --args ${global} ${egg_treasury} '["${item}"]' false --gas-budget 100000

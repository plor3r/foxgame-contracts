#!/bin/bash
set -x

sui move build
sui client publish . --gas-budget 30000

export fox_game=0xe565042f7efaf6c408eb67fd635055b7364951db
export foc_registry=0x9f5ee2b42375732304111d0e1a78314d774015cd
sui client call --function mint --module fox --package ${fox_game} --args ${foc_registry} --gas-budget 100000

export item=0x85ccb0c44a5e6fe16cc9041927f652f576d7ece6

export barn_registry=0xf2c11755be7a9f98db4d534b44cdbb73bc4ca3a3
export barn=0x5fe8230e20bdee41f13522f88c6a82ccbb664321
sui client call --function add_to_barn --module barn --package ${fox_game} --args ${barn} ${item} --gas-budget 100000
sui client call --function claim_from_barn --module barn --package ${fox_game} --args ${barn} ${item} --gas-budget 100000

export pack=0x049932eae3a54a8fe5134715ecbe8e22c073d316
sui client call --function add_to_pack --module barn --package ${fox_game} --args ${pack} ${item} --gas-budget 100000
sui client call --function claim_from_pack --module barn --package ${fox_game} --args ${pack} ${item} --gas-budget 100000

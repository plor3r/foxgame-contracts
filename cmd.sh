#!/bin/bash
set -x

sui move build
sui client publish . --gas-budget 30000

export fox_game=0x889f8dce3c6eaa80e528bdd4c3c1b4552595b7cb
export foc_registry=0xe711e606e294387fb47626b4bd2b8750d2fea274
sui client call --function mint --module fox --package ${fox_game} --args ${foc_registry} \"2\" false --gas-budget 100000

export item=0x54515bbd3ec302fdc9e16f7357e7001ecb26ea6e

export barn_registry=0xcf5e99e39cc22cbd4bb43b3a432e82fdc417b222
export barn=0xd48a9d45c43caef183b8b2658a7b519ec6407ae9
sui client call --function add_to_barn --module barn --package ${fox_game} --args ${barn} ${item} --gas-budget 100000
sui client call --function claim_from_barn --module barn --package ${fox_game} --args ${barn} ${item} --gas-budget 100000

export pack=0xe6155ee1710758d52c54d9f4c47ce051898ff842
sui client call --function add_to_pack --module barn --package ${fox_game} --args ${pack} ${item} --gas-budget 100000
sui client call --function claim_from_pack --module barn --package ${fox_game} --args ${pack} ${item} --gas-budget 100000

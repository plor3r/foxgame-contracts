module fox_game::egg {
    use std::option;
    use sui::transfer;
    use sui::tx_context::TxContext;
    use sui::balance;
    use sui::sui::SUI;
    use sui::clock::Clock;

    use fox_game::config;

    use smartinscription::tick_factory;
    use smartinscription::movescription::{Self, Movescription, TickRecordV2, DeployRecord};

    friend fox_game::fox;
    friend fox_game::barn;

    struct WITNESS has drop {}

    #[lint_allow(share_owned)]
    public(friend) fun deploy_egg_ins(
        deploy_record: &mut DeployRecord,
        tick_tick_record: &mut TickRecordV2,
        tick_name: Movescription,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let total_supply = config::max_eggs();
        let tick_record = tick_factory::do_deploy(
            deploy_record,
            tick_tick_record,
            tick_name,
            total_supply,
            true,
            WITNESS {},
            clock,
            ctx
        );
        // movescription::tick_record_add_df(&mut tick_record, factory, WITNESS{});
        transfer::public_share_object(tick_record);
    }

    public(friend) fun mint_egg_ins(
        tick_record: &mut TickRecordV2,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let ins = movescription::do_mint_with_witness(
            tick_record,
            balance::zero<SUI>(),
            amount,
            option::none(),
            WITNESS {},
            ctx
        );
        transfer::public_transfer(ins, recipient);
    }
}
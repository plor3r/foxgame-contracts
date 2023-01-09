module fox_game::fox {
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::transfer;

    use fox_game::config;
    use fox_game::token_helper::{Self, FoCRegistry};
    use fox_game::barn;

    fun init(ctx: &mut TxContext) {
        token_helper::initialize(ctx);
        barn::initialize(ctx);
    }

    public fun mint_cost(token_index: u64): u64 {
        if (token_index <= config::paid_tokens()) {
            return 0
        } else if (token_index <= config::max_tokens() * 2 / 5) {
            return 20000 * config::octas()
        } else if (token_index <= config::max_tokens() * 4 / 5) {
            return 40000 * config::octas()
        };
        80000 * config::octas()
    }

    /// mint a fox or chicken
    entry fun mint(reg: &mut FoCRegistry, ctx: &mut TxContext) {
        transfer(token_helper::create_foc(reg, ctx), sender(ctx));
    }
}
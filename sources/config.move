module fox_game::config {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    friend fox_game::fox;

    // Manager cap to set time
    struct TimeManagerCap has key, store { id: UID }

    public(friend) fun init_time_manager_cap(ctx: &mut TxContext): TimeManagerCap {
        TimeManagerCap { id: object::new(ctx) }
    }

    public fun paid_tokens(): u64 {
        100
    }

    public fun max_tokens(): u64 {
        10000
    }

    public fun octas(): u64 {
        1000000000
    }

    public fun max_single_mint(): u64 {
        10
    }

    public fun target_max_tokens(): u64 {
        50000
    }

    public fun mint_price(): u64 {
        // FIXME
        // 1 * octas()
        // 0.00099
        990000
    }

    public fun is_enabled(): bool {
        true
    }


}
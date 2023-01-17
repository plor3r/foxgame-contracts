module fox_game::config {

    public fun paid_tokens(): u64 {
        100
    }

    public fun max_tokens(): u64 {
        10000
    }

    public fun octas(): u64 {
        100000000
    }

    public fun max_single_mint(): u64 {
        10
    }
    public fun target_max_tokens(): u64 {
        50000
    }

    public fun mint_price(): u64 {
        // 1 * octas()
        1
    }

    public fun is_enabled(): bool {
        true
    }
}
module fox_game::config {
    friend fox_game::fox;

    public fun paid_tokens(): u64 {
        2000
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

    // MOVE
    public fun mint_price(): u64 {
        10000
    }

    public fun is_enabled(): bool {
        true
    }

    public fun max_eggs(): u64 {
        14000000
    }
}
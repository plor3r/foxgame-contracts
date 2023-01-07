module fox_game::fox {
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::transfer::transfer;
    use sui::bcs;

    use std::hash::sha3_256 as hash;
    use std::vector as vec;

    use fox_game::config;
    use fox_game::token_helper::{Self, Attribute, FoCRegistry};

    /// Custom attributes assigned randomly when a box is opened.
    const ATTRIBUTE_VALUES: vector<vector<u8>> = vector[
        b"snow globe",
        b"antlers",
        b"garland",
        b"beard",
    ];

    /// The name for custom attributes.
    const ATTRIBUTE_NAME: vector<u8> = b"special";

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

    /// Get a 'random' attribute based on a seed.
    ///
    /// For fun and exploration we get the number from the BCS bytes.
    /// This function demonstrates the way of getting a `u64` number
    /// from a vector of bytes.
    fun get_attribute(seed: &vector<u8>): Attribute {
        let bcs_bytes = bcs::new(hash(*seed));
        let attr_idx = bcs::peel_u64(&mut bcs_bytes) % vec::length(&ATTRIBUTE_VALUES); // get the index of the attribute
        let attr_value = *vec::borrow(&ATTRIBUTE_VALUES, attr_idx);

        token_helper::create_attribute(ATTRIBUTE_NAME, attr_value)
    }

    /// mint a fox or chicken
    entry fun mint(reg: &mut FoCRegistry, ctx: &mut TxContext) {
        transfer(token_helper::create_foc(reg, ctx), sender(ctx));
    }
}
module fox_game::egg {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::TxContext;

    friend fox_game::fox;
    friend fox_game::barn;

    struct EGG has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: EGG, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<EGG>(
            witness,
            9,
            b"EGG",
            b"Fox Game Egg",
            b"Fox game egg coin",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_share_object(treasury_cap);
    }

    /// Manager can mint new coins
    public(friend) fun mint(
        treasury_cap: &mut TreasuryCap<EGG>, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    }

    /// Manager can burn coins
    public(friend) fun burn(treasury_cap: &mut TreasuryCap<EGG>, coin: Coin<EGG>) {
        coin::burn(treasury_cap, coin);
    }
}
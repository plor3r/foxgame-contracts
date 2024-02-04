module fox_game::fox {
    use std::ascii::string;
    use std::hash::sha3_256 as hash;
    use std::option::{Self, Option};
    use std::vector;

    use sui::clock::{Self, Clock};
    use sui::coin::TreasuryCap;
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::{public_share_object, public_transfer};
    use sui::package;
    use sui::table::{Self, Table};
    use sui::balance;
    use sui::sui::SUI;

    use fox_game::config;
    use fox_game::token::{Self, FoCRegistry, FoxOrChicken};
    use fox_game::barn::{Self, Pack, Barn, BarnRegistry};
    use fox_game::egg::EGG;
    use fox_game::utf8_utils::to_vector;

    use smartinscription::movescription::{Self, Movescription, TickRecordV2};
    use smartinscription::content_type::{content_type_image_svg};
    use smartinscription::util::split_and_return_remain;

    /// The Naming Service contract is not enabled
    const ENOT_ENABLED: u64 = 1;
    const EALL_MINTED: u64 = 2;
    const EINVALID_MINTING: u64 = 3;
    const EInvalidMovescription: u64 = 4;

    /// One-Time-Witness for the module.
    struct FOX has drop {}

    struct WITNESS has drop {}

    struct Global has key, store {
        id: UID,
        minting_enabled: bool,
        treasury: Option<Movescription>,
        pack: Pack,
        barn: Barn,
        barn_registry: BarnRegistry,
        foc_registry: FoCRegistry,
        // movescription ID -> FoxOrChicken
        escrow: Table<ID, FoxOrChicken>,
        // FoxOrChicken ID -> Movescription
        stores: Table<ID, Movescription>,
    }

    fun init(otw: FOX, ctx: &mut TxContext) {
        let deployer = sender(ctx);
        public_transfer(token::init_foc_manage_cap(ctx), deployer);
        public_share_object(Global {
            id: object::new(ctx),
            minting_enabled: true,
            treasury: option::none(),
            barn_registry: barn::init_barn_registry(ctx),
            pack: barn::init_pack(ctx),
            barn: barn::init_barn(ctx),
            foc_registry: token::init_foc_registry(ctx),
            escrow: table::new(ctx),
            stores: table::new(ctx),
        });

        let publisher = package::claim(otw, ctx);
        let display = token::init_display(&publisher, ctx);
        public_transfer(publisher, deployer);
        public_transfer(display, deployer);
    }

    // Assertations

    fun assert_enabled(global: &Global) {
        assert!(global.minting_enabled, ENOT_ENABLED);
    }

    fun assert_valid_inscription(inscription: &Movescription, required_minimum: u64) {
        assert!(movescription::tick(inscription) == string(b"MOVE"), EInvalidMovescription);
        assert!(movescription::amount(inscription) >= required_minimum, EInvalidMovescription);
    }

    fun add_to_treasury(global: &mut Global, movescription: Movescription) {
        if (option::is_some(&global.treasury)) {
            movescription::merge(option::borrow_mut(&mut global.treasury), movescription);
        } else {
            option::fill(&mut global.treasury, movescription);
        };
    }

    fun add_ins_to_stores(
        global: &mut Global,
        token_id: ID,
        movescription: Movescription
    ) {
        table::add(&mut global.stores, token_id, movescription);
    }

    fun add_token_to_escrow(
        global: &mut Global,
        ins_id: ID,
        token: FoxOrChicken
    ) {
        table::add(&mut global.escrow, ins_id, token);
    }

    fun mint_ins_with_token(
        tick_record: &mut TickRecordV2,
        token: &FoxOrChicken,
        locked_move: Movescription,
        ctx: &mut TxContext
    ): Movescription {
        // name_tick_record: &mut TickRecordV2,
        let url = token::token_url_bytes(token);
        let metadata = movescription::new_metadata(content_type_image_svg(), url);
        let ins = movescription::do_mint_with_witness(
            tick_record,
            balance::zero<SUI>(),
            1,
            option::some(metadata),
            WITNESS {},
            ctx
        );
        movescription::lock_within(&mut ins, locked_move);
        ins
    }

    fun retrieve_ins_with_token_id(
        global: &mut Global,
        id: ID,
    ): Movescription {
        assert!(table::contains(&global.stores, id), 1);
        let ins = table::remove(&mut global.stores, id);
        ins
    }

    fun retrieve_token_with_ins_id(
        global: &mut Global,
        id: ID,
    ): FoxOrChicken {
        assert!(table::contains(&global.escrow, id), 1);
        let token = table::remove(&mut global.escrow, id);
        token
    }

    fun retrieve_token(
        global: &mut Global,
        inscription: Movescription,
    ): FoxOrChicken {
        let id = object::id(&inscription);
        assert!(table::contains(&global.escrow, id), 1);
        let token = table::remove(&mut global.escrow, id);
        let token_id = object::id(&token);
        add_ins_to_stores(global, token_id, inscription);
        token
    }

    fun retrieve_tokens(
        global: &mut Global,
        inscriptions: vector<Movescription>,
    ): vector<FoxOrChicken> {
        let tokens = vector::empty();
        let length = vector::length(&inscriptions);
        while (length > 0) {
            let inscription = vector::pop_back(&mut inscriptions);
            let token = retrieve_token(global, inscription);
            vector::push_back(&mut tokens, token);
            length = length - 1;
        };
        vector::destroy_empty(inscriptions);
        tokens
    }

    // mint a fox or chicken
    #[lint_allow(self_transfer)]
    public entry fun mint(
        global: &mut Global,
        tick_record: &mut TickRecordV2,
        amount: u64,
        stake: bool,
        paid_move: Movescription,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert_enabled(global);

        assert!(amount > 0 && amount <= config::max_single_mint(), EINVALID_MINTING);
        let token_supply = token::total_supply(&global.foc_registry);
        assert!(token_supply + amount <= config::max_tokens(), EALL_MINTED);

        let minter = sender(ctx);

        // currently only for paid_tokens
        if (token_supply < config::paid_tokens()) {
            assert!(token_supply + amount <= config::paid_tokens(), EALL_MINTED);
            let price = mint_cost(token_supply) * amount;
            assert_valid_inscription(&paid_move, price);
            // return extra movescription
            let move_amount = movescription::amount(&paid_move);
            if (move_amount > price) {
                let return_amount = move_amount - price;
                let remainder = movescription::do_split(&mut paid_move, return_amount, ctx);
                public_transfer(remainder, sender(ctx));
            };
            // transfer extra move to treasury
            let base_price = amount * config::mint_price();
            if (price > base_price) {
                let treasury_move = movescription::do_split(&mut paid_move, price - base_price, ctx);
                add_to_treasury(global, treasury_move);
            };
        } else {
            // return extra movescription
            public_transfer(paid_move, sender(ctx));
            return
        };

        // mint token with movescription
        // FIXME: random seed
        let id = object::new(ctx);
        let hash_seed = object::uid_to_bytes(&id);
        vector::append(&mut hash_seed, to_vector(clock::timestamp_ms(clock)));
        let seed = hash(hash_seed);
        object::delete(id);
        let tokens: vector<FoxOrChicken> = vector::empty<FoxOrChicken>();
        let i = 0;
        while (i < amount - 1) {
            let token_index = token_supply + i + 1;

            let recipient = minter;
            if (token_index > config::paid_tokens()) {
                recipient = select_recipient(&mut global.pack, minter, seed);
            };

            let move_to_lock = movescription::do_split(&mut paid_move, config::mint_price(), ctx);
            let the_token = token::create_foc(&mut global.foc_registry, ctx);
            let foc_ins = mint_ins_with_token(tick_record, &the_token, move_to_lock, ctx);

            if (!stake) {
                add_token_to_escrow(global, object::id(&foc_ins), the_token);
                public_transfer(foc_ins, recipient);
            } else {
                add_ins_to_stores(global, object::id(&the_token), foc_ins);
                vector::push_back(&mut tokens, the_token);
            };
            i = i + 1;
        };
        // the last one
        let token_index = token_supply + 1;
        let recipient = minter;
        if (token_index > config::paid_tokens()) {
            recipient = select_recipient(&mut global.pack, minter, seed);
        };
        let the_token = token::create_foc(&mut global.foc_registry, ctx);
        let foc_ins = mint_ins_with_token(tick_record, &the_token, paid_move, ctx);
        if (!stake) {
            add_token_to_escrow(global, object::id(&foc_ins), the_token);
            public_transfer(foc_ins, recipient);
        } else {
            add_ins_to_stores(global, object::id(&the_token), foc_ins);
            vector::push_back(&mut tokens, the_token);
        };

        if (stake) {
            barn::stake_many_to_barn_and_pack(
                &mut global.barn_registry,
                &mut global.barn,
                &mut global.pack,
                clock,
                tokens,
                ctx
            );
        } else {
            vector::destroy_empty(tokens);
        };
    }

    public entry fun add_many_to_barn_and_pack(
        global: &mut Global,
        ins: vector<Movescription>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert_enabled(global);
        let tokens = retrieve_tokens(global, ins);
        barn::stake_many_to_barn_and_pack(
            &mut global.barn_registry,
            &mut global.barn,
            &mut global.pack,
            clock,
            tokens,
            ctx
        );
    }

    public entry fun claim_many_from_barn_and_pack(
        global: &mut Global,
        egg_treasury_cap: &mut TreasuryCap<EGG>,
        tokens: vector<ID>, // token ID
        unstake: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert_enabled(global);
        let focs = barn::claim_many_from_barn_and_pack(
            &mut global.foc_registry,
            &mut global.barn_registry,
            &mut global.barn,
            &mut global.pack,
            egg_treasury_cap,
            clock,
            tokens,
            unstake,
            ctx
        );
        let i = vector::length(&focs);
        while (i > 0) {
            let token = vector::pop_back(&mut focs);
            let ins = retrieve_ins_with_token_id(global, object::id(&token));
            add_token_to_escrow(global, object::id(&ins), token);
            public_transfer(ins, sender(ctx));
        };
        vector::destroy_empty(focs);
    }

    #[lint_allow(self_transfer)]
    public entry fun burn(
        global: &mut Global,
        tick_record: &mut TickRecordV2,
        inscription: Movescription,
        ctx: &mut TxContext
    ) {
        assert_enabled(global);
        burn_one(global, tick_record, inscription, ctx);
    }

    #[lint_allow(self_transfer)]
    public entry fun burn_many(
        global: &mut Global,
        tick_record: &mut TickRecordV2,
        inscriptions: vector<Movescription>,
        ctx: &mut TxContext
    ) {
        assert_enabled(global);
        let i = vector::length(&inscriptions);
        while (i > 0) {
            let inscription = vector::pop_back(&mut inscriptions);
            burn_one(global, tick_record, inscription, ctx);
            i = i - 1;
        };
        vector::destroy_empty(inscriptions);
    }

    #[lint_allow(self_transfer)]
    fun burn_one(global: &mut Global, tick_record: &mut TickRecordV2, inscription: Movescription, ctx: &mut TxContext) {
        let id = object::id(&inscription);
        let foc = retrieve_token_with_ins_id(global, id);
        // destroy foc
        token::burn_foc(&mut global.foc_registry, foc, ctx);
        // destroy ins and return fee
        let (locked_sui, locked_move) = movescription::do_burn_with_witness(
            tick_record,
            inscription,
            b"burn",
            WITNESS {},
            ctx
        );
        let remain = charge_fee(global, locked_move, 500, ctx);
        if (option::is_some(&remain)) {
            public_transfer(option::destroy_some(remain), sender(ctx));
        }else {
            option::destroy_none(remain);
        };
        public_transfer(locked_sui, sender(ctx));
    }

    fun charge_fee(
        global: &mut Global,
        locked_move: Option<Movescription>,
        fee: u64,
        ctx: &mut TxContext
    ): Option<Movescription> {
        if (option::is_some(&locked_move)) {
            let locked_move = option::destroy_some(locked_move);
            let (fee_move, remain) = split_and_return_remain(locked_move, fee, ctx);
            add_to_treasury(global, fee_move);
            remain
        }else {
            locked_move
        }
    }

    // the first 20% go to the minter
    // the remaining 80% have a 10% chance to be given to a random staked fox
    fun select_recipient(pack: &mut Pack, minter: address, seed: vector<u8>): address {
        let rand = *vector::borrow(&seed, 0) % 10;
        if (rand > 0)
            return minter;
        let thief = barn::random_fox_owner(pack, seed);
        if (thief == @0x0) return minter;
        return thief
    }

    public fun mint_cost(token_index: u64): u64 {
        if (token_index <= config::paid_tokens()) {
            return config::mint_price()
        } else if (token_index <= config::max_tokens() * 2 / 5) {
            return 110 * config::mint_price() / 100
        } else if (token_index <= config::max_tokens() * 4 / 5) {
            return 120 * config::mint_price() / 100
        };
        140 * config::mint_price() / 100
    }
}
module fox_game::barn {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{TxContext, sender};
    use sui::table::{Self, Table};
    use sui::object_table::{Self, ObjectTable};
    use sui::event::emit;
    use sui::dynamic_field as dof;
    use sui::clock::{Self, Clock};

    use std::option::{Self, Option};
    use std::vector as vec;
    use std::hash::sha3_256 as hash;

    use fox_game::token::{Self, FoxOrChicken, FoCRegistry, alpha_for_fox, alpha_for_fox_from_id};
    use fox_game::random;
    use fox_game::egg;

    use smartinscription::movescription::TickRecordV2;

    friend fox_game::fox;

    // maximum alpha score for a fox
    const MAX_ALPHA: u8 = 8;
    // sheep earn 10 $EGG per day
    // FIXME
    const DAILY_EGG_RATE: u64 = 10000;
    // chicken must have 2 days worth of $EGG to unstake or else it's too cold
    // FIXME: 2 days, 2 * 86400000, currently 5 minutes
    const MINIMUM_TO_EXIT: u64 = 300000;
    const ONE_DAY_IN_SECOND: u64 = 86400000;
    // foxes take a 20% tax on all $EGG claimed
    const EGG_CLAIM_TAX_PERCENTAGE: u64 = 20;
    // there will only ever be (roughly) 5 billion $EGG earned through staking
    const MAXIMUM_GLOBAL_EGG: u64 = 5000000000;

    //
    // Errors
    //
    const ENOT_IN_PACK_OR_BARN: u64 = 1;
    /// For when someone tries to unstake without ownership.
    const EINVALID_OWNER: u64 = 2;
    const ESTILL_COLD: u64 = 3;

    struct BarnRegistry has key, store {
        id: UID,
        // amount of $WOOL earned so far
        total_egg_earned: u64,
        // number of Sheep staked in the Barn
        total_chicken_staked: u64,
        // the last time $WOOL was claimed
        last_claim_timestamp: u64,
        // total alpha scores staked
        total_alpha_staked: u64,
        // any rewards distributed when no foxes are staked
        unaccounted_rewards: u64,
        // amount of $EGG due for each alpha point staked
        egg_per_alpha: u64,
        // timestamp
        timestamp: u64,
    }

    // struct to store a stake's token, owner, and earning values
    struct Stake has key, store {
        id: UID,
        item: FoxOrChicken,
        value: u64,
        owner: address,
    }

    struct Barn has key, store {
        id: UID,
        items: ObjectTable<ID, Stake>,
        // staked: Table<address, vector<ID>>, // address -> stake_id
    }

    struct Pack has key, store {
        id: UID,
        items: ObjectTable<u8, ObjectTable<u64, Stake>>,
        // alpha -> index -> Stake
        item_size: vector<u64>,
        // size for each alpha
        pack_indices: Table<ID, u64>,
        // staked: Table<address, vector<ID>>, // address -> stake_id
    }

    // Events
    struct BarnRegistryCreated has copy, drop { id: ID }

    struct PackCreated has copy, drop { id: ID }

    struct BarnCreated has copy, drop { id: ID }

    struct FoCStaked has copy, drop {
        owner: address,
        id: ID,
        value: u64,
    }

    struct FoCClaimed has copy, drop {
        id: ID,
        earned: u64,
        unstake: bool,
    }

    public fun init_barn_registry(ctx: &mut TxContext): BarnRegistry {
        let id = object::new(ctx);
        emit(BarnRegistryCreated { id: object::uid_to_inner(&id) });
        BarnRegistry {
            id,
            total_egg_earned: 0,
            total_chicken_staked: 0,
            last_claim_timestamp: 0,
            total_alpha_staked: 0,
            unaccounted_rewards: 0,
            egg_per_alpha: 0,
            timestamp: 0,
        }
    }

    public fun init_pack(ctx: &mut TxContext): Pack {
        let id = object::new(ctx);
        emit(PackCreated { id: object::uid_to_inner(&id) });
        Pack {
            id,
            items: object_table::new(ctx),
            item_size: vector[0, 0, 0, 0], // alpha is 5,6,7,8
            pack_indices: table::new(ctx),
            // staked: table::new(ctx),
        }
    }

    public fun init_barn(ctx: &mut TxContext): Barn {
        let id = object::new(ctx);
        emit(BarnCreated { id: object::uid_to_inner(&id) });
        Barn {
            id,
            items: object_table::new(ctx),
            // staked: table::new(ctx),
        }
    }

    fun record_staked(staked: &mut UID, account: address, stake_id: ID) {
        if (dof::exists_(staked, account)) {
            vec::push_back(dof::borrow_mut(staked, account), stake_id);
        } else {
            dof::add(staked, account, vec::singleton(stake_id));
        };
    }

    fun remove_staked(staked: &mut UID, account: address, stake_id: ID) {
        if (dof::exists_(staked, account)) {
            let list = dof::borrow_mut(staked, account);
            let (is_in, index) = vec::index_of(list, &stake_id);
            if (is_in) {
                vec::remove(list, index);
            };
        };
    }

    public fun stake_many_to_barn_and_pack(
        reg: &mut BarnRegistry,
        barn: &mut Barn,
        pack: &mut Pack,
        clock: &Clock,
        tokens: vector<FoxOrChicken>,
        ctx: &mut TxContext,
    ) {
        let i = vec::length<FoxOrChicken>(&tokens);
        while (i > 0) {
            let the_token = vec::pop_back(&mut tokens);
            if (token::is_chicken(&the_token)) {
                update_earnings(reg, clock);
                stake_chicken_to_barn(reg, barn, clock, the_token, ctx);
            } else {
                stake_fox_to_pack(reg, pack, clock, the_token, ctx);
            };
            i = i - 1;
        };
        vec::destroy_empty(tokens)
    }

    public fun claim_many_from_barn_and_pack(
        foc_reg: &mut FoCRegistry,
        reg: &mut BarnRegistry,
        barn: &mut Barn,
        pack: &mut Pack,
        egg_tick_record: &mut TickRecordV2,
        clock: &Clock,
        tokens: vector<ID>,
        unstake: bool,
        ctx: &mut TxContext,
    ): vector<FoxOrChicken> {
        update_earnings(reg, clock);
        let i = vec::length<ID>(&tokens);
        let focs = vec::empty<FoxOrChicken>();
        let owed: u64 = 0;
        while (i > 0) {
            let token_id = vec::pop_back(&mut tokens);
            if (token::is_chicken_from_id(foc_reg, token_id)) {
                let (the_owed, foc) = claim_chicken_from_barn(reg, barn, clock, token_id, unstake, ctx);
                owed = owed + the_owed;
                if (option::is_some(&foc)) {
                    vec::push_back(&mut focs, option::destroy_some(foc));
                } else {
                    option::destroy_none(foc);
                };
            } else {
                let (the_owed, foc) = claim_fox_from_pack(foc_reg, reg, pack, token_id, unstake, ctx);
                owed = owed + the_owed;
                if (option::is_some(&foc)) {
                    vec::push_back(&mut focs, option::destroy_some(foc));
                } else {
                    option::destroy_none(foc);
                };
            };
            i = i - 1;
        };
        vec::destroy_empty(tokens);
        if (owed == 0) { return focs };
        egg::mint_egg_ins(egg_tick_record, owed, sender(ctx), ctx);
        focs
    }

    fun stake_chicken_to_barn(
        reg: &mut BarnRegistry,
        barn: &mut Barn,
        clock: &Clock,
        item: FoxOrChicken,
        ctx: &mut TxContext
    ) {
        reg.total_chicken_staked = reg.total_chicken_staked + 1;
        let stake_id = add_chicken_to_barn(barn, clock, item, ctx);
        record_staked(&mut barn.id, sender(ctx), stake_id);
    }

    fun stake_fox_to_pack(
        reg: &mut BarnRegistry,
        pack: &mut Pack,
        clock: &Clock,
        item: FoxOrChicken,
        ctx: &mut TxContext
    ) {
        let alpha = alpha_for_fox(&item);
        reg.total_alpha_staked = reg.total_alpha_staked + (alpha as u64);
        let stake_id = add_fox_to_pack(pack, clock, item, ctx);
        record_staked(&mut pack.id, sender(ctx), stake_id);
    }

    #[lint_allow(self_transfer)]
    fun claim_chicken_from_barn(
        reg: &mut BarnRegistry,
        barn: &mut Barn,
        clock: &Clock,
        foc_id: ID,
        unstake: bool,
        ctx: &mut TxContext
    ): (u64, Option<FoxOrChicken>) {
        assert!(object_table::contains(&barn.items, foc_id), ENOT_IN_PACK_OR_BARN);
        let owner = get_chicken_stake_owner(barn, foc_id);
        assert!(sender(ctx) == owner, EINVALID_OWNER);
        let stake_time = get_chicken_stake_value(barn, foc_id);
        let timenow = timestamp_now(clock);
        assert!(!(unstake && timenow - stake_time < MINIMUM_TO_EXIT), ESTILL_COLD);
        let owed: u64;
        if (reg.total_egg_earned < MAXIMUM_GLOBAL_EGG) {
            owed = (timenow - stake_time) * DAILY_EGG_RATE / ONE_DAY_IN_SECOND;
        } else if (stake_time > reg.last_claim_timestamp) {
            owed = 0; // $WOOL production stopped already
        } else {
            // stop earning additional $WOOL if it's all been earned
            owed = (reg.last_claim_timestamp - stake_time) * DAILY_EGG_RATE / ONE_DAY_IN_SECOND;
        };
        let foc_item = option::none();
        if (unstake) {
            let id = object::new(ctx);
            // FIXME
            if (random::rand_u64_range_with_seed(hash(object::uid_to_bytes(&id)), 0, 2) == 0) {
                // 50% chance of all $EGG stolen
                pay_fox_tax(reg, owed);
                owed = 0;
            };
            object::delete(id);
            reg.total_chicken_staked = reg.total_chicken_staked - 1;
            let (item, stake_id) = remove_chicken_from_barn(barn, foc_id, ctx);
            remove_staked(&mut barn.id, sender(ctx), stake_id);
            option::fill(&mut foc_item, item);
        } else {
            // percentage tax to staked foxes
            pay_fox_tax(reg, owed * EGG_CLAIM_TAX_PERCENTAGE / 100);
            // remainder goes to Chicken owner
            owed = owed * (100 - EGG_CLAIM_TAX_PERCENTAGE) / 100;
            // reset stake
            set_chicken_stake_value(barn, foc_id, timenow);
        };
        emit(FoCClaimed { id: foc_id, earned: owed, unstake });
        (owed, foc_item)
    }

    #[lint_allow(self_transfer)]
    fun claim_fox_from_pack(
        foc_reg: &mut FoCRegistry,
        reg: &mut BarnRegistry,
        pack: &mut Pack,
        foc_id: ID,
        unstake: bool,
        ctx: &TxContext
    ): (u64, Option<FoxOrChicken>) {
        assert!(table::contains(&pack.pack_indices, foc_id), ENOT_IN_PACK_OR_BARN);
        let alpha = alpha_for_fox_from_id(foc_reg, foc_id);
        assert!(object_table::contains(&pack.items, alpha), ENOT_IN_PACK_OR_BARN);
        let owner = get_fox_stake_owner(pack, alpha, foc_id);
        assert!(sender(ctx) == owner, EINVALID_OWNER);
        let stake_value = get_fox_stake_value(pack, alpha, foc_id);
        // Calculate portion of tokens based on Alpha
        let owed = (alpha as u64) * (reg.egg_per_alpha - stake_value);
        let foc_item = option::none();
        if (unstake) {
            // Remove Alpha from total staked
            reg.total_alpha_staked = reg.total_alpha_staked - (alpha as u64);
            let (item, stake_id) = remove_fox_from_pack(pack, alpha, foc_id, ctx);
            remove_staked(&mut pack.id, sender(ctx), stake_id);
            option::fill(&mut foc_item, item);
        } else {
            set_fox_stake_value(pack, alpha, foc_id, reg.egg_per_alpha);
        };
        emit(FoCClaimed { id: foc_id, earned: 0, unstake });
        (owed, foc_item)
    }

    fun add_chicken_to_barn(
        barn: &mut Barn,
        clock: &Clock,
        item: FoxOrChicken,
        ctx: &mut TxContext
    ): ID {
        let foc_id = object::id(&item);
        let value = timestamp_now(clock);
        let stake = Stake {
            id: object::new(ctx),
            item,
            value,
            owner: sender(ctx),
        };
        let stake_id = object::id(&stake);
        emit(FoCStaked { id: foc_id, owner: sender(ctx), value });
        object_table::add(&mut barn.items, foc_id, stake);
        stake_id
    }

    fun add_fox_to_pack(pack: &mut Pack, clock: &Clock, foc: FoxOrChicken, ctx: &mut TxContext): ID {
        let foc_id = object::id(&foc);
        let value = timestamp_now(clock);
        let alpha = alpha_for_fox(&foc);
        let stake = Stake {
            id: object::new(ctx),
            item: foc,
            value,
            owner: sender(ctx),
        };
        let stake_id = object::id(&stake);
        if (!object_table::contains(&pack.items, alpha)) {
            object_table::add(&mut pack.items, alpha, object_table::new(ctx));
        };
        let pack_items = object_table::borrow_mut(&mut pack.items, alpha);
        let cur = vec::borrow_mut(&mut pack.item_size, (alpha as u64) - 5);
        object_table::add(pack_items, *cur, stake);
        // Store the location of the fox in the Pack
        table::add(&mut pack.pack_indices, foc_id, *cur);

        *cur = *cur + 1;

        emit(FoCStaked { id: foc_id, owner: sender(ctx), value });
        stake_id
    }

    fun remove_chicken_from_barn(barn: &mut Barn, foc_id: ID, ctx: &TxContext): (FoxOrChicken, ID) {
        let Stake { id, item, value: _, owner } = object_table::remove(&mut barn.items, foc_id);
        let stake_id = object::uid_to_inner(&id);
        assert!(sender(ctx) == owner, EINVALID_OWNER);
        object::delete(id);
        (item, stake_id)
    }

    fun remove_fox_from_pack(pack: &mut Pack, alpha: u8, foc_id: ID, ctx: &TxContext): (FoxOrChicken, ID) {
        let pack_items = object_table::borrow_mut(&mut pack.items, alpha);
        // get the index
        let stake_index = table::remove(&mut pack.pack_indices, foc_id);
        let cur = vec::borrow_mut(&mut pack.item_size, (alpha as u64) - 5);

        let last_stake_index = *cur - 1;
        let Stake { id, item, value: _, owner } = object_table::remove(pack_items, stake_index);
        assert!(sender(ctx) == owner, EINVALID_OWNER);
        if (stake_index != last_stake_index) {
            let last_stake = object_table::remove(pack_items, last_stake_index);
            // update index for swapped token
            let last_foc_id = object::id(&last_stake.item);
            table::remove(&mut pack.pack_indices, last_foc_id);
            table::add(&mut pack.pack_indices, last_foc_id, stake_index);
            // insert back last_stake
            object_table::add(pack_items, stake_index, last_stake);
        };
        *cur = *cur - 1;

        let stake_id = object::uid_to_inner(&id);
        object::delete(id);
        (item, stake_id)
    }

    fun get_chicken_stake_owner(barn: &Barn, foc_id: ID): address {
        let stake = object_table::borrow(&barn.items, foc_id);
        stake.owner
    }

    fun get_chicken_stake_value(barn: &Barn, foc_id: ID): u64 {
        let stake = object_table::borrow(&barn.items, foc_id);
        stake.value
    }

    fun set_chicken_stake_value(barn: &mut Barn, foc_id: ID, new_value: u64) {
        let stake = object_table::borrow_mut(&mut barn.items, foc_id);
        stake.value = new_value;
    }

    fun get_fox_stake_owner(pack: &Pack, alpha: u8, foc_id: ID): address {
        let items = object_table::borrow(&pack.items, alpha);
        let stake_index = *table::borrow(&pack.pack_indices, foc_id);
        let stake = object_table::borrow(items, stake_index);
        stake.owner
    }

    fun get_fox_stake_value(pack: &Pack, alpha: u8, foc_id: ID): u64 {
        let items = object_table::borrow(&pack.items, alpha);
        let stake_index = *table::borrow(&pack.pack_indices, foc_id);
        let stake = object_table::borrow(items, stake_index);
        stake.value
    }

    fun set_fox_stake_value(pack: &mut Pack, alpha: u8, foc_id: ID, new_value: u64) {
        let items = object_table::borrow_mut(&mut pack.items, alpha);
        let stake_index = *table::borrow(&pack.pack_indices, foc_id);
        let stake = object_table::borrow_mut(items, stake_index);
        stake.value = new_value;
    }

    // chooses a random fox thief when a newly minted token is stolen
    public fun random_fox_owner(pack: &mut Pack, seed: vector<u8>): address {
        let total_alpha_staked = 10;
        if (total_alpha_staked == 0) {
            return @0x0
        };
        let bucket = random::rand_u64_range_with_seed(seed, 0, total_alpha_staked);
        let cumulative: u64 = 0;
        // loop through each bucket of foxes with the same alpha score
        let i = MAX_ALPHA - 3;
        while (i <= MAX_ALPHA) {
            let foxes = object_table::borrow(&pack.items, i);
            let foxes_length = *vec::borrow_mut(&mut pack.item_size, (i as u64) - 5);
            cumulative = cumulative + foxes_length * (i as u64);
            // if the value is not inside of that bucket, keep going
            if (bucket < cumulative) {
                // get the address of a random fox with that alpha score
                return object_table::borrow(foxes, random::rand_u64_with_seed(seed) % foxes_length).owner
            };
            i = i + 1;
        };
        @0x0
    }

    // tracks $EGG earnings to ensure it stops once 1.4 million is eclipsed
    // FIXME use timestamp instead of epoch once sui team has supported timestamp
    // currently epoch will be update about every 24 hours,
    fun update_earnings(reg: &mut BarnRegistry, clock: &Clock) {
        let timenow = timestamp_now(clock);
        if (reg.total_egg_earned < MAXIMUM_GLOBAL_EGG) {
            reg.total_egg_earned = reg.total_egg_earned +
                (timenow - reg.last_claim_timestamp)
                    * reg.total_chicken_staked / ONE_DAY_IN_SECOND * DAILY_EGG_RATE;
            reg.last_claim_timestamp = timenow;
        };
    }

    fun timestamp_now(clock: &Clock): u64 {
        clock::timestamp_ms(clock)
    }

    // add $WOOL to claimable pot for the Pack
    fun pay_fox_tax(reg: &mut BarnRegistry, amount: u64) {
        if (reg.total_alpha_staked == 0) {
            // if there's no staked foxed
            // keep track of $EGG due to foxes
            reg.unaccounted_rewards = reg.unaccounted_rewards + amount;
            return
        };
        // makes sure to include any unaccounted $EGG
        reg.egg_per_alpha = reg.egg_per_alpha +
            (amount + reg.unaccounted_rewards) / reg.total_alpha_staked;
        reg.unaccounted_rewards = 0;
    }

    #[test]
    fun test_remove_fox_from_pack() {
        use sui::test_scenario;
        use sui::transfer;
        use sui::clock::{Self, Clock};

        let dummy = @0xcafe;
        let admin = @0xBABE;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        let ctx = test_scenario::ctx(scenario);
        clock::create_for_testing(ctx);
        {
            transfer::share_object(token::init_foc_registry(ctx));
            transfer::share_object(init_pack(ctx));
        };
        test_scenario::next_tx(scenario, dummy);
        {
            let clock = test_scenario::take_shared<Clock>(&scenario_val);
            clock::increment_for_testing(&mut clock, 20);
            let foc_registry = test_scenario::take_shared<FoCRegistry>(scenario);
            let item = token::create_foc(&mut foc_registry, ctx);
            let item_id = object::id(&item);
            let pack = test_scenario::take_shared<Pack>(scenario);
            add_fox_to_pack(&mut pack, &clock, item, ctx);

            assert!(table::contains(&pack.pack_indices, item_id), 1);
            let alpha = alpha_for_fox(&item);

            let item_out = remove_fox_from_pack(&mut pack, alpha, item_id, ctx);
            assert!(!table::contains(&pack.pack_indices, item_id), 1);

            public_transfer(item_out, dummy);
            test_scenario::return_shared(foc_registry);
            test_scenario::return_shared(pack);
        };
        test_scenario::end(scenario_val);
    }
}
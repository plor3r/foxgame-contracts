module fox_game::barn {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::transfer;
    use sui::table::{Self, Table};
    use sui::object_table::{Self, ObjectTable};
    use sui::event::emit;
    use sui::coin::TreasuryCap;
    use sui::dynamic_field as dof;

    use std::vector as vec;
    use std::hash::sha3_256 as hash;

    use fox_game::token_helper::{Self, FoxOrChicken};
    use fox_game::random;
    use fox_game::egg::{Self, EGG};
    #[test_only]
    use fox_game::token_helper::{FoCRegistry, alpha_for_fox};

    friend fox_game::fox;

    // maximum alpha score for a fox
    const MAX_ALPHA: u8 = 8;
    // sheep earn 10 $EGG per day
    // FIXME
    const DAILY_EGG_RATE: u64 = 10000 * 1000000000;
    // chicken must have 2 days worth of $EGG to unstake or else it's too cold
    // FIXME
    // const MINIMUM_TO_EXIT: u64 = 2 * 86400;
    // TEST
    const MINIMUM_TO_EXIT: u64 = 600;
    const ONE_DAY_IN_SECOND: u64 = 86400;
    // foxes take a 20% tax on all $EGG claimed
    const EGG_CLAIM_TAX_PERCENTAGE: u64 = 20;
    // there will only ever be (roughly) 1.4 million $EGG earned through staking
    const MAXIMUM_GLOBAL_EGG: u64 = 1400000 * 1000000000;

    //
    // Errors
    //
    const EALPHA_NOT_STAKED: u64 = 1;
    const ENOT_IN_PACK_OR_BARN: u64 = 2;
    const EINVALID_CALLER: u64 = 3;
    /// For when someone tries to unstake without ownership.
    const EINVALID_OWNER: u64 = 4;
    const ESTILL_COLD: u64 = 5;

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
        // fake_timestamp
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
        items: Table<u8, vector<Stake>>,
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
            items: table::new(ctx),
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
        tokens: vector<FoxOrChicken>,
        ctx: &mut TxContext,
    ) {
        let i = vec::length<FoxOrChicken>(&tokens);
        while (i > 0) {
            let token = vec::pop_back(&mut tokens);
            if (token_helper::is_chicken(object::id(&token))) {
                update_earnings(reg, ctx);
                stake_chicken_to_barn(reg, barn, token, ctx);
            } else {
                stake_fox_to_pack(reg, pack, token, ctx);
            };
            i = i - 1;
        };
        vec::destroy_empty(tokens)
    }

    public fun claim_many_from_barn_and_pack(
        reg: &mut BarnRegistry,
        barn: &mut Barn,
        pack: &mut Pack,
        treasury_cap: &mut TreasuryCap<EGG>,
        tokens: vector<ID>,
        unstake: bool,
        ctx: &mut TxContext,
    ) {
        update_earnings(reg, ctx);
        let i = vec::length<ID>(&tokens);
        let owed: u64 = 0;
        while (i > 0) {
            let token_id = vec::pop_back(&mut tokens);
            if (token_helper::is_chicken(token_id)) {
                owed = owed + claim_chicken_from_barn(reg, barn, token_id, unstake, ctx);
            } else {
                owed = owed + claim_fox_from_pack(reg, pack, token_id, unstake, ctx);
            };
            i = i - 1;
        };
        if (owed == 0) { return };
        egg::mint(treasury_cap, owed, sender(ctx), ctx);
        vec::destroy_empty(tokens)
    }

    fun stake_chicken_to_barn(reg: &mut BarnRegistry, barn: &mut Barn, item: FoxOrChicken, ctx: &mut TxContext) {
        reg.total_chicken_staked = reg.total_chicken_staked + 1;
        let stake_id = add_chicken_to_barn(reg, barn, item, ctx);
        record_staked(&mut barn.id, sender(ctx), stake_id);
    }

    fun stake_fox_to_pack(reg: &mut BarnRegistry, pack: &mut Pack, item: FoxOrChicken, ctx: &mut TxContext) {
        let alpha = token_helper::alpha_for_fox();
        reg.total_alpha_staked = reg.total_alpha_staked + (alpha as u64);
        let stake_id = add_fox_to_pack(reg, pack, item, ctx);
        record_staked(&mut pack.id, sender(ctx), stake_id);
    }

    fun claim_chicken_from_barn(
        reg: &mut BarnRegistry,
        barn: &mut Barn,
        foc_id: ID,
        unstake: bool,
        ctx: &mut TxContext
    ): u64 {
        assert!(object_table::contains(&barn.items, foc_id), ENOT_IN_PACK_OR_BARN);
        let stake_time = get_chicken_stake_value(barn, foc_id);
        let timenow = timestamp_now(reg, ctx);
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
        if (unstake) {
            let id = object::new(ctx);
            if (random::rand_u64_range_with_seed(hash(object::uid_to_bytes(&id)), 0, 2) == 0) {
                // 50% chance of all $EGG stolen
                pay_fox_tax(reg, owed);
                owed = 0;
            };
            object::delete(id);
            reg.total_chicken_staked = reg.total_chicken_staked - 1;
            let (item, stake_id) = remove_chicken_from_barn(barn, foc_id, ctx);
            remove_staked(&mut barn.id, sender(ctx), stake_id);
            transfer::transfer(item, sender(ctx));
        } else {
            // percentage tax to staked foxes
            pay_fox_tax(reg, owed * EGG_CLAIM_TAX_PERCENTAGE / 100);
            // remainder goes to Chicken owner
            owed = owed * (100 - EGG_CLAIM_TAX_PERCENTAGE) / 100;
            // reset stake
            set_chicken_stake_value(barn, foc_id, timenow);
        };
        emit(FoCClaimed { id: foc_id, earned: owed, unstake });
        owed
    }

    fun claim_fox_from_pack(
        reg: &mut BarnRegistry,
        pack: &mut Pack,
        foc_id: ID,
        unstake: bool,
        ctx: &mut TxContext
    ): u64 {
        assert!(table::contains(&pack.pack_indices, foc_id), ENOT_IN_PACK_OR_BARN);
        // TODO get alpha from foc_id
        let alpha = token_helper::alpha_for_fox();
        assert!(table::contains(&pack.items, alpha), ENOT_IN_PACK_OR_BARN);

        let stake_value = get_fox_stake_value(pack, alpha, foc_id);
        // Calculate portion of tokens based on Alpha
        let owed = (alpha as u64) * (reg.egg_per_alpha - stake_value);
        if (unstake) {
            // Remove Alpha from total staked
            reg.total_alpha_staked = reg.total_alpha_staked - (alpha as u64);
            let (item, stake_id) = remove_fox_from_pack(pack, alpha, foc_id, ctx);
            remove_staked(&mut pack.id, sender(ctx), stake_id);
            transfer::transfer(item, sender(ctx));
        } else {
            set_fox_stake_value(pack, alpha, foc_id, reg.egg_per_alpha);
        };
        emit(FoCClaimed { id: foc_id, earned: 0, unstake });
        owed
    }

    fun add_chicken_to_barn(reg: &mut BarnRegistry, barn: &mut Barn, item: FoxOrChicken, ctx: &mut TxContext): ID {
        let foc_id = object::id(&item);
        let value = timestamp_now(reg, ctx);
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

    fun add_fox_to_pack(reg: &mut BarnRegistry, pack: &mut Pack, foc: FoxOrChicken, ctx: &mut TxContext): ID {
        let foc_id = object::id(&foc);
        let value = timestamp_now(reg, ctx);
        let stake = Stake {
            id: object::new(ctx),
            item: foc,
            value,
            owner: sender(ctx),
        };
        let stake_id = object::id(&stake);
        let alpha = token_helper::alpha_for_fox();
        if (!table::contains(&mut pack.items, alpha)) {
            table::add(&mut pack.items, alpha, vec::empty());
        };
        let pack_items = table::borrow_mut(&mut pack.items, alpha);
        vec::push_back(pack_items, stake);

        // Store the location of the fox in the Pack
        let token_index = vec::length(pack_items) - 1;
        table::add(&mut pack.pack_indices, foc_id, token_index);
        emit(FoCStaked { id: foc_id, owner: sender(ctx), value });
        stake_id
    }

    fun remove_chicken_from_barn(barn: &mut Barn, foc_id: ID, ctx: &mut TxContext): (FoxOrChicken, ID) {
        let Stake { id, item, value: _, owner } = object_table::remove(&mut barn.items, foc_id);
        let stake_id = object::uid_to_inner(&id);
        assert!(tx_context::sender(ctx) == owner, EINVALID_OWNER);
        object::delete(id);
        (item, stake_id)
    }

    fun remove_fox_from_pack(pack: &mut Pack, alpha: u8, foc_id: ID, ctx: &mut TxContext): (FoxOrChicken, ID) {
        let pack_items = table::borrow_mut(&mut pack.items, alpha);
        // get the index
        let stake_index = table::remove(&mut pack.pack_indices, foc_id);

        let last_stake_index = vec::length(pack_items) - 1;
        if (stake_index != last_stake_index) {
            let last_stake = vec::borrow(pack_items, last_stake_index);
            // update index for swapped token
            let last_foc_id = object::id(&last_stake.item);
            table::remove(&mut pack.pack_indices, last_foc_id);
            table::add(&mut pack.pack_indices, last_foc_id, stake_index);
            // swap last token to current token location and then pop
            vec::swap(pack_items, stake_index, last_stake_index);
        };

        let Stake { id, item, value: _, owner } = vec::pop_back(pack_items);
        assert!(tx_context::sender(ctx) == owner, EINVALID_OWNER);
        let stake_id = object::uid_to_inner(&id);
        object::delete(id);
        (item, stake_id)
    }

    fun get_chicken_stake_value(barn: &mut Barn, foc_id: ID): u64 {
        let stake = object_table::borrow(&barn.items, foc_id);
        stake.value
    }

    fun set_chicken_stake_value(barn: &mut Barn, foc_id: ID, new_value: u64) {
        let stake = object_table::borrow_mut(&mut barn.items, foc_id);
        stake.value = new_value;
    }

    fun get_fox_stake_value(pack: &mut Pack, alpha: u8, foc_id: ID): u64 {
        let items = table::borrow(&pack.items, alpha);
        let stake_index = *table::borrow(&pack.pack_indices, foc_id);
        let stake = vec::borrow(items, stake_index);
        stake.value
    }

    fun set_fox_stake_value(pack: &mut Pack, alpha: u8, foc_id: ID, new_value: u64) {
        let items = table::borrow_mut(&mut pack.items, alpha);
        let stake_index = *table::borrow(&pack.pack_indices, foc_id);
        let stake = vec::borrow_mut(items, stake_index);
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
            let foxes = table::borrow(&pack.items, i);
            let foxes_length = vec::length(foxes);
            cumulative = cumulative + foxes_length * (i as u64);
            // if the value is not inside of that bucket, keep going
            if (bucket < cumulative) {
                // get the address of a random fox with that alpha score
                return vec::borrow(foxes, random::rand_u64_with_seed(seed) % foxes_length).owner
            };
            i = i + 1;
        };
        @0x0
    }

    // tracks $EGG earnings to ensure it stops once 1.4 million is eclipsed
    // FIXME use timestamp instead of epoch once sui team has supported timestamp
    // currently epoch will be update about every 24 hours,
    fun update_earnings(reg: &mut BarnRegistry, ctx: &mut TxContext) {
        let timenow = timestamp_now(reg, ctx);
        if (reg.total_egg_earned < MAXIMUM_GLOBAL_EGG) {
            reg.total_egg_earned = reg.total_egg_earned +
                (timenow - reg.last_claim_timestamp)
                    * reg.total_chicken_staked / ONE_DAY_IN_SECOND * DAILY_EGG_RATE;
            reg.last_claim_timestamp = timenow;
        };
    }

    public(friend) fun set_timestamp(reg: &mut BarnRegistry, current: u64, _ctx: &mut TxContext) {
        reg.timestamp = current;
    }

    fun timestamp_now(reg: &mut BarnRegistry, _ctx: &mut TxContext): u64 {
        reg.timestamp
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

        let dummy = @0xcafe;
        let admin = @0xBABE;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            transfer::share_object(token_helper::init_foc_registry(test_scenario::ctx(scenario)));
            transfer::share_object(init_pack(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, dummy);
        {
            let foc_registry = test_scenario::take_shared<FoCRegistry>(scenario);
            let item = token_helper::create_foc(&mut foc_registry, test_scenario::ctx(scenario));
            let item_id = object::id(&item);
            let pack = test_scenario::take_shared<Pack>(scenario);
            let barn_reg = init_barn_registry(test_scenario::ctx(scenario));
            add_fox_to_pack(&mut barn_reg, &mut pack, item, test_scenario::ctx(scenario));

            assert!(table::contains(&pack.pack_indices, item_id), 1);
            let alpha = alpha_for_fox();

            let item_out = remove_fox_from_pack(&mut pack, alpha, item_id, test_scenario::ctx(scenario));
            assert!(!table::contains(&pack.pack_indices, item_id), 1);

            transfer::transfer(item_out, dummy);
            test_scenario::return_shared(foc_registry);
            test_scenario::return_shared(pack);
        };
        test_scenario::end(scenario_val);
    }
}
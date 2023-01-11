module fox_game::token_helper {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::url::{Self, Url};
    use sui::event::emit;
    // use sui::dynamic_object_field as dof;

    use std::vector as vec;
    use std::string::{Self, String};
    use std::hash::sha3_256 as hash;

    use fox_game::utf8_utils::{to_string, to_vector};

    friend fox_game::fox;
    friend fox_game::barn;

    /// Base path for `FoxOrChicken.url` attribute. Is temporary and improves
    /// explorer / wallet display. Always points to the dev/testnet server.
    const IMAGE_URL: vector<u8> = b"https://wolfgame.s3.amazonaws.com/";

    /// Link to the Fox or Chicken on the website.
    /// FIXME
    const MAIN_URL: vector<u8> = b"https://wolfgameaptos.xyz/";

    /// Defines a Fox or Chicken attribute. Eg: `pattern: 'panda'`
    struct Attribute has store, copy, drop {
        name: String,
        value: String,
    }

    struct FoxOrChicken has key, store {
        id: UID,
        index: u64,
        url: Url,
        link: Url,
        item_count: u8,
        attributes: vector<Attribute>,
    }

    /// Belongs to the creator of the game. Has store, which
    /// allows building something on top of it (ie shared object with
    /// multi-access policy for managers).
    struct FoCManagerCap has key, store { id: UID }

    /// Every capybara is registered here. Acts as a source of randomness
    /// as well as the storage for the main information about the gamestate.
    struct FoCRegistry has key, store {
        id: UID,
        foc_born: u64,
        foc_hash: vector<u8>,
        rarities: vector<vector<u8>>,
        aliases: vector<vector<u8>>,
    }

    // ======= Types =======

    struct Traits has drop {
        is_chicken: bool,
        fur: u8,
        head: u8,
        ears: u8,
        eyes: u8,
        nose: u8,
        mouth: u8,
        neck: u8,
        feet: u8,
        alpha_index: u8,
    }

    fun generate(): (vector<vector<u8>>, vector<vector<u8>>) {
        let rarities: vector<vector<u8>> = vec::empty();
        let aliases: vector<vector<u8>> = vec::empty();
        // I know this looks weird but it saves users gas by making lookup O(1)
        // A.J. Walker's Alias Algorithm
        // fur
        vec::push_back(&mut rarities, vector[15, 50, 200, 250, 255]);
        vec::push_back(&mut aliases, vector[4, 4, 4, 4, 4]);
        // head
        vec::push_back(
            &mut rarities,
            vector[190, 215, 240, 100, 110, 135, 160, 185, 80, 210, 235, 240, 80, 80, 100, 100, 100, 245, 250, 255]
        );
        vec::push_back(&mut aliases, vector[1, 2, 4, 0, 5, 6, 7, 9, 0, 10, 11, 17, 0, 0, 0, 0, 4, 18, 19, 19]);
        // ears
        vec::push_back(&mut rarities, vector[255, 30, 60, 60, 150, 156]);
        vec::push_back(&mut aliases, vector[0, 0, 0, 0, 0, 0]);
        // eyes
        vec::push_back(
            &mut rarities,
            vector[221, 100, 181, 140, 224, 147, 84, 228, 140, 224, 250, 160, 241, 207, 173, 84, 254, 220, 196, 140, 168, 252, 140, 183, 236, 252, 224, 255]
        );
        vec::push_back(
            &mut aliases,
            vector[1, 2, 5, 0, 1, 7, 1, 10, 5, 10, 11, 12, 13, 14, 16, 11, 17, 23, 13, 14, 17, 23, 23, 24, 27, 27, 27, 27]
        );
        // nose
        vec::push_back(&mut rarities, vector[175, 100, 40, 250, 115, 100, 185, 175, 180, 255]);
        vec::push_back(&mut aliases, vector[3, 0, 4, 6, 6, 7, 8, 8, 9, 9]);
        // mouth
        vec::push_back(
            &mut rarities,
            vector[80, 225, 227, 228, 112, 240, 64, 160, 167, 217, 171, 64, 240, 126, 80, 255]
        );
        vec::push_back(&mut aliases, vector[1, 2, 3, 8, 2, 8, 8, 9, 9, 10, 13, 10, 13, 15, 13, 15]);
        // neck
        vec::push_back(&mut rarities, vector[255]);
        vec::push_back(&mut aliases, vector[0]);
        // feet
        vec::push_back(
            &mut rarities,
            vector[243, 189, 133, 133, 57, 95, 152, 135, 133, 57, 222, 168, 57, 57, 38, 114, 114, 114, 255]
        );
        vec::push_back(&mut aliases, vector[1, 7, 0, 0, 0, 0, 0, 10, 0, 0, 11, 18, 0, 0, 0, 1, 7, 11, 18]);
        // alphaIndex
        vec::push_back(&mut rarities, vector[255]);
        vec::push_back(&mut aliases, vector[0]);

        // wolves
        // fur
        vec::push_back(&mut rarities, vector[210, 90, 9, 9, 9, 150, 9, 255, 9]);
        vec::push_back(&mut aliases, vector[5, 0, 0, 5, 5, 7, 5, 7, 5]);
        // head
        vec::push_back(&mut rarities, vector[255]);
        vec::push_back(&mut aliases, vector[0]);
        // ears
        vec::push_back(&mut rarities, vector[255]);
        vec::push_back(&mut aliases, vector[0]);
        // eyes
        vec::push_back(
            &mut rarities,
            vector[135, 177, 219, 141, 183, 225, 147, 189, 231, 135, 135, 135, 135, 246, 150, 150, 156, 165, 171, 180, 186, 195, 201, 210, 243, 252, 255]
        );
        vec::push_back(
            &mut aliases,
            vector[1, 2, 3, 4, 5, 6, 7, 8, 13, 3, 6, 14, 15, 16, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 26, 26]
        );
        // nose
        vec::push_back(&mut rarities, vector[255]);
        vec::push_back(&mut aliases, vector[0]);
        // mouth
        vec::push_back(&mut rarities, vector[239, 244, 249, 234, 234, 234, 234, 234, 234, 234, 130, 255, 247]);
        vec::push_back(&mut aliases, vector[1, 2, 11, 0, 11, 11, 11, 11, 11, 11, 11, 11, 11]);
        // neck
        vec::push_back(&mut rarities, vector[75, 180, 165, 120, 60, 150, 105, 195, 45, 225, 75, 45, 195, 120, 255]);
        vec::push_back(&mut aliases, vector[1, 9, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 14, 12, 14]);
        // feet
        vec::push_back(&mut rarities, vector[255]);
        vec::push_back(&mut aliases, vector[0]);
        // alphaIndex
        vec::push_back(&mut rarities, vector[8, 160, 73, 255]);
        vec::push_back(&mut aliases, vector[2, 3, 3, 3]);

        (rarities, aliases)
    }

    // ======== Events ========

    /// Event. When a new registry has been created.
    /// Marks the start of the game.
    struct RegistryCreated has copy, drop { id: ID }

    /// Event. When new FoC is born.
    struct FoCBorn has copy, drop {
        id: ID,
        index: u64,
        attributes: vector<Attribute>,
        created_by: address
    }

    // ======== Functions =========

    public(friend) fun init_foc_manage_cap(ctx: &mut TxContext): FoCManagerCap {
        FoCManagerCap { id: object::new(ctx) }
    }

    public fun init_foc_registry(ctx: &mut TxContext): FoCRegistry {
        let id = object::new(ctx);
        let foc_hash = hash(object::uid_to_bytes(&id));
        let (rarities, aliases) = generate();
        emit(RegistryCreated { id: object::uid_to_inner(&id) });
        FoCRegistry {
            id,
            foc_hash,
            foc_born: 0,
            rarities,
            aliases,
        }
    }

    /// Construct an image URL for the capy.
    fun img_url(c: u64, is_chicken: bool): Url {
        let capy_url = *&IMAGE_URL;
        if (is_chicken) {
            vec::append(&mut capy_url, b"sheep/");
        } else {
            vec::append(&mut capy_url, b"wolf/");
        };
        vec::append(&mut capy_url, to_vector(c));
        vec::append(&mut capy_url, b".svg");

        url::new_unsafe_from_bytes(capy_url)
    }

    /// Construct a Url to the capy.art.
    fun link_url(c: u64, _is_chicken: bool): Url {
        let capy_url = *&MAIN_URL;
        vec::append(&mut capy_url, to_vector(c));
        url::new_unsafe_from_bytes(capy_url)
    }

    public fun alpha_for_fox(): u8 {
        7
    }

    public fun total_supply(reg: &FoCRegistry): u64 {
        reg.foc_born
    }

    public fun is_chicken(_item_id: ID): bool {
        false
    }

    /// Create a Capy with a specified gene sequence.
    /// Also allows assigning custom attributes if an App is authorized to do it.
    public(friend) fun create_foc(
        reg: &mut FoCRegistry, ctx: &mut TxContext
    ): FoxOrChicken {
        let id = object::new(ctx);
        reg.foc_born = reg.foc_born + 1;

        vec::append(&mut reg.foc_hash, object::uid_to_bytes(&id));
        reg.foc_hash = hash(reg.foc_hash);

        let fc = generate_traits(reg);

        let attributes = get_attributes(&fc);

        emit(FoCBorn {
            id: object::uid_to_inner(&id),
            index: reg.foc_born,
            attributes: *&attributes,
            created_by: tx_context::sender(ctx),
        });

        FoxOrChicken {
            id,
            index: reg.foc_born,
            url: img_url(reg.foc_born, fc.is_chicken),
            link: link_url(reg.foc_born, fc.is_chicken),
            attributes,
            item_count: 0,
        }
    }

    // ======= Private and Utility functions =======

    /// Get Capy attributes from the gene sequence.
    fun get_attributes(fc: &Traits): vector<Attribute> {
        let attributes = vec::empty();
        vec::push_back(
            &mut attributes,
            Attribute { name: string::utf8(b"IsChicken"), value: to_string(if (fc.is_chicken) 1 else 0) }
        );
        vec::push_back(&mut attributes, Attribute { name: string::utf8(b"Fur"), value: to_string((fc.fur as u64)) });
        vec::push_back(&mut attributes, Attribute { name: string::utf8(b"Head"), value: to_string((fc.head as u64)) });
        vec::push_back(&mut attributes, Attribute { name: string::utf8(b"Ears"), value: to_string((fc.ears as u64)) });
        vec::push_back(&mut attributes, Attribute { name: string::utf8(b"Nose"), value: to_string((fc.nose as u64)) });
        vec::push_back(
            &mut attributes,
            Attribute { name: string::utf8(b"Mouth"), value: to_string((fc.mouth as u64)) }
        );
        vec::push_back(&mut attributes, Attribute { name: string::utf8(b"Neck"), value: to_string((fc.neck as u64)) });
        vec::push_back(&mut attributes, Attribute { name: string::utf8(b"Feet"), value: to_string((fc.feet as u64)) });
        vec::push_back(
            &mut attributes,
            Attribute { name: string::utf8(b"Alpha"), value: to_string((fc.alpha_index as u64)) }
        );
        attributes
    }

    // generates traits for a specific token, checking to make sure it's unique
    public fun generate_traits(
        reg: &FoCRegistry,
        // seed: &vector<u8>
    ): Traits {
        let seed = reg.foc_hash;
        let is_chicken = *vec::borrow(&seed, 0) >= 26; // 90%
        let shift = if (is_chicken) 0 else 9;
        Traits {
            is_chicken,
            fur: select_trait(reg, (*vec::borrow(&seed, 1) as u64), 0 + shift),
            head: select_trait(reg, (*vec::borrow(&seed, 2) as u64), 1 + shift),
            ears: select_trait(reg, (*vec::borrow(&seed, 3) as u64), 2 + shift),
            eyes: select_trait(reg, (*vec::borrow(&seed, 4) as u64), 3 + shift),
            nose: select_trait(reg, (*vec::borrow(&seed, 5) as u64), 4 + shift),
            mouth: select_trait(reg, (*vec::borrow(&seed, 6) as u64), 5 + shift),
            neck: select_trait(reg, (*vec::borrow(&seed, 7) as u64), 6 + shift),
            feet: select_trait(reg, (*vec::borrow(&seed, 8) as u64), 7 + shift),
            alpha_index: select_trait(reg, (*vec::borrow(&seed, 9) as u64), 8 + shift),
        }
    }

    fun select_trait(reg: &FoCRegistry, seed: u64, trait_type: u64): u8 {
        let trait = seed % vec::length(vec::borrow(&reg.rarities, trait_type));
        if (seed < (*vec::borrow(vec::borrow(&reg.rarities, trait_type), trait) as u64)) {
            return (trait as u8)
        };
        *vec::borrow(vec::borrow(&reg.aliases, trait_type), trait)
    }
}

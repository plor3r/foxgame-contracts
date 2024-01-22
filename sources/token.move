module fox_game::token {
    use sui::tx_context::{TxContext, sender};
    use sui::object::{Self, UID, ID};
    use sui::url::{Self, Url};
    use sui::event::emit;
    use sui::table::{Self, Table};
    use std::vector as vec;
    use std::hash::sha3_256 as hash;
    use std::option::{Self, Option};

    use fox_game::base64;
    use smartinscription::movescription::Movescription;
    friend fox_game::fox;
    friend fox_game::barn;

    // Errors

    const ENOT_EXISTS: u64 = 1;
    const EMISMATCHED_INPUT: u64 = 2;

    const ALPHAS: vector<u8> = vector[8, 7, 6, 5];

    /// Defines a Fox or Chicken attribute. Eg: `pattern: 'panda'`
    struct Attribute has store, copy, drop {
        name: vector<u8>,
        value: vector<u8>,
    }

    struct FoxOrChicken has key, store {
        id: UID,
        index: u64,
        is_chicken: bool,
        alpha: u8,
        url: Url,
        attributes: vector<Attribute>,
        attach_move: Movescription
    }

    // struct to store each trait's data for metadata and rendering
    struct Trait has store, drop, copy {
        name: vector<u8>,
        png: vector<u8>,
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
        foc_alive: u64,
        foc_hash: vector<u8>,
        rarities: vector<vector<u8>>,
        aliases: vector<vector<u8>>,
        types: Table<ID, bool>,
        alphas: Table<ID, u8>,
        trait_data: Table<u8, Table<u8, Trait>>,
        trait_types: vector<vector<u8>>,
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

    /// Event. When new FoC is born.
    struct FoCBurn has copy, drop {
        id: ID,
        index: u64,
        burned_by: address
    }

    // ======== Functions =========

    public(friend) fun init_foc_manage_cap(ctx: &mut TxContext): FoCManagerCap {
        FoCManagerCap { id: object::new(ctx) }
    }

    public(friend) fun init_foc_registry(ctx: &mut TxContext): FoCRegistry {
        let id = object::new(ctx);
        let foc_hash = hash(object::uid_to_bytes(&id));
        emit(RegistryCreated { id: object::uid_to_inner(&id) });

        let (rarities, aliases) = init_rarities_and_aliases();
        let reg = FoCRegistry {
            id,
            foc_hash,
            foc_born: 0,
            foc_alive: 0,
            rarities,
            aliases,
            types: table::new(ctx),
            alphas: table::new(ctx),
            trait_data: table::new(ctx),
            trait_types: vector[
                b"Fur",
                b"Head",
                b"Ears",
                b"Eyes",
                b"Nose",
                b"Mouth",
                b"Neck",
                b"Feet",
                b"Alpha",
            ],
        };
        init_traits(&mut reg.trait_data, ctx);
        reg
    }

    fun init_rarities_and_aliases(): (vector<vector<u8>>, vector<vector<u8>>) {
        let rarities: vector<vector<u8>> = vec::empty();
        let aliases: vector<vector<u8>> = vec::empty();
        // I know this looks weird but it saves users gas by making lookup O(1)
        // A.J. Walker's Alias Algorithm
        // for Chicken
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

        // Fox
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

    fun init_traits(trait_data: &mut Table<u8, Table<u8, Trait>>, ctx: &mut TxContext) {
        upload_traits(trait_data, 0, vector<u8>[0,1,2,3,4], vector[
            Trait { name: b"Survivor", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAG1BMVEUAAAAAAADfvqf////U1NSgoKDaPDayjXMTERC+6f+SAAAAAXRSTlMAQObYZgAAARFJREFUKM9dzjGOwjAQBVDnBh6I19smDXX0Az2agT5SfIAIyb3TpKVbjr1jJwGJr2n89GdkU0KWqCKzpyJcgRpkt3eNHgCDu1VqAZSYe3SlIMJgZBTYUhhZCzo9oytwEz4DOoxr2XCjBMaZcQSswjUFNZ2u6RWcHE5uSEHHt0fdcUOb0uFEOmlu9Krzi5/bkpOf685UAw0bNAPlG2N4A3DXFbl94PKYFOQNlxgz8BumH5pMNaLbwVYmH/2A0SjINzD8ClSgCsJaKTc3UKGSaNedMDL38sifsHtFWDjGXZzKLdxjzlpRcSFOWqCnKUKUiDzR76xQZEnL0y/2r91hbl5P39rXawM/N9pqrdlDRPlQgX8Br1cKW3BhdQAAAABJRU5ErkJggg=="},
            Trait { name: b"Black", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAAAAAABUVFTfvqcnJyeyjXMTERCh6BJhAAAAAXRSTlMAQObYZgAAAQBJREFUKM9V0NFthDAQBFCuAw+x8++RG0DoCvBqG7AQ//cT+i8hYwO5y2pliefZFfI0CgF4YLrrAVYyEuH6jiwkjZZPiU6KzArzCLjrkh2dYQSiKaAuxjygumVSbaxjAtGhS+NMBkFtkKnzUgTwryfQeqd11gywtiZTt23RVqQ9beuoZ9pi1n8DFyxA3xHfQJpGvH4AO/gflDNhHwnX0sj8hqKl/yELnOmE+dwRTZEzoNIOuBG9ZivGIOjiZjqKm54MGrLiLEWqFxsRNz2aTk2oIKnqWBEFPTKqRh2v6ZIGJOB7EwzZ2/5Ke/hZb9iW45XWcBwXpG1Rag3TXQD6ogG/hxdGus2GU1IAAAAASUVORK5CYII="},
            Trait { name: b"Brown", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAACyjXMAAADfvqeUXFl3RkwTERCfc+i4AAAAAXRSTlMAQObYZgAAAQlJREFUKM9V0UGOgzAMBdCKG3yT7mMXZl84gZG5AEr2nU3vf4T5BNppLQuJp58vES5tLJt1dnlNZ1iAAZbP9wEJgMPlkCEAknuCtECEw7FjILdAcQa4ySEN1vArwHUs7cRYojquDgUyYZFK48qUCGPc7uMmlauz8sy4zSK3u3Gln9g6KrSf29y1H+TSbbadMG22d5T6BsCFpesHYId4QzoS/pEIlhbIPySWfoMQAnqAHh3Fz8gEDjtqOGwf9eTIhF3CnY8Uzisba3FPgZSovLEWCeel8QkGGKGs3LLW0qCjcBd+pT3OP2dipmY/PaEJBA9F/p1f0E/Ph875+TxB+4mpmY3nmNle1OAPuP9KNkOoX8MAAAAASUVORK5CYII="},
            Trait { name: b"Gray", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAGFBMVEUAAACgoKAAAADfvqd8fHxUVFSyjXMTERAArvWNAAAAAXRSTlMAQObYZgAAARFJREFUKM9V0cGqgzAQBdDiH9yQ7uNU8/YK3Y+MPyDJD0Rw3dXr779rtH3tMAgebi4YL3UkiDRyeU0jmIAOEs73Dh6AQt0hnQEkVQ9XA2YKxY6GUANJGeB6haswm14BrmKqJ/pkWXFVtEAgTCXTuG7whN5u934pmRvHlmf6ZSzldhduWQe29nGL61jnHtfOXZpFlhOGRfaOlN8AqGPp/AHYwd7gj4R+JIylCe4fPEu/wREM8YD26Eh6RgZw2JFNIfu06hWBsIup8uFNeWV9Tqre4D2VN1Yjprw0PsEAI5SZm+acKjQU7sSvlMf556SIRJGflVBlK9sjbuF3fME6PB9xDM/nCXEdmBrZeI6I7EUV/gDoXlOpQvhhEgAAAABJRU5ErkJggg=="},
            Trait { name: b"White", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAGFBMVEUAAAD///8AAADfvqfU1NSgoKCyjXMTERDoC1piAAAAAXRSTlMAQObYZgAAARNJREFUKM9VkbGKwzAQRE3+YIzSyxtL19uQfs2a6430AzK4TnX5/RvLTi43DAI9Zge0aqrEi1ykeekimIAe4s97DwdAoe1BegOIVB3aGjBTKHZo8DWQlAHaKdoKZtMrQCumOhGSZcVV0QGeYCqZjG4HRxDsdg9LyXQcO86EZSzldhe6rANbQ9ziOlbd49q3zWWR5QTDIntHym8AKEds/gDYgb2BOxL6kTCWJrR/wLH0P2gJDPEA3dGR9IwMoNiRTSG7OnUKT7ATU+XhTLmykBPXaXCOlBurEVMujSe+GyqQzHSac/J17ST0xFfK4/w5KSJR5GslqGQr2yNu/md8gXV4PuLon88TxHVgamTjKRHZiyr4BfrNU9BDNuzNAAAAAElFTkSuQmCC"}
        ], ctx);

        upload_traits(trait_data, 1, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19], vector[
            Trait { name: b"None", png: b"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="},
            Trait { name: b"Beanie", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAADesC8AAACygyzig7/6AAAAAXRSTlMAQObYZgAAADRJREFUGNNjYGBYtWrVCgYgYPoaGhqGg7EKCEAM7qtfa+MbgAz98Kvx4Q8wGXA1cF1DGwAAvHUdFaOI7ngAAAAASUVORK5CYII="},
            Trait { name: b"Blue Hat", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAAAAxfAUPVwwY9MkUpn///8Xb+CzKPBIAAAAAXRSTlMAQObYZgAAAExJREFUKM9jAAElCFBggAImQ0EgCA0UggmoGAuCQaACmoAoXMBZEAIQAsYIAYQlCGuY3KA6hKECKolQASOoAhdnYwiA6YAbwTAK6AQA8i0NMLnMBUEAAAAASUVORK5CYII="},
            Trait { name: b"Blue Horns", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAAAAAAAAxfAkUpmUXFnp4iXeuZlDAAAAAXRSTlMAQObYZgAAAE1JREFUKM/tirsNwEAIQ6FIz2cCyARhg+y/VPBJVFnginuybAtDf1hlqircMmaqlPZELDyx2e0Z8+C92cM1h+AS8iXQeXVlggDypcOefGhhBSYgB3MPAAAAAElFTkSuQmCC"},
            Trait { name: b"Bucket Hat", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAUPVwAAAD////U1NQeCbBYAAAAAXRSTlMAQObYZgAAADtJREFUKM9jAAImJShggAJFQShQIFpAxdkYAqACTC4wASO4DhQ9TIIIIARTgFACVYBQAncm3LGjgA4AALPMDRDZPu+xAAAAAElFTkSuQmCC"},
            Trait { name: b"Capone", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAnJycAAADXzrjdAAAAAXRSTlMAQObYZgAAAC5JREFUGNNjYGBaBQQMQMC1NDQ0tAHEmEo8g2sVGDQwaAF1A0ECgxZEZAHDsAAAhfQbk6I91xcAAAAASUVORK5CYII="},
            Trait { name: b"Cowboy Hat", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAAAAAACUXFlrTVl3RkyyhH5PPVAKPoY5AAAAAXRSTlMAQObYZgAAAFlJREFUKM9jAAFGQTAQYIABERclIAgNhPEZXcACSqoCaAJKAmCeAANjWrIxGAiAeY7IAqJARSKCYjABQ8FAiAlQM0JDQ8GmCAIFnCCmKkJsATkK5rRRMCAAAEwDEcWhVXTnAAAAAElFTkSuQmCC"},
            Trait { name: b"Curved Brown Horns", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAACUXFl3RkxwD5rMAAAAAXRSTlMAQObYZgAAAExJREFUGNNjgAPGEBAZysDAthLEe+XAIAXEDOyrJjBUV01gYJBbvoShch6IMXMJQ1U5SKpsCYPcVpBioDz7BZB2eQcGRgcQg5VheAAAslgQppQv9PkAAAAASUVORK5CYII="},
            Trait { name: b"Curved Golden Horns", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAAAADesC+ygyzp4iW2FyRIAAAAAXRSTlMAQObYZgAAAF1JREFUKM/tjsENgEAIBM8OwLUBuGtAtAGS678mIZH4sAA/7mMgy0Joby1M1TInt+k1OicF1cYdgaoHO7JkwBQxg7iVIZ6GArWCdVD4nesoVNLfnw8OSgZK3H59ogviAQfA0IBaBAAAAABJRU5ErkJggg=="},
            Trait { name: b"Fedora", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAABTMG8AAAA4HUwse/DbAAAAAXRSTlMAQObYZgAAAEZJREFUGNNjYGBYtWrVCgYQ2BsaGgGimb6GhoYhMxZAGBoMO7iBjNCGGQx63FeBjKYEBu71IEZmAwPT/1AgCAObBzZxeAAAAv4b7SQW3IgAAAAASUVORK5CYII="},
            Trait { name: b"Mailman", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAkUpkAAAAUPVyUvX2gAAAAAXRSTlMAQObYZgAAAD1JREFUGNNjYGBYtWrVCgYgYPobGhoGYnB/DQ0NbUBm6F8FMhKwMriA2uEiS0GK9wNlokDmaAGlFjAMbQAATiUbPfY9QmIAAAAASUVORK5CYII="},
            Trait { name: b"Pointy Brown Horns", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAACUXFl3RkxwD5rMAAAAAXRSTlMAQObYZgAAADVJREFUGNNjwASiYJIxgEHKAcRgm8AgNwHEkLrAwL4ExMh2YGB8CVKyFkiUMEAJAQYwMcwAAHIQBuXcyXwPAAAAAElFTkSuQmCC"},
            Trait { name: b"Pointy Golden Horns", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAAAADesC+ygyzp4iW2FyRIAAAAAXRSTlMAQObYZgAAADdJREFUKM9jIAwYBdE4jCoCCAERRaCAkSNCgZMhkBRGKBFRBjIhShAKQEpAwsgsRoQZDKNgkAAAsRUDNeESnRIAAAAASUVORK5CYII="},
            Trait { name: b"Rainbow Fro", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAAAAAAAki0gAxfDp4iWtKZWxHRj6e/wSAAAAAXRSTlMAQObYZgAAAG1JREFUKM/tjs0NgDAIRmED8Kd3cQJDHKCGBXroBsb9R9C2Vk28e/KFCy98AGSYmJGhgmxepFWms3dmi4jqHIpxq5mIjKox5IHtFpHSwFOEl8iRa2mfI8Bo1qSzEwYodB5lQCWg+hkBHwU/H7ED9CEVeXhOdWcAAAAASUVORK5CYII="},
            Trait { name: b"Red Cap", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAACxHRgAAACGIickUpkwY9MrfZpjAAAAAXRSTlMAQObYZgAAADtJREFUKM9jAAElCFBggAImY2VBQUEhQSGYgLKRoSAQKAoqUEuASUkJVUDFBQhcQ4EArgIBFBhGwcAAAGyiDXTUrjeJAAAAAElFTkSuQmCC"},
            Trait { name: b"Santa", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAAAAAAD////aPDbU1NSzs7OxRF5xtqTLAAAAAXRSTlMAQObYZgAAAGFJREFUKM9jAAFBGGCAAjFjMBAzFoDwGZMhAobJBAUSoQKiLk5KTkoqSqqiihAFIS4qSkoqQBioJAARcFICAiARGAQVcFFyAnKBKkIhAqEuQK6TipNqoCADqkMFGEYBXQAA18AUiMy3ysEAAAAASUVORK5CYII="},
            Trait { name: b"Silky", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAACxHRgAAADaPDblLkmbAAAAAXRSTlMAQObYZgAAAEZJREFUGNNjYGBYtWrVCgYgYAoNDa0DMTiBjPgGGKNpAZTR/QPKWJsAZUxtgDKmARVzrQKC5SBtYDMeQBlMFQxQsIBhCAIAtFEYSeIKfXkAAAAASUVORK5CYII="},
            Trait { name: b"Sun Hat", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAGFBMVEUAAADft1IAAACygywBAAGygy2zgyyygiwt9VdQAAAAAXRSTlMAQObYZgAAAGZJREFUKM/tzbENgCAQheGLG+AE+DgXELA2SGLv/sP4RCIJtaVfx8/lTmiAIiEDUh2msjXMfXBdQJFAtmw0zaic9ywNZPcRbwICA+Xpefv1DgtgVRVI/AriIldXcP7kFWkG3eT3uQv4TxEdSz1gaQAAAABJRU5ErkJggg=="},
            Trait { name: b"Visor", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAAAAAAAAxfD///9RzuowY9OA/ye6AAAAAXRSTlMAQObYZgAAAC1JREFUKM9joBIQhAEBqICIszEE4BJgRNciGqQEAYpQBaFKUCCAbgnDKKATAADXjwhxIw22hAAAAABJRU5ErkJggg=="},
            Trait { name: b"White Cap", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAGFBMVEUAAAD///8AAACf3flRzuqxHRjaPDaGIifUMawjAAAAAXRSTlMAQObYZgAAADpJREFUKM9jAAElCFBggAImF2NjQSAQggmoOBsbCoKAArUEmJSUUAXUy0NBICwNCKAqEECBYRQMDAAAXlYPxDEH70IAAAAASUVORK5CYII="}
        ], ctx);

        upload_traits(trait_data, 2, vector<u8>[0,1,2,3,4,5], vector[
            Trait { name: b"None", png: b"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="},
            Trait { name: b"Diamond Bling", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAxfCf3fkiSJbrAAAAAXRSTlMAQObYZgAAACNJREFUGNNjoCtwABEsDAyME0AMSQYGthQQI80BJoJQM0gAANAXAu1JLL1KAAAAAElFTkSuQmCC"},
            Trait { name: b"Diamond Stud", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAABRzuqf3fkAxfD1N1m7AAAAAXRSTlMAQObYZgAAACFJREFUGNNjoAdwABEsQNwAYnAAcQGIwQ7EASAGK8OgBQAUogGZJVeZqAAAAABJRU5ErkJggg=="},
            Trait { name: b"Gold Bling", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAACygyzesC/p4iXHD2p5AAAAAXRSTlMAQObYZgAAACxJREFUGNNjoCs4ACJ4GBiYN4AY1gwMbDkgRtoBBsYJIIYkEDuAGCwMgwQAAKzKBEH6IVfBAAAAAElFTkSuQmCC"},
            Trait { name: b"Gold Hoop", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAADesC/p4iWygywWMD4DAAAAAXRSTlMAQObYZgAAAC1JREFUGNNjoAdoABEcDAxMYJ4CkGEAYigDGQIghiIDAyOYIQjEDiAGC8MgAQALcAGZnwuuxQAAAABJRU5ErkJggg=="},
            Trait { name: b"Two Gold Piercings", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAADp4iXesC+/0+PiAAAAAXRSTlMAQObYZgAAABpJREFUGNNjoANgFACRggwMTAoghhJCZPADAF5gAImSV/7gAAAAAElFTkSuQmCC"}
        ], ctx);

        upload_traits(trait_data, 3, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27], vector[
            Trait { name: b"Angry", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABRJREFUCNdjIBcIOAAJjgYkLk0AAG9gASkMl47GAAAAAElFTkSuQmCC"},
            Trait { name: b"Basic Sun Protection", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAACJJREFUGNNjoAdgDAUCMCsyIDIAzAgLCIMwRB1EHRgGLwAAHzIEnvQWWWQAAAAASUVORK5CYII="},
            Trait { name: b"Black Glasses", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAACf3fmF2+fnAAAAAXRSTlMAQObYZgAAACBJREFUGNNjoAdgDA0IDQWzsqZmTYAwJkAZQKkAhsELAF2sBoi6TPWPAAAAAElFTkSuQmCC"},
            Trait { name: b"Bloodshot", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAACxHRgAAAD////ZxzMJAAAAAXRSTlMAQObYZgAAABtJREFUGNNjoC/QYlgBYYg3xEEYog1hDIMYAADBZgKzhJLdVwAAAABJRU5ErkJggg=="},
            Trait { name: b"Confused", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAAAAAAD///8wY9PU1NQkUpmlxgFPAAAAAXRSTlMAQObYZgAAACxJREFUKM9jGAaAUVAAiSfIwCDiHIgk6yzAIKRsiCSgBBRQUkTWAjFjFGACANkKAlE1Ptk/AAAAAElFTkSuQmCC"},
            Trait { name: b"Cross Eyed", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAD///8AAABzxoNxAAAAAXRSTlMAQObYZgAAABpJREFUGNNjoAtgaliAJsLoEABlNExgGMQAANhaAsVGXr3gAAAAAElFTkSuQmCC"},
            Trait { name: b"Cyclops", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAAB1JREFUGNNjoCkIdYDQjKsmQBhsy5bARRBqBjEAAGQRBPHyQj4NAAAAAElFTkSuQmCC"},
            Trait { name: b"Dork", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAACf3fkAAAD///8AxfCCQkOpAAAAAXRSTlMAQObYZgAAAChJREFUKM9jGNqASUlJiQGIFeAijsaCSkDMgBAQNARhZAFBMB4FRAAA9SgD5/qQtmEAAAAASUVORK5CYII="},
            Trait { name: b"Face Painted", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAAD///8AAADaPDaGIiexHRgAd/VpAAAAAXRSTlMAQObYZgAAAB9JREFUKM9jGHZAUACIUAQUGBTxCrgaAIkQA4ZRgAkAU8sCAFzFgE4AAAAASUVORK5CYII="},
            Trait { name: b"Fake Glasses", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAACBJREFUGNNjoAtgdRCFMKQmZDmAGZFT00LgInA1gw8AAER0BQWlV3LJAAAAAElFTkSuQmCC"},
            Trait { name: b"Fearful", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABRJREFUCNdjIBcIOAAJBQUkLk0AAFQwAOF0Uq3NAAAAAElFTkSuQmCC"},
            Trait { name: b"Fearless", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAAAAD///8AxfAUPVwGtYjRAAAAAXRSTlMAQObYZgAAACdJREFUKM9jGOqAEYgFkAVEBBgYHZEFhIEChsgCQkABRUwzRgEWAABnSQEiql7SnwAAAABJRU5ErkJggg=="},
            Trait { name: b"Happy", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABRJREFUCNdjoAgYJAAJjwkQgiYAAM74AkGPa/xKAAAAAElFTkSuQmCC"},
            Trait { name: b"Leafy Green", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAAAAAAD///9y4cMYbUUVq5Gzb1utAAAAAXRSTlMAQObYZgAAAC1JREFUKM9jGOKAUVCAQVAQSUBI0JFRUUQASUAokFFRFVnA2ZBRxViAYRQQAQBL7gKpc11X4gAAAABJRU5ErkJggg=="},
            Trait { name: b"Livid", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAADaPDa/NLVAAAAAAXRSTlMAQObYZgAAAB5JREFUGNNjoA9wEIAyBBwgNKuDKIQhOSHNgWHwAgB6SgJKNOqwvwAAAABJRU5ErkJggg=="},
            Trait { name: b"Night Vision Visor", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAGFBMVEUAAAAAAADH242Ry2kki0gYbUUlrjsRTS0uPD9QAAAAAXRSTlMAQObYZgAAACJJREFUKM9jGNqAURAK4CIhyUpKyinhBbgFoDoEGEYBYQAAHNsFo8gXz6AAAAAASUVORK5CYII="},
            Trait { name: b"Big Blue", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAAAAAAD///8wY9MAxfDU1NSzs7M1QfpOAAAAAXRSTlMAQObYZgAAADZJREFUKM9jGOKAUVCAQVAQSYBJTJBBMVEASYVpIINwKJIAs5ESg7GSAkKAxUmBwUWJYRRgAQBXoAOXwF4RywAAAABJRU5ErkJggg=="},
            Trait { name: b"OMG", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAD///8AAABzxoNxAAAAAXRSTlMAQObYZgAAABVJREFUGNNjoC8QBUIwkARCuMggBgBYigCHfySWeAAAAABJRU5ErkJggg=="},
            Trait { name: b"Small Blue", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAAAAAAD///8AxfDU1NSzs7N9AqmZAAAAAXRSTlMAQObYZgAAACtJREFUKM9jGG6AUVCAQVAQSYBJVIBBMRBZhQhQhSOSALORAoOxEsMowAIAWw4B/3P/5x0AAAAASUVORK5CYII="},
            Trait { name: b"Rainbow Sunnies", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAKlBMVEUAAAD////p4iWRy2kkUpmtKZUlrjsAxfAwY9O6Rp3esC/aPDaGIiexHRjD61CUAAAAAXRSTlMAQObYZgAAADFJREFUKM9jGNqA5/YiIbPkCpFIuMguRWUG80ZXhBKgAgZkBQyMygkMjK4TGEYBEQAAmnoIPpGtZsYAAAAASUVORK5CYII="},
            Trait { name: b"Red Glasses", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAADaPDb///+f3flbDE79AAAAAXRSTlMAQObYZgAAACBJREFUGNNjoAdgDA0IDQWzqqZWTYAwJkAZQKkAhsELAIiMBsjrryLrAAAAAElFTkSuQmCC"},
            Trait { name: b"Rolling", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABtJREFUGNNjoAtgdQiBMCQnzoQwpCauZBgKAAAqTQMxWBpKpAAAAABJRU5ErkJggg=="},
            Trait { name: b"X Ray", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAG1BMVEUAAADU1NQnJydUVFSzs7OgoKB8fHwAAAD///9+jYp9AAAAAXRSTlMAQObYZgAAACdJREFUKM9jGFrAgL2cAYgUYHwmsxDBRpEwIyW4CqiAAhECo4AwAAAyZQixBvvRRwAAAABJRU5ErkJggg=="},
            Trait { name: b"Sleepy", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAADaPDYAAACxHRiFjUoGAAAAAXRSTlMAQObYZgAAAB1JREFUGNNjoC/gdTCFMEwDrjqAGVoLVjUwDF4AAJfkBBFicZT9AAAAAElFTkSuQmCC"},
            Trait { name: b"Spacey", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABtJREFUGNNjoC9gdQiBMKQmroQwJCfOZBjEAAAONgMxlwEXawAAAABJRU5ErkJggg=="},
            Trait { name: b"Squint Left", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABZJREFUGNNjGCAg6hAKYag1zGIYxAAANOEB67hwr/gAAAAASUVORK5CYII="},
            Trait { name: b"Squint Right", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAACyjXP///9SqdirAAAAAXRSTlMAQObYZgAAAB5JREFUGNNjoC8QdRB1ADNsD9geADO0GrQaGAYvAACPDAP5rXCA5AAAAABJRU5ErkJggg=="},
            Trait { name: b"Staring Contest", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABxJREFUGNNjoAtgdQiBMKQmroQwJCfORIgMYgAA/C8EhQfzzFEAAAAASUVORK5CYII="}
        ], ctx);

        upload_traits(trait_data, 4, vector<u8>[0,1,2,3,4,5,6,7,8,9], vector[
            Trait { name: b"Dot", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAAA5JREFUCNdjoDpgoqppAAE8AAPNbYZEAAAAAElFTkSuQmCC"},
            Trait { name: b"Red", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAACxHRiN+9miAAAAAXRSTlMAQObYZgAAAA5JREFUCNdjoA1gpZZBAAINAAaOzYqnAAAAAElFTkSuQmCC"},
            Trait { name: b"Gold", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAADesC+ygyzp4iXM8PRTAAAAAXRSTlMAQObYZgAAABVJREFUGNNjGDyABcbQhTE4GAYcAAAgKAA6oPTpgwAAAABJRU5ErkJggg=="},
            Trait { name: b"Normal", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABFJREFUCNdjoDpgBRFM1DINAAK4AAgZ7pXcAAAAAElFTkSuQmCC"},
            Trait { name: b"Dots", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAAA5JREFUCNdjoA1gpZZBAAINAAaOzYqnAAAAAElFTkSuQmCC"},
            Trait { name: b"Punched", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAACxHRir/4mtAAAAAXRSTlMAQObYZgAAABJJREFUGNNjGIRAEMZgYhhwAAALcgAU1IRuSQAAAABJRU5ErkJggg=="},
            Trait { name: b"Triangle", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABVJREFUCNdjoCZgAhHsIIK/gUpGAgArrwCZZLzKJAAAAABJRU5ErkJggg=="},
            Trait { name: b"U", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABJJREFUCNdjoDpgaQASzNQyDQApMwCIejoWBgAAAABJRU5ErkJggg=="},
            Trait { name: b"Wide", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAACyjXMCmAU+AAAAAXRSTlMAQObYZgAAABNJREFUGNNjGIRAEMZIc2AYaAAAXx4AuAHt6rEAAAAASUVORK5CYII="},
            Trait { name: b"X", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAnJycAAABUVFTztD9wAAAAAXRSTlMAQObYZgAAABVJREFUGNNjGDyABcbQhTE4GAYcAAAgKAA6oPTpgwAAAABJRU5ErkJggg=="}
        ], ctx);

        upload_traits(trait_data, 5, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15], vector[
            Trait { name: b"Beard", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAABUVFQnJycAAABIDEZpAAAAAXRSTlMAQObYZgAAACRJREFUGNNjGAqAMTSABcxo/X9FBMxQZRANADO4Vq1qYKAhAABKYgV/qKbb9AAAAABJRU5ErkJggg=="},
            Trait { name: b"Big Smile", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAACBJREFUGNNjGFKANTTUAcxgW7UKwmBctRIqFxrCQAMAAMVABIfzxX3aAAAAAElFTkSuQmCC"},
            Trait { name: b"Chill Smile", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABNJREFUCNdjoCFQEAAS8g8oMgMASzEBMGn9xVEAAAAASUVORK5CYII="},
            Trait { name: b"Chinstrap", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAABUVFQAAACdgFLfAAAAAXRSTlMAQObYZgAAAB1JREFUGNNjGFLAQYuBBcwQYGEIADNYQ0MdGGgIALHXAcIZaItpAAAAAElFTkSuQmCC"},
            Trait { name: b"Cigarette", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAAD////ft1JteCeNAAAAAXRSTlMAQObYZgAAABVJREFUGNNjGAogNADKeLUEIUIfAABEGwLZXNgLagAAAABJRU5ErkJggg=="},
            Trait { name: b"Cheese", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABZJREFUGNNjGFog1AFCM66agBChJQAA+RkCZmh5XfwAAAAASUVORK5CYII="},
            Trait { name: b"Grillz", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAAD////p4iVEM/MhAAAAAXRSTlMAQObYZgAAAB9JREFUGNNjGFKANTQUwmB7tRPCYNz1BMoIDWGgAQAAy/oEopz4M1EAAAAASUVORK5CYII="},
            Trait { name: b"Missing Tooth", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAAD///+LK2OK52TNAAAAAXRSTlMAQObYZgAAAB9JREFUGNNjGFKANTQUwmBbvRLCYFy1BCoXGsBAAwAAjNcD/iN6+sgAAAAASUVORK5CYII="},
            Trait { name: b"Mustache", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAnJycAAADXzrjdAAAAAXRSTlMAQObYZgAAABZJREFUGNNjGAqAMTQAwmDRYmGgLwAAZf8A2SyaZ90AAAAASUVORK5CYII="},
            Trait { name: b"Narrow Open Mouth", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAACGIiexHRhTeEvdAAAAAXRSTlMAQObYZgAAABRJREFUGNNjGFpAFMaQhDFkGWgKAB9QAEw967k5AAAAAElFTkSuQmCC"},
            Trait { name: b"Neutral", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAAA9JREFUCNdjoDWw/0CRdgBKQQEwYvMazgAAAABJRU5ErkJggg=="},
            Trait { name: b"Pipe", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAAB3RkyUXFnbHKunAAAAAXRSTlMAQObYZgAAACNJREFUGNNjGLxAFMbIdgyAMsKXQBhZ/6AiUiuhalhDGGgCAECZBUzRP8rtAAAAAElFTkSuQmCC"},
            Trait { name: b"Pouting", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAAA5JREFUCNdjoDVgokw7AAEeAAMmmXWWAAAAAElFTkSuQmCC"},
            Trait { name: b"Smirk", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABJJREFUCNdjoCVQAGL+AxQZAQA7MQDw3RJz6wAAAABJRU5ErkJggg=="},
            Trait { name: b"Teasing", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAACxHRir/4mtAAAAAXRSTlMAQObYZgAAABxJREFUGNNjGAqAhYERwmAMDYEKrWqAMrQYaAoA1mICBEG5ud0AAAAASUVORK5CYII="},
            Trait { name: b"Wide Open Mouth", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAACLK2PMyNAqAAAAAXRSTlMAQObYZgAAABhJREFUGNNjGFKAMTQEyli1BM5ASNEAAACH0gPzIqMenAAAAABJRU5ErkJggg=="}
        ], ctx);

        upload_traits(trait_data, 6, vector<u8>[0], vector[
            Trait { name: b"", png: b""}
        ], ctx);

        upload_traits(trait_data, 7, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18], vector[
            Trait { name: b"None", png: b"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="},
            Trait { name: b"Blue Sneakers", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAkUpn///8UPVxkGBcRAAAAAXRSTlMAQObYZgAAAB9JREFUGNNjGLGAF0Rw9TMtUAXzHJgDwMKqDpwBSKoARRECzKMjW7YAAAAASUVORK5CYII="},
            Trait { name: b"Clogs", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAACUXFl3RkyyjXPfvqcAAADm9aNwAAAAAXRSTlMAQObYZgAAADBJREFUKM9jGAXDDBgwMDABkSCUG6ToIMiqJMzAJAwTEHZgYFU0QWhgAgowQAQwAQCTqwMCqj+T/gAAAABJRU5ErkJggg=="},
            Trait { name: b"Dress Shoes", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAABrTVmLYHAAAABpcGB9AAAAAXRSTlMAQObYZgAAAClJREFUGNNjGJnAgZFBDESzujIGR4EY1xpMF4No5qiGawvADAaGA0AKAH+CBpRB4MtmAAAAAElFTkSuQmCC"},
            Trait { name: b"Elf", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAACxHRiGIicAAAATERAFVo93AAAAAXRSTlMAQObYZgAAADZJREFUKM9jGAXDDAgwMDABKUUIz5hBUUDZgEmQRUkQImBkoCjALMwkCFfPLCgowGAoKIjdNAB7PwJ5dZ0C2wAAAABJRU5ErkJggg=="},
            Trait { name: b"Frozen", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAxfCf3fkAAAAF6gJPAAAAAXRSTlMAQObYZgAAACRJREFUGNNjGJnAgZGBDUSzujIGSIEY1xpMF4BlpBrYFiApBABjtARoNgJwbQAAAABJRU5ErkJggg=="},
            Trait { name: b"Gray Shoes", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAB8fHxUVFQnJycAAAAL5v8lAAAAAXRSTlMAQObYZgAAAC5JREFUKM9jGAXDDBgwMDADkRKMbySgxMCsCEIQ4KwowMBiJIjQwAwUYIAIYAIAbzACN3lvSakAAAAASUVORK5CYII="},
            Trait { name: b"Green Sneakers", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAYbUX///8RTS2SZfaAAAAAAXRSTlMAQObYZgAAAB9JREFUGNNjGLGAF0Rw9TMtUAXzHJgDwMKqDpwBSKoARRECzKMjW7YAAAAASUVORK5CYII="},
            Trait { name: b"High", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAABrTVmLYHAvriRzAAAAAXRSTlMAQObYZgAAACRJREFUGNNjGJnAgZGBDUSzujIGSIEYbA2MC8AyYg2sC5AUAgBLcwNfMjTmaQAAAABJRU5ErkJggg=="},
            Trait { name: b"Ice Skates", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAB8fHwAAAD////aPDa68bjrAAAAAXRSTlMAQObYZgAAAEBJREFUKM9jGAXDDBgwMDADKSUFCJfJxclYQMVFQVhYACKgpKQkKKSkpCAoCBUQFjZkYDQ0FoCbICgoyMAIlQYAw+IEUFxH0moAAAAASUVORK5CYII="},
            Trait { name: b"Purple Sneakers", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAACtKZX///+LK2PExSGQAAAAAXRSTlMAQObYZgAAAB9JREFUGNNjGLGAF0Rw9TMtUAXzHJgDwMKqDpwBSKoARRECzKMjW7YAAAAASUVORK5CYII="},
            Trait { name: b"Red Sneakers", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAACxHRj///+GIifO3OvTAAAAAXRSTlMAQObYZgAAAB9JREFUGNNjGLGAF0RwtTItUAXzHJgDwMKqDpwBSKoAQ9ECwqXLH3QAAAAASUVORK5CYII="},
            Trait { name: b"Roller Blades", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAAAAAADaPDYwY9P///+GIifs5m8RAAAAAXRSTlMAQObYZgAAAEBJREFUKM9jGAXDDBgwMDAzMAoKCkC4jMaGTgzCxoKKjooQAUFBQVVFQUGhIKcgiICQiJAAI0gaBlRVVBWYoNIA02sFvbgiUlcAAAAASUVORK5CYII="},
            Trait { name: b"Slippers", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAAD////U1NQrJtYdAAAAAXRSTlMAQObYZgAAAClJREFUGNNjGLGAG0SE8IsyrwbSjC9DqkJBAuyrVr5a5QBksIYCgQMDAIWHCAZ0ivZ6AAAAAElFTkSuQmCC"},
            Trait { name: b"Snowboard", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAAAxfCIUzjXAAAAAXRSTlMAQObYZgAAACRJREFUGNNjGMlABEZJhgawhjCGpjCwrXLgamBaNYGBMRQMHABaSgbvYKSrowAAAABJRU5ErkJggg=="},
            Trait { name: b"Striped Socks", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAACxHRiGIifU1NT///8JCi5WAAAAAXRSTlMAQObYZgAAAC1JREFUKM9jGAXDDBgwMDADKWUYX1FAiYFJEISgwMQBqMIFrh4oIwBUJYjdNABfAQHgRgVXngAAAABJRU5ErkJggg=="},
            Trait { name: b"White and Gray Sneakers", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAD///+goKDSb8EQAAAAAXRSTlMAQObYZgAAACNJREFUGNNjGJmggYmBE0RzdTEtUAUxOB2YAsAyog6sAUgKAVcPAyyjM3sZAAAAAElFTkSuQmCC"},
            Trait { name: b"White Boots", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAAD////U1NQrJtYdAAAAAXRSTlMAQObYZgAAAChJREFUGNNjGJmggZmBD0TLzWdfYgdmTGBfApapmyAPYYQGiIYwMAAAhjIGcCT0leIAAAAASUVORK5CYII="},
            Trait { name: b"Yellow Sneakers", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAADp4iX////esC/HqtVrAAAAAXRSTlMAQObYZgAAAB9JREFUGNNjGLGAF0Rw9TMtUAXzHJgDwMKqDpwBSKoARRECzKMjW7YAAAAASUVORK5CYII="}
        ], ctx);

        upload_traits(trait_data, 8, vector<u8>[0], vector[
            Trait { name: b"", png: b""}
        ], ctx);

        upload_traits(trait_data, 9, vector<u8>[0,1,2,3,4,5,6,7,8], vector[
            Trait { name: b"Brown", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAADfvqeyjXOUXFkAAAB3RkwnJye5rIxEAAAAAXRSTlMAQObYZgAAAOlJREFUKM9d0UtywyAMBuAsuADuY59fNAeQSNcEK9m3uAfoeHz/K0QmjmGihZj5RhIaOFhoarlGDpYcGoxIptQBB1VIBwKAOsjew/sOLhXaDOcrDLGDAYbhFd53OG7QDa3RX7vG0MBV+HyFObSW/7WA26rjl8Evy/TsEPz4DwLFHXjwEJJz2oDYVmMi2YGO/g0m0xPAHsS8D8nMA4tJTBucrZ+pUJgeMn6DBVIkcnzAKYOEZg4FqbacRqDwIkE51Io4AbNcS9w+cYkT41ZuywZXiX9jLGKn8ytkjqpKlDld6js6VcuqTi0d7qKuM66LilVzAAAAAElFTkSuQmCC"},
            Trait { name: b"Black", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAAAAB8fHxUVFQzMzP62w08AAAAAXRSTlMAQObYZgAAANBJREFUKM9d0dGtwzAIBdBmA9+YBYLfAi4sgGD/mR5x3dgqHyQ68sVIfmWhrD6q9myHLCApqbqBd0BigxAR3aAyC/MG54A14+ABzTZokth/4XrgPWEbOmq/9q624Bhw/QL1FTnvA75WpZ5QPfBNhJx8qag94I0lNKxMUM/VXDUe0Df/SQq+IM6i7s+Q6t48UqxMsMy7knZ8hEw8JCjMbS5WRUPJO0kZkfwRckSH908ECQGy+YgwuICACQgDGUV+D76hugFQrV5OLiOC7MCBbK9/btEuQ7KP2ysAAAAASUVORK5CYII="},
            Trait { name: b"Cyborg", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAHlBMVEUAAAAAAADU1NSzs7N8fHwmJiZUVFTaExM+Pte2FSj4QyJcAAAAAXRSTlMAQObYZgAAASVJREFUKM9dj7FugzAQhskb+EIodCyoVVYwaWeE5c7GQLLSUHdGaVplLFNXxr5tfTYmVf/hbH/6dOfzvBUA8XQAAA8NWDngcWKFZwPwpJUwRdEqB38AOEXCcwkEpTRtyAL8OKZxzK5gbUC+gFVsQFL8AQnVMP0P7haQOXBtakLcP8E37wTsNtF2FAbcr7+3KK3GGdTV+OVhIn1FgVUoGEVyDfq8QsEoMn+JH0p6EO4fkpo0PXHAjm25A0eaZDShfd/NQKksy7hS3O3rP0pWHtEgM+B1U8tSG8KSDW/3bc3qvpN2cvgRnM/7z5YXO0kM4EHT1O+tuoWdsD0mpWQ5NSEJhBn7OvBCdYO6ED9FIX+ebrDkb/CDxobxAbAwCC/YFHRMAaIvv1CnSEBkTjEbAAAAAElFTkSuQmCC"},
            Trait { name: b"Demon", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAGFBMVEUAAAD/YEUAAADqJhfJABiKGTRgFzb/o6OFcHZiAAAAAXRSTlMAQObYZgAAAQtJREFUKM9dz8FOwzAMBuAqb5AVOGdpOs6NzR4gduFMFuAMankAJLTXn5NMzTSrl3z1HztdLmuNfN1WSvtOTbsGe5S/bmot7vPH2t/UYFwAANcGg9agNTfYF0DThhToww30IOjvYbfBtEG7NFe+1FzH5urloGqXKvB0D4uXcH3Q8J0bSFYdoIB7ETgRR9VDziiGd/2IgEGdIBagXgMjz2acTQYkWY0Q2SiqgJN+AJHYOV8ASAMSYehcKGOJemKRDWbJEyb0lgq4VyAGThzSdbHjAMi4kJeGEjk6gEQr+2gKuBABFh5TqGe7hkj+kA5rDaiUwocbZx7nCs//b9Hac/o7f9WEstZKLlc+XgDimToFb45F8wAAAABJRU5ErkJggg=="},
            Trait { name: b"Golden", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAGFBMVEUAAAD/9cz/1zgAAADvtBazfBz///9/Vx4OPYF3AAAAAXRSTlMAQObYZgAAAPJJREFUKM9d0cFOwzAMBuBJeYIUEOf9Meya1Z12dwycoYEH2KB3pPb9l2VtE80HR/pkx1ayScG+5BytS8mgQAeflCoQxwytQAFQBa21sLaCfQZawdgMTaigQUJ3Dw8rbBcol+aox16jKWAyPN/D6ErL/7VAyqrdS4Iv0fPSofi0T4TXYQVpLJT0z89AklYTIl2BtvYRSfoFIBYkQmEZK9KIJgl+hjciFYrk+pt0HxDFb9Qg5xvsWtD7MIr7GXxu2XVAPE3q+ORyReiBUQ8xzJ84hV5wjMdphoOG7y5ETaexLq8RmJmoFb/P72iYU2Y2nNLmAqlBNWjrQUErAAAAAElFTkSuQmCC"},
            Trait { name: b"Gray", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAADU1NSzs7N8fHwAAABUVFQzMzN30vgtAAAAAXRSTlMAQObYZgAAAOlJREFUKM9d0UtywyAMBuAsuADuY59fNAeQSNcEK9m3uAfoeHz/K0QmjmGihZj5RhIaOFhoarlGDpYcGoxIptQBB1VIBwKAOsjew/sOLhXaDOcrDLGDAYbhFd53OG7QDa3RX7vG0MBV+HyFObSW/7WA26rjl8Evy/TsEPz4DwLFHXjwEJJz2oDYVmMi2YGO/g0m0xPAHsS8D8nMA4tJTBucrZ+pUJgeMn6DBVIkcnzAKYOEZg4FqbacRqDwIkE51Io4AbNcS9w+cYkT41ZuywZXiX9jLGKn8ytkjqpKlDld6js6VcuqTi0d7qKuM66LilVzAAAAAElFTkSuQmCC"},
            Trait { name: b"Skeleton", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAADU1NQAAABUVFSzs7N8fHwmJibTOhb/AAAAAXRSTlMAQObYZgAAAOtJREFUKM91z01uxCAMBWDEDWxD1+Bkujck3adDZ0+iOUC7yP2PUPJTiCrNAyHx6SFhVcKunkf6z3Lo1OCWXNGvCyyBOT4vIFAyNuhgC70GDUfwP8wV8n63rWF3yBWUz1sBXAMpQKaBpgLyuMAUYzQ/qqUvjUdQrfGRUvp+8uXr67oKtHE9WcgEMFfId4mT5DqeH0DKHm0FKQ2RCOGEnowMZJaMfyCxLDMCuvPJAiIgweIptzcyKRq2weMJgyyTsHXa75UO+0j3DdQBjHNK7+J8OED7OXXIwB4P8IDMDOTJadynZ97esWalnfoFyskoXjMg55wAAAAASUVORK5CYII="},
            Trait { name: b"White", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAADU1NQAAAD///+zs7OgoKB8fHy2ACS8AAAAAXRSTlMAQObYZgAAAN1JREFUKM910dGNwyAMBuCIDWyn9xxMO4CxOgAcC1SXBbr/EmfTlKBKtSIn+hT/WGKx4u3svSJaC3DC1b/jOkFBZmgTNGhlnSACNHs+4cwI0AHqBKsDfocyYIT2mjf1mjYNHX4+4ZkHpKf/8HuGxLvBH0EdE/qAi6jgAFJVkHFOEAcSgQGiKi71DUomRCMkESmBCW4HrDZPUiTXl8SLEigUQMJjsaQC8qBcdOsj96haaIfMlB0iVrVl7XqW5BB2rKS3ctsPuAK2iAXsHdQhETKzSKIt9dDAbJ05sLXlH99sKB2+O3PtAAAAAElFTkSuQmCC"},
            Trait { name: b"Zombie", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAHlBMVEUAAADd4c4TFQ3CyaeVomhsdkk7QCjNQGHybX0AAADJ4bO/AAAAAXRSTlMAQObYZgAAAQVJREFUKM9d0cFOwzAMBuAqbxAKnLOkG+fFpg8Qu0McacMQR0TKAyAh7Q125ZGXpl1SzQdH+eTfipQqllalpzI2NgEFGlBRcQVktR5eqwIM7emP/8sOKWE8f5aJTQR59HmHkBPI2q2ghoj2Fu4y7DPkpalWT0/3uoBI8HgLwZbI1zRAnEea5wgDcX9NMLzJBwR0GaiWwMidWgApPo0+AmfAvbznc8D+CkASD6fvvMQQ1dT9DOTUAh0i09GjXTLNAYih8+xe1AytAWQMZPvfOdI2AJ5GtupJpQnXAwTeeleZCcToeoKd341u/tUtu/fGeY6nkBMYclprRENqI1NE69i1Fjq26gLc1jdBSLXPzQAAAABJRU5ErkJggg=="}
        ], ctx);

        upload_traits(trait_data, 10, vector<u8>[0,1,2,3], vector[
            Trait { name: b"Alpha", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAADp4iWxHRjesC/aPDaGIiey0+b9AAAAAXRSTlMAQObYZgAAADVJREFUKM9jAAFmAUMBQwYkIOSo5KgigOAzB4kqqQg5IqkwVQxSDAKqQCgxNhYUZBgFwwwAACa2BCnRkiorAAAAAElFTkSuQmCC"},
            Trait { name: b"Beta", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAADesC/p4iWygywWMD4DAAAAAXRSTlMAQObYZgAAACdJREFUGNNjYGBgNGKAAKObBmCaSTrtEpjBnDu7Gsxg3Jb7lmFEAgB10gZbpLr1hQAAAABJRU5ErkJggg=="},
            Trait { name: b"Delta", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAnJydsiL5QWZY3dEemAAAAAXRSTlMAQObYZgAAACZJREFUGNNjYGBgUmKAAMGZAmCaWS0tGcxgnDlzJoQRGhrKMCIBALIqBJ2aDbFxAAAAAElFTkSuQmCC"},
            Trait { name: b"Omega", png: b"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="},
        ], ctx);

        upload_traits(trait_data, 11, vector<u8>[0], vector[
            Trait { name: b"", png: b""}
        ], ctx);

        upload_traits(trait_data, 12, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26], vector[
            Trait { name: b"3D Glasses", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAABDP2RQWZYwY9PaPDYkUpmxHRgkvYJJAAAAAXRSTlMAQObYZgAAACpJREFUKM9joBsQUhIUFFRSEoQLMIYGMqYlMjAIwAWMDRldHLEKjIIBAgCzEQQyLJg4UgAAAABJRU5ErkJggg=="},
            Trait { name: b"Calm", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABlJREFUGNNjIBc4sEAZIawOEEYEawPDsAMAeYwBu2eqK7sAAAAASUVORK5CYII="},
            Trait { name: b"Challenged", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABhJREFUGNNjIBcEMDpAGKKiUBExMYbhBwDMUwDo9EJHjwAAAABJRU5ErkJggg=="},
            Trait { name: b"Closed", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABNJREFUCNdjIAZMaQAS34EE/QEAMSUCjGzFT/EAAAAASUVORK5CYII="},
            Trait { name: b"Crossed", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABVJREFUGNNjoBiEijpAGJwSDMMPAACvVADMF486XAAAAABJRU5ErkJggg=="},
            Trait { name: b"Curious", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABZJREFUGNNjIBeEiEJoxiliDgjGsAMA7gACQHP1B3QAAAAASUVORK5CYII="},
            Trait { name: b"Deep Blue", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAAAAD///8wY9NRzuok7Q52AAAAAXRSTlMAQObYZgAAACZJREFUKM9joB9gFGAQRBEQVmRUFkAWUDFkNFFAFhAUAKFRMHAAAFMpAXckuR9KAAAAAElFTkSuQmCC"},
            Trait { name: b"Downward Gaze", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABxJREFUGNNjIBeEsDqAacaVUhMgIjM4GxiGHQAAn9MDD9NbETgAAAAASUVORK5CYII="},
            Trait { name: b"Expressionless", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABBJREFUCNdjIBo8bmAYAAAAo8IBZAeCbMMAAAAASUVORK5CYII="},
            Trait { name: b"Flashy Sunnies", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAADaPDbWXjMlMaJrAAAAAXRSTlMAQObYZgAAACRJREFUGNNjIBOwhoaGBoAYjD/lJ7CAGSulIAyGEFYHFoZhAgA+eAT3cXb5TAAAAABJRU5ErkJggg=="},
            Trait { name: b"Full Moon", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAADp4iUCHEfGAAAAAXRSTlMAQObYZgAAABZJREFUGNNjIBeEsgZAGFGsCxiGLwAAdc0Bqi7falEAAAAASUVORK5CYII="},
            Trait { name: b"Hipster Glasses", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAACGIiexHRjF5O0AAADncVZCAAAAAXRSTlMAQObYZgAAAC5JREFUKM9joBtQUhQUFFJSEoQLMBobKhobMjAIwAVcDIEIWUBQEIhAAqNggAAA/9cDGdCkuJEAAAAASUVORK5CYII="},
            Trait { name: b"Mascara", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAAAAD////31GjesC/wTwMfAAAAAXRSTlMAQObYZgAAACdJREFUKM9jGDjAyMjIICAggCQgKMggKIgkwGQowuAorMAwCgYMAADySAFEqKSTQQAAAABJRU5ErkJggg=="},
            Trait { name: b"Leftward Gaze", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABVJREFUGNNjIBeIsEIZkWIODMMXAACu1gDJQdqGPQAAAABJRU5ErkJggg=="},
            Trait { name: b"Lovable", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAAA9JREFUCNdjIACUUAj6AwAxogBn9QqdoAAAAABJRU5ErkJggg=="},
            Trait { name: b"Narrow Dots", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAAA9JREFUCNdjIBqIMAwEAAAJ2AAVPM/xJQAAAABJRU5ErkJggg=="},
            Trait { name: b"Non", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABlJREFUGNNjIBsIQCjGENEACCuStYFh2AEAZ9gBqbVtzwEAAAAASUVORK5CYII="},
            Trait { name: b"Pouncing", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAADp4iUCHEfGAAAAAXRSTlMAQObYZgAAABRJREFUGNNjoBg4MEIZU8QYhh8AAMbZAOyq9yoHAAAAAElFTkSuQmCC"},
            Trait { name: b"Triangle", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAAAAD////esC/p4iXz4cM1AAAAAXRSTlMAQObYZgAAACBJREFUKM9joB9gFGAQRBEQFgAiZAUqAgwiigyjYBABAFRUANOQf3MAAAAAAElFTkSuQmCC"},
            Trait { name: b"Restless", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAD///8AAABzxoNxAAAAAXRSTlMAQObYZgAAABhJREFUGNNjIBeIMDpAGJlsE+AMhNRwAQA/rAKpjHjtFQAAAABJRU5ErkJggg=="},
            Trait { name: b"Rightward Gaze", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABZJREFUGNNjoBiEsDpAGEu5AhiGHQAAWNkBmUCD1MMAAAAASUVORK5CYII="},
            Trait { name: b"Sus", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABlJREFUGNNjIBcEsEIZLAwOEEYm2wSGYQcAW1oBmREaM9oAAAAASUVORK5CYII="},
            Trait { name: b"Simple", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAABJJREFUGNNjoBhEsDYgGMMOAAB2rAG7OrJocQAAAABJRU5ErkJggg=="},
            Trait { name: b"Standard Sunnies", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAB8fHwEsXMZAAAAAXRSTlMAQObYZgAAACRJREFUGNNjIBOwhoaGBoAYjKliASxgxlRJCIMhhNWBhWGYAAA5FAPF0zfHvQAAAABJRU5ErkJggg=="},
            Trait { name: b"The Intellectual", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAAD///8AxvILX77fAAAAAXRSTlMAQObYZgAAACNJREFUGNNjIBOwhjCGBoBZleETWMCMXLYLEIYIowMLwzABAG3FBAShPbp8AAAAAElFTkSuQmCC"},
            Trait { name: b"Unibrow", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABJJREFUCNdjIAb8bwASjgwDAQDWGwHBdn5dmwAAAABJRU5ErkJggg=="},
            Trait { name: b"Wide Dots", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABBJREFUCNdjIAY4NDAMFAAAXGAAwbIThh4AAAAASUVORK5CYII="}
        ], ctx);

        upload_traits(trait_data, 13, vector<u8>[0], vector[
            Trait { name: b"", png: b""}
        ], ctx);

        upload_traits(trait_data, 14, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12], vector[
            Trait { name: b"Brown Nose Smirk", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAAAACGREumXFiyLQuqAAAAAXRSTlMAQObYZgAAABtJREFUGNNjoAvg/wBlcC2AMoQaoQzWEIbBDADFWQKWe1o0aQAAAABJRU5ErkJggg=="},
            Trait { name: b"Flared Nostrils", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAB8fHwEsXMZAAAAAXRSTlMAQObYZgAAABxJREFUGNNjoAtgDIAy2FLQRRgc0EVYWBgGDwAAFIEBpqhDJG4AAAAASUVORK5CYII="},
            Trait { name: b"Frown", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAA8SURBVHgB7dAxCgAwCENRvf+h06VbhxIVXP7bBIOSCADAsjR29Ubl5Cek7iOKRaPH3QrVyLbpMwMAAJQcVNII/nWG3ZYAAAAASUVORK5CYII="},
            Trait { name: b"Gray Nose Smirk", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAABUVFQAAAB8fHybc42tAAAAAXRSTlMAQObYZgAAAB9JREFUGNNjoAtg/wJlsIZAGYwBDVBWE5RmWsEwCAEALuUDUsAgC00AAAAASUVORK5CYII="},
            Trait { name: b"Howling", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAA3SURBVHgB7dCxDQAwCANBk/13dgZIhQKi4K82ErYEABgWiaw/bstY7yN7OBran0x47/YAAKDTBWMEBgBVGLRtAAAAAElFTkSuQmCC"},
            Trait { name: b"Narrow Smile", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABVJREFUCNdjIBfYwQkZEOEJ4VIdAABorAEgjL+rgAAAAABJRU5ErkJggg=="},
            Trait { name: b"Neutral", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAQMAAABJtOi3AAAABlBMVEUAAAAAAAClZ7nPAAAAAXRSTlMAQObYZgAAABVJREFUCNdjIBfYgQgZEMEBYdEGAAAw0gB/IiGr2QAAAABJRU5ErkJggg=="},
            Trait { name: b"Mischievous", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAABASURBVHgB7dE7DgAgCATR9f6HXls/FWI0mnk1hEmQAACXlcCs5zVH9tMBQ4TSx1e5SbD6qKMBWw4/+QIAAPCXCsbCCQB95XMPAAAAAElFTkSuQmCC"},
            Trait { name: b"Red Nose Smirk", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAACGIicAAACUXFlvTMdOAAAAAXRSTlMAQObYZgAAAB5JREFUGNNjoAtg/wJlsIZAGYwBMLkmKM21gmEQAgDghgLa1TaQZAAAAABJRU5ErkJggg=="},
            Trait { name: b"Relaxed", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAABUVFQAAAB8fHybc42tAAAAAXRSTlMAQObYZgAAAB5JREFUGNNjoAuQ/wtliKVCGawhMLkGKM20gGEQAgAKnwMTkr3sIAAAAABJRU5ErkJggg=="},
            Trait { name: b"Smoking", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAAAACzs7N3RkzaPDZbArQ5AAAAAXRSTlMAQObYZgAAACtJREFUKM9jGLyAiaAAgwIDg6CgAIoSTAFGQTQtDALIAizGxoaCDKMAOwAAzGwBezfyYbcAAAAASUVORK5CYII="},
            Trait { name: b"Tongue Out", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAAAACLK2PaPDZ8fHwwqgYNAAAAAXRSTlMAQObYZgAAADNJREFUKM9jGGJAxEUAhS8gKCgggCLAKMiAKgCGSIBRSEkQ1VBhZQFUAWZldHsVGEYmAABo/wHvITi3ZQAAAABJRU5ErkJggg=="},
            Trait { name: b"Wide Smile", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAB9fX1rbxj5AAAAAXRSTlMAQObYZgAAACFJREFUGNNjoCVgWwJlsIZAGY4BARCGg4MDhCEayjCYAQAb0AMPL3oWpgAAAABJRU5ErkJggg=="}
        ], ctx);

        upload_traits(trait_data, 15, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14], vector[
            Trait { name: b"None", png: b"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="},
            Trait { name: b"Bandana", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAACxHRjaPDaGIic8TUzRAAAAAXRSTlMAQObYZgAAADZJREFUGNNjGHjADCP5wQzGAwzmEMYGhusQxtKwGIjSrKgCCENq5QEIg2051BTGGJh5BdR0HACoFggfrfG60wAAAABJRU5ErkJggg=="},
            Trait { name: b"Bowtie", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAADPFxGdHCL8OTPmGSr0AAAAAXRSTlMAQObYZgAAACNJREFUGNNjGArAhvkAhHHrVwGEEbYyAMKIioIyRFkdGGgAAIFjBfERQcIxAAAAAElFTkSuQmCC"},
            Trait { name: b"Clock", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAAAAAAD///8mJibU1NQAxfCf3fniSfVsAAAAAXRSTlMAQObYZgAAAERJREFUKM9jGAWs6AJs6KKsUFEESADiADgPyklAMQTD4GDjBFQBExMDFD6jk5EjqoCSsSKaCiVUFQwiKgKoAoyCVA0cAGd+BTKRuF0RAAAAAElFTkSuQmCC"},
            Trait { name: b"Diamond", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAGFBMVEUAAABDP2RRzuoAxfBsiL7///+f3fm96eYt/Nz0AAAAAXRSTlMAQObYZgAAADlJREFUKM9jGAWYQACIGUkQgHIEUA0BiaEqEUCzRxCNz6SqgCqgWlyGKuBkqoIqwJzmgGaIM1WDAgCs1ANUMV5SlAAAAABJRU5ErkJggg=="},
            Trait { name: b"Dress Tie", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAADaPDaxHRiGIieWWlKBAAAAAXRSTlMAQObYZgAAAB1JREFUGNNjGMTAgOEAhMEbDhVh/gOTS6AaAz8AAAFFBbQwGANWAAAAAElFTkSuQmCC"},
            Trait { name: b"Flowers", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAAB+QJQAUZ30XizPFxHs4wAAsCrBqxd6AAAAAXRSTlMAQObYZgAAAFFJREFUKM9jGCFAAc4KAJNMSnABUzDJCFfBbAymBAXgKkzApCPCNBcHIMHighBgEQBpdEAIMAoyMLAaGyC5QFCBLTQYyoY6IS0VzZFsDIMNAACDCQVI4lQm7gAAAABJRU5ErkJggg=="},
            Trait { name: b"Gold", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAACygyz31GjesC/p4iXl/SAkAAAAAXRSTlMAQObYZgAAADZJREFUKM9jGAUQIIDEdoASCEl0FQpgAk0FM7IKQyBmRLaACYiFkAUYHRgYDVDcICwkwjDIAACrXQIFuHNyTwAAAABJRU5ErkJggg=="},
            Trait { name: b"Mask", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAD1BMVEUAAAAAz+z///8AxvJeicGHiYOQAAAAAXRSTlMAQObYZgAAACtJREFUKM9jGAWYQAGImSgUMHRgYDFAFmA0cXEWQLFGWNAQ1V5GYwGGQQYA7Y8Ck6qdnCcAAAAASUVORK5CYII="},
            Trait { name: b"Pearls", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAADFBMVEUAAAAwY9MAxfAkUplGHsLCAAAAAXRSTlMAQObYZgAAADJJREFUGNNjGHjACCaZGBjYINwDDLwQEQcGCZiICUTpBIYECKOS7QKEwZ4LMwYoQAMAAH48BapPurmuAAAAAElFTkSuQmCC"},
            Trait { name: b"Secret Society", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAG1BMVEUAAAAmJiZ8fHwAAACGIiexHRizs7NUVFT///9CtDXHAAAAAXRSTlMAQObYZgAAAEJJREFUKM9jGAUsYNIBIcAKJgNwqIBLsiIb4gDFCEMMBU1RrGEWKhJGEWDUUFNEFShKKkQVUFNTxG8Gg6GgAQMtAQAPUQX5XIuKQgAAAABJRU5ErkJggg=="},
            Trait { name: b"Sheep Heart", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAElBMVEUAAACxHRjesC/aPDb31GjWXjOwiADrAAAAAXRSTlMAQObYZgAAADBJREFUKM9jGAVEACYgVkAWYAFiB/wqQAgFKDMqoAoYigqgCQiiCTALorvEgIG+AAA21QHBYNpakgAAAABJRU5ErkJggg=="},
            Trait { name: b"Silver", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAD////U1NSdrAhLAAAAAXRSTlMAQObYZgAAACtJREFUGNNjGESAA0I5MLBAGA1YRCQgjAQGBQhDgGEChKHC5ABhcM6kppsAl3oD2R6TEoEAAAAASUVORK5CYII="},
            Trait { name: b"Sunglasses", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAFVBMVEUAAACGIiexHRgkUpkUPVzesC+ygyyPHH7yAAAAAXRSTlMAQObYZgAAAEtJREFUKM9jGKGADYmJLsAKIUlRwZAIxIwJSAKBIIEAJAFRkA4BJAEwG6+AEggoIAmIGAsImyCrAPKAYsgqHBkYXZAFGIEcQfLDCQDEhgTz1mA1JwAAAABJRU5ErkJggg=="},
            Trait { name: b"Teeth", png: b"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgAgMAAAAOFJJnAAAACVBMVEUAAAAAAAD///+D3c/SAAAAAXRSTlMAQObYZgAAACdJREFUGNNjGESADUwyOTCwQPgO+EQEwAwgFQFhtIY2QBgcHdR0EwB3ZAPDpQXUNQAAAABJRU5ErkJggg=="}
        ], ctx);

        upload_traits(trait_data, 16, vector<u8>[0], vector[
            Trait { name: b"", png: b""}
        ], ctx);

        upload_traits(trait_data, 17, vector<u8>[0,1,2,3], vector[
            Trait { name: b"", png: b""},
            Trait { name: b"", png: b""},
            Trait { name: b"", png: b""},
            Trait { name: b"", png: b""}
        ], ctx);
    }

    /// Construct an image URL for the token.
    fun img_url(reg: &FoCRegistry, fc: &Traits): Url {
        url::new_unsafe_from_bytes(token_uri(reg, fc))
    }

    public fun alpha_for_fox(foc: &FoxOrChicken): u8 {
        foc.alpha
    }

    public fun alpha_for_fox_from_id(reg: &mut FoCRegistry, token_id: ID): u8 {
        assert!(table::contains(&reg.alphas, token_id), ENOT_EXISTS);
        *table::borrow(&reg.alphas, token_id)
    }

    public fun total_supply(reg: &FoCRegistry): u64 {
        reg.foc_born
    }

    public fun current_supply(reg: &FoCRegistry): u64 {
        reg.foc_alive
    }

    public fun is_chicken(foc: &FoxOrChicken): bool {
        foc.is_chicken
    }

    public fun is_chicken_from_id(reg: &mut FoCRegistry, token_id: ID): bool {
        assert!(table::contains(&reg.types, token_id), ENOT_EXISTS);
        *table::borrow(&reg.types, token_id)
    }

    /// Create a Fox or Chicken with a specified gene sequence.
    /// Also allows assigning custom attributes if an App is authorized to do it.
    public(friend) fun create_foc(
        reg: &mut FoCRegistry, movescription: Movescription, ctx: &mut TxContext
    ): FoxOrChicken {
        let id = object::new(ctx);
        reg.foc_born = reg.foc_born + 1;
        reg.foc_alive = reg.foc_alive + 1;

        vec::append(&mut reg.foc_hash, object::uid_to_bytes(&id));
        reg.foc_hash = hash(reg.foc_hash);

        let fc = generate_traits(reg);
        let attributes = get_attributes(reg, &fc);

        let alpha = *vec::borrow(&ALPHAS, (fc.alpha_index as u64));

        table::add(&mut reg.types, object::uid_to_inner(&id), fc.is_chicken);
        if (!fc.is_chicken) {
            table::add(&mut reg.alphas, object::uid_to_inner(&id), alpha);
        };

        emit(FoCBorn {
            id: object::uid_to_inner(&id),
            index: reg.foc_born,
            attributes: *&attributes,
            created_by: sender(ctx),
        });

        FoxOrChicken {
            id,
            index: reg.foc_born,
            is_chicken: fc.is_chicken,
            alpha: alpha,
            url: img_url(reg, &fc),
            attributes,
            attach_move: movescription
        }
    }

    public(friend) fun burn_foc(reg: &mut FoCRegistry, foc: FoxOrChicken, ctx: &TxContext): Movescription {
        let FoxOrChicken {id: id, index: index, is_chicken: _, alpha: _, url: _, attributes: _, attach_move: attach_move} = foc;
        reg.foc_alive = reg.foc_alive - 1;
        emit(FoCBurn {
            id: object::uid_to_inner(&id),
            index: index,
            burned_by: sender(ctx),
        });
        object::delete(id);
        attach_move
    }

    fun upload_traits(
        trait_data: &mut Table<u8, Table<u8, Trait>>,
        trait_type: u8,
        trait_ids: vector<u8>,
        traits: vector<Trait>,
        ctx: &mut TxContext
    ) {
        assert!(vec::length(&trait_ids) == vec::length(&traits), EMISMATCHED_INPUT);
        let i = 0;
        while (i < vec::length(&traits)) {
            if (!table::contains(trait_data, trait_type)) {
                table::add(trait_data, trait_type, table::new(ctx));
            };
            let trait_data_table = table::borrow_mut(trait_data, trait_type);

            let trait = *vec::borrow(&traits, i);
            let trait_id = *vec::borrow(&trait_ids, i);
            if (table::contains(trait_data_table, trait_id)) {
                // update
                table::remove(trait_data_table, trait_id);
                table::add(trait_data_table, trait_id, trait);
            } else {
                table::add(trait_data_table, trait_id, trait);
            };
            i = i + 1;
        }
    }

    // ======= Private and Utility functions =======

    /// Get Capy attributes from the gene sequence.
    fun get_attributes(reg: &FoCRegistry, fc: &Traits): vector<Attribute> {
        let attributes = vec::empty();

        let values = vector[fc.fur, fc.head, fc.ears, fc.eyes, fc.nose, fc.mouth, fc.neck, fc.feet, fc.alpha_index];
        let shift: u8 = if (fc.is_chicken) 0 else 9;

        let len = vec::length(&reg.trait_types);
        let i = 0;
        while (i < len) {
            vec::push_back(
                &mut attributes,
                Attribute {
                    name: *vec::borrow(&reg.trait_types, i),
                    value: table::borrow(table::borrow(&reg.trait_data, (i as u8) + shift), *vec::borrow(&values, i)).name
                }
            );
            i = i + 1;
        };
        attributes
    }

    // generates traits for a specific token, checking to make sure it's unique
    public fun generate_traits(
        reg: &FoCRegistry,
        // seed: &vector<u8>
    ): Traits {
        let seed = reg.foc_hash;
        let is_chicken = *vec::borrow(&seed, 0) >= 26; // 90% 0f 255
        let shift = if (is_chicken) 0 else 9;
        Traits {
            is_chicken,
            fur: select_trait(reg, *vec::borrow(&seed, 1), *vec::borrow(&seed, 10), 0 + shift),
            head: select_trait(reg, *vec::borrow(&seed, 2), *vec::borrow(&seed, 11), 1 + shift),
            ears: select_trait(reg, *vec::borrow(&seed, 3), *vec::borrow(&seed, 12), 2 + shift),
            eyes: select_trait(reg, *vec::borrow(&seed, 4), *vec::borrow(&seed, 13), 3 + shift),
            nose: select_trait(reg, *vec::borrow(&seed, 5), *vec::borrow(&seed, 14), 4 + shift),
            mouth: select_trait(reg, *vec::borrow(&seed, 6), *vec::borrow(&seed, 15), 5 + shift),
            neck: select_trait(reg, *vec::borrow(&seed, 7), *vec::borrow(&seed, 16), 6 + shift),
            feet: select_trait(reg, *vec::borrow(&seed, 8), *vec::borrow(&seed, 17), 7 + shift),
            alpha_index: select_trait(reg, *vec::borrow(&seed, 9), *vec::borrow(&seed, 18), 8 + shift),
        }
    }

    fun select_trait(reg: &FoCRegistry, seed1: u8, seed2: u8, trait_type: u64): u8 {
        // FIXME something wrong
        let trait = (seed1 as u64) % vec::length(vec::borrow(&reg.rarities, trait_type));
        if (seed2 < *vec::borrow(vec::borrow(&reg.rarities, trait_type), trait)) {
            return (trait as u8)
        };
        *vec::borrow(vec::borrow(&reg.aliases, trait_type), trait)
    }

    fun token_uri(reg: &FoCRegistry, foc: &Traits): vector<u8> {
        let uri = b"data:image/svg+xml;base64,";
        vec::append(&mut uri, base64::encode(&draw_svg(reg, foc)));
        uri
    }

    fun draw_trait(trait: Trait): vector<u8> {
        let s = b"";
        vec::append(&mut s, b"<image x=\"4\" y=\"4\" width=\"32\" height=\"32\" image-rendering=\"pixelated\" preserveAspectRatio=\"xMidYMid\" xlink:href=\"data:image/png;base64,");
        vec::append(&mut s, trait.png);
        vec::append(&mut s, b"\"/>");
        s
    }

    fun draw_trait_or_none(trait: Option<Trait>): vector<u8> {
        if (option::is_some(&trait)) {
            draw_trait(option::extract(&mut trait))
        } else {
            b""
        }
    }

    fun draw_svg(reg: &FoCRegistry, fc: &Traits): vector<u8> {

        let shift: u8 = if (fc.is_chicken) 0 else 9;
        let s0 = option::some(*table::borrow(table::borrow(&reg.trait_data, 0 + shift), fc.fur));
        let s1 = if (fc.is_chicken) {
            option::some(*table::borrow(table::borrow(&reg.trait_data, 1 + shift), fc.head))
        } else {
            option::some(*table::borrow(table::borrow(&reg.trait_data, 1 + shift), fc.alpha_index))
        };
        let s2 = if (fc.is_chicken) option::some(
            *table::borrow(table::borrow(&reg.trait_data, 2 + shift), fc.ears)
        ) else option::none<Trait>();
        let s3 = option::some(*table::borrow(table::borrow(&reg.trait_data, 3 + shift), fc.eyes));
        let s4 = if (fc.is_chicken) option::some(
            *table::borrow(table::borrow(&reg.trait_data, 4 + shift), fc.nose)
        ) else option::none<Trait>();
        let s5 = option::some(*table::borrow(table::borrow(&reg.trait_data, 5 + shift), fc.mouth));
        let s6 = if (fc.is_chicken) option::none<Trait>() else option::some(
            *table::borrow(table::borrow(&reg.trait_data, 6 + shift), fc.neck)
        );
        let s7 = if (fc.is_chicken) option::some(
            *table::borrow(table::borrow(&reg.trait_data, 7 + shift), fc.feet)
        ) else option::none<Trait>();

        let svg = b"";
        vec::append(&mut svg, b"<svg id=\"fox\" width=\"100%\" height=\"100%\" version=\"1.1\" viewBox=\"0 0 40 40\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\">");
        vec::append(&mut svg, draw_trait_or_none(s0));
        vec::append(&mut svg, draw_trait_or_none(s1));
        vec::append(&mut svg, draw_trait_or_none(s2));
        vec::append(&mut svg, draw_trait_or_none(s3));
        vec::append(&mut svg, draw_trait_or_none(s4));
        vec::append(&mut svg, draw_trait_or_none(s5));
        vec::append(&mut svg, draw_trait_or_none(s6));
        vec::append(&mut svg, draw_trait_or_none(s7));
        vec::append(&mut svg, b"</svg>");
        svg
    }
}

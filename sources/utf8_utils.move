module fox_game::utf8_utils {

    use std::string::{Self, String};
    use std::vector;

    /// @dev Converts a `u64` to its `ascii::String` decimal representation.
    public fun to_string(value: u64): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }

    public fun to_vector(value: u64): vector<u8> {
        if (value == 0) {
            return b"0"
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        buffer
    }


    /// @dev Converts a `ascii::String` to its `u64` decimal representation.
    public fun to_integer(s: String): u64 {
        let res = 0;
        let s_bytes = *string::bytes(&s);
        let i = 0;
        let k: u64 = 1;
        while (i < vector::length(&s_bytes)) {
            let n = vector::pop_back(&mut s_bytes);
            res = res + ((n as u64) - 48) * k;
            k = k * 10;
            i = i + 1;
        };
        res
    }
}

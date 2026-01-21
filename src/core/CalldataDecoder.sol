// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @dev This library's ABIDeocding is more lax than the Solidity ABIDecoder. This library omits index bounds/overflow
/// checking when accessing calldata arrays for gas efficiency. It also omits checks against `calldatasize()`. This
/// means that it is possible that `args` will run off the end of calldata and be implicitly padded with zeroes. That we
/// don't check for overflow means that offsets can be negative. This can also result in `args` that alias other parts
/// of calldata, or even the `actions` array itself.
library CalldataDecoder {
    function decodeCall(bytes[] calldata data, uint256 i)
        internal
        pure
        returns (uint256 selector, bytes calldata args)
    {
        assembly ("memory-safe") {
            // initially, we set `args.offset` to the pointer to the length. this is 32 bytes before the actual start of data
            args.offset :=
                add(
                    data.offset,
                    // We allow the indirection/offset to `calls[i]` to be negative
                    calldataload(i)
                    // calldataload(
                    //     add(shl(0x05, i), data.offset) // can't overflow; we assume `i` is in-bounds
                    // )
                )
            // now we load `args.length` and set `args.offset` to the start of data
            args.length := calldataload(args.offset)
            args.offset := add(0x20, args.offset)

            // slice off the first 4 bytes of `args` as the selector
            selector := shr(0xe0, calldataload(args.offset))
            args.length := sub(args.length, 0x04)
            args.offset := add(0x04, args.offset)
        }
    }
}
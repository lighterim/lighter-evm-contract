// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {ParamsHash} from "../../src/utils/ParamsHash.sol";
import {ISettlerBase} from "../../src/interfaces/ISettlerBase.sol";
import {console} from "forge-std/console.sol";

contract ParamsHashDebugTest is Test {
    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.Range;

    function test_debugIntentParams() public view {
        ISettlerBase.IntentParams memory intentParams = ISettlerBase.IntentParams({
            token: address(0x1234567890123456789012345678901234567890),
            range: ISettlerBase.Range({
                min: 1000,
                max: 5000
            }),
            expiryTime: uint64(1234567890),
            currency: bytes32(uint256(0xABCD)),
            paymentMethod: bytes32(uint256(0xEF01)),
            payeeDetails: bytes32(uint256(0x2345)),
            price: 1000000000000000000
        });

        bytes32 hash1 = intentParams.hash();
        bytes32 rangeHash = intentParams.range.hash();
        
        // Debug: Check what abi.encode produces
        bytes memory encoded = abi.encode(
            ParamsHash._INTENT_PARAMS_TYPEHASH,
            intentParams.token,
            rangeHash,
            intentParams.expiryTime,
            intentParams.currency,
            intentParams.paymentMethod,
            intentParams.payeeDetails,
            intentParams.price
        );
        
        console.log("Encoded length:");
        console.log(encoded.length);
        console.log("Hash1 (assembly):");
        console.logBytes32(hash1);
        console.log("Hash2 (abi.encode):");
        console.logBytes32(keccak256(encoded));
        
        // Print each field from encoded data
        console.log("=== Encoded data breakdown ===");
        uint256 offset = 0;
        
        // typeHash (32 bytes)
        bytes32 typeHashFromEncoded;
        assembly {
            typeHashFromEncoded := mload(add(encoded, add(0x20, offset)))
        }
        console.log("typeHash from encoded:");
        console.logBytes32(typeHashFromEncoded);
        offset += 32;
        
        // token (32 bytes)
        address tokenFromEncoded;
        assembly {
            tokenFromEncoded := mload(add(encoded, add(0x20, offset)))
        }
        console.log("token from encoded:");
        console.logAddress(tokenFromEncoded);
        offset += 32;
        
        // rangeHash (32 bytes)
        bytes32 rangeHashFromEncoded;
        assembly {
            rangeHashFromEncoded := mload(add(encoded, add(0x20, offset)))
        }
        console.log("rangeHash from encoded:");
        console.logBytes32(rangeHashFromEncoded);
        offset += 32;
        
        // expiryTime (32 bytes) - uint64
        uint256 expiryTimeFromEncoded;
        assembly {
            expiryTimeFromEncoded := mload(add(encoded, add(0x20, offset)))
        }
        console.log("expiryTime from encoded (full 32 bytes):");
        console.log(expiryTimeFromEncoded);
        console.log("expiryTime masked (low 8 bytes):");
        console.log(expiryTimeFromEncoded & 0xffffffffffffffff);
        offset += 32;
        
        // currency (32 bytes)
        bytes32 currencyFromEncoded;
        assembly {
            currencyFromEncoded := mload(add(encoded, add(0x20, offset)))
        }
        console.log("currency from encoded:");
        console.logBytes32(currencyFromEncoded);
        offset += 32;
        
        // paymentMethod (32 bytes)
        bytes32 paymentMethodFromEncoded;
        assembly {
            paymentMethodFromEncoded := mload(add(encoded, add(0x20, offset)))
        }
        console.log("paymentMethod from encoded:");
        console.logBytes32(paymentMethodFromEncoded);
        offset += 32;
        
        // payeeDetails (32 bytes)
        bytes32 payeeDetailsFromEncoded;
        assembly {
            payeeDetailsFromEncoded := mload(add(encoded, add(0x20, offset)))
        }
        console.log("payeeDetails from encoded:");
        console.logBytes32(payeeDetailsFromEncoded);
        offset += 32;
        
        // price (32 bytes)
        uint256 priceFromEncoded;
        assembly {
            priceFromEncoded := mload(add(encoded, add(0x20, offset)))
        }
        console.log("price from encoded:");
        console.log(priceFromEncoded);
        
        // Now check what our assembly code produces
        console.log("=== Assembly code output ===");
        bytes32 typeHash = ParamsHash._INTENT_PARAMS_TYPEHASH;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            
            mstore(ptr, typeHash)
            mstore(add(ptr, 0x20), mload(intentParams))
            mstore(add(ptr, 0x40), rangeHash)
            mstore(add(ptr, 0x60), and(mload(add(intentParams, 0x60)), 0xffffffffffffffff))
            mstore(add(ptr, 0x80), mload(add(intentParams, 0x80)))
            mstore(add(ptr, 0xa0), mload(add(intentParams, 0xa0)))
            mstore(add(ptr, 0xc0), mload(add(intentParams, 0xc0)))
            mstore(add(ptr, 0xe0), mload(add(intentParams, 0xe0)))
            
            let assemblyHash := keccak256(ptr, 0x100)
        }
            // Print each stored value
            // console.log("Assembly stored typeHash:");
            // console.logBytes32(mload(ptr));
            
            // console.log("Assembly stored token:");
            // console.logAddress(mload(add(ptr, 0x20)));
            
            // console.log("Assembly stored rangeHash:");
            // console.logBytes32(mload(add(ptr, 0x40)));
            
            // console.log("Assembly stored expiryTime:");
            // console.log(mload(add(ptr, 0x60)))
            
            // console.log("Assembly stored currency:");
            // console.logBytes32(mload(add(ptr, 0x80)));
            
            // console.log("Assembly stored paymentMethod:");
            // console.logBytes32(mload(add(ptr, 0xa0)));
            
            // console.log("Assembly stored payeeDetails:");
            // console.logBytes32(mload(add(ptr, 0xc0)));
            
            // console.log("Assembly stored price:");
            // console.log(mload(add(ptr, 0xe0)));
        // }
    }
}

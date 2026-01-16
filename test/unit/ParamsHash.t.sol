// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {ParamsHash} from "../../src/utils/ParamsHash.sol";
import {ISettlerBase} from "../../src/interfaces/ISettlerBase.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {console} from "forge-std/console.sol";

contract ParamsHashTest is Test {
    using ParamsHash for ISettlerBase.Range;
    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.EscrowParams;
    using ParamsHash for ISignatureTransfer.TokenPermissions;

    function setUp() public {}

    // ============ Test hash(Range) ============

    function test_hashRange_Basic() public pure {
        ISettlerBase.Range memory range = ISettlerBase.Range({
            min: 1000,
            max: 5000
        });

        bytes32 hash1 = ParamsHash.hash(range);
        bytes32 hash2 = keccak256(abi.encode(ParamsHash._RANGE_TYPEHASH, range));

        assertEq(hash1, hash2);
    }

    

    function test_hashRange_OrderMatters() public pure {
        ISettlerBase.Range memory range1 = ISettlerBase.Range({
            min: 1000,
            max: 5000
        });

        ISettlerBase.Range memory range2 = ISettlerBase.Range({
            min: 5000,
            max: 1000
        });

        bytes32 hash1 = range1.hash();
        bytes32 hash2 = range2.hash();

        // console.log("hash1");
        // console.logBytes32(hash1);
        // console.log("hash2");
        // console.logBytes32(hash2);

        assertNotEq(hash1, hash2);
    }

    // ============ Test hash(TokenPermissions) ============

    function test_hashTokenPermissions_Basic() public pure {
        ISignatureTransfer.TokenPermissions memory permitted = ISignatureTransfer.TokenPermissions({
            token: address(0x1234567890123456789012345678901234567890),
            amount: 1000000
        });

        bytes32 hash1 = permitted.hash();
        bytes32 hash2 = keccak256(abi.encode(ParamsHash._TOKEN_PERMISSIONS_TYPEHASH, permitted));

        // Same input should produce same hash
        assertEq(hash1, hash2);
        assertTrue(hash1 != bytes32(0));
    }

    // ============ Test hash(IntentParams) ============

    function test_hashIntentParams_Basic() public view{
        ISettlerBase.IntentParams memory intentParams = _createIntentParams();

        bytes32 hash1 = intentParams.hash();
        bytes32 rangeHash = intentParams.range.hash();
        bytes32 hash2 = keccak256(abi.encode(ParamsHash._INTENT_PARAMS_TYPEHASH, intentParams.token, rangeHash, intentParams.expiryTime, intentParams.currency, intentParams.paymentMethod, intentParams.payeeDetails, intentParams.price));

        // Same input should produce same hash
        assertEq(hash1, hash2);
        assertTrue(hash1 != bytes32(0));
    }

    function test_hashIntentParams_AllFieldsMatter() public view{
        ISettlerBase.IntentParams memory base = _createIntentParams();
        bytes32 baseHash = base.hash();

        // Test each field change produces different hash
        ISettlerBase.IntentParams memory modified;

        modified = _createIntentParams();
        modified.token = address(0x1111111111111111111111111111111111111111);
        assertTrue(modified.hash() != baseHash);

        modified = _createIntentParams();
        modified.range.min = 999;
        assertTrue(modified.hash() != baseHash);

        modified = _createIntentParams();
        modified.range.max = 5001;
        assertTrue(modified.hash() != baseHash);

        modified = _createIntentParams();
        modified.expiryTime = 1234567890;
        assertTrue(modified.hash() != baseHash);

        modified = _createIntentParams();
        modified.currency = bytes32(uint256(0x1111));
        assertTrue(modified.hash() != baseHash);

        modified = _createIntentParams();
        modified.paymentMethod = bytes32(uint256(0x2222));
        assertTrue(modified.hash() != baseHash);

        modified = _createIntentParams();
        modified.payeeDetails = bytes32(uint256(0x3333));
        assertTrue(modified.hash() != baseHash);

        modified = _createIntentParams();
        modified.price = 999999999999999999;
        assertTrue(modified.hash() != baseHash);
    }

    // ============ Test hashWithWitness(IntentParams) ============

    function test_hashWithWitnessIntentParams_Basic() public view{
        ISettlerBase.IntentParams memory intentParams = _createIntentParams();

        bytes32 hash1 = intentParams.hashWithWitness();
        bytes32 rangeHash = intentParams.range.hash();
        bytes32 hash2 = keccak256(abi.encode(
            ParamsHash._INTENT_PARAMS_TYPEHASH, intentParams.token, rangeHash, intentParams.expiryTime, 
            intentParams.currency, intentParams.paymentMethod, intentParams.payeeDetails, intentParams.price)
            );

        // Same input should produce same hash
        assertEq(hash1, hash2);
        assertTrue(hash1 != bytes32(0));
    }

    // ============ Test hash(EscrowParams) ============

    function test_hashEscrowParams_Basic() public pure{
        ISettlerBase.EscrowParams memory escrowParams = _createEscrowParams();

        bytes32 hash1 = ParamsHash.hash(escrowParams);
        bytes32 hash2 = keccak256(
            abi.encode(
                ParamsHash._ESCROW_PARAMS_TYPEHASH, escrowParams.id, escrowParams.token, escrowParams.volume,
                escrowParams.price, escrowParams.usdRate, escrowParams.payer, escrowParams.seller, 
                escrowParams.sellerFeeRate, escrowParams.paymentMethod, escrowParams.currency, 
                escrowParams.payeeDetails, escrowParams.buyer, escrowParams.buyerFeeRate
            )
        );

        // Same input should produce same hash
        assertEq(hash1, hash2);
        assertTrue(hash1 != bytes32(0));
    }

    function test_hashEscrowParams_DifferentValues() public pure{
        ISettlerBase.EscrowParams memory escrowParams1 = _createEscrowParams();
        
        ISettlerBase.EscrowParams memory escrowParams2 = _createEscrowParams();
        escrowParams2.id = 2;

        ISettlerBase.EscrowParams memory escrowParams3 = _createEscrowParams();
        escrowParams3.volume = 2000000;

        bytes32 hash1 = ParamsHash.hash(escrowParams1);
        bytes32 hash2 = ParamsHash.hash(escrowParams2);
        bytes32 hash3 = ParamsHash.hash(escrowParams3);

        // Different inputs should produce different hashes
        assertTrue(hash1 != hash2);
        assertTrue(hash1 != hash3);
        assertTrue(hash2 != hash3);
    }

    function test_hashEscrowParams_AllFieldsMatter() public pure{
        ISettlerBase.EscrowParams memory base = _createEscrowParams();
        bytes32 baseHash = ParamsHash.hash(base);

        // Test each field change produces different hash
        ISettlerBase.EscrowParams memory modified;

        modified = _createEscrowParams();
        modified.id = 999;
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.token = address(0x2222222222222222222222222222222222222222);
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.volume = 999999;
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.price = 999999999999999999;
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.usdRate = 888888888888888888;
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.payer = address(0x3333333333333333333333333333333333333333);
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.seller = address(0x4444444444444444444444444444444444444444);
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.sellerFeeRate = 100;
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.paymentMethod = bytes32(uint256(0x4444));
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.currency = bytes32(uint256(0x5555));
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.payeeDetails = bytes32(uint256(0x6666));
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.buyer = address(0x5555555555555555555555555555555555555555);
        assertTrue(ParamsHash.hash(modified) != baseHash);

        modified = _createEscrowParams();
        modified.buyerFeeRate = 200;
        assertTrue(ParamsHash.hash(modified) != baseHash);
    }

    function test_hashEscrowParams_ZeroValues() public pure{
        ISettlerBase.EscrowParams memory escrowParams = ISettlerBase.EscrowParams({
            id: 0,
            token: address(0),
            volume: 0,
            price: 0,
            usdRate: 0,
            payer: address(0),
            seller: address(0),
            sellerFeeRate: 0,
            paymentMethod: bytes32(0),
            currency: bytes32(0),
            payeeDetails: bytes32(0),
            buyer: address(0),
            buyerFeeRate: 0
        });

        bytes32 hash = ParamsHash.hash(escrowParams);
        assertTrue(hash != bytes32(0));
    }

    function test_hashEscrowParams_MaxValues() public pure{
        ISettlerBase.EscrowParams memory escrowParams = ISettlerBase.EscrowParams({
            id: type(uint256).max,
            token: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
            volume: type(uint256).max,
            price: type(uint256).max,
            usdRate: type(uint256).max,
            payer: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
            seller: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
            sellerFeeRate: type(uint256).max,
            paymentMethod: bytes32(type(uint256).max),
            currency: bytes32(type(uint256).max),
            payeeDetails: bytes32(type(uint256).max),
            buyer: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
            buyerFeeRate: type(uint256).max
        });

        bytes32 hash = ParamsHash.hash(escrowParams);
        assertTrue(hash != bytes32(0));
    }

    // ============ Helper Functions ============

    function _createIntentParams() internal view returns (ISettlerBase.IntentParams memory) {
        return ISettlerBase.IntentParams({
            token: address(0x1234567890123456789012345678901234567890),
            range: ISettlerBase.Range({
                min: 1000,
                max: 5000
            }),
            expiryTime: uint64(block.timestamp + 3600),
            currency: bytes32(uint256(0xABCD)),
            paymentMethod: bytes32(uint256(0xEF01)),
            payeeDetails: bytes32(uint256(0x2345)),
            price: 1000000000000000000 // 1e18
        });
    }

    function _createEscrowParams() internal pure returns (ISettlerBase.EscrowParams memory) {
        return ISettlerBase.EscrowParams({
            id: 1,
            token: address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238),
            volume: 1500000,
            price: 1000000000000000000,
            usdRate: 1000000000000000000,
            payer: address(0xD58382f295f5c98BAeB525FAbb7FEBcCc62bc63B),
            seller: address(0xD58382f295f5c98BAeB525FAbb7FEBcCc62bc63B),
            sellerFeeRate: 0,
            paymentMethod: bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
            currency: bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
            payeeDetails: bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
            buyer: address(0xD58382f295f5c98BAeB525FAbb7FEBcCc62bc63B),
            buyerFeeRate: 0
        });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";

import {ISettlerBase} from "../interfaces/ISettlerBase.sol";

library ParamsHash {

    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    string public constant _TOKEN_PERMISSIONS_TYPE_STRING = "TokenPermissions(address token,uint256 amount)";
    string public constant _RANGE_TYPE = "Range(uint256 min,uint256 max)";
    string public constant _INTENT_PARAMS_TYPE = string(
        abi.encodePacked(
            "IntentParams(address token,Range range,uint64 expiryTime,bytes32 currency,bytes32 paymentMethod,bytes32 payeeDetails,uint256 price)",
            _RANGE_TYPE
        )
    );
    string public constant _PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB =
        "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";
    
    string public constant _INTENT_WITNESS_TYPE_STRING = string(
        abi.encodePacked("IntentParams witness)",
        _INTENT_PARAMS_TYPE,
        _TOKEN_PERMISSIONS_TYPE_STRING
        )
    );

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 public constant _INTENT_PARAMS_TYPEHASH = keccak256(abi.encodePacked(_INTENT_PARAMS_TYPE));
    bytes32 public constant _RANGE_TYPEHASH = keccak256(abi.encodePacked(_RANGE_TYPE));

    bytes32 public constant _ESCROW_PARAMS_TYPEHASH = keccak256(
        "EscrowParams(uint256 id,address token,uint256 volume,uint256 price,uint256 usdRate,address payer,address seller,uint256 sellerFeeRate,bytes32 paymentMethod,bytes32 currency,bytes32 payeeDetails,address buyer,uint256 buyerFeeRate)"
    );

    /*
    bytes32 public constant _PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

    bytes32 public constant _PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    bytes32 public constant _PERMIT_BATCH_TYPEHASH = keccak256(
        "PermitBatch(PermitDetails[] details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    bytes32 public constant _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    */

    // string public constant _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB =
    //     "PermitBatchWitnessTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline,";
    function hashWithWitness(ISettlerBase.IntentParams memory intentParams) internal pure returns (bytes32 result) {
        // First compute rangeHash
        bytes32 rangeHash = hash(intentParams.range);
        
        // Extract fields to ensure proper encoding (especially for uint64)
        address token = intentParams.token;
        uint64 expiryTime = intentParams.expiryTime;
        bytes32 currency = intentParams.currency;
        bytes32 paymentMethod = intentParams.paymentMethod;
        bytes32 payeeDetails = intentParams.payeeDetails;
        uint256 price = intentParams.price;
        
        // Then compute main hash
        bytes32 typeHash = _INTENT_PARAMS_TYPEHASH;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            
            // Store _INTENT_PARAMS_TYPEHASH (32 bytes)
            mstore(ptr, typeHash)
            
            // Store token (address, 32 bytes padded) at offset 0x20
            mstore(add(ptr, 0x20), token)
            
            // Store rangeHash (bytes32) at offset 0x40
            mstore(add(ptr, 0x40), rangeHash)
            
            // Store expiryTime (uint64, encoded as uint256 in abi.encode)
            // abi.encode converts uint64 to uint256 (32 bytes, right-aligned)
            mstore(add(ptr, 0x60), expiryTime)
            
            // Store currency (bytes32) at offset 0x80
            mstore(add(ptr, 0x80), currency)
            
            // Store paymentMethod (bytes32) at offset 0xa0
            mstore(add(ptr, 0xa0), paymentMethod)
            
            // Store payeeDetails (bytes32) at offset 0xc0
            mstore(add(ptr, 0xc0), payeeDetails)
            
            // Store price (uint256) at offset 0xe0
            mstore(add(ptr, 0xe0), price)
            
            // Compute keccak256 hash of 0x100 bytes (8 * 32 bytes = 256 bytes)
            result := keccak256(ptr, 0x100)
        }
    }
    
    function hash(ISettlerBase.IntentParams memory intentParams) internal pure returns (bytes32 result) {
        // First compute rangeHash
        bytes32 rangeHash = hash(intentParams.range);
        
        // Extract fields to ensure proper encoding (especially for uint64)
        address token = intentParams.token;
        uint64 expiryTime = intentParams.expiryTime;
        bytes32 currency = intentParams.currency;
        bytes32 paymentMethod = intentParams.paymentMethod;
        bytes32 payeeDetails = intentParams.payeeDetails;
        uint256 price = intentParams.price;
        
        // Then compute main hash
        bytes32 typeHash = _INTENT_PARAMS_TYPEHASH;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            
            // Store _INTENT_PARAMS_TYPEHASH (32 bytes)
            mstore(ptr, typeHash)
            
            // Store token (address, 32 bytes padded) at offset 0x20
            mstore(add(ptr, 0x20), token)
            
            // Store rangeHash (bytes32) at offset 0x40
            mstore(add(ptr, 0x40), rangeHash)
            
            // Store expiryTime (uint64, encoded as uint256 in abi.encode)
            // abi.encode converts uint64 to uint256 (32 bytes, right-aligned)
            mstore(add(ptr, 0x60), expiryTime)
            
            // Store currency (bytes32) at offset 0x80
            mstore(add(ptr, 0x80), currency)
            
            // Store paymentMethod (bytes32) at offset 0xa0
            mstore(add(ptr, 0xa0), paymentMethod)
            
            // Store payeeDetails (bytes32) at offset 0xc0
            mstore(add(ptr, 0xc0), payeeDetails)
            
            // Store price (uint256) at offset 0xe0
            mstore(add(ptr, 0xe0), price)
            
            // Compute keccak256 hash of 0x100 bytes (8 * 32 bytes = 256 bytes)
            result := keccak256(ptr, 0x100)
        }
    }

    function hash(ISettlerBase.Range memory range) internal pure returns (bytes32 result) {
        bytes32 typeHash = _RANGE_TYPEHASH;
        assembly ("memory-safe") {
            // Load free memory pointer
            let ptr := mload(0x40)
            
            // Store _RANGE_TYPEHASH (32 bytes)
            mstore(ptr, typeHash)
            
            // Store min (32 bytes) at offset 0x20
            mstore(add(ptr, 0x20), mload(range))
            
            // Store max (32 bytes) at offset 0x40
            mstore(add(ptr, 0x40), mload(add(range, 0x20)))
            
            // Compute keccak256 hash of 0x60 bytes (3 * 32 bytes = 96 bytes)
            result := keccak256(ptr, 0x60)
        }
    }

    function hash(ISettlerBase.EscrowParams memory escrowParams) internal pure returns (bytes32 result) {
        bytes32 typeHash = _ESCROW_PARAMS_TYPEHASH;
        assembly ("memory-safe") {
            // Load free memory pointer
            let ptr := mload(0x40)
            
            // Store _ESCROW_PARAMS_TYPEHASH (32 bytes)
            mstore(ptr, typeHash)
            
            // Store id (32 bytes) at offset 0x20
            mstore(add(ptr, 0x20), mload(escrowParams))
            
            // Store token (address, 32 bytes padded) at offset 0x40
            mstore(add(ptr, 0x40), mload(add(escrowParams, 0x20)))
            
            // Store volume (32 bytes) at offset 0x60
            mstore(add(ptr, 0x60), mload(add(escrowParams, 0x40)))
            
            // Store price (32 bytes) at offset 0x80
            mstore(add(ptr, 0x80), mload(add(escrowParams, 0x60)))
            
            // Store usdRate (32 bytes) at offset 0xa0
            mstore(add(ptr, 0xa0), mload(add(escrowParams, 0x80)))
            
            // Store payer (address, 32 bytes padded) at offset 0xc0
            mstore(add(ptr, 0xc0), mload(add(escrowParams, 0xa0)))
            
            // Store seller (address, 32 bytes padded) at offset 0xe0
            mstore(add(ptr, 0xe0), mload(add(escrowParams, 0xc0)))
            
            // Store sellerFeeRate (32 bytes) at offset 0x100
            mstore(add(ptr, 0x100), mload(add(escrowParams, 0xe0)))
            
            // Store paymentMethod (bytes32) at offset 0x120
            mstore(add(ptr, 0x120), mload(add(escrowParams, 0x100)))
            
            // Store currency (bytes32) at offset 0x140
            mstore(add(ptr, 0x140), mload(add(escrowParams, 0x120)))
            
            // Store payeeDetails (bytes32) at offset 0x160
            mstore(add(ptr, 0x160), mload(add(escrowParams, 0x140)))
            
            // Store buyer (address, 32 bytes padded) at offset 0x180
            mstore(add(ptr, 0x180), mload(add(escrowParams, 0x160)))
            
            // Store buyerFeeRate (32 bytes) at offset 0x1a0
            mstore(add(ptr, 0x1a0), mload(add(escrowParams, 0x180)))
            
            // Compute keccak256 hash of 0x1c0 bytes (14 * 32 bytes = 448 bytes)
            result := keccak256(ptr, 0x1c0)
        }
    }

    function hash(ISignatureTransfer.TokenPermissions memory permitted)
        internal
        pure
        returns (bytes32 result)
    {
        bytes32 typeHash = _TOKEN_PERMISSIONS_TYPEHASH;
        assembly ("memory-safe") {
            // Load free memory pointer
            let ptr := mload(0x40)
            
            // Store _TOKEN_PERMISSIONS_TYPEHASH (32 bytes)
            mstore(ptr, typeHash)
            
            // Store token (address, 32 bytes padded) at offset 0x20
            mstore(add(ptr, 0x20), mload(permitted))
            
            // Store amount (32 bytes) at offset 0x40
            mstore(add(ptr, 0x40), mload(add(permitted, 0x20)))
            
            // Compute keccak256 hash of 0x60 bytes (3 * 32 bytes = 96 bytes)
            result := keccak256(ptr, 0x60)
        }
    }

    /*
    function hash(IAllowanceTransfer.PermitSingle memory permitSingle) internal pure returns (bytes32) {
        bytes32 permitHash = _hashPermitDetails(permitSingle.details);
        return
            keccak256(abi.encode(_PERMIT_SINGLE_TYPEHASH, permitHash, permitSingle.spender, permitSingle.sigDeadline));
    }

    function hash(IAllowanceTransfer.PermitBatch memory permitBatch) internal pure returns (bytes32) {
        uint256 numPermits = permitBatch.details.length;
        bytes32[] memory permitHashes = new bytes32[](numPermits);
        for (uint256 i = 0; i < numPermits; ++i) {
            permitHashes[i] = _hashPermitDetails(permitBatch.details[i]);
        }
        return keccak256(
            abi.encode(
                _PERMIT_BATCH_TYPEHASH,
                keccak256(abi.encodePacked(permitHashes)),
                permitBatch.spender,
                permitBatch.sigDeadline
            )
        );
    }

    function hash(ISignatureTransfer.PermitTransferFrom memory permit) internal view returns (bytes32) {
        bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
        return keccak256(
            abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, msg.sender, permit.nonce, permit.deadline)
        );
    }

    function hash(ISignatureTransfer.PermitBatchTransferFrom memory permit) internal view returns (bytes32) {
        uint256 numPermitted = permit.permitted.length;
        bytes32[] memory tokenPermissionHashes = new bytes32[](numPermitted);

        for (uint256 i = 0; i < numPermitted; ++i) {
            tokenPermissionHashes[i] = _hashTokenPermissions(permit.permitted[i]);
        }

        return keccak256(
            abi.encode(
                _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                keccak256(abi.encodePacked(tokenPermissionHashes)),
                msg.sender,
                permit.nonce,
                permit.deadline
            )
        );
    }

    function hashWithWitness(
        ISignatureTransfer.PermitTransferFrom memory permit,
        bytes32 witness,
        string calldata witnessTypeString
    ) internal view returns (bytes32) {
        bytes32 typeHash = keccak256(abi.encodePacked(_PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, witnessTypeString));

        bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
        return keccak256(abi.encode(typeHash, tokenPermissionsHash, msg.sender, permit.nonce, permit.deadline, witness));
    }

    function hashWithWitness(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes32 witness,
        string calldata witnessTypeString
    ) internal view returns (bytes32) {
        bytes32 typeHash =
            keccak256(abi.encodePacked(_PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB, witnessTypeString));

        uint256 numPermitted = permit.permitted.length;
        bytes32[] memory tokenPermissionHashes = new bytes32[](numPermitted);

        for (uint256 i = 0; i < numPermitted; ++i) {
            tokenPermissionHashes[i] = _hashTokenPermissions(permit.permitted[i]);
        }

        return keccak256(
            abi.encode(
                typeHash,
                keccak256(abi.encodePacked(tokenPermissionHashes)),
                msg.sender,
                permit.nonce,
                permit.deadline,
                witness
            )
        );
    }

    function _hashPermitDetails(IAllowanceTransfer.PermitDetails memory details) private pure returns (bytes32) {
        return keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, details));
    }

    function _hashTokenPermissions(ISignatureTransfer.TokenPermissions memory permitted)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permitted));
    }
    */
}

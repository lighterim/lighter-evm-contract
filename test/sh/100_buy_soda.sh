#!/bin/bash
#
# Take Intent Test Script
# 
# This script executes testTakeSellerIntent functionality via command line.
# 
# Required Environment Variables:
#   BUYER_PRIVATE_KEY    - Private key for buyer account (EOA)
#   SELLER_PRIVATE_KEY   - Private key for seller account (EOA)
#   RELAYER_PRIVATE_KEY  - Private key for relayer account (optional, defaults to SELLER_PRIVATE_KEY)
#   TBA_BUYER            - Token Bound Account address for buyer
#   TBA_SELLER           - Token Bound Account address for seller
#   ETH_RPC_URL          - Ethereum RPC endpoint URL
#   PAYEE_DETAILS        - Payee details(account + qrCode + memo)
#
# Optional Environment Variables (contract addresses):
#   USDC                 - USDC token address (default: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)
#   LIGHTER_ACCOUNT      - LighterAccount contract address
#   ESCROW               - Escrow contract address
#   ALLOWANCE_HOLDER     - AllowanceHolder contract address
#   TAKE_INTENT          - TakeIntent contract address
#   PERMIT2_HELPER       - Permit2Helper contract address
#
# Example usage:
#   # Option 1: Export variables directly
#   export BUYER_PRIVATE_KEY=0x...
#   export SELLER_PRIVATE_KEY=0x...
#   export RELAYER_PRIVATE_KEY=0x...
#   export TBA_BUYER=0x...
#   export TBA_SELLER=0x...
#   export ETH_RPC_URL=https://...
#   export PAYEE_DETAILS=1234567890xxxxxxxxyyyyzzzz
#   export TRADE_ID=1
#   export ESCROW=0x...
#   export TAKE_INTENT=0x...
#   ./0_takeSellerIntent.sh
#
#   # Option 2: Use .env file (create test/sh/.env and source it)
#   source test/sh/.env
#   ./0_takeSellerIntent.sh
#
# Note: Never commit .env files or private keys to version control!

set -e  # Exit on error

# Check required environment variables
if [ -z "$BUYER_PRIVATE_KEY" ]; then
    echo "Error: BUYER_PRIVATE_KEY environment variable is not set"
    exit 1
fi

if [ -z "$SELLER_PRIVATE_KEY" ]; then
    echo "Error: SELLER_PRIVATE_KEY environment variable is not set"
    exit 1
fi

if [ -z "$TBA_BUYER" ]; then
    echo "Error: TBA_BUYER environment variable is not set"
    exit 1
fi

if [ -z "$TBA_SELLER" ]; then
    echo "Error: TBA_SELLER environment variable is not set"
    exit 1
fi

if [ -z "$ETH_RPC_URL" ]; then
    echo "Error: ETH_RPC_URL environment variable is not set"
    exit 1
fi

if [ -z "$PAYEE_DETAILS" ]; then
    echo "Error: PAYEE_DETAILS environment variable is not set"
    exit 1
fi

# Load sensitive information from environment variables
export buyerPrivKey=$BUYER_PRIV_KEY
export sellerPrivKey=$SELLER_PRIV_KEY
export relayerPrivKey=${RELAYER_PRIVATE_KEY:-$sellerPrivKey}  # Default to seller if not set
export tbaBuyer=$TBA_BUYER
export tbaSeller=$TBA_SELLER
export tradeId=${TRADE_ID:-1}
export usdc=${USDC}
export permit2=0x000000000022D473030F116dDEE9F6B43aC78BA3  # Standard Permit2 address
export usdcDecimals=6

# Load contract addresses from environment or use defaults
export LighterAccount=${LIGHTER_ACCOUNT:-0x31d42A0f1C9d338B5477fce674745835CEEde398}
export LighterTicket=${LIGHTER_TICKET:-0xac70D4678Bc57B402c58F863a79d3437425C7305}
export Escrow=${ESCROW:-0x6C99AF667b8Ea8c7f7B2083F08CfDb8feF653B87}
export AllowanceHolder=${ALLOWANCE_HOLDER:-0xb8846d05341446108BDE1a8248fC9b60975cD89C}
export TakeIntent=${TAKE_INTENT:-0xb4557925b667f98767dA841c0fC03e6bC408C7Af}
export SetWaypoint=${SET_WAYPOINT:-0x3a1F23470ED277898f962E3fcA94c2D0225FC6A0}
export ZkVerifyProofVerifier=${ZK_VERIFY_PROOF_VERIFIER:-0xa2607E73CA6ccb2F5Ca5883cB7757904aB3fF74e}
export Permit2Helper=${PERMIT2_HELPER:-0x69047390100A919bE0B6c453D4Acb05b3d317395}

# Display configuration summary
echo "=========================================="
echo "Configuration Summary"
echo "=========================================="
echo "Network RPC: $ETH_RPC_URL"
echo "Buyer TBA: $tbaBuyer"
echo "Seller TBA: $tbaSeller"
echo "TakeIntent Contract: $TakeIntent"
echo "Escrow Contract: $Escrow"
echo "=========================================="
echo ""

# cast send $usdc 'approve(address,uint256)' $permit2 $(cast --to-uint256 99999999999999999999999999) --private-key=$sellerPrivKey

export eoaSeller=$(cast wallet address --private-key=$sellerPrivKey)
export eoaBuyer=$(cast wallet address --private-key=$buyerPrivKey)
export expiryTime=$(date -v+7d +%s)
export amount=567896
export currency=$(cast keccak "USD")
export paymentMethod=$(cast keccak "wechat")
export payeeDetails=$(cast keccak $PAYEE_DETAILS)
export price=1000000000000000000
export usdRate=1000000000000000000

export sellerFeeRate=20
export buyerFeeRate=20
export bp=10000
export permit2Nonce=$(LC_ALL=C tr -dc '0-9' < /dev/urandom | head -c 11)
export permit2Amount=$(echo "($amount * ($bp + $sellerFeeRate) + ($bp - 1)) / $bp" | bc)
echo "permit2Amount: $permit2Amount"
echo "bp: $bp"
echo "sellerFeeRate: $sellerFeeRate"
echo "buyerFeeRate: $buyerFeeRate"
echo "permit2Nonce: $permit2Nonce"
echo "expiryTime: $expiryTime"
echo "currency: $currency"
echo "paymentMethod: $paymentMethod"
echo "payeeDetails: $payeeDetails"
echo "price: $price"
echo "usdRate: $usdRate"
echo "eoaSeller: $eoaSeller"
echo "tbaSeller: $tbaSeller"
echo "tradeId: $tradeId"
echo "usdc: $usdc"
echo "amount: $amount"
echo "price: $price"
echo "usdRate: $usdRate"
echo "eoaBuyer: $eoaBuyer"
echo "tbaBuyer: $tbaBuyer"
echo "buyerFeeRate: $buyerFeeRate"
echo "TakeIntent: $TakeIntent"
echo "SetWaypoint: $SetWaypoint"
echo "ZkVerifyProofVerifier: $ZkVerifyProofVerifier"
echo "Permit2Helper: $Permit2Helper"
echo "=========================================="

export intentParams="($usdc,($amount,$amount), $expiryTime, $currency, $paymentMethod, $payeeDetails, $price)"
export escrowParms="($tradeId, $usdc, $amount, $price, $usdRate, $eoaSeller, $tbaSeller, $sellerFeeRate, $paymentMethod, $currency, $payeeDetails, $tbaBuyer, $buyerFeeRate)"
export permit="(($usdc,$permit2Amount),$permit2Nonce,$expiryTime)"
export intentTypedHash=$(cast call $TakeIntent "getIntentTypedHash((address,(uint256,uint256),uint64,bytes32,bytes32,bytes32,uint256))" "$intentParams")
export escrowTypedHash=$(cast call $TakeIntent "getEscrowTypedHash((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256))" "$escrowParms")
export tokenPermissionsHash=$(cast call $TakeIntent "getTokenPermissionsHash((address,uint256))" "($usdc, $permit2Amount)")
export sellSignHash=$(cast call $Permit2Helper "getPermitWitnessTransferFromHash((address,(uint256,uint256),uint64,bytes32,bytes32,bytes32,uint256),((address,uint256),uint256,uint256))" "$intentParams" "$permit")
echo "sellSignHash: $sellSignHash"
echo "intentParams: $intentParams"

export sig=$(cast wallet sign --no-hash $sellSignHash --private-key=$sellerPrivKey)
export relayerSig=$(cast wallet sign --no-hash $escrowTypedHash --private-key=$relayerPrivKey)

echo "=========================================="
echo "Permit2 Details"
echo "=========================================="
echo "Token: $usdc"
echo "Amount: $permit2Amount"
echo "Nonce: $permit2Nonce"
echo "Expiry Time: $expiryTime"
echo "intentParams: $intentParams"
echo "escrowParms: $escrowParms"
echo "tokenPermissionsHash: $tokenPermissionsHash"
echo "sellSignHash: $sellSignHash"
echo "sig: $sig"
echo "relayerSig: $relayerSig"
echo "action1Data: $action1Data"
echo "action2Data: $action2Data"
echo "action3Data: $action3Data"
echo "=========================================="


export transferDetails="($Escrow,$permit2Amount)"

export emptyBytes="0x"
export action1Selector=$(cast sig "ESCROW_AND_INTENT_CHECK((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256),(address,(uint256,uint256),uint64,bytes32,bytes32,bytes32,uint256),bytes)")
echo "action1Selector: $action1Selector"
export action1Params=$(cast abi-encode "x((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256),(address,(uint256,uint256),uint64,bytes32,bytes32,bytes32,uint256),bytes)" "$escrowParms" "$intentParams" $emptyBytes)
echo "action1Params: $action1Params"
export action1Data="${action1Selector}${action1Params:2}"
export action2Selector=$(cast sig "ESCROW_PARAMS_CHECK((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256),bytes)")
echo "action2Selector: $action2Selector"
export action2Params=$(cast abi-encode "x((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256),bytes)" "$escrowParms" "$relayerSig")
echo "action2Params: $action2Params"

export action2Data="${action2Selector}${action2Params:2}"
export action3Selector=$(cast sig "SIGNATURE_TRANSFER_FROM_WITH_WITNESS(((address,uint256),uint256,uint256),(address,uint256),(address,(uint256,uint256),uint64,bytes32,bytes32,bytes32,uint256),bytes)")
echo "action3Selector: $action3Selector"
export action3Params=$(cast abi-encode "x(((address,uint256),uint256,uint256),(address,uint256),(address,(uint256,uint256),uint64,bytes32,bytes32,bytes32,uint256),bytes)" "$permit" "$transferDetails" "$intentParams" "$sig")
echo "action3Params: $action3Params" 
export action3Data="${action3Selector}${action3Params:2}"

# Note: For bytes[] encoding in cast abi-encode, we need to ensure each bytes value is properly formatted
# Each action data is already a hex string with 0x prefix, which cast should handle correctly
# However, we'll encode the array directly in the execute function call instead

# Execute the transaction
# execute(address payer, bytes32 tokenPermissionsHash, bytes32 witness, bytes32 intentTypeHash, bytes[] actions)
echo "=========================================="
echo "Executing takeSellerIntent..."
echo "=========================================="
echo "TakeIntent Contract: $TakeIntent"
echo "Payer (EOA Seller): $eoaSeller"
echo "Executor (EOA Buyer): $eoaBuyer"
echo "Token Permissions Hash: $tokenPermissionsHash"
echo "Escrow Typed Hash (witness): $escrowTypedHash"
echo "Intent Typed Hash: $intentTypedHash"
echo ""
echo "Action 1 (ESCROW_AND_INTENT_CHECK): $action1Data"
echo "Action 2 (ESCROW_PARAMS_CHECK): $action2Data"
echo "Action 3 (SIGNATURE_TRANSFER_FROM_WITH_WITNESS): $action3Data"
echo "=========================================="

# Build the full calldata for execute function
# Note: cast abi-encode for bytes[] arrays can be tricky
# We'll use cast's built-in encoding by calling the function directly
# Format actions as array: [bytes1, bytes2, bytes3]
# Each action is already a hex string with function selector + encoded params

# Ensure actions have 0x prefix
export action1Hex=$(echo "$action1Data" | grep -q "^0x" && echo "$action1Data" || echo "0x$action1Data")
export action2Hex=$(echo "$action2Data" | grep -q "^0x" && echo "$action2Data" || echo "0x$action2Data")
export action3Hex=$(echo "$action3Data" | grep -q "^0x" && echo "$action3Data" || echo "0x$action3Data")

cast send $TakeIntent \
  "execute(address,bytes32,bytes32,bytes32,bytes[])" \
  $eoaSeller \
  $tokenPermissionsHash \
  $escrowTypedHash \
  $intentTypedHash \
  "[$action1Hex,$action2Hex,$action3Hex]" \
  --rpc-url $ETH_RPC_URL \
  --private-key=$buyerPrivKey \
  --gas-limit 5000000


export waypointEscrowTypedHash=$(cast call $SetWaypoint "getEscrowTypedHash((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256))" "$escrowParms")
echo "waypointEscrowTypedHash: $waypointEscrowTypedHash \n escrowParms: $escrowParms"
export relayerSig=$(cast wallet sign --no-hash $waypointEscrowTypedHash --private-key=$relayerPrivKey)
echo "relayerSig: $relayerSig"

export action1Selector=$(cast sig "MAKE_PAYMENT((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256),bytes)")
export action1Params=$(cast abi-encode "x((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256),bytes)" "$escrowParms" "$relayerSig")
echo "action1Params: $action1Params"
export action1Data="${action1Selector}${action1Params:2}"
echo "action1Data: $action1Data"
export action1Hex=$(echo "$action1Data" | grep -q "^0x" && echo "$action1Data" || echo "0x$action1Data")
echo "action1Hex: $action1Hex"
echo "=========================================="
echo "Executing make payment..."
echo "=========================================="
echo "SetWaypoint Contract: $SetWaypoint"
echo "Payer (EOA Buyer): $eoaBuyer"
echo "Executor (EOA Seller): $eoaSeller"
echo "Escrow Typed Hash (witness): $waypointEscrowTypedHash"
echo "=========================================="


cast send $SetWaypoint \
  "execute(bytes32,bytes[])" \
  $waypointEscrowTypedHash \
  "[$action1Hex]" \
  --rpc-url $ETH_RPC_URL \
  --private-key=$buyerPrivKey \
  --gas-limit 5000000


export action1Selector=$(cast sig "RELEASE_BY_SELLER((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256),bytes)")
export action1Params=$(cast abi-encode "x((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256),bytes)" "$escrowParms" "$relayerSig")
export action1Data="${action1Selector}${action1Params:2}"
export action1Hex=$(echo "$action1Data" | grep -q "^0x" && echo "$action1Data" || echo "0x$action1Data")

cast send $SetWaypoint \
  "execute(bytes32,bytes[])" \
  $waypointEscrowTypedHash \
  "[$action1Hex]" \
  --rpc-url $ETH_RPC_URL \
  --private-key=$sellerPrivKey \
  --gas-limit 5000000


echo "=========================================="
echo "Executing release by seller..."
echo "=========================================="
echo "SetWaypoint Contract: $SetWaypoint"
echo "Payer (EOA Seller): $eoaSeller"
echo "Executor (EOA Buyer): $eoaBuyer"
echo "Escrow Typed Hash (witness): $waypointEscrowTypedHash"
echo "=========================================="


echo "=========================================="
echo "Transaction completed!"
echo "=========================================="

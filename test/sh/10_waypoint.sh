#!/bin/bash
#
# Take Intent Test Script
# 
# This script executes MainnetWaypoint functionality via command line.
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
export buyerPrivKey=$BUYER_PRIVATE_KEY
export sellerPrivKey=$SELLER_PRIVATE_KEY
export relayerPrivKey=${RELAYER_PRIVATE_KEY:-$sellerPrivKey}  # Default to seller if not set
export tbaBuyer=$TBA_BUYER
export tbaSeller=$TBA_SELLER
export tradeId=${TRADE_ID:-1}


# Contract addresses (can be overridden via environment variables)
export usdc=${USDC:-0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238}
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


export eoaSeller=$(cast wallet address --private-key=$sellerPrivKey)
export eoaBuyer=$(cast wallet address --private-key=$buyerPrivKey)

#export expiryTime=$(date -d "+7 days" +%s) #ubuntu

#export amount=1234567
export amount=234567
export currency=$(cast keccak "USD")
export paymentMethod=$(cast keccak "wechat")
export payeeDetails=$(cast keccak $PAYEE_DETAILS)
export price=1000000000000000000
export usdRate=1000000000000000000
export sellerFeeRate=20
export buyerFeeRate=20


export escrowParms="($tradeId, $usdc, $amount, $price, $usdRate, $eoaSeller, $tbaSeller, $sellerFeeRate, $paymentMethod, $currency, $payeeDetails, $tbaBuyer, $buyerFeeRate)"
export escrowTypedHash=$(cast call $SetWaypoint "getEscrowTypedHash((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256))" $escrowParms)
export relayerSig=$(cast wallet sign --no-hash $escrowTypedHash --private-key=$relayerPrivKey)

export action1Selector=$(cast sig "MAKE_PAYMENT((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256),bytes)")
export action1Params=$(cast abi-encode "x((uint256,address,uint256,uint256,uint256,address,address,uint256,bytes32,bytes32,bytes32,address,uint256),bytes)" "$escrowParms" "$relayerSig")
export action1Data="${action1Selector}${action1Params:2}"
export action1Hex=$(echo "$action1Data" | grep -q "^0x" && echo "$action1Data" || echo "0x$action1Data")

cast send $SetWaypoint \
  "execute(bytes32,bytes[])" \
  $escrowTypedHash \
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
  $escrowTypedHash \
  "[$action1Hex]" \
  --rpc-url $ETH_RPC_URL \
  --private-key=$sellerPrivKey \
  --gas-limit 5000000

result=$(cast call $LighterAccount 'getUserHonour(address)' $tbaSeller)
read -r accumulatedUsd placeholder count pendingCount cancelledCount disputesReceivedAsBuyer disputesReceivedAsSeller totalAdverseRulings disputesInitiatedAsBuyer disputesInitiatedAsSeller failedInitiations avgReleaseSeconds avgPaidSeconds <<< $(cast abi-decode -i "decodeResult(uint256,uint32,uint32,uint32,uint32,uint32,uint32,uint32,uint32,uint32,uint32,uint32)" $result | tr '\n' ' ')
echo "=========================================="
echo "Seller Honour"
echo "=========================================="
echo "Accumulated USD: $accumulatedUsd"
echo "Count: $count"
echo "Pending Count: $pendingCount"
echo "Cancelled Count: $cancelledCount"  
echo "Disputes Received As Buyer: $disputesReceivedAsBuyer"
echo "Disputes Received As Seller: $disputesReceivedAsSeller"
echo "Total Adverse Rulings: $totalAdverseRulings"  
echo "Disputes Initiated As Buyer: $disputesInitiatedAsBuyer"
echo "Disputes Initiated As Seller: $disputesInitiatedAsSeller"
echo "Failed Initiations: $failedInitiations"
echo "Avg Release Seconds: $avgReleaseSeconds"
echo "Avg Paid Seconds: $avgPaidSeconds"


result=$(cast call $LighterAccount 'getUserHonour(address)' $tbaBuyer)
read -r accumulatedUsd placeholder count pendingCount cancelledCount disputesReceivedAsBuyer disputesReceivedAsSeller totalAdverseRulings disputesInitiatedAsBuyer disputesInitiatedAsSeller failedInitiations avgReleaseSeconds avgPaidSeconds <<< $(cast abi-decode -i "decodeResult(uint256,uint32,uint32,uint32,uint32,uint32,uint32,uint32,uint32,uint32,uint32,uint32)" $result | tr '\n' ' ')
echo "=========================================="
echo "Buyer Honour"
echo "=========================================="
echo "Accumulated USD: $accumulatedUsd"
echo "Count: $count"
echo "Pending Count: $pendingCount"
echo "Cancelled Count: $cancelledCount"  
echo "Disputes Received As Buyer: $disputesReceivedAsBuyer"
echo "Disputes Received As Seller: $disputesReceivedAsSeller"
echo "Total Adverse Rulings: $totalAdverseRulings"  
echo "Disputes Initiated As Buyer: $disputesInitiatedAsBuyer"
echo "Disputes Initiated As Seller: $disputesInitiatedAsSeller"
echo "Failed Initiations: $failedInitiations"
echo "Avg Release Seconds: $avgReleaseSeconds"
echo "Avg Paid Seconds: $avgPaidSeconds"

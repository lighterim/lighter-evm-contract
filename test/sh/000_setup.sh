#!/bin/bash

set -e  # Exit on error

if [ -z "$LIGHTER_ACCOUNT" ]; then
    echo "Error: LIGHTER_ACCOUNT environment variable is not set"
    exit 1
fi

if [ -z "$LIGHTER_TICKET" ]; then
    echo "Error: LIGHTER_TICKET environment variable is not set"
    exit 1
fi

if [ -z "$ESCROW" ]; then
    echo "Error: ESCROW environment variable is not set"
    exit 1
fi

if [ -z "$ALLOWANCE_HOLDER" ]; then
    echo "Error: ALLOWANCE_HOLDER environment variable is not set"
    exit 1
fi

if [ -z "$TAKE_INTENT" ]; then
    echo "Error: TAKE_INTENT environment variable is not set"
    exit 1
fi

if [ -z "$SET_WAYPOINT" ]; then
    echo "Error: SET_WAYPOINT environment variable is not set"
    exit 1
fi

if [ -z "$ZK_VERIFY_PROOF_VERIFIER" ]; then
    echo "Error: ZK_VERIFY_PROOF_VERIFIER environment variable is not set"
    exit 1
fi

if [ -z "$PERMIT2_HELPER" ]; then
    echo "Error: PERMIT2_HELPER environment variable is not set"
    exit 1
fi
if [ -z "$BUYER_PRIV_KEY" ]; then
    echo "Error: BUYER_PRIV_KEY environment variable is not set"
    exit 1
fi

if [ -z "$SELLER_PRIV_KEY" ]; then
    echo "Error: SELLER_PRIV_KEY environment variable is not set"
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

if [ -z "$AMOUNT" ]; then
    echo "Error: AMOUNT environment variable is not set"
    exit 1
fi

if [ -z "$TRADE_ID" ]; then
    echo "Error: TRADE_ID environment variable is not set"
    exit 1
fi

if [ -z "$BUYER_PRIV_KEY" ]; then
    echo "Error: BUYER_PRIV_KEY environment variable is not set"
    exit 1
fi

if [ -z "$SELLER_PRIV_KEY" ]; then
    echo "Error: SELLER_PRIV_KEY environment variable is not set"
    exit 1
fi

export usdc=${USDC:-0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238}
export permit2=0x000000000022D473030F116dDEE9F6B43aC78BA3  # Standard Permit2 address
export usdcDecimals=6

# Load contract addresses from environment or use defaults
export LighterAccount=${LIGHTER_ACCOUNT}
export LighterTicket=${LIGHTER_TICKET}
export Escrow=${ESCROW}
export AllowanceHolder=${ALLOWANCE_HOLDER}
export TakeIntent=${TAKE_INTENT}
export SetWaypoint=${SET_WAYPOINT}
export ZkVerifyProofVerifier=${ZK_VERIFY_PROOF_VERIFIER}
export Permit2Helper=${PERMIT2_HELPER}
export buyerPrivKey=${BUYER_PRIV_KEY}
export sellerPrivKey=${SELLER_PRIV_KEY}

export nostrSeller=0x2a9716cdd08bd7b14c94119c8259c89f3baab64d7b161eb03ad43dc1c1ccec68
export nostrBuyer=0x36bd5b22605899659cb1053737316096195b3ceb37c851645efd23e4497d7097

# Function to create account and return TBA address
# Parameters: privateKey, nostrPubkey, lighterTicket
# Returns: tbaAddress
create_account_and_get_tba() {
    local accountManager=$1
    local nft=$2
    local privateKey=$3
    local nostrPubkey=$4
    local index=$5
    if [ -z "$index" ]; then
        index=0
    fi
    
    local eoa=$(cast wallet address --private-key=$privateKey)
    cast send $accountManager 'createAccount(address,bytes32)' $eoa $nostrPubkey --value 0.0001ether --private-key $privateKey
    
    local tokenId=$(cast --to-dec $(cast call $nft "tokenOfOwnerByIndex(address,uint256)" $eoa $index))
    echo "tokenId: $tokenId" >&2
    local tbaAddress=$(cast call $accountManager "getAccountAddress(uint256)(address)" $tokenId)
    echo "tbaAddress: $tbaAddress" >&2
    
    echo $tbaAddress
}

get_tba(){
    local accountManager=$1
    local nftId=$2
    local tbaAddress=$(cast call $accountManager "getAccountAddress(uint256)(address)" $nftId)
    echo "tbaAddress: $tbaAddress" >&2
    echo $tbaAddress
}

export eoaBuyer=$(cast wallet address --private-key=$buyerPrivKey)
export tbaBuyer=$(create_account_and_get_tba $LighterAccount $LighterTicket $buyerPrivKey $nostrBuyer)
export TBA_BUYER=$tbaBuyer

export eoaSeller=$(cast wallet address --private-key=$sellerPrivKey)
export tbaSeller=$(create_account_and_get_tba $LighterAccount $LighterTicket $sellerPrivKey $nostrSeller 10)
export TBA_SELLER=$tbaSeller

export tradeId=245
export usdc=0x1c7d4b196cb0c7b01d743fbc6116a902379c7238
export amount=100000
export price=1000000000000000000
export usdRate=0
export eoaSeller=0x34ed42fe688331040e4b37227a831a2603b4ab22
export tbaSeller=0xc3583eda25f800366fcd9ab1cd5c6510d8e753d2
export sellerFeeRate=0
export paymentMethod=0xa87f59463aa7edfb0cc3cc39e28ba98c83fda1a3b5c6c9d10219c02669eb8a19
export currency=0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e
export payeeDetails=0x48851157537b362efbdfbc1ca889da2693f554ac8052030acbe16a0fd411faf2
export tbaBuyer=0xd244ddfae5dd922c71ea8ccf3081ee554db0da7e
export buyerFeeRate=0
export relayerPrivKey=0x199b1a34d5cd548314842f6996456bb2a930c3763193dbe900192f993321ea43
export buyerPrivKey=0xe1feb4fca49ea4eba54f82c90b2c5736c64650f35337225311be16d81b94ca32
export SetWaypoint=0xc37160aadD3F53e0bAF9ccc7327aa4b9b05D2F4f
export ETH_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/tE4nUL18kXAYmNOM9M4U4K-jL21y5oJ3


# {"id":"245","token":"0x1c7d4b196cb0c7b01d743fbc6116a902379c7238","volume":"100000","price":"1000000000000000000","usdRate":"0","payer":"0x34ed42fe688331040e4b37227a831a2603b4ab22","seller":"0xc3583eda25f800366fcd9ab1cd5c6510d8e753d2","sellerFeeRate":"0","paymentMethod":"0xa87f59463aa7edfb0cc3cc39e28ba98c83fda1a3b5c6c9d10219c02669eb8a19","currency":"0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e","payeeDetails":"0x48851157537b362efbdfbc1ca889da2693f554ac8052030acbe16a0fd411faf2","buyer":"0xd244ddfae5dd922c71ea8ccf3081ee554db0da7e","buyerFeeRate":"0"}


export escrowParms="($tradeId, $usdc, $amount, $price, $usdRate, $eoaSeller, $tbaSeller, $sellerFeeRate, $paymentMethod, $currency, $payeeDetails, $tbaBuyer, $buyerFeeRate)"
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

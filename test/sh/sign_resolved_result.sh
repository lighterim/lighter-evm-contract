#!/bin/bash


# EIP-712 签名函数
sig_resolved_result() {
    # 参数映射
    local domainAppName=$1
    local domainAppVersion=$2
    local chainId=$3
    local verifyContractAddress=$4
    local escrowHash=$5
    local buyerThresholdBp=$6
    local privKey=$7

    # 1. 创建临时文件
    local tmp_json=$(mktemp /tmp/eip712_XXXXXX.json)

    # 2. 构造 JSON 内容 (注意数值类型不加引号)
    cat <<EOF > "$tmp_json"
{
  "types": {
    "EIP712Domain": [
      { "name": "name", "type": "string" },
      { "name": "version", "type": "string" },
      { "name": "chainId", "type": "uint256" },
      { "name": "verifyingContract", "type": "address" }
    ],
    "ResolvedResult": [
      { "name": "escrowHash", "type": "bytes32" },
      { "name": "buyerThresholdBp", "type": "uint16" }
    ]
  },
  "primaryType": "ResolvedResult",
  "domain": {
    "name": "$domainAppName",
    "version": "$domainAppVersion",
    "chainId": $chainId,
    "verifyingContract": "$verifyContractAddress"
  },
  "message": {
    "escrowHash": "$escrowHash",
    "buyerThresholdBp": $buyerThresholdBp
  }
}
EOF

    # 3. 调用 cast 执行签名并捕获输出
    # 根据你提供的版本指令使用 --data --from-file
    local signature=$(cast wallet sign --data --from-file "$tmp_json" --private-key "$privKey")

    # 4. 清理临时文件
    rm "$tmp_json"

    # 5. 输出结果 (供外部变量接收)
    echo "$signature"
}
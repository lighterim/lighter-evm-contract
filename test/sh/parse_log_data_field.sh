#!/bin/bash

# 定义解析函数
# 参数: $1=TransactionHash, $2=FullEventSignature, $3=DataEventSignature
parse_log_field() {
    # local tx_hash=$1
    local json=$1
    local full_sig=$2  # 完整的事件签名，用于计算 Topic0 检索 Log
    local data_sig=$3  # 仅包含 non-indexed 字段的签名，用于解码 Data
    local field_index=$4 # 你想要取的字段行号 (1, 2, 3...)

    # 1. 计算完整的 32 字节 Topic0
    local topic0=$(cast keccak "$full_sig")

    # 2. 获取 Receipt 并通过 Topic0 锁定特定的 Log 内容
    # local json=$(cast receipt "$tx_hash" --json)
    local log_info=$(echo "$json" | jq -r ".logs[] | select(.topics[0] == \"$topic0\")")

    if [ -z "$log_info" ]; then
        echo "Error: 未找到匹配的事件日志" >&2
        return 1
    fi

    # 3. 提取 data 部分
    local data=$(echo "$log_info" | jq -r '.data')

    # 4. 使用“伪签名”解码 Data 部分，并取指定行
    # tr -d '[:space:]' 用于确保输出没有杂质
    local result=$(cast decode-event --sig "$data_sig" "$data" | awk "NR==$field_index" | tr -d '[:space:]')

    echo "$result"
}
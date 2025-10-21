#!/usr/bin/env ts-node

/**
 * ABI 同步脚本
 * 
 * 此脚本用于将合约编译生成的 ABI 文件同步到 dapp 项目中
 * 确保 dapp 中的 ABI 定义与合约代码保持同步
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';

// 合约 ABI 映射配置
const CONTRACT_ABI_MAPPING = {
  'MainnetUserTxn': {
    source: 'artifacts/contracts/chains/Mainnet/UserTxn.sol/MainnetUserTxn.json',
    target: 'dapp/src/abis/MainnetUserTxn.json'
  },
  'LighterAccount': {
    source: 'artifacts/contracts/account/LighterAccount.sol/LighterAccount.json',
    target: 'dapp/src/abis/LighterAccount.json'
  },
  'Escrow': {
    source: 'artifacts/contracts/Escrow.sol/Escrow.json',
    target: 'dapp/src/abis/Escrow.json'
  },
  'ISettlerBase': {
    source: 'artifacts/contracts/interfaces/ISettlerBase.sol/ISettlerBase.json',
    target: 'dapp/src/abis/ISettlerBase.json'
  },
  'AllowanceHolder': {
    source: 'artifacts/contracts/allowanceholder/AllowanceHolder.sol/AllowanceHolder.json',
    target: 'dapp/src/abis/AllowanceHolder.json'
  }
};

/**
 * 同步单个合约的 ABI
 */
function syncContractABI(contractName: string, mapping: { source: string; target: string }) {
  const sourcePath = join(process.cwd(), mapping.source);
  const targetPath = join(process.cwd(), mapping.target);

  console.log(`🔄 同步 ${contractName} ABI...`);

  // 检查源文件是否存在
  if (!existsSync(sourcePath)) {
    console.error(`❌ 源文件不存在: ${sourcePath}`);
    console.log(`   请先运行: npx hardhat compile`);
    return false;
  }

  try {
    // 读取源 ABI 文件
    const sourceContent = readFileSync(sourcePath, 'utf-8');
    const sourceData = JSON.parse(sourceContent);

    // 提取 ABI 部分
    const abi = sourceData.abi;
    if (!abi) {
      console.error(`❌ 源文件中没有找到 ABI: ${sourcePath}`);
      return false;
    }

    // 确保目标目录存在
    const targetDir = join(targetPath, '..');
    if (!existsSync(targetDir)) {
      mkdirSync(targetDir, { recursive: true });
    }

    // 写入目标文件
    writeFileSync(targetPath, JSON.stringify(abi, null, 2));
    console.log(`✅ ${contractName} ABI 同步成功: ${mapping.target}`);
    return true;
  } catch (error) {
    console.error(`❌ 同步 ${contractName} ABI 失败:`, error);
    return false;
  }
}

/**
 * 主函数
 */
async function main() {
  console.log('🚀 开始同步合约 ABI 到 dapp 项目...');
  console.log('=====================================');

  let successCount = 0;
  let totalCount = Object.keys(CONTRACT_ABI_MAPPING).length;

  for (const [contractName, mapping] of Object.entries(CONTRACT_ABI_MAPPING)) {
    if (syncContractABI(contractName, mapping)) {
      successCount++;
    }
  }

  console.log('=====================================');
  console.log(`📊 同步完成: ${successCount}/${totalCount} 个合约 ABI 同步成功`);

  if (successCount === totalCount) {
    console.log('🎉 所有 ABI 同步成功！');
    console.log('');
    console.log('📝 下一步:');
    console.log('1. 检查 dapp 中的 ABI 导入路径是否正确');
    console.log('2. 运行 dapp 项目确保没有编译错误');
    console.log('3. 测试合约交互功能');
  } else {
    console.log('⚠️ 部分 ABI 同步失败，请检查错误信息');
    process.exit(1);
  }
}

// 运行脚本
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error('❌ 脚本执行失败:', error);
    process.exit(1);
  });
}

export { syncContractABI, CONTRACT_ABI_MAPPING };

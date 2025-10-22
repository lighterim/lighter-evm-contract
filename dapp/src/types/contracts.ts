/**
 * 合约 ABI 类型定义
 * 
 * 此文件定义了所有合约的 ABI 类型，确保类型安全
 */

import MainnetUserTxnABIJson from '../abis/MainnetUserTxn.json';
import LighterAccountABIJson from '../abis/LighterAccount.json';
import ISettlerBaseABIJson from '../abis/ISettlerBase.json';

// 提取 ABI 数组并断言为 const
export const MainnetUserTxnABI = MainnetUserTxnABIJson as unknown as Readonly<typeof MainnetUserTxnABIJson>;
export const LighterAccountABI = LighterAccountABIJson as unknown as Readonly<typeof LighterAccountABIJson>;
export const ISettlerBaseErrors = ISettlerBaseABIJson as unknown as Readonly<typeof ISettlerBaseABIJson>;

// 导出所有 ABI
export {
  MainnetUserTxnABIJson,
  LighterAccountABIJson,
  ISettlerBaseABIJson,
};
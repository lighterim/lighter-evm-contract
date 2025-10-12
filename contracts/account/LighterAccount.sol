// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import "erc6551/src/interfaces/IERC6551Registry.sol";
import "../token/LighterTicket.sol";
import {
    PendingTxExists, ZeroAddress, ZeroFunds, InvalidRecipient, InvalidRentPrice, HasPendingTx,
    InsufficientPayment, WithdrawalFailed, PendingTxNotExists, InvalidSender, InvalidTokenId
    } from "../core/SettlerErrors.sol";

/**
 * @title LighterAccount
 * @dev 业务合约：铸造 Ticket NFT 并自动创建对应的 TokenBound AccountV3 (TBA)
 * 
 * 功能：
 * 1. 按照售卖价格 mint Ticket NFT
 * 2. 自动为每个 mint 的 NFT 创建 TBA（AccountV3 实例）
 * 3. 支持批量 mint
 * 4. 价格管理和收益提取
 */
contract LighterAccount is Ownable, ReentrancyGuard {

    /// @notice LighterTicket 合约实例
    LighterTicket public immutable ticketContract;
    
    /// @notice ERC6551Registry 地址
    address public immutable registry;
    
    /// @notice AccountV3 实现合约地址
    address public immutable accountImpl;

    bytes32 public immutable salt;
    
    /// @notice 单个票券的租借价格
    uint256 public rentPrice;
    
    /// @notice 票券租借记录
    mapping(address => uint256) public ticketReceipts;

    // pending tx list [user => [tradeId...]]
    mapping(address => uint32) internal pendingTxCount;

    // / @notice 租借者地址
    // address payable public rentee;

    /// @notice 已租借的票券数量
    uint256 public totalRented;

    // ============ Events ============
    
    /**
     * @notice 当 NFT mint 并创建 TBA 时触发
     * @param renter 购买者地址
     * @param tokenId 票券 token ID
     * @param tbaAddress 创建的 TBA 地址
     * @param nostrPubKey NIP-05
     * @param rent 支付的价格
     */
    event TicketRentedWithTBA(
        address indexed renter,
        uint256 indexed tokenId,
        address indexed tbaAddress,
        bytes32 nostrPubKey,
        uint256 rent
    );

    event QuotaUpgraded(
        address indexed renter,
        uint256 indexed tokenId,
        address indexed tbaAddress,
        string hexNostrPubKey,
        uint256 rent
    );

    event TicketDestroyed(
        address indexed recipient,
        uint256 indexed tokenId,
        address indexed tbaAddress,
        string hexNostrPubKey,
        uint256 amount
    );
    
    /**
     * @notice 当 mint 价格更新时触发
     * @param oldPrice 旧价格
     * @param newPrice 新价格
     */
    event RentPriceUpdated(uint256 oldPrice, uint256 newPrice);
    

    // ============ Constructor ============

    /**
     * @param ticketContract_ LighterTicket 合约地址
     * @param registry_ ERC6551Registry 地址
     * @param accountImplementation_ AccountV3 实现地址
     * @param rentPrice_ 初始 mint 价格
     */
    constructor(
        address ticketContract_,
        address registry_,
        address accountImplementation_,
        uint256 rentPrice_
    ) Ownable(msg.sender) {
        if (rentPrice_ == 0) revert InvalidRentPrice();
        if (ticketContract_ == address(0)) revert ZeroAddress();
        if (registry_ == address(0)) revert ZeroAddress();
        if (accountImplementation_ == address(0)) revert ZeroAddress();
        
        ticketContract = LighterTicket(ticketContract_);
        registry = registry_;
        accountImpl= accountImplementation_;
        rentPrice = rentPrice_;
        salt = bytes32(uint256(uint160(address(this))));
    }

    // ============ Public Functions ============

    /**
     * @notice Mint 单个 NFT 并创建对应的 TBA
     * @param recipient NFT 接收者地址
     * @param nostrPubKey NOSTR pubkey
     * @return tokenId mint 的 token ID
     * @return tbaAddress 创建的 TBA 地址
     */
    function createAccount(address recipient, bytes32 nostrPubKey) 
        external 
        payable 
        nonReentrant
        returns (uint256 tokenId, address tbaAddress) 
    {
        if (recipient == address(0)) revert InvalidRecipient();
        if (msg.value < rentPrice) {
            revert InsufficientPayment(rentPrice, msg.value);
        }

        // 1. Mint NFT
        tokenId = ticketContract.mintWithURI(recipient, nostrPubKey);
        
        
        // 2. 创建 TBA (AccountV3 实例)
        tbaAddress = IERC6551Registry(registry).createAccount(
            accountImpl,
            salt,
            block.chainid,
            address(ticketContract),
            tokenId
        );
        
        // 3. 更新统计
        unchecked {
            totalRented++;
        }
        ticketReceipts[tbaAddress] += msg.value;
        
        emit TicketRentedWithTBA(recipient, tokenId, tbaAddress, nostrPubKey, msg.value);
        
        return (tokenId, tbaAddress);
    }

    function destroyAccount(uint256 tokenId, address payable recipient) external nonReentrant {
        if (tokenId == 0) revert InvalidTokenId();
        if (recipient == address(0)) revert ZeroAddress();

        address tbaAddress = IERC6551Registry(registry).account(
            accountImpl,
            salt,
            block.chainid,
            address(ticketContract),
            tokenId
        );

        if (tbaAddress == address(0)) revert ZeroAddress();
        if (msg.sender != tbaAddress) revert InvalidSender();

        string memory hexNostrPubKey = ticketContract.burn(tokenId);
        uint256 amount = ticketReceipts[tbaAddress];
        if (ticketReceipts[tbaAddress] > 0) {
            delete ticketReceipts[tbaAddress];
            (bool success, ) = recipient.call{value: amount}("");
            if (!success) revert WithdrawalFailed();
        }

        emit TicketDestroyed(recipient, tokenId, tbaAddress, hexNostrPubKey, amount);
    }
    
    /// @notice add pending tx count
    /// @param account user address
    function addPendingTx(address account) external {
        pendingTxCount[account]++;
    }

    /// @notice remove pending tx count
    /// @param account user address
    function removePendingTx(address account) external {
        pendingTxCount[account]--;
    }

    /// @notice upgrade quota
    /// @param tokenId token id
    function upgradeQuota(uint256  tokenId) external payable {
        if (msg.value < rentPrice) {
            revert InsufficientPayment(rentPrice, msg.value);
        }
        address account = IERC6551Registry(registry).account(
            accountImpl,
            salt,
            block.chainid,
            address(ticketContract),
            tokenId
        );

        if (account == address(0)) revert ZeroAddress();
        if (pendingTxCount[account] > 0) revert HasPendingTx(account);
        string memory hexNostrPubKey = ticketContract.tokenURI(tokenId);

        ticketReceipts[account] += msg.value;

        emit QuotaUpgraded(account, tokenId, account, hexNostrPubKey, msg.value);
        
    }

        /**
     * @notice 计算指定 NFT 的 TBA 地址（不创建）
     * @param tokenId NFT token ID
     * @return TBA 地址
     */
    function getAccountAddress(uint256 tokenId) external view returns (address) {
        return IERC6551Registry(registry).account(
            accountImpl,
            salt,
            block.chainid,
            address(ticketContract),
            tokenId
        );
    }

    /**
     * @notice 批量计算多个 NFT 的 TBA 地址
     * @param tokenIds NFT token ID 数组
     * @return TBA 地址数组
     */
    function batchGetAccountAddresses(uint256[] calldata tokenIds) 
        external 
        view 
        returns (address[] memory) 
    {
        address[] memory tbaAddresses = new address[](tokenIds.length);
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tbaAddresses[i] = IERC6551Registry(registry).account(
                accountImpl,
                salt,
                block.chainid,
                address(ticketContract),
                tokenIds[i]
            );
        }
        
        return tbaAddresses;
    }

    /// @notice check if user has available quota
    /// @param account user address
    /// @return true if user has available quota
    function hasAvailableQuota(address account) public view returns (bool) {
        uint256 quota = getQuota(account);
        return pendingTxCount[account] < quota;
    }

    /// @notice get quota
    /// @param account user address
    /// @return quota quota
    function getQuota(address account) public view returns (uint256) {
        return ticketReceipts[account] == 0 ? 1 : (ticketReceipts[account] + rentPrice-1) / rentPrice;
    }

    // ============ Admin Functions ============

    /**
     * @notice 更新 mint 价格
     * @param newPrice 新价格
     */
    function setRentPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = rentPrice;
        rentPrice = newPrice;
        emit RentPriceUpdated(oldPrice, newPrice);
    }

    // /**
    //  * @notice 提取合约中的 ETH
    //  */
    // function withdraw() external onlyOwner {
    //     uint256 balance = address(this).balance;
    //     if (balance == 0) revert ZeroFunds();
        
    //     (bool success, ) = msg.sender.call{value: balance}("");
    //     if (!success) revert WithdrawalFailed();
        
    //     emit FundsWithdrawn(msg.sender, balance);
    // }

    // /**
    //  * @notice 提取指定金额的 ETH
    //  * @param amount 提取金额
    //  */
    // function withdrawAmount(uint256 amount) external onlyOwner {
    //     require(amount > 0 && amount <= address(this).balance, "Invalid amount");
        
    //     (bool success, ) = msg.sender.call{value: amount}("");
    //     if (!success) revert WithdrawalFailed();
        
    //     emit FundsWithdrawn(msg.sender, amount);
    // }

    // ============ View Functions ============

    /**
     * @notice 获取合约余额
     * @return 合约中的 ETH 余额
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // /**
    //  * @notice 计算批量 mint 的总价格
    //  * @param count mint 数量
    //  * @return 总价格
    //  */
    // function calculateTotalPrice(uint256 count) external view returns (uint256) {
    //     return mintPrice * count;
    // }
}


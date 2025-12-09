// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import "erc6551/src/interfaces/IERC6551Registry.sol";
import "erc6551/src/interfaces/IERC6551Account.sol";
import "../token/LighterTicket.sol";
import {
    PendingTxExists, ZeroAddress, ZeroFunds, InvalidRecipient, InvalidRentPrice, HasPendingTx,
    InsufficientPayment, WithdrawalFailed, PendingTxNotExists, InvalidSender, InvalidTokenId,
    UnauthorizedExecutor,MaxPendingTxReached, NoPendingTx
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
    mapping(address => uint256) public ticketRents;

    // pending tx list [user => [tradeId...]]
    mapping(address => uint32) internal ticketPendingCounts;

    // authorized list [operator => isAuthorized]
    mapping(address => bool) public authorizedOperators;

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
        uint256 rent,
        bytes32 nostrPubKey
    );

    event QuotaUpgraded(
        address indexed renter,
        uint256 indexed tokenId,
        address indexed tbaAddress,
        uint256 rent,
        string hexNostrPubKey
    );

    event TicketDestroyed(
        address indexed recipient,
        uint256 indexed tokenId,
        address indexed tbaAddress,
        uint256 amount,
        string hexNostrPubKey
    );
    
    /**
     * @notice 当 mint 价格更新时触发
     * @param oldPrice 旧价格
     * @param newPrice 新价格
     */
    event RentPriceUpdated(uint256 oldPrice, uint256 newPrice);
    
    event OperatorAuthorized(address indexed operator, bool isAuthorized);

    modifier onlyAuthorized() {
        if (!authorizedOperators[msg.sender]) revert UnauthorizedExecutor(msg.sender);
        _;
    }

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

        ticketRents[tbaAddress] += msg.value;
        
        emit TicketRentedWithTBA(recipient, tokenId, tbaAddress, msg.value, nostrPubKey);
        
        return (tokenId, tbaAddress);
    }

    /// @notice 销毁票券，也会失去去TBA的控制权，退回租借资产。
    /// @param nftId token id
    /// @param recipient recipient address
    function destroyAccount(uint256 nftId, address payable recipient) external nonReentrant {
        if (nftId == 0) revert InvalidTokenId();
        if (recipient == address(0)) revert ZeroAddress();

        address tbaAddress = IERC6551Registry(registry).account(
            accountImpl,
            salt,
            block.chainid,
            address(ticketContract),
            nftId
        );

        if (tbaAddress == address(0)) revert ZeroAddress();
        if (msg.sender != ticketContract.ownerOf(nftId)) revert InvalidSender();
        if (ticketPendingCounts[tbaAddress] > 0) revert HasPendingTx(tbaAddress);

        string memory hexNostrPubKey = ticketContract.burn(nftId);
        uint256 amount = ticketRents[tbaAddress];
        if (ticketRents[tbaAddress] > 0) {
            delete ticketRents[tbaAddress];
            (bool success, ) = recipient.call{value: amount}("");
            if (!success) revert WithdrawalFailed();
        }

        emit TicketDestroyed(recipient, nftId, tbaAddress, amount, hexNostrPubKey);
    }
    
    /// @notice add pending tx count
    /// @param account user address
    function addPendingTx(address account) public onlyAuthorized {
        if (ticketPendingCounts[account] > getQuota(account) -1 ) revert MaxPendingTxReached(account);
        ticketPendingCounts[account]++;
    }

    /// @notice remove pending tx count
    /// @param account user address
    function removePendingTx(address account) public onlyAuthorized {
        if (ticketPendingCounts[account] <= 0) revert NoPendingTx(account);
        ticketPendingCounts[account]--;
    }

    /// @notice upgrade quota
    /// @param nftId token id
    function upgradeQuota(uint256  nftId) external payable {
        if (msg.value < rentPrice) {
            revert InsufficientPayment(rentPrice, msg.value);
        }
        address account = IERC6551Registry(registry).account(
            accountImpl,
            salt,
            block.chainid,
            address(ticketContract),
            nftId
        );

        if (account == address(0)) revert ZeroAddress();
        if (ticketPendingCounts[account] > 0) revert HasPendingTx(account);
        string memory hexNostrPubKey = ticketContract.tokenURI(nftId);

        ticketRents[account] += msg.value;

        emit QuotaUpgraded(msg.sender, nftId, account, msg.value, hexNostrPubKey);
    }

    function setTicketBaseURI(string calldata newBaseURI) external onlyOwner {
        ticketContract.setBaseURI(newBaseURI);
    }

    function authorizeOperator(address operator, bool isAuthorized) external onlyOwner {
        authorizedOperators[operator] = isAuthorized;
        emit OperatorAuthorized(operator, isAuthorized);
    }

    function token(address tbaAddress) public view returns (uint256, address, uint256) {
        IERC6551Account account = IERC6551Account(payable(tbaAddress));
        return account.token();
    }

    function isOwnerCall(address tbaAddress) public view returns (bool) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token(tbaAddress);
        if (chainId == block.chainid && tokenContract == address(ticketContract)){
            if(tbaAddress == msg.sender) return true;
            address owner = IERC721(tokenContract).ownerOf(tokenId);
            return owner == msg.sender;
        }
        return false;
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
        return ticketPendingCounts[account] < quota;
    }

    /// @notice get quota
    /// @param account user address
    /// @return quota quota
    function getQuota(address account) public view returns (uint256) {
        return ticketRents[account] == 0 ? 1 : (ticketRents[account] + rentPrice-1) / rentPrice;
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


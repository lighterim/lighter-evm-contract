// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "erc6551/src/interfaces/IERC6551Registry.sol";
import "erc6551/src/interfaces/IERC6551Account.sol";
import "../token/LighterTicket.sol";
// import {console} from "forge-std/console.sol";
import {
    ZeroAddress, InvalidRecipient, InvalidRentPrice, HasPendingTx,
    InsufficientPayment, WithdrawalFailed, InvalidSender, InvalidTokenId,
    UnauthorizedExecutor, NoPendingTx, InsufficientQuota
    } from "../core/SettlerErrors.sol";

/**
 * @title LighterAccount
 * @dev Business contract: Mints Ticket NFT and automatically creates corresponding TokenBound AccountV3 (TBA)
 * 
 * Features:
 * 1. Mint Ticket NFT at sale price
 * 2. Automatically create TBA (AccountV3 instance) for each minted NFT
 * 3. Support batch minting
 * 4. Price management and revenue extraction
 */
contract LighterAccount is Ownable, ReentrancyGuard {

    /// @notice LighterTicket contract instance
    LighterTicket public immutable ticketContract;
    
    /// @notice ERC6551Registry address
    address public immutable registry;
    
    /// @notice AccountV3 implementation contract address
    address public immutable accountImpl;

    bytes32 public immutable salt;
    
    /// @notice Rent price for a single ticket
    uint256 public rentPrice;
    
    /// @notice Ticket rental records
    mapping(address => uint256) public ticketRents;

    // pending tx list [user => [tradeId...]]
    mapping(address => uint32) internal ticketPendingCounts;

    // authorized list [operator => isAuthorized]
    mapping(address => bool) public authorizedOperators;

    // / @notice Renter address
    // address payable public rentee;

    /// @notice Total number of rented tickets
    uint256 public totalRented;

    // ============ Events ============
    
    /**
     * @notice Emitted when NFT is minted and TBA is created
     * @param renter Purchaser address
     * @param tokenId Ticket token ID
     * @param tbaAddress Created TBA address
     * @param nostrPubKey NIP-05
     * @param rent Price paid
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
     * @notice Emitted when mint price is updated
     * @param oldPrice Old price
     * @param newPrice New price
     */
    event RentPriceUpdated(uint256 oldPrice, uint256 newPrice);
    
    event OperatorAuthorized(address indexed operator, bool isAuthorized);

    modifier onlyAuthorized() {
        _onlyAuthorized();
        _;
    }


     function _onlyAuthorized() private view {
         if (!authorizedOperators[msg.sender]) revert UnauthorizedExecutor(msg.sender);
     }


    // ============ Constructor ============

    /**
     * @param ticketContract_ LighterTicket contract address
     * @param registry_ ERC6551Registry address
     * @param accountImplementation_ AccountV3 implementation address
     * @param rentPrice_ Initial mint price
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
     * @notice Mint a single NFT and create corresponding TBA
     * @param recipient NFT recipient address
     * @param nostrPubKey NOSTR pubkey
     * @return tokenId Minted token ID
     * @return tbaAddress Created TBA address
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
        
        
        // 2. Create TBA (AccountV3 instance)
        tbaAddress = IERC6551Registry(registry).createAccount(
            accountImpl,
            salt,
            block.chainid,
            address(ticketContract),
            tokenId
        );
        
        // 3. Update statistics
        unchecked {
            totalRented++;
        }

        ticketRents[tbaAddress] += msg.value;
        
        emit TicketRentedWithTBA(recipient, tokenId, tbaAddress, msg.value, nostrPubKey);
        
        return (tokenId, tbaAddress);
    }

    /// @notice Destroy ticket, also lose control of TBA, return rental assets
    /// @param nftId Token ID
    /// @param recipient Recipient address
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
        // console.logString("------------addPendingTx--------------------");
        // console.logAddress(account);
        // console.log("ticketPendingCounts[account]", ticketPendingCounts[account]);
        if(!hasAvailableQuota(account)) revert InsufficientQuota(account);
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
    function upgradeQuota(uint256  nftId) external payable nonReentrant {
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

    function isOwnerCall(address tbaAddress, address caller) public view returns (bool) {
        // console.logString("------------isOwnerCall--------------------");
        // console.logAddress(tbaAddress);
        // console.logAddress(caller);
        // console.logString("------------isOwnerCall------------------end------------------");
        (uint256 chainId, address tokenContract, uint256 tokenId) = token(tbaAddress);
        if (chainId == block.chainid && tokenContract == address(ticketContract)){
            if(tbaAddress == caller) return true;
            address owner = IERC721(tokenContract).ownerOf(tokenId);
            return owner == caller;
        }
        return false;
    }

    /**
     * @notice Calculate TBA address for specified NFT (without creating)
     * @param tokenId NFT token ID
     * @return TBA address
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
     * @notice Batch calculate TBA addresses for multiple NFTs
     * @param tokenIds Array of NFT token IDs
     * @return Array of TBA addresses
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
        // console.log("account", account);
        // console.log("quota", quota);
        // console.log("ticketPendingCounts[account]", ticketPendingCounts[account]);
        return ticketPendingCounts[account] < quota;
    }

    /// @notice get quota
    /// @param account user address
    /// @return quota quota
    function getQuota(address account) public view returns (uint256) {
        return ticketRents[account] == 0 ? 0 : (ticketRents[account] + rentPrice-1) / rentPrice;
    }


    // ============ Admin Functions ============

    /**
     * @notice Update mint price
     * @param newPrice New price
     */
    function setRentPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = rentPrice;
        rentPrice = newPrice;
        emit RentPriceUpdated(oldPrice, newPrice);
    }

    // /**
    //  * @notice Withdraw ETH from contract
    //  */
    // function withdraw() external onlyOwner {
    //     uint256 balance = address(this).balance;
    //     if (balance == 0) revert ZeroFunds();
        
    //     (bool success, ) = msg.sender.call{value: balance}("");
    //     if (!success) revert WithdrawalFailed();
        
    //     emit FundsWithdrawn(msg.sender, balance);
    // }

    // /**
    //  * @notice Withdraw specified amount of ETH
    //  * @param amount Amount to withdraw
    //  */
    // function withdrawAmount(uint256 amount) external onlyOwner {
    //     require(amount > 0 && amount <= address(this).balance, "Invalid amount");
        
    //     (bool success, ) = msg.sender.call{value: amount}("");
    //     if (!success) revert WithdrawalFailed();
        
    //     emit FundsWithdrawn(msg.sender, amount);
    // }

    // ============ View Functions ============

    /**
     * @notice Get contract balance
     * @return ETH balance in contract
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // /**
    //  * @notice Calculate total price for batch minting
    //  * @param count Number of mints
    //  * @return Total price
    //  */
    // function calculateTotalPrice(uint256 count) external view returns (uint256) {
    //     return mintPrice * count;
    // }
}


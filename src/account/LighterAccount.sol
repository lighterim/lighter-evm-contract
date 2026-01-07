// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "erc6551/src/interfaces/IERC6551Registry.sol";
import "erc6551/src/interfaces/IERC6551Account.sol";
import "../token/LighterTicket.sol";
import "../interfaces/ISettlerBase.sol";
// import {console} from "forge-std/console.sol";
import {
    ZeroAddress, InvalidAccountAddress, InvalidRecipient, InvalidRentPrice, HasPendingTx,
    InsufficientPayment, WithdrawalFailed, InvalidSender, InvalidTokenId, AccountAlreadyCreated,
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

    uint8 public immutable GENESIS1_END = 10;
    uint8 public immutable GENESIS2_END = 101;
    uint256 public immutable LIGHTER_TICKET_ID_START = 10000;
    
    /// @notice Total number of rented tickets
    uint256 public totalRented;
    /// @notice Rent price for a single ticket
    uint256 public rentPrice;
    /// @notice Ticket rental records
    mapping(address => uint256) public ticketRents;
    // user honour list [user => honour]
    mapping(address => ISettlerBase.Honour) internal userHonour;
    // authorized list [operator => isAuthorized]
    mapping(address => bool) internal authorizedOperators;
    
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
        
        // 1. Mint NFT
        tokenId = ticketContract.mintWithURI(recipient, nostrPubKey);
        
        tbaAddress = _createAccount(tokenId, nostrPubKey, recipient);
    }

    function createAccount(uint256 tokenId, bytes32 nostrPubKey) external payable nonReentrant returns (address tbaAddress) {
        if (getAccountAddress(tokenId).code.length > 0) revert AccountAlreadyCreated();
        
        return _createAccount(tokenId, nostrPubKey, ticketContract.ownerOf(tokenId));
    }

    function _createAccount(uint256 tokenId, bytes32 nostrPubKey, address recipient) internal returns (address) {
        if (msg.value < rentPrice) revert InsufficientPayment(rentPrice, msg.value);

        // 2. Create TBA (AccountV3 instance)
        address tbaAddress = IERC6551Registry(registry).createAccount(
            accountImpl,
            salt,
            block.chainid,
            address(ticketContract),
            tokenId
        );
        
        // 3. Update statistics
        unchecked {
            totalRented++;
            ticketRents[tbaAddress] += msg.value;
        }

        emit TicketRentedWithTBA(recipient, tokenId, tbaAddress, msg.value, nostrPubKey);
        
        return tbaAddress;
    }

    /// @notice Destroy ticket, also lose control of TBA, return rental assets
    /// @param nftId Token ID
    /// @param recipient Recipient address
    function destroyAccount(uint256 nftId, address payable recipient) external nonReentrant {
        if (nftId == 0) revert InvalidTokenId();
        if (recipient == address(0)) revert InvalidRecipient();

        address tbaAddress = IERC6551Registry(registry).account(
            accountImpl,
            salt,
            block.chainid,
            address(ticketContract),
            nftId
        );

        if (tbaAddress.code.length == 0) revert InvalidAccountAddress();
        if (msg.sender != ticketContract.ownerOf(nftId)) revert InvalidSender();
        if (userHonour[tbaAddress].pendingCount > 0) revert HasPendingTx(tbaAddress);

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
        userHonour[account].pendingCount++;
    }

    /// @notice release pending tx
    /// @param account account address
    /// @param usdAmount usd amount
    /// @param releaseSeconds release seconds
    /// @param paidSeconds paid seconds
    function releasePendingTx(address account, uint256 usdAmount, uint32 paidSeconds, uint32 releaseSeconds) public onlyAuthorized {
        if (userHonour[account].pendingCount <= 0) revert NoPendingTx(account);
        uint256 count = userHonour[account].count;
        uint256 tradeCount = count - userHonour[account].cancelledCount;
        uint256 denominator = tradeCount + 1;

        // Calculate weighted average: (avg * n + new) / (n + 1)
        // Since avg and new are both uint32, the result is guaranteed to fit in uint32
        // because weighted average cannot exceed max(avg, new)
        uint256 releaseSecondsSum = tradeCount == 0 
            ? releaseSeconds 
            : uint256(userHonour[account].avgReleaseSeconds) * tradeCount + releaseSeconds;
        uint256 paidSecondsSum = tradeCount == 0 
            ? paidSeconds 
            : uint256(userHonour[account].avgPaidSeconds) * tradeCount + paidSeconds;

        // Safe cast: weighted average result is bounded by max(avg, new), both are uint32
        unchecked {
            userHonour[account].avgReleaseSeconds = uint32(releaseSecondsSum / denominator);
            userHonour[account].avgPaidSeconds = uint32(paidSecondsSum / denominator);
            userHonour[account].count = uint32(count + 1);
        }
        userHonour[account].pendingCount--;
        userHonour[account].accumulatedUsd += usdAmount;
    }

    function cancelPendingTx(address account, bool isDuty) public onlyAuthorized {
        if (userHonour[account].pendingCount <= 0) revert NoPendingTx(account);
        userHonour[account].pendingCount--;
        userHonour[account].count++;
        if(isDuty) {
            userHonour[account].cancelledCount++;
        }
        
    }

    function resolvePendingTx(address account, uint256 usdAmount, bool isLoseDispute) public onlyAuthorized {
        if (userHonour[account].pendingCount <= 0) revert NoPendingTx(account);
        userHonour[account].pendingCount--;
        userHonour[account].count++;
        if(usdAmount > 0) {
            userHonour[account].accumulatedUsd += usdAmount;
        }
        if(isLoseDispute) {
            userHonour[account].lostDisputeCount++;
        }
    }

    function disputePendingTx(address account, bool byBuyer) public onlyAuthorized {
        if (userHonour[account].pendingCount <= 0) revert NoPendingTx(account);
        if(byBuyer) {
            userHonour[account].disputedAsSeller++;
        } else {
            userHonour[account].disputedAsBuyer++;
        }
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

        if (account.code.length == 0) revert InvalidAccountAddress();
        if (userHonour[account].pendingCount > 0) revert HasPendingTx(account);
        
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

    /// @notice get token id, token contract address and token id from tba address
    /// @param tbaAddress tba address
    /// @return tokenId token id
    /// @return tokenContract token contract address
    /// @return tokenId token id
    function token(address tbaAddress) public view returns (uint256, address, uint256) {
        IERC6551Account account = IERC6551Account(payable(tbaAddress));
        if (address(account).code.length == 0) revert InvalidAccountAddress();
        return account.token();
    }

    /// @notice check if the caller is the owner of the token
    /// @param tbaAddress tba address
    /// @param caller caller address
    /// @return true if the caller is the owner of the token
    function isOwnerCall(address tbaAddress, address caller) public view returns (bool) {
        // console.logString("------------isOwnerCall--------------------");
        // console.logAddress(tbaAddress);
        // console.logAddress(caller);
        // console.logString("------------isOwnerCall------------------end------------------");
        (uint256 chainId, address tokenContract, uint256 tokenId) = token(tbaAddress);
        if ((block.chainid == 31337 || chainId == block.chainid) && tokenContract == address(ticketContract)){
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
    function getAccountAddress(uint256 tokenId) public view returns (address) {
        return IERC6551Registry(registry).account(
            accountImpl,
            salt,
            block.chainid,
            address(ticketContract),
            tokenId
        );
    }

    /// @notice check if user has available quota
    /// @param account user address
    /// @return true if user has available quota
    function hasAvailableQuota(address account) public view returns (bool) {
        uint256 quota = getQuota(account);
        return userHonour[account].pendingCount < quota;
    }

    /// @notice get quota
    /// @param account user address
    /// @return quota quota
    function getQuota(address account) public view returns (uint256) {
        if(ticketRents[account] == 0) revert InvalidAccountAddress();
        return (ticketRents[account] + rentPrice-1) / rentPrice;
    }

    /// @notice get ticket type
    /// @param tbaAddress tba address
    /// @return ticket type
    function getTicketType(address tbaAddress) public view returns (ISettlerBase.TicketType) {
        (uint256 chainId, address tokenContract, uint256 tokenId)  = token(tbaAddress);
        if(
            (block.chainid != 31337 && chainId != block.chainid) 
            || tokenContract != address(ticketContract)
        ) revert InvalidAccountAddress();

        if(tokenId < GENESIS1_END) return ISettlerBase.TicketType.GENESIS1;
        if(tokenId < GENESIS2_END) return ISettlerBase.TicketType.GENESIS2;
        return ISettlerBase.TicketType.LIGHTER_USER;
    }

    
    function getUserHonour(address account) public view returns (ISettlerBase.Honour memory) {
        if(ticketRents[account] == 0) revert InvalidAccountAddress();
        return userHonour[account];
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

    /**
     * @notice Get contract balance
     * @return ETH balance in contract
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}


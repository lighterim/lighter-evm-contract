// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC6551Registry} from "erc6551/src/interfaces/IERC6551Registry.sol";
import {IERC6551Account} from "erc6551/src/interfaces/IERC6551Account.sol";

import "../token/LighterTicket.sol";
import "../interfaces/ISettlerBase.sol";
// import {console} from "forge-std/console.sol";
import {
    ZeroAddress, InvalidAccountAddress, InvalidRecipient, InvalidRentPrice, HasPendingTx,
    InsufficientPayment, InvalidSender, InvalidTokenId, AccountAlreadyCreated,
    UnauthorizedExecutor, NoPendingTx, InsufficientQuota
    } from "../core/SettlerErrors.sol";

/**
 * @title LighterAccount
 * @dev Business contract: Mints Ticket NFT and automatically creates corresponding TokenBound AccountV3 (TBA)
 * 
 * Features:
 * 1. Mint Ticket NFT at sale price
 * 2. Automatically create TBA (AccountV3 instance) for each minted NFT
 * 4. Price management 
 */
contract LighterAccount is Ownable, ReentrancyGuard {

    /// @notice LighterTicket contract instance
    LighterTicket public immutable TICKET_CONTRACT;
    /// @notice ERC6551Registry address
    address public immutable REGISTRY;
    /// @notice AccountV3 implementation contract address
    address public immutable ACCOUNT_IMPL;
    bytes32 public immutable SALT;

    // the end token id for genesis1(user group for genesis1) and genesis2(user group for genesis2)
    uint8 public constant GENESIS1_END = 10;
    // the end token id for genesis2(user group for genesis2)
    uint8 public constant GENESIS2_END = 101;
    // the start token id for lighter user(user group for lighter user).
    uint256 public constant LIGHTER_TICKET_ID_START = 10000;
    
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


    // ============ Modifiers ============
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
        
        TICKET_CONTRACT = LighterTicket(ticketContract_);
        REGISTRY = registry_;
        ACCOUNT_IMPL= accountImplementation_;
        rentPrice = rentPrice_;
        SALT = bytes32(uint256(uint160(address(this))));
    }


    // ============ Owner Functions ============
    /**
     * @notice Update mint price
     * @param newPrice New price
     */
    function setRentPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = rentPrice;
        rentPrice = newPrice;
        emit RentPriceUpdated(oldPrice, newPrice);
    }

    function setTicketBaseURI(string calldata newBaseURI) external onlyOwner {
        TICKET_CONTRACT.setBaseURI(newBaseURI);
    }

    function authorizeOperator(address operator, bool isAuthorized) external onlyOwner {
        authorizedOperators[operator] = isAuthorized;
        emit OperatorAuthorized(operator, isAuthorized);
    }

    // ============ Internal(authorized) Functions ============
    /// @notice add pending tx count
    /// @param tbaBuyer tba buyer address
    /// @param tbaSeller tba seller address
    function addPendingTx(address tbaBuyer, address tbaSeller) public onlyAuthorized {
        _addPendingTx(tbaBuyer);
        _addPendingTx(tbaSeller);
    }

    function _addPendingTx(address account) private {
        if(!hasAvailableQuota(account)) revert InsufficientQuota(account);
        userHonour[account].pendingCount++;
    }

    /// @notice release pending tx
    /// @param tbaBuyer tba buyer address
    /// @param tbaSeller tba seller address
    /// @param usdAmount usd amount
    /// @param releaseSeconds release seconds
    /// @param paidSeconds paid seconds
    function releasePendingTx(
        address tbaBuyer,
        address tbaSeller,
        uint256 usdAmount,
        uint32 paidSeconds,
        uint32 releaseSeconds
    ) public onlyAuthorized {
        _releaseBuyerPendingTx(tbaBuyer, usdAmount, paidSeconds);
        _releaseSellerPendingTx(tbaSeller, usdAmount, releaseSeconds);
    }

    function _releaseBuyerPendingTx(address account, uint256 usdAmount, uint32 paidSeconds) private {
        ISettlerBase.Honour storage honour = userHonour[account];
        uint32 currentAvg = honour.avgPaidSeconds;

        uint256 tradeCount = _updateRelease(honour, account, usdAmount);
        honour.avgPaidSeconds = _calcAvg(currentAvg, tradeCount, paidSeconds);
    }

    function _releaseSellerPendingTx(address account, uint256 usdAmount, uint32 releaseSeconds) private {
        ISettlerBase.Honour storage honour = userHonour[account];
        uint32 currentAvg = honour.avgReleaseSeconds;
        
        uint256 tradeCount = _updateRelease(honour, account, usdAmount);
        honour.avgReleaseSeconds = _calcAvg(currentAvg, tradeCount, releaseSeconds);
    }

    /**
     * @dev Internal helper to update core transaction metrics and return denominator for averages.
     * @return tradeCount Total successful trades before this update (for weighted average)
     */
    function _updateRelease(
        ISettlerBase.Honour storage honour, 
        address account,
        uint256 usdAmount
    ) private returns (uint256 tradeCount) {
        uint32 pendingCount = honour.pendingCount;
        if (pendingCount == 0) revert NoPendingTx(account);

        uint32 count = honour.count;
        uint32 cancelledCount = honour.cancelledCount;
        tradeCount = uint256(count - cancelledCount);

        unchecked {
            honour.accumulatedUsd += usdAmount;
            honour.count = count + 1;
            honour.pendingCount = pendingCount - 1;
        }
    }

    /**
     * @dev Calculates the weighted average: (currentAvg * n + newValue) / (n + 1)
     * @param currentAvg The existing average value
     * @param previousCount The number of successful trades PRIOR to this update (n)
     * @param newValue The new data point to incorporate
     * @return The new weighted average
     */
    function _calcAvg(
        uint32 currentAvg, 
        uint256 previousCount, 
        uint32 newValue
    ) private pure returns (uint32) {
        // If this is the first successful trade, the new value is the average
        if (previousCount == 0) {
            return newValue;
        }

        // Use uint256 for intermediate calculation to prevent overflow
        // Formula: (avg * n + new) / (n + 1)
        // Note: Weighted average will never exceed max(currentAvg, newValue),
        // so it is guaranteed to fit back into uint32.
        uint256 numerator = (uint256(currentAvg) * previousCount) + uint256(newValue);
        uint256 denominator = previousCount + 1;

        // casting to 'uint32' is safe because weighted average will never exceed max(currentAvg, newValue),
        // so it is guaranteed to fit back into uint32.
        unchecked {
            // forge-lint: disable-next-line(unsafe-typecast)
            return uint32(numerator / denominator);
        }
    }

    function cancelPendingTx(address tbaBuyer, address tbaSeller, bool isBuyerDuty) public onlyAuthorized {
        _cancelPendingTx(tbaBuyer, isBuyerDuty);
        _cancelPendingTx(tbaSeller, !isBuyerDuty);
    }

    function _cancelPendingTx(address account, bool isDuty) private {
        ISettlerBase.Honour storage honour = userHonour[account];
        uint32 pendingCount = honour.pendingCount;
        if(pendingCount == 0) revert NoPendingTx(account);
        unchecked {
            honour.pendingCount = (pendingCount -1);
            honour.count++;
        }
        if(isDuty) {
            unchecked {
                honour.cancelledCount++;
            }
        }
    }

    function resolvePendingTx(
        address tbaBuyer, 
        uint256 buyerAmount, 
        address tbaSeller, 
        uint256 sellerAmount,
        bool isInitiatedByBuyer,
        bool isBuyerLoseDispute
    ) public onlyAuthorized {
        _updateHonourOnResolve(tbaBuyer, buyerAmount, isInitiatedByBuyer, isBuyerLoseDispute);
        _updateHonourOnResolve(tbaSeller, sellerAmount, !isInitiatedByBuyer, !isBuyerLoseDispute);
    }

    function _updateHonourOnResolve(
        address account,
        uint256 usdAmount,
        bool iAmInitiator, 
        bool iLose
    ) private {
        ISettlerBase.Honour storage honour = userHonour[account];
        uint32 pendingCount = honour.pendingCount;
        if(pendingCount == 0) revert NoPendingTx(account);

        unchecked {
            honour.pendingCount = (pendingCount - 1);
            honour.count++;
            honour.accumulatedUsd += usdAmount;

            if(iLose) {
                if(iAmInitiator) honour.failedInitiations++;
                else honour.totalAdverseRulings++;
            }
        }
    }

    /// @notice Record a dispute for a pending transaction
    /// @param tbaBuyer The tba address of the buyer
    /// @param tbaSeller The tba address of the seller
    /// @param initiatedByBuyer True if buyer initiated the dispute, false if seller initiated
    function disputePendingTx(address tbaBuyer, address tbaSeller, bool initiatedByBuyer) public onlyAuthorized {
        ISettlerBase.Honour storage buyerHonour = userHonour[tbaBuyer];
        if (buyerHonour.pendingCount == 0) revert NoPendingTx(tbaBuyer); 
        ISettlerBase.Honour storage sellerHonour = userHonour[tbaSeller];
        if (sellerHonour.pendingCount == 0) revert NoPendingTx(tbaSeller);

        if(initiatedByBuyer) {
            unchecked{
                buyerHonour.disputesInitiatedAsBuyer++;
                sellerHonour.disputesReceivedAsSeller++;
            }
        } else {
            unchecked{
                sellerHonour.disputesInitiatedAsSeller++;
                buyerHonour.disputesReceivedAsBuyer++;
            }
        }
    }

    // ============ Public User Functions ============
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
        if (msg.value < rentPrice) revert InsufficientPayment(rentPrice, msg.value);
        if (recipient == address(0)) revert InvalidRecipient();
        
        // 1. Mint NFT
        tokenId = TICKET_CONTRACT.mintWithURI(recipient, nostrPubKey);
        tbaAddress = _createAccount(tokenId, nostrPubKey, recipient);
    }

    function createAccount(uint256 tokenId, bytes32 nostrPubKey) external nonReentrant returns (address tbaAddress) {
        if (isDeployedContract(getAccountAddress(tokenId))) revert AccountAlreadyCreated();
        
        return _createAccount(tokenId, nostrPubKey, TICKET_CONTRACT.ownerOf(tokenId));
    }

    function _createAccount(uint256 tokenId, bytes32 nostrPubKey, address recipient) internal returns (address) {
        // 2. Create TBA (AccountV3 instance)
        address tbaAddress = IERC6551Registry(REGISTRY).createAccount(
            ACCOUNT_IMPL,
            SALT,
            block.chainid,
            address(TICKET_CONTRACT),
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

        address tbaAddress = IERC6551Registry(REGISTRY).account(
            ACCOUNT_IMPL,
            SALT,
            block.chainid,
            address(TICKET_CONTRACT),
            nftId
        );

        if (!isDeployedContract(tbaAddress)) revert InvalidAccountAddress();
        if (msg.sender != TICKET_CONTRACT.ownerOf(nftId)) revert InvalidSender();
        if (userHonour[tbaAddress].pendingCount > 0) revert HasPendingTx(tbaAddress);

        string memory hexNostrPubKey = TICKET_CONTRACT.burn(nftId);
        uint256 amount = ticketRents[tbaAddress];
        if (amount > 0) {
            delete ticketRents[tbaAddress];
            Address.sendValue(recipient, amount);
        }

        emit TicketDestroyed(recipient, nftId, tbaAddress, amount, hexNostrPubKey);
    }

    /// @notice upgrade quota
    /// @param nftId token id
    function upgradeQuota(uint256  nftId) external payable nonReentrant {
        // genesis1 and genesis2 ticket id are not allowed to upgrade quota
        if (nftId < LIGHTER_TICKET_ID_START) revert InvalidTokenId();
        if (msg.value < rentPrice) revert InsufficientPayment(rentPrice, msg.value);

        address account = IERC6551Registry(REGISTRY).account(
            ACCOUNT_IMPL,
            SALT,
            block.chainid,
            address(TICKET_CONTRACT),
            nftId
        );

        if (!isDeployedContract(account)) revert InvalidAccountAddress();
        if (userHonour[account].pendingCount > 0) revert HasPendingTx(account);
        
        string memory hexNostrPubKey = TICKET_CONTRACT.tokenURI(nftId);
        ticketRents[account] += msg.value;

        emit QuotaUpgraded(msg.sender, nftId, account, msg.value, hexNostrPubKey);
    }


    /// @notice get token id, token contract address and token id from tba address
    /// @param tbaAddress tba address
    /// @return tokenId token id
    /// @return tokenContract token contract address
    /// @return tokenId token id
    function token(address tbaAddress) public view returns (uint256, address, uint256) {
        if(!isDeployedContract(tbaAddress)) revert InvalidAccountAddress();
        IERC6551Account account = IERC6551Account(payable(tbaAddress));
        return account.token();
    }

    /// @notice check if the caller is the owner of the token
    /// @param tbaAddress tba address
    /// @param caller caller address
    /// @return true if the caller is the owner of the token
    function isOwnerCall(address tbaAddress, address caller) public view returns (bool) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token(tbaAddress);
        if ((block.chainid == 31337 || chainId == block.chainid) && tokenContract == address(TICKET_CONTRACT)){
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
        return IERC6551Registry(REGISTRY).account(
            ACCOUNT_IMPL,
            SALT,
            block.chainid,
            address(TICKET_CONTRACT),
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
        if(!isDeployedContract(account) || ticketRents[account] == 0) return 0;
        return (ticketRents[account] + rentPrice-1) / rentPrice;
    }

    /// @notice get ticket type
    /// @param tbaAddress tba address
    /// @return ticket type
    function getTicketType(address tbaAddress) public view returns (ISettlerBase.TicketType) {
        (uint256 chainId, address tokenContract, uint256 tokenId)  = token(tbaAddress);
        if(
            (block.chainid != 31337 && chainId != block.chainid) 
            || tokenContract != address(TICKET_CONTRACT)
        ) revert InvalidAccountAddress();

        // the token id is less than GENESIS1_END, return GENESIS1(1-9)
        if(tokenId < GENESIS1_END) return ISettlerBase.TicketType.GENESIS1;
        // the token id is less than GENESIS2_END, return GENESIS2(10-100)
        if(tokenId < GENESIS2_END) return ISettlerBase.TicketType.GENESIS2;
        // deploment error, the token id is less than LIGHTER_TICKET_ID_START.
        if(tokenId < LIGHTER_TICKET_ID_START) revert InvalidAccountAddress();
        // the token id is greater than or equal to GENESIS2_END, return LIGHTER_USER(10000-)
        return ISettlerBase.TicketType.LIGHTER_USER;
    }
    
    function getUserHonour(address account) public view returns (ISettlerBase.Honour memory) {
        if(ticketRents[account] == 0) revert InvalidAccountAddress();
        return userHonour[account];
    }
    
    /**
     * @dev Check if given address is a deployed TokenBound contract
     */
    function isDeployedContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }


}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {GasSnapshot} from "@forge-gas-snapshot/GasSnapshot.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";

import {Permit2Signature} from "./utils/Permit2Signature.sol";

import {SafeTransferLib} from "../src/vendor/SafeTransferLib.sol";
import {LocalFork} from "./BaseForkTest.t.sol";
import {ISettlerBase} from "../src/interfaces/ISettlerBase.sol";


abstract contract BasePairTest is Test, GasSnapshot, Permit2Signature, LocalFork {
    using SafeTransferLib for IERC20;

    uint256 internal constant FROM_PRIVATE_KEY = 0x1337;
    address payable internal FROM = payable(vm.addr(FROM_PRIVATE_KEY));
    uint256 internal constant MAKER_PRIVATE_KEY = 0x0ff1c1a1;
    address payable internal MAKER = payable(vm.addr(MAKER_PRIVATE_KEY));

    uint48 internal constant PERMIT2_FROM_NONCE = 1;

    // address internal constant BURN_ADDRESS = 0x2222222222222222222222222222222222222222;

    ISignatureTransfer internal constant PERMIT2 = ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    // address internal constant ZERO_EX_ADDRESS = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    // IERC20 internal constant ETH = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    // IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    bytes32 internal immutable permit2Domain;

    constructor() {
        permit2Domain = bytes32(0x94c1dec87927751697bfc9ebf6fc4ca506bed30308b518f0e9d6c5f74bbafdb8);
        // Note: Remove vm.label() call in constructor as it may trigger FFI
        // Label setting moved to setUp()
        // vm.label(address(PERMIT2), "LocalPermit2");
    }

    function _testName() internal view virtual returns (string memory);
    function fromToken() internal view virtual returns (IERC20);
    // function toToken() internal view virtual returns (IERC20);
    function buyerFeeRate() internal pure virtual returns (uint256);
    function sellerFeeRate() internal pure virtual returns (uint256);
    function amount() internal pure virtual returns (uint256);
    function getBuyer() internal view virtual returns (address);
    function getSeller() internal view virtual returns (address);
    
    function getDeadline() internal view virtual returns (uint64){
        return uint64(block.timestamp + 7 days);
    }
    function getCurrency() internal view virtual returns (bytes32){
        return keccak256(abi.encodePacked("USD"));
    }
    function getPaymentMethod() internal view virtual returns (bytes32){
        return keccak256(abi.encodePacked("wechat"));
    }
    function getPayeeDetails() internal view virtual returns (bytes32){
        return keccak256(abi.encodePacked("dust", "wxp://f2f0in9xnsA4G_eXWBRORK63ixD6bMQcP11eKGFz1VS4Kf0", "memo" ));
    }
    function getPrice() internal view virtual returns (uint256){
        return 1 ether;
    }

    function slippageLimit() internal view virtual returns (uint256) {
        return 0;
    }

    function setUp() public virtual {
        // Local mode: do not fork, skip vm.createSelectFork call
        // if(bytes(_testChainId()).length > 0) {
        //     vm.createSelectFork(_testChainId(), _testBlockNumber());
        // }
        // vm.label(address(this), "FoundryTest");
        // vm.label(address(PERMIT2), "Permit2");
        // vm.label(FROM, "FROM");
        // vm.label(MAKER, "MAKER");
        
        

        // Initialize addresses with non-zero balances
        // https://github.com/0xProject/0x-settler#gas-comparisons
        // if (address(fromToken()).code.length != 0) {
        //     deal(address(fromToken()), FROM, amount());
        //     deal(address(fromToken()), MAKER, 1);
        // }
        // if (address(toToken()).code.length != 0) {
        //     deal(address(toToken()), MAKER, amount());
        //     deal(address(toToken()), BURN_ADDRESS, 1);
        // }
    }

    function snapStartName(string memory name) internal {
        snapStart(string.concat(name, "_", _testName()));
    }

    /// @dev Manually store a non-zero value as a nonce for Permit2
    /// note: we attempt to avoid touching storage by the usual means to side
    /// step gas metering
    function warmPermit2Nonce(address who) internal {
        // mapping(address => mapping(uint256 => uint256)) public nonceBitmap;
        //         msg.sender         wordPos    bitmap
        // as of writing, nonceBitmap begins at slot 0
        // keccak256(uint256(wordPos) . keccak256(uint256(msg.sender) . uint256(slot0)))
        // https://docs.soliditylang.org/en/v0.8.25/internals/layout_in_storage.html
        bytes32 slotId = keccak256(abi.encode(uint256(0), keccak256(abi.encode(who, uint256(0)))));
        bytes32 beforeValue = vm.load(address(PERMIT2), slotId);
        if (uint256(beforeValue) == 0) {
            vm.store(address(PERMIT2), slotId, bytes32(uint256(1)));
        }

        // For AllowanceTransfer, we also warm the nonce for `fromToken()`
        slotId = keccak256(
            abi.encode("UNIVERSAL_ROUTER", keccak256(abi.encode(fromToken(), keccak256(abi.encode(FROM, uint256(1))))))
        );
        beforeValue = vm.load(address(PERMIT2), slotId);
        if (uint256(beforeValue) == 0) {
            vm.store(address(PERMIT2), slotId, bytes32(uint256(1 << 208)));
        }
    }

    /// @dev Manually store a non-zero value as a nonce for 0xV4 OTC Orders
    /// note: we attempt to avoid touching storage by the usual means to side
    /// step gas metering
    function warmZeroExOtcNonce(address who) internal {
        // mapping(address => mapping(uint64 => uint128)) txOriginNonces;
        //        tx.origin          bucket    min nonce
        // OtcOrders is 8th in LibStorage Enum
        bytes32 slotId = keccak256(abi.encode(uint256(0), keccak256(abi.encode(who, (uint256(8) + 1) << 128))));
        // vm.store(address(ZERO_EX_ADDRESS), slotId, bytes32(uint256(1)));
    }

    modifier skipIf(bool condition) {
        if (!condition) {
            _;
        }
    }

    function safeApproveIfBelow(IERC20 token, address who, address spender, uint256 _amount) internal {
        // Can't use SafeTransferLib directly due to Foundry.prank not changing address(this)
        if (spender != address(0) && token.allowance(who, spender) < _amount) {
            vm.startPrank(who);
            SafeTransferLib.safeApprove(token, spender, type(uint256).max);
            vm.stopPrank();
        }
    }

    function balanceOf(IERC20 token, address account) internal view returns (uint256) {
        (bool success, bytes memory returnData) =
            address(this).staticcall(abi.encodeCall(this._balanceOf, (token, account)));
        assert(!success);
        assert(returnData.length == 32);
        return abi.decode(returnData, (uint256));
    }

    function _balanceOf(IERC20 token, address account) external view {
        uint256 result = token.balanceOf(account);
        assembly ("memory-safe") {
            mstore(0x00, result)
            revert(0x00, 0x20)
        }
    }

    function getIntentParams() public view returns (ISettlerBase.IntentParams memory intentParams) {
        intentParams = ISettlerBase.IntentParams({
            token: address(fromToken()),
            range: ISettlerBase.Range({ min: amount(), max: amount() }),
            expiryTime: getDeadline(),
            currency: getCurrency(), 
            paymentMethod: getPaymentMethod(),
            payeeDetails: getPayeeDetails(),
            price: getPrice()
        });
    }

    function getEscrowParams() public view returns (ISettlerBase.EscrowParams memory escrowParams) {
        escrowParams = ISettlerBase.EscrowParams({
            id: 1,
            token: address(fromToken()),
            volume: amount(),
            price: getPrice(),
            usdRate: 1_000,
            payer: getSeller(),
            seller: getSeller(),
            sellerFeeRate: sellerFeeRate(),
            paymentMethod: getPaymentMethod(),
            currency: getCurrency(),
            payeeDetails: getPayeeDetails(),
            buyer: getBuyer(),
            buyerFeeRate: buyerFeeRate()
        });
    }

}

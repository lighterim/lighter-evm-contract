// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {FullMath} from "../vendor/FullMath.sol";

/**
 * @title AmountMath
 * @notice Shared utility for converting token amounts to USD values.
 * @dev Uses FullMath.mulDiv to avoid intermediate overflow when multiplying
 *      tokenAmount × price × usdRate before dividing by the scale factor.
 */
library AmountMath {

    /// @dev Must match Context.USD_DECIMALS
    uint8 private constant USD_DECIMALS = 6;
    /// @dev Must match Context.PRICE_DECIMALS
    uint8 private constant PRICE_DECIMALS = 18;
    /// @dev Must match Context.USD_RATE_DECIMALS
    uint8 private constant USD_RATE_DECIMALS = 18;

    /**
     * @notice Calculates the USD value of a given token amount.
     * @dev Formula: (tokenAmount * price * usdRate) / 10^(tokenDecimals + PRICE_DECIMALS + USD_RATE_DECIMALS - USD_DECIMALS)
     *      Uses FullMath.mulDiv to prevent intermediate overflow.
     * @param tokenAmount The raw amount of the token (in its smallest unit)
     * @param tokenDecimals The decimals of the token
     * @param price The price of the token (scaled by PRICE_DECIMALS)
     * @param usdRate The conversion rate to USD (scaled by USD_RATE_DECIMALS)
     * @return amountUsd The total value in USD (scaled by USD_DECIMALS)
     */
    function calcAmountUsd(
        uint256 tokenAmount,
        uint8 tokenDecimals,
        uint256 price,
        uint256 usdRate
    ) internal pure returns (uint256 amountUsd) {
        uint256 exponent;
        unchecked {
            exponent = uint256(tokenDecimals) + PRICE_DECIMALS + USD_RATE_DECIMALS - USD_DECIMALS;
        }
        amountUsd = FullMath.mulDiv(tokenAmount * price, usdRate, 10 ** exponent);
    }
}

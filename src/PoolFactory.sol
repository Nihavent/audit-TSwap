/**
 * /-\|/-\|/-\|/-\|/-\|/-\|/-\|/-\|/-\|/-\
 * |                                     |
 * \ _____    ____                       /
 * -|_   _|  / ___|_      ____ _ _ __    -
 * /  | |____\___ \ \ /\ / / _` | '_ \   \
 * |  | |_____|__) \ V  V / (_| | |_) |  |
 * \  |_|    |____/ \_/\_/ \__,_| .__/   /
 * -                            |_|      -
 * /                                     \
 * |                                     |
 * \-/|\-/|\-/|\-/|\-/|\-/|\-/|\-/|\-/|\-/
 */
// SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity 0.8.20;

import { TSwapPool } from "./TSwapPool.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract PoolFactory {
    error PoolFactory__PoolAlreadyExists(address tokenAddress);
    //@report-written this error is not used
    error PoolFactory__PoolDoesNotExist(address tokenAddress);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(address token => address pool) private s_pools; // n probably poolTolen -> pool
    mapping(address pool => address token) private s_tokens; // n probably pool -> poolToken

    address private immutable i_wethToken;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PoolCreated(address tokenAddress, address poolAddress);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    //@report-written lacks zero check
    constructor(address wethToken) {
        i_wethToken = wethToken;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    // n creates a pool based on input token address and weth
    // q what happens if someone tries to create a pool with a zero token address?
    function createPool(address tokenAddress) external returns (address) {
        if (s_pools[tokenAddress] != address(0)) { //n checks if a pool address already exists that uses this token address
            revert PoolFactory__PoolAlreadyExists(tokenAddress);
        }
        // q weird ERC20 stuff, what if the name function reverts?
        string memory liquidityTokenName = string.concat("T-Swap ", IERC20(tokenAddress).name());
        // @report-written this should be .symbol() not .name()
        string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
        TSwapPool tPool = new TSwapPool(
            tokenAddress, 
            i_wethToken, 
            liquidityTokenName, 
            liquidityTokenSymbol
        );
        s_pools[tokenAddress] = address(tPool);
        s_tokens[address(tPool)] = tokenAddress;
        emit PoolCreated(tokenAddress, address(tPool));
        return address(tPool);
    }

    /*//////////////////////////////////////////////////////////////
                   EXTERNAL AND PUBLIC VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getPool(address tokenAddress) external view returns (address) {
        return s_pools[tokenAddress];
    }

    function getToken(address pool) external view returns (address) {
        return s_tokens[pool];
    }

    function getWethToken() external view returns (address) {
        return i_wethToken;
    }
}

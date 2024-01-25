// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {ERC20Mock} from "../Mocks/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool pool;

    ERC20Mock weth;
    ERC20Mock poolToken;

    address liquidityProvider = makeAddr("lp");
    address swapper = makeAddr("swapper");

    // Ghost variables - don't exist in contract but do exist in our handler
    int256 public expectedDeltaY;
    int256 public expectedDeltaX;
    int256 actualStartingY;
    int256 actualStartingX;

    int256 public actualDeltaY;
    int256 public actualDeltaX;

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(_pool.getWeth());
        poolToken = ERC20Mock(_pool.getPoolToken());
    }

    //Fuzz test deposits
    function deposit(uint256 wethAmount) public {
        //Lets make sure it's a reasonable amount to avoid weird overflow errors
        wethAmount = bound(
            wethAmount, 
            pool.getMinimumWethDepositAmount(), 
            type(uint64).max
        );

        actualStartingY = int256(weth.balanceOf(address(pool)));
        actualStartingX = int256(poolToken.balanceOf(address(pool)));
        expectedDeltaY = int256(wethAmount); // Expected increase in pool weth as a result of deposit
        expectedDeltaX = int256(pool.getPoolTokensToDepositBasedOnWeth(wethAmount)); // Expected number of pool tokens to deposit to maintain raitio K = XY

        //do deposit
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmount);
        poolToken.mint(liquidityProvider, uint256(expectedDeltaX));
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        pool.deposit(
                wethAmount, 
                0,
                uint256(expectedDeltaX),
                uint64(block.timestamp));
        
        vm.stopPrank();

        //check actual amounts
        int256 endingY = int256(weth.balanceOf(address(pool)));
        int256 endingX = int256(poolToken.balanceOf(address(pool)));

        actualDeltaY = int256(endingY) - int256(actualStartingY);
        actualDeltaX = int256(endingX) - int256(actualStartingX);
    }


    //Fuzz test swaps - we want to get some weth, lets deposit some poolTokens
    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWeth) public {
        // deltaY = outputWeth
        // deltaX = poolTokenAmount (calculated soon)

        outputWeth = bound(
            outputWeth, 
            pool.getMinimumWethDepositAmount(), 
            weth.balanceOf(address(pool))
        );
        //Do not allow a swap of all weth in pool
        if (outputWeth >= weth.balanceOf(address(pool))) {
            return;
        }

        //This is deltaX
        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
            outputWeth,
            poolToken.balanceOf(address(pool)),
            weth.balanceOf(address(pool))
        );

        if (poolTokenAmount >= type(uint64).max) {
            return;
        }
        
        //Update starting deltas
        actualStartingY = int256(weth.balanceOf(address(pool)));
        actualStartingX = int256(poolToken.balanceOf(address(pool)));

        expectedDeltaY = int256(-1) * int256(outputWeth); // Expected change in pool weth as a result of swap
        expectedDeltaX = int256(poolTokenAmount); // Expected number of pool tokens to deposit to maintain raitio K = XY

        //If the amount to deposit exceeds the swapper's balance, then mint them more tokens
        if(poolToken.balanceOf(swapper) < poolTokenAmount) {
            poolToken.mint(swapper, poolTokenAmount - poolToken.balanceOf(swapper) + 1);
        }

        //do swap
        vm.startPrank(swapper);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        //check actual amounts in pool
        int256 endingY = int256(weth.balanceOf(address(pool)));
        int256 endingX = int256(poolToken.balanceOf(address(pool)));

        actualDeltaY = int256(endingY) - int256(actualStartingY);
        actualDeltaX = int256(endingX) - int256(actualStartingX);

    }
    
}



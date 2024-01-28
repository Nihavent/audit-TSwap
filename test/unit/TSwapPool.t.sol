// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(address(poolToken), address(weth), "LTokenA", "LA");

        weth.mint(liquidityProvider, 2000e18);
        poolToken.mint(liquidityProvider, 2000e18);

        weth.mint(user, 10e18);
        poolToken.mint(user, 10e18);
    }

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        poolToken.approve(address(pool), 10e18);
        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, uint64(block.timestamp));
        assertEq(pool.totalSupply(), 0);
        assert(weth.balanceOf(liquidityProvider) + poolToken.balanceOf(liquidityProvider) > 400e18);
    }

    /*//////////////////////////////////////////////////////////////
                            Audit Unit Tests
    //////////////////////////////////////////////////////////////*/

    function testIncorrectFeesCalculatedIn_getInputAmountBasedOnOutput() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        console2.log("pool.getPriceOfOneWethInPoolTokens(): ", pool.getPriceOfOneWethInPoolTokens());
        //0.987158034397061298, ie. the user should pay ~0.9871 poolTokens for 1 WETH
        console2.log("pool.getPriceOfOnePoolTokenInWeth(): ", pool.getPriceOfOnePoolTokenInWeth());


        uint256 startingPoolWethBalance = weth.balanceOf(address(pool));
        uint256 startingPoolPoolTokenBalance = poolToken.balanceOf(address(pool));
        uint256 startingUserWethBalance = weth.balanceOf(address(user));
        uint256 startingUserPoolTokenBalance = poolToken.balanceOf(address(user));

        console2.log("Starting weth pool balance: ", startingPoolWethBalance);
        console2.log("Starting poolToken pool balance: ", startingPoolPoolTokenBalance);
        console2.log("Starting weth user balance: ", startingUserWethBalance);
        console2.log("Starting poolToken user balance: ", startingUserPoolTokenBalance);


        //Example: User says "I want 10 output WETH, and my input is poolToken"

        vm.startPrank(user);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);

        uint256 expectedOutput = 5e17;

        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        //uint256 expected = 9e18;

        pool.swapExactOutput(poolToken, weth, expectedOutput, uint64(block.timestamp));

        //Check balances
        uint256 endingPoolWethBalance = weth.balanceOf(address(pool));
        uint256 endingPoolPoolTokenBalance = poolToken.balanceOf(address(pool));
        uint256 endingUserWethBalance = weth.balanceOf(address(user));
        uint256 endingUserPoolTokenBalance = poolToken.balanceOf(address(user));

        console2.log("Ending weth pool balance: ", endingPoolWethBalance);
        console2.log("Ending poolToken pool balance: ", endingPoolPoolTokenBalance);
        console2.log("Ending weth user balance: ", endingUserWethBalance);
        console2.log("Ending poolToken user balance: ", endingUserPoolTokenBalance);

        //Check deltas as a result of swap
        int256 deltaPoolWethBalance = int256(endingPoolWethBalance) - int256(startingPoolWethBalance);
        int256 deltaPoolPoolTokenBalance = int256(endingPoolPoolTokenBalance) - int256(startingPoolPoolTokenBalance);
        int256 deltaUserWethBalance = int256(endingUserWethBalance) - int256(startingUserWethBalance);
        int256 deltaUserPoolTokenBalance = int256(endingUserPoolTokenBalance) - int256(startingUserPoolTokenBalance);

        console2.log("deltaPoolWethBalance: ", deltaPoolWethBalance);
        console2.log("deltaPoolPoolTokenBalance: ", deltaPoolPoolTokenBalance);
        console2.log("deltaUserWethBalance: ", deltaUserWethBalance);
        console2.log("deltaUserPoolTokenBalance: ", deltaUserPoolTokenBalance);


        //User has effectively swapped 5.04 poolTokens for 0.5 WETH at a ratio of ~10.08, ie. the user ended up paying ~10.08 poolTokens per WETH
        //-.500000000000000000
        // .500000000000000000
        // 5.040246367242430810
        //-5.040246367242430810
        
        // If we correct the magic numbers in fees... User swaps 0.5025 poolTokens for 0.5 WETH at a ratio of 1.005
        // -.500000000000000000
        //  .500000000000000000
        //  .502512562814070351
        // -.502512562814070351

    }


    // Cyfrin test for ### [H-1] Incorrect fee calculation in `TSwapPool::getInputAmountBasedOnOutput` causes protocol to take too many tokens from user

    function testFlawedSwapExactOutput() public {
        uint256 initialLiquidity = 100e18;
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), initialLiquidity);
        poolToken.approve(address(pool), initialLiquidity);

        pool.deposit({
            wethToDeposit: initialLiquidity,
            minimumLiquidityTokensToMint: 0,
            maximumPoolTokensToDeposit: initialLiquidity,
            deadline: uint64(block.timestamp)
        });

        vm.stopPrank();

        //user has 11 pool tokens
        address someUser = makeAddr("someUser");
        uint256 userInitialTokenBalance = 11e18;
        poolToken.mint(someUser, userInitialTokenBalance);

        vm.startPrank(someUser);

        // Users buys 1 WETH from the pool, paying with pool tokens
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(
            poolToken,
            weth,
            1 ether,
            uint64(block.timestamp)
        );

        // Initial liquidity was 1:1, so user should have paid ~1 pool token
        // However, it spent much more than that. The user started with 11 tokens, and now only has less than 1.
        assertLt(poolToken.balanceOf(someUser), 1 ether);
        vm.stopPrank();

        // The liquidity provider can rug all funds from the pool now,
        // including those deposited by user.
        vm.startPrank(liquidityProvider);
        pool.withdraw(
            pool.balanceOf(liquidityProvider),
            1, // minWethToWithdraw
            1, // minPoolTokensToWithdraw
            uint64(block.timestamp)
        );

        assertEq(weth.balanceOf(address(pool)), 0);
        assertEq(poolToken.balanceOf(address(pool)), 0);
    
    }


    //My test for ### [H-2] No slippage protection in `TSwapPool::swapExactOutput` may result in significant variance between expected swap and actual swap.

    function testNoSlippageProtectionIn_swapExactOutput() public {
        // 1. The price of 1 WETH is 1,000 USDC
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 1e18);
        poolToken.approve(address(pool), 2000e18); //In this case poolToken is USDC
        pool.deposit(
            1e18, //wethToDeposit
            100e18, //minimumLiquidityTokensToMint
            2000e18, //maximumPoolTokensToDeposit
            uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        console2.log("pool.getPriceOfOneWethInPoolTokens(): ", pool.getPriceOfOneWethInPoolTokens());
        // 1000 USDC ~ 1 WETH. The pool calculation considers the imapct of the potential deposited WETH and the fees..

        // 2. A user inputs a `swapExactOutput` looking to receive 1 WETH for their USDC:"
        //     1. inputToken: USDC
        //     2. outputToken: WETH
        //     3. outputAnount: 1
        //     4. deadline: whenever
        // 3. The function does not offer a maxInput amount
        // 4. As the transaction is pending in the mempool, the market changes. The price moves and now 1 WETH is worth 10,000 USDC, 10x more than the user expected.

        // n need to figure out how to not execute the swap in step 2. immediately. ie we need to submit a transaction but not execute it so we can change the pool values (price)

        // 5. The transaction completes, but the user sent the protocol 10,000 USDC instead of the expected 1,000 USDC.

        }



}

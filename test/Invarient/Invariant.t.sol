// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "../Mocks/ERC20Mock.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {
    //these pools have 2 assssets
    ERC20Mock weth;
    ERC20Mock poolToken;

    //Contracts being tested
    PoolFactory factory;
    TSwapPool pool;
    Handler handler;

    int256 constant STARTING_X = 100e18; // Starting poolToken
    int256 constant STARTING_Y = 50e18; // Starting WETH

    function setUp() public {
        weth = new ERC20Mock();
        poolToken = new ERC20Mock(); //?

        //Declare new pool and create a pool with weth and pooltoken
        factory = new PoolFactory(address(weth));
        pool = TSwapPool(factory.createPool(address(poolToken)));

        //Create initial x & y token balances
        poolToken.mint(address(this), uint256(STARTING_X));
        weth.mint(address(this), uint256(STARTING_Y));

        //Approve the ERC20 tokens to be spent by the pool
        poolToken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);

        //Deposit tokens intot he pool, give the starting X & Y balances
        pool.deposit(
            uint256(STARTING_Y), 
            uint256(STARTING_Y), 
            uint256(STARTING_X),
            uint64(block.timestamp)
        );

        handler = new Handler(pool);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.swapPoolTokenForWethBasedOnOutputWeth.selector;

        targetSelector(FuzzSelector({addr:address(handler), selectors:selectors}));
        targetContract(address(handler));
    }

    function statefulFuzz_constantProductFormulaStaysTheSameOnSwapX() public {
        assertEq(handler.actualDeltaX(), handler.expectedDeltaX());
    }

    function statefulFuzz_constantProductFormulaStaysTheSameOnSwapY() public {
        assertEq(handler.actualDeltaY(), handler.expectedDeltaY());
    }
}
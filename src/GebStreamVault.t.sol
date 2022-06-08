// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./GebStreamVault.sol";

contract GebStreamVaultTest is DSTest {
    GebStreamVault vault;

    function setUp() public {
        vault = new GebStreamVault();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}

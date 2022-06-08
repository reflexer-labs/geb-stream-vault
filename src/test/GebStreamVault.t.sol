// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.7;

import "ds-test/test.sol";
import "../sablier/Sablier.sol";
import "ds-token/token.sol";

import "../GebStreamVault.sol";

interface Hevm {
    function warp(uint256) external;
}

contract GebStreamVaultTest is DSTest {
    GebStreamVault vault;
    Sablier sablier;
    DSToken token;
    Hevm hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 initialVaultBalance = 1000 ether;

    address streamRecipient = address(0xfab);
    uint256 streamAmount = 200 ether;
    uint256 streamLength = 52 weeks;
    uint256 streamStart = now + 1 hours;
    uint256 streamEnd = streamStart + streamLength;

    function setUp() public {
        token = new DSToken("name", "symbol");
        sablier = new Sablier();
        vault = new GebStreamVault(address(sablier));

        token.mint(address(vault), initialVaultBalance);

        streamAmount = streamAmount - (streamAmount % streamLength);
    }

    function test_setup() public {
        assertEq(address(vault.sablier()), address(sablier));
        assertEq(vault.authorizedAccounts(address(this)), 1);
        assertEq(token.balanceOf(address(vault)), initialVaultBalance);
    }

    function testFail_setup_null_sablier() public {
        vault = new GebStreamVault(address(0));
    }

    function test_modify_parameters() public {
        vault.modifyParameters("sablierAddress", address(123));
        assertEq(address(vault.sablier()), address(123));
    }

    function testFail_modify_parameters_null_address() public {
        vault.modifyParameters("sablierAddress", address(0));
    }

    function testFail_modify_parameters_invalid_param() public {
        vault.modifyParameters("invalid", address(123));
    }

    function testFail_modify_parameters_unauthed() public {
        vault.removeAuthorization(address(this));
        vault.modifyParameters("sablierAddress", address(123));
    }

    function test_create_stream() public {
        uint streamId = vault.createStream(streamRecipient, streamAmount, address(token), streamStart, streamEnd);

        assertEq(vault.streamId(), streamId);

        (
            address sender,
            address recipient,
            uint256 deposit,
            address tokenAddress,
            uint256 startTime,
            uint256 stopTime,
            uint256 remainingBalance,
            uint256 ratePerSecond
        ) = sablier.getStream(streamId);

        assertEq(sender, address(vault));
        assertEq(recipient, streamRecipient);
        assertEq(deposit, streamAmount);
        assertEq(tokenAddress, address(token));
        assertEq(startTime, streamStart);
        assertEq(stopTime, streamEnd);
        assertEq(remainingBalance, streamAmount);
        assertEq(ratePerSecond, streamAmount / streamLength);

        assertEq(token.balanceOf(address(vault)), initialVaultBalance - streamAmount);
        assertEq(token.balanceOf(address(sablier)), streamAmount);
    }

    function testFail_create_stream_twice() public {
        vault.createStream(streamRecipient, streamAmount, address(token), streamStart, streamEnd);
        vault.createStream(streamRecipient, streamAmount, address(token), streamStart, streamEnd);
    }

    function testFail_create_stream_unauthed() public {
        vault.removeAuthorization(address(this));
        vault.createStream(streamRecipient, streamAmount, address(token), streamStart, streamEnd);
    }

    function test_cancel_stream_before_starts() public {
        test_create_stream();
        assertTrue(vault.streamId() != 0);

        vault.cancelStream();
        assertEq(vault.streamId(), 0);
        assertEq(token.balanceOf(address(vault)), initialVaultBalance);
        assertEq(token.balanceOf(address(sablier)), 0);
        assertEq(token.balanceOf(address(streamRecipient)), 0);
    }

    function test_cancel_mid_stream() public {
        test_create_stream();
        assertTrue(vault.streamId() != 0);

        hevm.warp(streamEnd - (streamLength / 2));

        vault.cancelStream();
        assertEq(vault.streamId(), 0);
        assertGt(token.balanceOf(address(vault)), initialVaultBalance - streamAmount);
        assertEq(token.balanceOf(address(sablier)), 0);
        assertGt(token.balanceOf(address(streamRecipient)), 0);
    }

    function test_cancel_after_stream_end() public {
        test_create_stream();
        assertTrue(vault.streamId() != 0);

        hevm.warp(streamEnd + 1);

        vault.cancelStream();
        assertEq(vault.streamId(), 0);
        assertEq(token.balanceOf(address(vault)), initialVaultBalance - streamAmount);
        assertEq(token.balanceOf(address(sablier)), 0);
        assertEq(token.balanceOf(address(streamRecipient)), streamAmount);
    }

    function testFail_cancel_stream_unexistent() public {
        vault.cancelStream();
    }

    function testFail_cancel_stream_unauthed() public {
        test_create_stream();
        vault.removeAuthorization(address(this));
        vault.cancelStream();
    }

    function test_transfer_ERC20() external {
        uint transferAmount = 25 ether;
        vault.transferERC20(address(token), address(0xfab), transferAmount);
        assertEq(token.balanceOf(address(vault)), initialVaultBalance - transferAmount);
        assertEq(token.balanceOf(address(0xfab)), transferAmount);
    }

    function testFail_transfer_ERC20_unauthed() external {
        vault.removeAuthorization(address(this));
        vault.transferERC20(address(token), address(0xfab), 2 ether);
    }
}

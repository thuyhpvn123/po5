// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/activeCode.sol";

contract MerchantActiveCodeTest is Test {
    MerchantActiveCode contractInstance;
    address owner = address(this);
    address merchant1 = address(0x1);
    address merchant2 = address(0x2);
    address user1 = address(0x3);
    
    function setUp() public {
        contractInstance = new MerchantActiveCode();
    }

    function testAddMerchant() public {
        vm.prank(owner);
        contractInstance.addMerchant(merchant1, "example.com", "https://install.com", "bundle123", "iOS");
        (string memory domain, , , , uint256 createTime) = contractInstance.merchants(merchant1);
        assertEq(domain, "example.com");
        assertGt(createTime, 0);
    }

    function testUpdateMerchant() public {
        vm.prank(owner);
        contractInstance.addMerchant(merchant1, "old.com", "https://old.com", "oldBundle", "iOS");
        vm.prank(merchant1);
        contractInstance.updateMerchant("new.com", "https://new.com", "newBundle", "Android");
        (string memory domain, , , , ) = contractInstance.merchants(merchant1);
        assertEq(domain, "new.com");
    }

    function testRemoveMerchant() public {
        vm.prank(owner);
        contractInstance.addMerchant(merchant1, "example.com", "https://install.com", "bundle123", "iOS");
        vm.prank(owner);
        contractInstance.removeMerchant(merchant1);
        (, , , , uint256 createTime) = contractInstance.merchants(merchant1);
        assertEq(createTime, 0);
    }

    function testRegisterDevice() public {
        vm.prank(user1);
        uint256 activeCode = contractInstance.registerDevice("1080p", "iOS", "16.0", "ref123");
        (, , , , uint256 storedActiveCode, ) = contractInstance.devices(user1);
        assertEq(activeCode, storedActiveCode);
    }

    function testGetActiveCodeInfo() public {
        vm.prank(user1);
        uint256 activeCode = contractInstance.registerDevice("1080p", "iOS", "16.0", "ref123");
        
        vm.prank(owner);
        contractInstance.addMerchant(user1, "example.com", "https://install.com", "bundle123", "iOS");
        
        (MerchantActiveCode.Merchant memory merchant, MerchantActiveCode.Device memory device) = contractInstance.getActiveCodeInfo(activeCode);
        assertEq(merchant.domain, "example.com");
        assertEq(device.screenSize, "1080p");
    }

    function testUseActiveCodeInfo() public {
        vm.prank(user1);
        uint256 activeCode = contractInstance.registerDevice("1080p", "iOS", "16.0", "ref123");
        
        vm.prank(user1);
        contractInstance.useActiveCodeInfo(activeCode);
        
        (, , , , uint256 storedActiveCode, ) = contractInstance.devices(user1);
        assertEq(storedActiveCode, 0);
    }

    function testOnlyOwnerCanRemoveMerchant() public {
        vm.prank(merchant1);
        vm.expectRevert("Not authorized");
        contractInstance.removeMerchant(merchant2);
    }
}

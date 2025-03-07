// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
// import {BalancesManager,TreeCommission,Showroom,EventLogger} from "../src/po5.sol";
import "../src/po5.sol";
import "../src/usdt.sol";
import "../src/ecom/EcomOrder.sol";
import "../src/ecom/EcomUser.sol";
import "../src/ecom/interfaces/IEcomProduct.sol";
contract BalancesManagerTest is Test {
    BalancesManager public BALANCE_MAN;
    TreeCommission public TREE_COM;
    Showroom public SHOWROOM;
    USDT public USDT_ERC;
    EventLogger public EVENT_LOG;
    ProposalVote public ROOT_NODE;
    ProposalVote public DAO_NODE;
    eStock public STOCK_NODE;
    EcomOrderContract public ECOM_ORDER;
    EcomUserContract public ECOM_USER;
    address public owner= address(0x1111);
    address[] public rootMembers;
    address[] public daoMembers;
    // address public StockNode = address(0x33);
    address public user1 = address(0x12345);
    address public user2 = address(0x22345);
    address public user3 = address(0x32345);
    address public SHOWROOM1 = address(0x111);
    address public SHOWROOM2 = address(0x222);
    uint256 count;
    uint MEMBERSHIP_BP =100;
    uint RETAIL_COMMISSION_PERCENT=20;
    uint ACTIVATION_BP = 10;
    uint SHOWROOM_BONUS = 20;
    constructor() {
        vm.startPrank(owner);
        rootMembers.push(address(0x11));
        rootMembers.push(address(0x12));
        rootMembers.push(address(0x13));
        daoMembers.push(address(0x21));
        daoMembers.push(address(0x22));
        daoMembers.push(address(0x23));
        USDT_ERC = new USDT();
        SHOWROOM = new Showroom();
        BALANCE_MAN = new BalancesManager();
        EVENT_LOG = new EventLogger();
        ROOT_NODE = new ProposalVote(rootMembers, address(BALANCE_MAN));
        DAO_NODE = new ProposalVote(daoMembers, address(BALANCE_MAN));
        ECOM_ORDER = new EcomOrderContract();
        ECOM_USER = new EcomUserContract();
        STOCK_NODE = new eStock("eStock", "po5", 1000, 1, address(USDT_ERC));
        TREE_COM = new TreeCommission(
            address(ECOM_ORDER), address(ECOM_USER),
            address(BALANCE_MAN),address(SHOWROOM),address(EVENT_LOG),address(ROOT_NODE),
            address(DAO_NODE),address(STOCK_NODE),address(USDT_ERC)
        );
        ECOM_USER.SetTreeCom(address(TREE_COM));
        ECOM_ORDER.SetTreeCom(address(TREE_COM));

        BALANCE_MAN.setTreeCommissionAddress(address(TREE_COM));
        SHOWROOM.setTreeCommissionContract(address(TREE_COM));
        USDT_ERC.mintToAddress(user1, 1000* 1e6);
        USDT_ERC.mintToAddress(user2, 1000* 1e6);
        USDT_ERC.mintToAddress(user3, 1000* 1e6);
        vm.stopPrank();
        
    }

    function testSetTreeCommissionAddress() public {
        vm.startPrank(owner);
        address newTreeCommission = address(0x4);
        BALANCE_MAN.setTreeCommissionAddress(newTreeCommission);
        assertEq(BALANCE_MAN.treeCommissionContract(), newTreeCommission);
        vm.stopPrank();
    }

    function testUpdateBalanceOnlyTreeCommission() public {
        vm.startPrank(address(TREE_COM));
        //thanh toan visa
        
        bytes32 utxoID = keccak256("test_utxo");
        BALANCE_MAN.updateBalance(user1, utxoID,100, true);
        assertEq(BALANCE_MAN.getBalance(user1), 100,"getBalance should be right");

        //thanh toan usdt
        bytes32 utxoID1 = bytes32(0);
        BALANCE_MAN.updateBalance(user1, utxoID1,100, true);
        (uint256 BP,,, ,) = BALANCE_MAN.getUltraBPInfo(user1, utxoID1);
        assertEq(BP, 100,"getUltraBPInfo should be right");
        vm.stopPrank();
    }

    function testUpdateBalanceUnauthorized() public {
        bytes32 utxoID = keccak256("test_utxo");
        vm.startPrank(user1);
        vm.expectRevert("Unauthorized");
        BALANCE_MAN.updateBalance(user1,utxoID, 100, true);
        vm.stopPrank();
    }

    function testBatchUpdateBalances() public {
        bytes32 utxoID = keccak256("test_utxo");
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;
        
        bool isAdd = true;

        vm.startPrank(address(TREE_COM));
        BALANCE_MAN.batchUpdateBalances(utxoID,users, amounts, isAdd);
        vm.stopPrank();

        assertEq(BALANCE_MAN.getBalance(user1), 100);
        assertEq(BALANCE_MAN.getBalance(user2), 200);
    }

    function testBatchUpdateBalancesArrayMismatch() public {
        bytes32 utxoID = keccak256("test_utxo");
        address[] memory users = new address[](2);
        uint256[] memory amounts = new uint256[](1);
        bool isAdd = true;

        vm.startPrank(address(TREE_COM));
        vm.expectRevert("Array lengths mismatch");
        BALANCE_MAN.batchUpdateBalances(utxoID,users, amounts, isAdd);
        vm.stopPrank();
    }
    //showroom
    function testShowroomTierCommissionRates() public {
        assertEq(SHOWROOM.getShowroomCommissionRate(Showroom.ShowroomTier.ShopInShop), 25);
        assertEq(SHOWROOM.getShowroomCommissionRate(Showroom.ShowroomTier.Kiosk), 50);
        assertEq(SHOWROOM.getShowroomCommissionRate(Showroom.ShowroomTier.Retail), 75);
        assertEq(SHOWROOM.getShowroomCommissionRate(Showroom.ShowroomTier.Hub), 100);
    }

    function testSetShowroomCommissionRate() public {
        vm.startPrank(owner);
        SHOWROOM.setShowroomCommissionRate(Showroom.ShowroomTier.Kiosk, 30);
        vm.stopPrank();
        assertEq(SHOWROOM.getShowroomCommissionRate(Showroom.ShowroomTier.Kiosk), 30);
        
    }

    function testAddShowroom() public {
        vm.startPrank(owner);
        SHOWROOM.addShowRoom(
            SHOWROOM1,
            address(0),
            Showroom.ShowroomTier.Kiosk,
            1000000,
            1000000
        );

        (address parent, 
         Showroom.ShowroomTier tier,
         uint256 totalBP,
         uint256 totalMember,
         uint256 expiryDate,
         uint256 longtitude,
         uint256 lattitude) = SHOWROOM.showroomNodes(SHOWROOM1);

        assertEq(parent, address(0));
        assertEq(uint(tier), uint(Showroom.ShowroomTier.Kiosk));
        assertEq(totalBP, 0);
        assertEq(totalMember, 0);
        assertEq(longtitude, 1000000);
        assertEq(lattitude, 1000000);
        vm.stopPrank();
    }

    function testGetShowrooms() public {
        vm.startPrank(owner);
        // Add multiple SHOWROOMs
        SHOWROOM.addShowRoom(SHOWROOM1, address(0), Showroom.ShowroomTier.Kiosk, 1000000, 1000000);
        SHOWROOM.addShowRoom(SHOWROOM2, address(0), Showroom.ShowroomTier.Retail, 2000000, 2000000);
        vm.stopPrank();

        Showroom.ShowroomNode[] memory nodes = SHOWROOM.getShowrooms(0, 2);
        assertEq(nodes.length, 2);
        assertEq(uint(nodes[0].tier), uint(Showroom.ShowroomTier.Kiosk));
        assertEq(uint(nodes[1].tier), uint(Showroom.ShowroomTier.Retail));
    }

    function testCalculateDistance() public {
        uint256 lat1 = 10 * 1e18; // 10 degrees
        uint256 lon1 = 20 * 1e18; // 20 degrees
        uint256 lat2 = 11 * 1e18; // 11 degrees
        uint256 lon2 = 21 * 1e18; // 21 degrees

        uint256 distance = SHOWROOM.calculateDistance(lat1, lon1, lat2, lon2);
        assertTrue(distance > 0);
    }

    function testFindNearestShowroom() public {
        vm.startPrank(owner);
        // Add SHOWROOMs with different locations
        SHOWROOM.addShowRoom(SHOWROOM1, address(0), Showroom.ShowroomTier.Kiosk, 1000000, 1000000);
        SHOWROOM.addShowRoom(SHOWROOM2, address(0), Showroom.ShowroomTier.Retail, 2000000, 2000000);

        address nearest = SHOWROOM.findNearestShowroom(1000100, 1000100);
        assertTrue(nearest != address(0));
        vm.stopPrank();
    }

    function testPlusCommission() public {
        vm.startPrank(owner);
        SHOWROOM.addShowRoom(SHOWROOM1, address(0), Showroom.ShowroomTier.Kiosk, 1000000, 1000000);
        vm.stopPrank();
        vm.startPrank(address(TREE_COM));
        uint256 commission = SHOWROOM.plusCommision(SHOWROOM1, 100);
        assertEq(commission, 50); // 50% commission for Kiosk tier
        vm.stopPrank();
    }

    function testPlusMember() public {
        vm.startPrank(owner);
        SHOWROOM.addShowRoom(SHOWROOM1, address(0), Showroom.ShowroomTier.Retail, 1000000, 1000000);
        vm.stopPrank();
        vm.startPrank(address(TREE_COM));
        uint256 commission = SHOWROOM.plusMember(SHOWROOM1, 1);
        assertEq(commission, 75); // 75% commission for Retail tier
        vm.stopPrank();
    }

    function testExpiredShowroom() public {
        vm.startPrank(owner);
        SHOWROOM.addShowRoom(SHOWROOM1, address(0), Showroom.ShowroomTier.Kiosk, 1000000, 1000000);
        
        // Set expiry date to past
        SHOWROOM.setShowroomExpiryDate(SHOWROOM1, 0);
        vm.stopPrank();
        vm.startPrank(address(TREE_COM));
        uint256 commission = SHOWROOM.plusCommision(SHOWROOM1, 100);
        assertEq(commission, 0); // Should return 0 for expired SHOWROOM
        vm.stopPrank();
    }
    //TreeCommission
     function testAddVIPMember() public {
        //1.register on EcomUser
        registerEcomUser(user1,address(ROOT_NODE));
        //
        vm.startPrank(owner);
        USDT_ERC.mintToAddress(user1, 1000* 1e6);
        SHOWROOM.addShowRoom(
            SHOWROOM1,
            address(0),
            Showroom.ShowroomTier.Kiosk,
            1000000,
            1000000
        );
        USDT_ERC.approve(address(TREE_COM), 1000 * 1e6);
        (address  daoNode,address  stockNode,address rootNode) = TREE_COM.getAddress();
        vm.stopPrank();
        vm.broadcast(owner); 
        // bytes32 utxoID1 = bytes32(0); //tt usdt
        bytes32 utxoID1 = keccak256(abi.encodePacked("1")); //tt visa
        console.log("rootnode:",address(ROOT_NODE));
        console.log("SHOWROOM:",address(SHOWROOM));
        TREE_COM.addVIPMember(user1, address(ROOT_NODE),utxoID1);
        vm.startBroadcast(user1);
        // Check if user1 is added as a VIP member
        (TreeCommission.VIPNode memory vipNodeInfo) = TREE_COM.getVIPInfo();
        assertEq(vipNodeInfo.parent, rootNode);
        uint bal = BALANCE_MAN.getBalance(vipNodeInfo.parent);
        console.log("bal:",bal);
        assertEq(bal,(MEMBERSHIP_BP * RETAIL_COMMISSION_PERCENT)/ 100,
            "parent of user1 should receive retail commission when itself buy vip membership"
        );
        // Upgrade user1 to promoter
        USDT_ERC.approve(address(TREE_COM), 1000 * 1e6);
        bytes32 utxoID2 = keccak256(abi.encodePacked("2"));
        TREE_COM.upgradeToPromoter(user1, 10000, 15000,utxoID2);
        // Check if user1 is now a promoter
        (TreeLib.NodeInfo memory nodeInfo, TreeLib.NodeData memory nodeData) = TREE_COM.getPromoterInfo();
        assertEq(nodeInfo.parent, rootNode);
        assertEq(uint(nodeInfo.status), uint(TreeLib.Status.InActive));
        assertEq(BALANCE_MAN.getBalance(rootNode),bal+ACTIVATION_BP,
            "rootNode should receive activation bonus-10bp"
        );
        assertEq(BALANCE_MAN.getBalance(SHOWROOM1),SHOWROOM_BONUS * 50/100,
            "rootNode should receive activation bonus-10bp"
        );
        vm.stopBroadcast();

        //test addPromoter
        //1.register on EcomUser
        registerEcomUser(user2,address(ROOT_NODE));
        //2.addPromoterMember cho user2 vao rootnode
        vm.startBroadcast(owner);
        TREE_COM.addPromoterMember(user2,address(ROOT_NODE),10000,2000,bytes32(0));
        assertEq(USDT_ERC.balanceOf(address(TREE_COM)), 160 * 1e6, "Incorrect USDT transfer"); // 120 + 40 USDT
        vm.stopBroadcast();
        //3.addPromoterMember cho user3 vao user2
        registerEcomUser(user3,user2);
        vm.startBroadcast(user2);
        USDT_ERC.approve(address(TREE_COM), 1000 * 1e6);
        TREE_COM.addPromoterMember(user3,user2,10000,2000,bytes32(0));
        uint balShowRoom = USDT_ERC.balanceOf(address(SHOWROOM));
        console.log("balShowRoom:",balShowRoom);

        // setDirector(user1);

        // vm.prank(owner);
        // TREE_COM.hourlyBatchProcessing();

        // vm.startBroadcast(user1);
        // ( nodeInfo,nodeData) = TREE_COM.getInfo();
        // console.log("children count:",nodeInfo.children.length);
        // console.log("teamBP:",nodeData.teamBP);

        //test national bonus

        // TREE_COM.distributeNationalBonus();
        // GetByteCode();
    }
    function registerEcomUser(address user,address parent )public{
        registerParams memory params;
        params.fullName = "thuy";
        params.email = "abc@gmail.com";
        params.gender = 0;
        params.dateOfBirth = 23041989;
        params.phoneNumber = "09312345678";
        params.parent = parent;
        vm.prank(user);
        ECOM_USER.register(params);
    }
    function setDirector(address rootUser) internal {
        bytes32 utxoID = keccak256("test_utxo");
        address[256] memory queue; // Danh sách chờ xử lý (max 256 node)
        uint256 front = 0;
        uint256 back = 0;
        uint256 totalNodes = 0;

        queue[back++] = rootUser; // Thêm user gốc vào hàng đợi

        while (front < back && totalNodes < 250) {
            address parent = queue[front++]; // Lấy user đang xử lý từ hàng đợi

            for (uint256 i = 1; i <= 6 && totalNodes < 250; i++) {
                address child = address(uint160(uint256(keccak256(abi.encodePacked(parent, i))))); // Tạo địa chỉ con giả lập

                // Sử dụng vm.prank để giả lập người gọi
                vm.prank(owner);
                USDT_ERC.mintToAddress(child, 1000 * 1e6);

                vm.prank(child);
                USDT_ERC.approve(address(TREE_COM), 1000 * 1e6);

                // Sử dụng vm.broadcast để giả lập giao dịch từ child
                vm.broadcast(child);
                TREE_COM.addPromoterMember(child, parent, 10000, 10000 + i * 10,utxoID);

                queue[back++] = child; // Thêm child vào hàng đợi
                totalNodes++;
            }
        }
    }


    // function testDistributeNationalBonus() public {
    //     // Add user1 as a VIP member and upgrade to promoter
    //     vm.prank(owner);
    //     TREE_COM.addVIPMember(user1, owner);
    //     vm.prank(user1);
    //     TREE_COM.upgradeToPromoter(user1, 0, 0);

    //     // Simulate some BP accumulation
    //     vm.prank(owner);
    //     TREE_COM.recordPersonalSales(user1, 100);

    //     // Distribute national bonus
    //     vm.prank(owner);
    //     TREE_COM.distributeNationalBonus();

    //     // Check if the national bonus pool is reset
    //     uint256 nationalBonusPool = TREE_COM.nationalBonusPool();
    //     assertEq(nationalBonusPool, 0);
    // }

    // function testHourlyRewardDistribution() public {
    //     // Add user1 as a VIP member and upgrade to promoter
    //     vm.prank(owner);
    //     TREE_COM.addVIPMember(user1, owner);
    //     vm.prank(user1);
    //     TREE_COM.upgradeToPromoter(user1, 0, 0);

    //     // Simulate some BP accumulation
    //     vm.prank(owner);
    //     TREE_COM.recordPersonalSales(user1, 100);

    //     // Distribute hourly rewards
    //     vm.prank(owner);
    //     TREE_COM.hourlyRewardDistribution();

    //     // Check if the sales data is reset
    //     (TreeCommission.NodeInfo memory nodeInfo, TreeCommission.NodeData memory nodeData) = TREE_COM.getInfo(user1);
    //     assertEq(nodeData.personalBP, 100);
    // }

    // function testResetMonthlyData() public {
    //     // Add user1 as a VIP member and upgrade to promoter
    //     vm.prank(owner);
    //     TREE_COM.addVIPMember(user1, owner);
    //     vm.prank(user1);
    //     TREE_COM.upgradeToPromoter(user1, 0, 0);

    //     // Simulate some BP accumulation
    //     vm.prank(owner);
    //     TREE_COM.recordPersonalSales(user1, 100);

    //     // Reset monthly data
    //     vm.prank(owner);
    //     TREE_COM.resetMonthlyData(0, 10);

    //     // Check if monthly data is reset
    //     (TreeCommission.NodeInfo memory nodeInfo, TreeCommission.NodeData memory nodeData) = TREE_COM.getInfo(user1);
    //     assertEq(nodeData.membershipSoldThisMonth, 0);
    //     assertEq(nodeData.productBPThisMonth, 0);
    // }
    function GetByteCode()public {
         //1.register on EcomUser
        registerParams memory params;
        params.fullName = "thuy";
        params.email = "abc@gmail.com";
        params.gender = 0;
        params.dateOfBirth = 23041989;
        params.phoneNumber = "09312345678";
        params.parent = 0xe59625Fa4989b91c208Fc18946dD3D3cc5701973;
        bytes memory bytesCodeCall = abi.encodeCall(
            ECOM_USER.register,
            (params)
        );
        console.log("ECOM_USER register: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
    }
}


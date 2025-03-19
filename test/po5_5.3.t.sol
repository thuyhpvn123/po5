// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
// import {BalancesManager,TreeCommission,Showroom,EventLogger} from "../src/po5.sol";
import "../src/po5.sol";
import "../src/usdt.sol";
import "../src/ecom/EcomOrder.sol";
import "../src/ecom/EcomUser.sol";
import "../src/ecom/EcomProduct.sol";
import "../src/ecom/EcomInfo.sol";
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
    EcomProductContract public ECOM_PRODUCT;
    EcomInfoContract public ECOM_INFO;
    MasterPool public MASTERPOOL;
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
    address retailer = address(0x123);
    address buyer = address(0x222);
    
    constructor() {
        vm.startPrank(owner);
        //Ecom
        ECOM_PRODUCT = new EcomProductContract();
        ECOM_USER = new EcomUserContract();
        ECOM_ORDER = new EcomOrderContract();
        ECOM_INFO = new EcomInfoContract();
        ECOM_PRODUCT.SetEcomUser(address(ECOM_USER));
        ECOM_ORDER.SetEcomUser(address(ECOM_USER));
        ECOM_ORDER.SetEcomProduct(address(ECOM_PRODUCT));
        ECOM_ORDER.SetEcomInfo(address(ECOM_INFO));
        ECOM_INFO.SetEcomOrder(address(ECOM_ORDER));
        ECOM_INFO.SetEcomProduct(address(ECOM_PRODUCT));
        //po5
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
        STOCK_NODE = new eStock("eStock", "po5", 1000*10**18, 10000, address(USDT_ERC));
        TREE_COM = new TreeCommission(
            address(ECOM_ORDER), address(ECOM_USER),
            address(BALANCE_MAN),address(SHOWROOM),address(EVENT_LOG),address(ROOT_NODE),
            address(DAO_NODE),address(STOCK_NODE),address(USDT_ERC)
        );
        MASTERPOOL = new MasterPool(address(USDT_ERC),address(BALANCE_MAN));
        //set treecom
        BALANCE_MAN.setTreeCommissionAddress(address(TREE_COM));
        BALANCE_MAN.setMasterPool(address(MASTERPOOL));
        SHOWROOM.setTreeCommissionContract(address(TREE_COM));
        STOCK_NODE.setTreeCom(address(TREE_COM));
        ROOT_NODE.setTreeCom(address(TREE_COM));
        DAO_NODE.setTreeCom(address(TREE_COM));
        ECOM_USER.SetTreeCom(address(TREE_COM));
        ECOM_ORDER.SetTreeCom(address(TREE_COM));
        // ECOM_ORDER.SetPos(address(TREE_COM));

        USDT_ERC.mintToAddress(user1, 1000* 1e6);
        USDT_ERC.mintToAddress(user2, 1000* 1e6);
        USDT_ERC.mintToAddress(user3, 1000* 1e6);
        USDT_ERC.mintToAddress(buyer, 10000000* 1e6);
        vm.stopPrank();
        
    }
    //test ProposalVote
    function testProposeAddMember() public {
        address newMember = address(0x4);
        vm.broadcast(address(0x11));
        ROOT_NODE.proposeAddMember(newMember);

        (address member, , , ) = ROOT_NODE.membershipProposals(0);
        assertEq(member, newMember);
    }
    function testVoteToAddAndRemoveMember() public {
        address newMember = address(0x4);
        vm.broadcast(address(0x11));
        ROOT_NODE.proposeAddMember(newMember);

        vm.broadcast(address(0x11));
        ROOT_NODE.voteToAddMember(0, true);
        vm.broadcast(address(0x12));
        ROOT_NODE.voteToAddMember(0, true);

        assertTrue(ROOT_NODE.isMember(newMember));
        //remove member
        vm.broadcast(address(0x11));
        ROOT_NODE.proposeRemoveMember(newMember);

        (address member, , , ) = ROOT_NODE.membershipProposals(1);
        assertEq(member, newMember);
        vm.broadcast(address(0x12));
        ROOT_NODE.voteToRemoveMember(1, true);
        vm.broadcast(address(0x13));
        ROOT_NODE.voteToRemoveMember(1, true);

        assertFalse(ROOT_NODE.isMember(newMember));
    }
    function testCreateProposal() public {
        vm.broadcast(address(0x11));
        ROOT_NODE.createProposal(payable(user2), 100 , "Project funding"); //neu muon chuyen amount usdt = 100*10**6 thi de la 100
        vm.startBroadcast(address(0x12));
        (address recipient, uint256 amount, string memory reason, , , ) = ROOT_NODE.getProposal(0);
        assertEq(recipient, user2);
        assertEq(amount, 100 );
        assertEq(reason, "Project funding");
        vm.stopBroadcast();
        //Gia dinh chuyen usdt cho Treecom de co the tra commission 
        vm.prank(owner);
        USDT_ERC.mintToAddress(address(TREE_COM),1_000_000 * 1e6);

        //
        vm.broadcast(address(0x12));
        ROOT_NODE.voteProposal(0, true);
        // vm.startBroadcast(address(0x13)); //chua test duoc tiep vi RootNode chua du tien. test ben Po5
        // ROOT_NODE.voteProposal(0, true);
        // (, , , uint256 approvals, , bool executed) = ROOT_NODE.getProposal(0);
        // assertTrue(executed);
        // assertEq(approvals, 2);
    }
    //test EStock
    function testSetExchangeRate() public {
        vm.prank(owner);
        STOCK_NODE.setExchangeRate(1500000);
        assertEq(STOCK_NODE.getExchangeRate(), 1500000);
    }

    function testBuyStock() public {
        vm.startPrank(user1);
        USDT_ERC.approve(address(STOCK_NODE), 100 * 1e6);
        STOCK_NODE.buyStock(100 * 1e6, 10000);
        assertEq(STOCK_NODE.balanceOf(user1), 10**6);
        vm.stopPrank();
    }
    // function testReceiveProfit() public {
    //     //user1 chuyen usdt cho contract estock
    //     vm.startPrank(user1);
    //     USDT_ERC.approve(address(STOCK_NODE), 200 * 1e6);
    //     STOCK_NODE.receiveProfitFromContract(200 * 1e6);
    //     assertEq(STOCK_NODE.getUserUSDTCommission(user1), 200 * 1e6);
    //     vm.stopPrank();
    //     //muon rut usdt thi phai nap usdt cho masterpool truoc
    //     vm.prank(owner);

    //     MASTERPOOL.deposit(200 * 1e6);
    //     vm.prank(user1);
    //     STOCK_NODE.withdrawUSDTCommission();
    //     // assertEq(STOCK_NODE.getUserUSDTCommission(user), 0);
    //     // assertEq(STOCK_NODE.getUserUSDTWithdrawn(user), 200 * 1e6);
    //     vm.stopPrank();
    // }

    //test BalanceManager
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
        BALANCE_MAN.updateBalance(user1, utxoID,100, true,ITreeCommission.TYPE_OF_COM.OTHER);
        (uint256 BP,,, ,) = BALANCE_MAN.getUltraBPInfo(user1, utxoID);
        assertEq(BP, 100,"getUltraBPInfo should be right");

        //thanh toan usdt
        bytes32 utxoID1 = bytes32(0);
        BALANCE_MAN.updateBalance(user1, utxoID1,100, true,ITreeCommission.TYPE_OF_COM.OTHER);
        assertEq(BALANCE_MAN.getBalance(user1), 100,"getBalance should be right");
        vm.stopPrank();
    }

    function testUpdateBalanceUnauthorized() public {
        bytes32 utxoID = keccak256("test_utxo");
        vm.startPrank(user1);
        vm.expectRevert("Unauthorized");
        BALANCE_MAN.updateBalance(user1,utxoID, 100, true,ITreeCommission.TYPE_OF_COM.OTHER);
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
        BALANCE_MAN.batchUpdateBalances(utxoID,users, amounts, isAdd,ITreeCommission.TYPE_OF_COM.OTHER);
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
        BALANCE_MAN.batchUpdateBalances(utxoID,users, amounts, isAdd,ITreeCommission.TYPE_OF_COM.OTHER);
        vm.stopPrank();
    }

    //test Showroom
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

    //test TreeCom
    function testGetChildren()public{
        registerEcomUser(user1,address(ROOT_NODE));
        vm.startBroadcast(owner);
        TREE_COM.addPromoterMember(user1,address(ROOT_NODE),10000,2000,keccak256(abi.encodePacked("1")));
        vm.stopBroadcast();
        registerEcomUser(address(0x331),user1);
        vm.broadcast(user1);
        TREE_COM.addPromoterMember(address(0x331), user1,10000,2000, keccak256(abi.encodePacked("2")));
        registerEcomUser(address(0x332),user1);
        vm.broadcast(user1);
        TREE_COM.addPromoterMember(address(0x332), user1,10000,2000, keccak256(abi.encodePacked("3")));
        registerEcomUser(address(0x333),user1);
        vm.broadcast(user1);
        TREE_COM.addPromoterMember(address(0x333), user1,10000,2000, keccak256(abi.encodePacked("4")));
        registerEcomUser(address(0x334),user1);
        vm.broadcast(user1);
        TREE_COM.addPromoterMember(address(0x334), user1,10000,2000, keccak256(abi.encodePacked("5")));
        registerEcomUser(address(0x335),user1);
        vm.broadcast(user1);
        TREE_COM.addPromoterMember(address(0x335), user1,10000,2000, keccak256(abi.encodePacked("6")));
        registerEcomUser(address(0x441),address(0x331));
        vm.broadcast(user1);
        TREE_COM.addPromoterMember(address(0x441),address(0x331),10000,2000, keccak256(abi.encodePacked("7")));
        registerEcomUser(address(0x442),address(0x331));
        vm.broadcast(user1);
        TREE_COM.addPromoterMember(address(0x442),address(0x331),10000,2000, keccak256(abi.encodePacked("8")));
        registerEcomUser(address(0x443),address(0x331));
        vm.broadcast(user1);
        TREE_COM.addPromoterMember(address(0x443),address(0x331),10000,2000, keccak256(abi.encodePacked("9")));
        vm.broadcast(user1);
        (address[] memory children, TreeLib.NodeInfo[] memory nodeinfos, TreeLib.NodeData[] memory nodedatas)= TREE_COM.getChildren(user1,10,0,1000);
        assertEq(children.length,5,"children number should be equal");

    }
    function testWithDrawCommissionUSDT()public {
        uint256 startTime = 1742025115; //7h49 ngay 15/3/2025
        vm.warp(startTime);
        registerEcomUser(user1,address(ROOT_NODE));
        vm.startBroadcast(owner);
        USDT_ERC.approve(address(TREE_COM), 1000 * 1e6);
        TREE_COM.addPromoterMember(user1,address(ROOT_NODE),10000,2000,bytes32(0));
        vm.stopBroadcast();
        (uint rootnodeBal,uint daonodeBal,uint stocknodeBal,,uint user1Bal,,,) = getBalance();
        uint256 endTime = 1742197963; //7h49 ngay 17/3/2025
        ITreeCommission.CommissionData memory commissionData = TREE_COM.getCommissionUSDTInRange(user1,startTime,endTime);
        assertEq(commissionData.retailBonus,20);//20 retail --personalSale
        assertEq(user1Bal,20,"balance of user1 should be equal");
        assertEq(stocknodeBal,62,"balance of estock should be equal"); 
        //62=10+20+32 voi
        // 10 = ACTIVATION_FEE -(SHOWROOM_BONUS + ACTIVATION_BP)  = 40-(20+10) = 10
        // 20 = membership_fee - membership_bp = 120-100 = 20
        // 32 = (bp * 32) / 100 = 32 --personalSale
        assertEq(daonodeBal,4,"balance of DAO should be equal"); //4- daonode
        //11 unilever???
        //1 showroom???
        //user1 withdraw commission
        vm.startBroadcast(user1);
        bytes32[] memory utxoArr = new  bytes32[](0);
        uint256 balUser1Before = USDT_ERC.balanceOf(user1);
        TREE_COM.withdrawBP(20,utxoArr);
        (rootnodeBal, daonodeBal, stocknodeBal, , user1Bal, , , ) = getBalance();
        assertEq(user1Bal,0,"balance bp of user1 should be deleted");
        uint256 balUser1After = USDT_ERC.balanceOf(user1);
        assertEq(balUser1Before + 20 * 10**6 ,balUser1After,"balance USDT of user1 should be equal");
        vm.stopBroadcast();
        assertEq(rootnodeBal,10,"balance of RootNode should be equal"); 

        //daonode withdraw commission
        //RootNode or DaoNode withdraw commission by withdrawUSDTCommission or withdrawUSDTCommission
        // executeProposal
        vm.broadcast(address(0x12));
        ROOT_NODE.createProposal(payable(user2), 10 , "Project funding"); //neu muon chuyen amount usdt = 100*10**6 thi de la 100
        //
        uint256 balUserBef = USDT_ERC.balanceOf(user2);
        vm.broadcast(address(0x12));
        ROOT_NODE.voteProposal(0, true);
        vm.startBroadcast(address(0x13)); 
        ROOT_NODE.voteProposal(0, true);
        (, , , uint256 approvals, , bool executed) = ROOT_NODE.getProposal(0);
        assertTrue(executed);
        assertEq(approvals, 2);
        assertEq(balUserBef + 10 * 10**6 ,USDT_ERC.balanceOf(user2),"balance USDT of user2 should be equal");
    }
    function testWithDrawCommissionVisa()public {
        bytes32 utxoID = keccak256(abi.encodePacked("1"));
        uint256 startTime = 1742025115; //7h49 ngay 15/3/2025
        vm.warp(startTime);
        registerEcomUser(user1,address(ROOT_NODE));
        vm.startBroadcast(owner);
        USDT_ERC.approve(address(TREE_COM), 1000 * 1e6);
        TREE_COM.addPromoterMember(user1,address(ROOT_NODE),10000,2000,utxoID);
        vm.stopBroadcast();
        (uint rootnodeBal,uint daonodeBal,uint stocknodeBal,,uint user1Bal,,,) = getBalanceUtxo(utxoID);
        (uint256 BP, uint256 createTime, uint256 activeTime, uint256 expiredTime, bool isDeny) = BALANCE_MAN.getUltraBPInfo(user1,utxoID);
        console.log("BP la:",BP);
        uint256 endTime = 1742197963; //7h49 ngay 17/3/2025
        ITreeCommission.CommissionData memory commissionData = TREE_COM.getCommissionUSDTInRange(user1,startTime,endTime);
        assertEq(commissionData.retailBonus,20);//20 retail --personalSale
        assertEq(user1Bal,20,"balance of user1 should be equal");
        assertEq(stocknodeBal,62,"balance of estock should be equal"); 
        //62=10+20+32 voi
        // 10 = ACTIVATION_FEE -(SHOWROOM_BONUS + ACTIVATION_BP)  = 40-(20+10) = 10
        // 20 = membership_fee - membership_bp = 120-100 = 20
        // 32 = (bp * 32) / 100 = 32 --personalSale
        assertEq(daonodeBal,4,"balance of DAO should be equal"); //4- daonode
        //11 unilever???
        //1 showroom???
        //user1 withdraw commission
        vm.startBroadcast(user1);
        bytes32[] memory utxoArr = new  bytes32[](0);
        uint256 balUser1Before = USDT_ERC.balanceOf(user1);
        TREE_COM.withdrawBP(20,utxoArr);
        // (rootnodeBal, daonodeBal, stocknodeBal, , user1Bal, , , ) = getBalance();
        // assertEq(user1Bal,0,"balance bp of user1 should be deleted");
        // uint256 balUser1After = USDT_ERC.balanceOf(user1);
        // assertEq(balUser1Before + 20 * 10**6 ,balUser1After,"balance USDT of user1 should be equal");
        // vm.stopBroadcast();
        // assertEq(rootnodeBal,10,"balance of RootNode should be equal"); 

        // //daonode withdraw commission
        // //RootNode or DaoNode withdraw commission by withdrawUSDTCommission or withdrawUSDTCommission
        // // executeProposal
        // vm.broadcast(address(0x12));
        // ROOT_NODE.createProposal(payable(user2), 10 , "Project funding"); //neu muon chuyen amount usdt = 100*10**6 thi de la 100
        // //
        // uint256 balUserBef = USDT_ERC.balanceOf(user2);
        // vm.broadcast(address(0x12));
        // ROOT_NODE.voteProposal(0, true);
        // vm.startBroadcast(address(0x13)); 
        // ROOT_NODE.voteProposal(0, true);
        // (, , , uint256 approvals, , bool executed) = ROOT_NODE.getProposal(0);
        // assertTrue(executed);
        // assertEq(approvals, 2);
        // assertEq(balUserBef + 10 * 10**6 ,USDT_ERC.balanceOf(user2),"balance USDT of user2 should be equal");

        //Masterpool can nap usdt de co the tra commission
        // vm.prank(owner);
        // USDT_ERC.approve(address(MASTERPOOL), 1_000_000 * 1e6);
        // vm.prank(owner);
        // MASTERPOOL.deposit(1_000_000 * 1e6);


    }

    function getBalance()public returns(uint amount1,uint amount2,uint amount3,uint amount4,uint amount5,uint amount6,uint amount7,uint amount8){
         amount1 = BALANCE_MAN.getBalance(address(ROOT_NODE));
         amount2 = BALANCE_MAN.getBalance(address(DAO_NODE));
         amount3 = BALANCE_MAN.getBalance(address(STOCK_NODE));
         amount4 = BALANCE_MAN.getBalance(address(SHOWROOM1));
         amount5 = BALANCE_MAN.getBalance(user1);
         amount6 = BALANCE_MAN.getBalance(user2);
         amount7 = BALANCE_MAN.getBalance(user3);
         amount8 = BALANCE_MAN.getBalance(buyer);
        // console.log("ROOT_NODE:",amount1);
        // console.log("DAO_NODE:",amount2);
        // console.log("STOCK_NODE:",amount3);
        // console.log("SHOWROOM1:",amount4);
        // console.log("user1:",amount5);
        // console.log("user2:",amount6);
        // console.log("user3:",amount7);
        // console.log("buyer:",amount8);
        
    }
    function getBalanceUtxo(bytes32 utxoID)public returns(uint amount1,uint amount2,uint amount3,uint amount4,uint amount5,uint amount6,uint amount7,uint amount8){
         (amount1,,,,) = BALANCE_MAN.getUltraBPInfo(address(ROOT_NODE),utxoID);
         (amount2,,,,) = BALANCE_MAN.getUltraBPInfo(address(DAO_NODE),utxoID);
         (amount3,,,,) = BALANCE_MAN.getUltraBPInfo(address(STOCK_NODE),utxoID);
         (amount4,,,,) = BALANCE_MAN.getUltraBPInfo(address(SHOWROOM1),utxoID);
         (amount5,,,,) = BALANCE_MAN.getUltraBPInfo(user1,utxoID);
         (amount6,,,,) = BALANCE_MAN.getUltraBPInfo(user2,utxoID);
         (amount7,,,,) = BALANCE_MAN.getUltraBPInfo(user3,utxoID);
         (amount8,,,,) = BALANCE_MAN.getUltraBPInfo(buyer,utxoID);
        console.log("ROOT_NODE:",amount1);
        console.log("DAO_NODE:",amount2);
        console.log("STOCK_NODE:",amount3);
        console.log("SHOWROOM1:",amount4);
        console.log("user1:",amount5);
        console.log("user2:",amount6);
        console.log("user3:",amount7);
        console.log("buyer:",amount8);
        
    }

    //TreeCommission
     function testFull() public {
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
        bytes32 utxoID1 = bytes32(0); //tt usdt
        // bytes32 utxoID1 = keccak256(abi.encodePacked("1")); //tt visa
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
        // bytes32 utxoID2 = keccak256(abi.encodePacked("2"));
        bytes32 utxoID2 = bytes32(0);
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
        registerEcomUser(buyer,address(ROOT_NODE));
        //2.addPromoterMember cho user2 vao rootnode
        vm.startBroadcast(owner);
        TREE_COM.addPromoterMember(buyer,address(ROOT_NODE),10000,2000,bytes32(0));
        assertEq(USDT_ERC.balanceOf(address(TREE_COM)), (120+40+160) * 1e6, "Incorrect USDT transfer"); // 120 + 40 USDT
        vm.stopBroadcast();
        //3.addPromoterMember cho user3 vao user2
        registerEcomUser(user3,buyer);
        vm.startBroadcast(buyer);
        USDT_ERC.approve(address(TREE_COM), 1000 * 1e6);
        TREE_COM.addPromoterMember(user3,buyer,10000,2000,bytes32(0));
        uint balShowRoom = USDT_ERC.balanceOf(address(SHOWROOM));
        console.log("balShowRoom:",balShowRoom);
        vm.stopBroadcast();
        vm.prank(owner);
        TREE_COM.processTeamBPAndActive(0,100);
        withdraw();
        retailerCreateProduct();

    }
    function withdraw() public {
        //  console.log("balance:");
        // BALANCE_MAN.getBalance(address(ROOT_NODE));
        // BALANCE_MAN.getBalance(address(DAO_NODE));
        // BALANCE_MAN.getBalance(address(STOCK_NODE));
        // BALANCE_MAN.getBalance(address(SHOWROOM1));
        // BALANCE_MAN.getBalance(user1);
        // BALANCE_MAN.getBalance(user2);
        // BALANCE_MAN.getBalance(user3);
        // BALANCE_MAN.getBalance(buyer);
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
    function retailerCreateProduct()public{
        //setRetailer
        vm.prank(owner);
        ECOM_USER.setRetailer(retailer);
        // ECOM_USER.registerRetailer("Retailer_Name","retailer_phone");//retailer tu dang ki
        //retailer register
        // registerEcomUser(buyer,address(ROOT_NODE));
        //createCategory
        vm.prank(owner);
        ECOM_PRODUCT.createCategory("cat","descrip");
        //
        uint256[] memory capacity = new uint256[](3);
        capacity[0] = 1;
        capacity[1] = 2;
        capacity[2] = 3;
        bytes[]  memory size = new bytes[](3);
        size[0] = hex"11";  // 1 byte
        size[1] = hex"0112"; // 2 bytes
        size[2] = hex"0113"; // 2 bytes
        bytes[]  memory color = new bytes[](3);
        color[0] = hex"11";  // 1 byte
        color[1] = hex"0112"; // 2 bytes
        color[2] = hex"0113"; // 2 bytes
        bytes[]  memory images = new bytes[](3);
        images[0] = hex"11";  // 1 byte
        images[1] = hex"0112"; // 2 bytes
        images[2] = hex"0113"; // 2 bytes
        
        createProductParams memory params = createProductParams({
            name: "Test Product",
            categoryID: 1,
            description: "A sample product",
            retailPrice: 1000 * 10**6,
            vipPrice: 1200 * 10**6,
            memberPrice: 1100 * 10**6,
            reward: 10 * 10**6,
            capacity: capacity,          
            size: size ,
            quantity: 100,
            shippingFee: 50,
            color: color ,
            retailer: retailer,
            brandName: "Brand A",
            warranty: "1 year",
            isFlashSale: false,
            images: images ,
            videoUrl: "",
            boostTime: 0,
            expiryTime: block.timestamp + 365 days,
            activateTime: block.timestamp,
            isMultipleDiscount: false,
            isApprove: true,
            sold: 0
        });
        Attribute[] memory attrs = new Attribute[](1);
        attrs[0] = Attribute({
            id:keccak256(abi.encodePacked("2")),
            key:"key",
            value:"value"
        });
        bytes32 variantID = hashAttributes(attrs);
        VariantParams[] memory variants = new VariantParams[](1);
        variants[0] = VariantParams({
            variantID : variantID,
            attrs: attrs ,
            priceOptions: Pricing({
                retailPrice: 1000 * 10**6,
                vipPrice: 1200 * 10**6,
                memberPrice: 1100 * 10**6,
                reward: 10,
                quantity: 100
            })
        });
        vm.prank(retailer);
        uint256 productId = ECOM_PRODUCT.createProduct(params, variants);
        //getbytecode
        createProductParams memory paramsByteCode = createProductParams({
            name: "Test Product",
            categoryID: 1,
            description: "A sample product",
            retailPrice: 1000 * 10**6,
            vipPrice: 1200 * 10**6,
            memberPrice: 1100 *10**6,
            reward: 10,
            capacity: capacity,          
            size: size ,
            quantity: 100,
            shippingFee: 3*10**6,
            color: color ,
            retailer: 0xB50b908fFd42d2eDb12b325e75330c1AaAf35dc0,
            brandName: "Brand A",
            warranty: "1 year",
            isFlashSale: false,
            images: images ,
            videoUrl: "",
            boostTime: 0,
            expiryTime: block.timestamp + 365 days,
            activateTime: block.timestamp,
            isMultipleDiscount: false,
            isApprove: true,
            sold: 0
        });

        // bytes memory bytesCodeCall = abi.encodeCall(
        //     ECOM_PRODUCT.createProduct,
        //     (paramsByteCode, variants)
        // );
        // console.log("ECOM_PRODUCT createProduct: ");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );
        //updateProduct
        // bytes memory bytesCodeCall = abi.encodeCall(
        //     ECOM_PRODUCT.updateProduct,
        //     (1,paramsByteCode, variants)
        // );
        // console.log("ECOM_PRODUCT updateProduct 1: ");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );

        assertEq(productId, 1);
        buyProduct(variantID);
        // GetByteCode();

    }   
    function buyProduct(bytes32 _variantID) public {
        
        
        CreateOrderParams[] memory params = new CreateOrderParams[](1);
        params[0] = CreateOrderParams({
            productID: 1,
            quantity: 2,
            variantID: _variantID,
            cartItemId: 1,
            discountCodes: new string[](0)
        });

       ShippingParams memory shippingParams = ShippingParams({
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com",
            country: "US",
            city: "New York",
            stateOrProvince: "NY",
            postalCode: "10001",
            phone: "1234567890",
            addressDetail: "123 Street"
        });

        orderDetails memory details = orderDetails({
            totalPriceWithoutDiscount: 100,
            codeRef: keccak256(abi.encodePacked("REF123")),
            checkoutType: CheckoutType.RECEIVE,
            paymentType: PaymentType.METANODE
        });
        
        CartItem memory cartItem = CartItem({
            id:1,
            productID: 1,
            quantity: 1,
            variantID: _variantID,
            createAt: block.timestamp
        });
        // vm.prank(buyer);
        // ECOM_ORDER.createCart(cartItem);//khong can
        vm.prank(buyer);
        ECOM_ORDER.addItemToCart(1,_variantID,1);
        //create orderid
        vm.prank(buyer);
        bytes32 orderCode = ECOM_ORDER.ExecuteOrder(params, shippingParams, details);
        assertTrue(orderCode != bytes32(0));
        //buyProduct 
        
        vm.startBroadcast(buyer);
        bytes32 utxoBuy = bytes32(0);
        USDT_ERC.approve(address(TREE_COM), 10000000 * 1e6);
        TREE_COM.buyProduct(orderCode,utxoBuy);

        // TREE_COM.updateDeliveryProduct(orderCode);
        vm.stopBroadcast();
        vm.prank(owner);
        ECOM_INFO.getUserPurchaseInfo(buyer);
        // GetByteCode();
    }
    function hashAttributes(
        Attribute[] memory attrs
    ) internal pure returns (bytes32) {
        bytes memory attributesHash;

        for (uint256 i = 0; i < attrs.length; i++) {
            attributesHash = abi.encodePacked(
                attributesHash,
                attrs[i].key,
                attrs[i].value
            );
        }

        return keccak256(attributesHash);
    }

    function GetByteCode()public {
         //1.register on EcomUser
        registerParams memory params;
        params.fullName = "thuy";
        params.email = "abc@gmail.com";
        params.gender = 0;
        params.dateOfBirth = 23041989;
        params.phoneNumber = "09312345678";
        params.parent = 0xcD1Dd05bC96778594F2401380cD20E28705A4E87; //co the la rootnode 
        bytes memory bytesCodeCall = abi.encodeCall(
            ECOM_USER.register,
            (params)
        );
        console.log("ECOM_USER register: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
        
        //ECOM_ORDER.addItemToCart(1,_variantID,1);
        Attribute[] memory attrs = new Attribute[](1);
        attrs[0] = Attribute({
            id:keccak256(abi.encodePacked("2")),
            key:"key",
            value:"value"
        });
        bytes32 _variantID = hashAttributes(attrs);
        bytesCodeCall = abi.encodeCall(
            ECOM_ORDER.addItemToCart,
            (1,_variantID,1)
        );
        console.log("ECOM_ORDER addItemToCart: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
        //ECOM_USER.setRetailer(retailer);
        address retailer = 0xEA3Db8925B49B5452eD74959Eb86bBBb7fAb59Ce;
        bytesCodeCall = abi.encodeCall(
            ECOM_USER.setRetailer,
            (retailer)
        );
        console.log("ECOM_USER setRetailer: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
        //ECOM_USER.mUserInfo(buyer);
        address buyer = 0x3a1a3ead8267cf63E4F58d4fE09B82f15a541Ae7;
        bytesCodeCall = abi.encodeCall(
            ECOM_USER.mUserInfo,
            (buyer)
        );
        console.log("ECOM_USER mUserInfo: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );

        //TREE_COM.addPromoterMember(user3,user2,10000,2000,bytes32(0));

        address userA = 0x391fFF8136E5066668F254F2bF074e5dAc318867;
        address parentB = 0xcD1Dd05bC96778594F2401380cD20E28705A4E87;
        bytes32 utxoID = keccak256(abi.encodePacked("abc"));
        bytesCodeCall = abi.encodeCall(
            TREE_COM.addPromoterMember,
            (userA,parentB,10000,2000,utxoID)
        );
        console.log("addPromoterMember: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
        //
        address user = 0x6f0B58b260178333C39F83e0AA0404581Bac8B26;
        bytesCodeCall = abi.encodeCall(
            ECOM_USER.getUserParent,
            (user)
        );
        console.log("getUserParent: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
        //TREE_COM.addVIPMember(user1, address(ROOT_NODE),utxoID1);
        address userB = 0x6f0B58b260178333C39F83e0AA0404581Bac8B26;
        address parentC = 0xf3440BCF4e24Bc17BA2fea252c942D7F52D79147;
         bytes32 utxoID1 = keccak256(abi.encodePacked("abc"));
        bytesCodeCall = abi.encodeCall(
            TREE_COM.addVIPMember,
            (userB, parentC,bytes32(0))
        );
        console.log("addVIPMember: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
        //ECOM_USER.registerRetailer("Retailer_Name","retailer_phone")
        bytesCodeCall = abi.encodeCall(
            ECOM_USER.registerRetailer,
            ("Retailer_Name","retailer_phone")
        );
        console.log("registerRetailer: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
        //addShowroom
        address showroom = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
        bytesCodeCall = abi.encodeCall(
            SHOWROOM.addShowRoom,
            (
                showroom,
                address(0),
                Showroom.ShowroomTier.Kiosk,
                1300000,
                2000000
            )
        );
        console.log("addShowRoom: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
        //processTeamBPAndActive
        // TREE_COM.processTeamBPAndActive(1,100);
        bytesCodeCall = abi.encodeCall(
            TREE_COM.processTeamBPAndActive,
            (0,100)
        );
        console.log("processTeamBPAndActive: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
        //
        bytesCodeCall = abi.encodeCall(
            ECOM_ORDER.SetPos,
            (0xe6543ceABFD0CB596c453FC702e3355cA54C71b3)
        );
        console.log("SetPos: ");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
   
    }
        // function setDirector(address rootUser) internal {
    //     bytes32 utxoID = keccak256("test_utxo");
    //     address[256] memory queue; // Danh sách chờ xử lý (max 256 node)
    //     uint256 front = 0;
    //     uint256 back = 0;
    //     uint256 totalNodes = 0;

    //     queue[back++] = rootUser; // Thêm user gốc vào hàng đợi

    //     while (front < back && totalNodes < 250) {
    //         address parent = queue[front++]; // Lấy user đang xử lý từ hàng đợi

    //         for (uint256 i = 1; i <= 6 && totalNodes < 250; i++) {
    //             address child = address(uint160(uint256(keccak256(abi.encodePacked(parent, i))))); // Tạo địa chỉ con giả lập

    //             // Sử dụng vm.prank để giả lập người gọi
    //             vm.prank(owner);
    //             USDT_ERC.mintToAddress(child, 1000 * 1e6);

    //             vm.prank(child);
    //             USDT_ERC.approve(address(TREE_COM), 1000 * 1e6);

    //             // Sử dụng vm.broadcast để giả lập giao dịch từ child
    //             vm.broadcast(child);
    //             TREE_COM.addPromoterMember(child, parent, 10000, 10000 + i * 10,utxoID);

    //             queue[back++] = child; // Thêm child vào hàng đợi
    //             totalNodes++;
    //         }
    //     }
    // }

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

}


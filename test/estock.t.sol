// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/eStock.sol";
import "../src/usdt.sol";
import "../src/po5.sol";
contract eStockTest is Test {
    TransactionHistoryFactory factory;
    TransactionHistory history;
    eStock stock;
    TreeCommission public MOCK_TREE_COM;
    USDT public USDT_ERC;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address owner = address(0x3);
    uint256 currentTime = 1742780278;
    uint256 public initialSupply = 1_000_000; // 1 million tokens
    uint256 public initialExchangeRate = 10**18; // 1 eStock = 1 USDT (100000/100 = 1000, 1000/1000 = 1)
    uint256 public initialSaleQuota = 500_000 * 10**18; // 500,000 tokens
    
    constructor() {
        vm.warp(currentTime);
        vm.startPrank(owner);
        USDT_ERC = new USDT();
        // Triển khai factory và tạo lịch sử giao dịch
        factory = new TransactionHistoryFactory();
        uint256 month = factory.getCurrentMonth();
        // Triển khai eStock
        stock = new eStock("eStock Token", "ESTK", initialSupply, initialExchangeRate, initialSaleQuota, address(USDT_ERC), address(factory));
        address historyAddress = factory.getHistoryAddress(month);
        history = TransactionHistory(historyAddress);

        USDT_ERC.mintToAddress(user1, 1000* 1e18);
        MOCK_TREE_COM = new TreeCommission(
            address(0x11), address(0x11),
            address(0x11),address(0x11),address(0x11),address(0x11),
            address(0x11),address(stock),address(USDT_ERC)
        );
        stock.setTreeCom(address(MOCK_TREE_COM));
        vm.stopPrank();
    }

    function testCreateTransactionHistory() public {
        uint256 month = factory.getCurrentMonth();
        address historyAddress = factory.getHistoryAddress(month);
        assert(historyAddress != address(0));
    }

    function testRecordTransaction() public {
        history.recordTransaction("BUY", user1, user2, 100 * 1e18);
        uint256 count = history.getTransactionCount(user1);
        assertEq(count, 1);
    }
    function testGetUserTransactions() public {
        history.recordTransaction("BUY", user1, user2, 100);
        history.recordTransaction("SELL", user1, user2, 50);

        TransactionHistory.Transaction[] memory transactions = history.getUserTransactions(user1, 0, 2);
        assertEq(transactions.length, 2, "Should return 2 transactions");
        assertEq(transactions[0].txType, "BUY", "First transaction should be BUY");
        assertEq(transactions[1].txType, "SELL", "Second transaction should be SELL");
    }

    function testGetUserTransactionsByTime() public {
        uint256 startTime = block.timestamp;
        history.recordTransaction("BUY", user1, user2, 100);
        vm.warp(startTime + 1 hours);
        history.recordTransaction("SELL", user1, user2, 50);

        TransactionHistory.Transaction[] memory transactions = history.getUserTransactionsByTime(user1, startTime, startTime + 2 hours, 2);
        assertEq(transactions.length, 2, "Should return 2 transactions");
        assertEq(transactions[0].txType, "SELL", "First transaction should be SELL");
        assertEq(transactions[1].txType, "BUY", "Second transaction should be BUY");
    }

    function testGetTransactionCount() public {
        history.recordTransaction("BUY", user1, user2, 100);
        history.recordTransaction("SELL", user1, user2, 50);

        uint256 txCount = history.getTransactionCount(user1);
        assertEq(txCount, 2, "Transaction count should be 2");
    }
    function testBuyStock() public {
        vm.startPrank(user1);
        USDT_ERC.approve(address(stock), 100 * 1e18);
        address history = stock.currentHistory();
        stock.buyStock(100 * 10**6, initialExchangeRate);
        vm.stopPrank();

        assertEq(stock.balanceOf(user1), (100 * 10**6 * initialExchangeRate) / (1e6 * 100) );
    }
    function testBuyStockWithWrongRate() public {
        uint initialExchangeRate = stock.exchangeRate();
        uint256 USDT_ERCAmount = 1000 * 10**6; // 1,000 USDT
        uint256 wrongRate = initialExchangeRate + 10000; // Wrong exchange rate
        
        vm.startPrank(user1);
        
        // Approve USDT spending
        USDT_ERC.approve(address(stock), USDT_ERCAmount);
        
        // Expect transaction to revert due to wrong exchange rate
        vm.expectRevert("Exchange rate changed");
        stock.buyStock(USDT_ERCAmount, wrongRate);
        
        vm.stopPrank();
    }
    function testBuyStockWithInsufficientQuota() public {
        uint initialExchangeRate = stock.exchangeRate();
        // Set a very small quota
        vm.startPrank(owner);
        stock.setSaleQuota(1 * 10**18); // Only 1 token available
        vm.stopPrank();
        
        uint256 USDT_ERCAmount = 10000 * 10**18; // 1,000 USDT would buy more than the quota
        
        vm.startPrank(user1);
        
        // Approve USDT spending
        USDT_ERC.approve(address(stock), USDT_ERCAmount);
        
        // Expect transaction to revert due to insufficient quota
        vm.expectRevert("Not enough stock in this sale");
        stock.buyStock(USDT_ERCAmount, initialExchangeRate);
        
        vm.stopPrank();
    }
     function testReceiveProfitFromContract() public {

        uint256 profitAmount = 5000 * 10**6; // 5,000 USDT
        
        // First, user1 buys some stock
        vm.startPrank(user1);
        USDT_ERC.approve(address(stock), 1000 * 10**6);
        stock.buyStock(1000 * 10**6, initialExchangeRate);
        vm.stopPrank();
        
        //gia dinh Send profit to contract treecom
        vm.startPrank(owner);
        USDT_ERC.mintToAddress(address(MOCK_TREE_COM), profitAmount);
        vm.stopPrank();
        
        // Get balances before profit distribution
        uint256 contractUSDTBefore = USDT_ERC.balanceOf(address(stock));
        
        // TreeCommission sends profit
        vm.startPrank(address(owner));
        MOCK_TREE_COM.sendProfitForEStock(profitAmount);
        vm.stopPrank();
        
        // Check updated contract state
        assertEq(USDT_ERC.balanceOf(address(stock)), contractUSDTBefore + profitAmount);
        assertEq(stock.totalUSDTReceived(), profitAmount);
    }
    function testUnauthorizedProfitSending() public {
        uint256 profitAmount = 5000 * 10**6; // 5,000 USDT
        
        // User1 tries to send profit directly (not allowed)
        vm.startPrank(user1);
        USDT_ERC.approve(address(stock), profitAmount);
        
        vm.expectRevert("Not authorized");
        stock.receiveProfitFromContract(profitAmount);
        
        vm.stopPrank();
    }
     function testWithdrawUSDTCommission() public {
        // Step 1: User1 buys stock
        vm.startPrank(user1);
        USDT_ERC.approve(address(stock), 1000 * 10**6);
        stock.buyStock(1000 * 10**6, initialExchangeRate);
        vm.stopPrank();
        
        // Calculate user1's stock percentage
        uint256 user1Stock = stock.balanceOf(user1);
        uint256 totalStock = stock.totalSupply();
        uint256 user1Percentage = (user1Stock * 100) / totalStock;
        
        // Step 2: Send profit from MOCK_TREE_COM
        uint256 profitAmount = 5000 * 10**6; // 5,000 USDT
        vm.startPrank(owner);
        USDT_ERC.mintToAddress(address(MOCK_TREE_COM), profitAmount);
        vm.stopPrank();
        
        vm.startPrank(owner);
        MOCK_TREE_COM.sendProfitForEStock(profitAmount);
        vm.stopPrank();
        
        // Step 3: User withdraws commission
        vm.startPrank(user1);
        stock.withdrawUSDTCommission();
        vm.stopPrank();
        
        // Calculate expected commission
        uint256 expectedCommission = (profitAmount * user1Stock) / totalStock;
        
        // Check user's USDT balance in contract
        assertEq(stock.userUSDTBalance(user1), expectedCommission);
        assertEq(stock.lastTotalUSDTReceived(user1), profitAmount);
    }
    function testClaimUSDT() public {
        // Step 1: User1 buys stock
        vm.startPrank(user1);
        USDT_ERC.approve(address(stock), 1000 * 10**6);
        stock.buyStock(1000 * 10**6, initialExchangeRate);
        vm.stopPrank();
        
        // Step 2: Send profit
        uint256 profitAmount = 5000 * 10**6; // 5,000 USDT
        vm.startPrank(owner);
        USDT_ERC.mintToAddress(address(MOCK_TREE_COM), profitAmount);
        vm.stopPrank();
        
        vm.startPrank(owner);
        MOCK_TREE_COM.sendProfitForEStock( profitAmount);
        vm.stopPrank();
        
        // Step 3: User withdraws commission
        vm.startPrank(user1);
        stock.withdrawUSDTCommission();
        
        // Calculate user's commission
        uint256 user1Commission = stock.userUSDTBalance(user1);
        uint256 user1USDTBefore = USDT_ERC.balanceOf(user1);
        // Claim USDT
        stock.claimUSDT(user1Commission);
        vm.stopPrank();
        
        // Check USDT was transferred to user's wallet
        assertEq(USDT_ERC.balanceOf(user1), user1USDTBefore + user1Commission);
        assertEq(stock.userUSDTWithdrawn(user1), user1Commission);
        assertEq(stock.totalUSDTWithdrawn(), user1Commission);
    }
     function testWithdrawUSDTPurchased() public {
        // Step 1: User buys stock to generate USDT in the contract
        vm.startPrank(user1);
        USDT_ERC.approve(address(stock), 1000 * 10**6);
        stock.buyStock(1000 * 10**6, initialExchangeRate);
        vm.stopPrank();
        
        uint256 ownerUSDTBefore = USDT_ERC.balanceOf(owner);
        uint256 withdrawAmount = 500 * 10**6; // 500 USDT
        
        // Owner withdraws USDT
        vm.startPrank(owner);
        stock.withdrawUSDTPurchased(withdrawAmount);
        vm.stopPrank();
        
        // Check USDT was transferred to owner
        assertEq(USDT_ERC.balanceOf(owner), ownerUSDTBefore + withdrawAmount);
        assertEq(stock.totalUSDTPurchased(), 1000 * 10**6 - withdrawAmount);
    }
    function testExcessiveUSDTWithdrawal() public {
        // Step 1: User buys stock to generate USDT in the contract
        vm.startPrank(user1);
        USDT_ERC.approve(address(stock), 1000 * 10**6);
        stock.buyStock(1000 * 10**6, initialExchangeRate);
        vm.stopPrank();
        
        uint256 excessAmount = 2000 * 10**6; // 2,000 USDT (more than available)
        
        // Owner tries to withdraw too much
        vm.startPrank(owner);
        vm.expectRevert("Not enough USDT from purchases");
        stock.withdrawUSDTPurchased(excessAmount);
        vm.stopPrank();
    }
     function testTransferWithCommissionUpdate() public {
        // Step 1: User1 buys stock
        vm.startPrank(user1);
        USDT_ERC.approve(address(stock), 1000 * 10**6);
        stock.buyStock(1000 * 10**6, initialExchangeRate);
        vm.stopPrank();
        
        // Step 2: Send profit
        uint256 profitAmount = 5000 * 10**6; // 5,000 USDT
        vm.startPrank(owner);
        USDT_ERC.transfer(address(MOCK_TREE_COM), profitAmount);
        vm.stopPrank();
        
        vm.startPrank(owner);
        MOCK_TREE_COM.sendProfitForEStock( profitAmount);
        vm.stopPrank();
        
        // Get balances before transfer
        uint256 user1StockBefore = stock.balanceOf(user1);
        uint256 user2StockBefore = stock.balanceOf(user2);
        uint256 transferAmount = user1StockBefore / 2;
        
        // User1 transfers some stock to User2
        vm.startPrank(user1);
        stock.transfer(user2, transferAmount);
        vm.stopPrank();
        
        // Check balances after transfer
        assertEq(stock.balanceOf(user1), user1StockBefore - transferAmount);
        assertEq(stock.balanceOf(user2), user2StockBefore + transferAmount);
        
        // Check that commissions were updated
        uint256 user1Commission = stock.userUSDTBalance(user1);
        assertGt(user1Commission, 0); // User1 should have received commission
        assertEq(stock.lastTotalUSDTReceived(user1), profitAmount);
        assertEq(stock.lastTotalUSDTReceived(user2), 0);
    }

}

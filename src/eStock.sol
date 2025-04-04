// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "forge-std/console.sol";
contract TransactionHistory {
    struct Transaction {
        string txType; // "BUY", "SELL", "TRANSFER", "WITHDRAW", "REWARD"
        address to;
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Transaction[]) private userTransactions;

    /// @dev Ghi nhận giao dịch của từng user
    function recordTransaction(
        string memory txType,
        address user,
        address to,
        uint256 amount
    ) external {
        userTransactions[user].push(Transaction(txType, to, amount, block.timestamp));
    }

    /// @dev Lấy tổng số giao dịch của user
    function getTransactionCount(address user) external view returns (uint256) {
        return userTransactions[user].length;
    }

    /// @dev Lấy lịch sử giao dịch theo phân trang với `startIndex`
    function getUserTransactions(
        address user,
        uint256 startIndex,
        uint256 limit
    ) external view returns (Transaction[] memory) {
        uint256 totalTx = userTransactions[user].length;
        if (totalTx == 0 || startIndex >= totalTx) return new Transaction[](0) ;

        uint256 endIndex = startIndex + limit;
        if (endIndex > totalTx) {
            endIndex = totalTx;
        }

        Transaction[] memory results = new Transaction[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            results[i - startIndex] = userTransactions[user][i];
        }
        return results;
    }

    /// @dev Lấy lịch sử giao dịch theo phân trang (startTime, endTime, limit)
    function getUserTransactionsByTime(
        address user,
        uint256 startTime,
        uint256 endTime,
        uint256 limit
    ) external view returns (Transaction[] memory) {
        uint256 count = 0;
        Transaction[] memory temp = new Transaction[](userTransactions[user].length);

        // Lọc giao dịch theo thời gian
        for (uint256 i = userTransactions[user].length; i > 0; i--) {
            Transaction memory txData = userTransactions[user][i - 1];
            if (txData.timestamp < startTime) break;
            if (txData.timestamp <= endTime) {
                temp[count] = txData;
                count++;
            }
            if (count >= limit) break;
        }

        // Sao chép dữ liệu chính xác
        Transaction[] memory results = new Transaction[](count);
        for (uint256 i = 0; i < count; i++) {
            results[i] = temp[i];
        }
        return results;
    }
    function getUserTransactionsByTimePagination(
        address user,
        uint256 startTime,
        uint256 endTime,
        uint256 limit,
        uint256 offset // Offset để xác định vị trí bắt đầu lấy dữ liệu
    ) external view returns (Transaction[] memory) {
        uint256 total = userTransactions[user].length;
        uint256 count = 0;
        uint256 index = 0;
        Transaction[] memory temp = new Transaction[](limit);

        // Lặp ngược để lấy giao dịch mới nhất trước
        for (uint256 i = total; i > 0; i--) {
            Transaction memory txData = userTransactions[user][i - 1];

            // Bỏ qua các giao dịch ngoài khoảng thời gian yêu cầu
            if (txData.timestamp < startTime) break;
            if (txData.timestamp > endTime) continue;

            // Bỏ qua giao dịch đến khi đạt offset
            if (index < offset) {
                index++;
                continue;
            }

            // Lưu vào mảng kết quả
            temp[count] = txData;
            count++;

            // Nếu đã đủ limit thì dừng
            if (count >= limit) break;
        }

        // Tạo mảng kết quả chính xác với số phần tử đã tìm được
        Transaction[] memory results = new Transaction[](count);
        for (uint256 j = 0; j < count; j++) {
            results[j] = temp[j];
        }

        return results;
    }

}

contract TransactionHistoryFactory {
    mapping(uint256 => address) public monthlyHistory; // Lưu contract của từng tháng

    function getCurrentMonth() public view returns (uint256) {
        return block.timestamp / 30 days; // Xác định tháng hiện tại
    }

    function createNewHistory() external returns (address) {
        uint256 month = getCurrentMonth();
        require(monthlyHistory[month] == address(0), "History already exists");

        TransactionHistory newHistory = new TransactionHistory();
        monthlyHistory[month] = address(newHistory);
        return address(newHistory);
    }

    function getHistoryAddress(uint256 month) external view returns (address) {
        return monthlyHistory[month];
    }
}

contract eStock is ERC20, Ownable {

    TransactionHistoryFactory public historyFactory;
    address public currentHistory; // Contract lưu lịch sử tháng hiện tại
    uint256 public lastUpdatedMonth;

    IERC20 public usdtToken; // USDT Token

    uint256 public exchangeRate; // Tỷ giá eStock / USDT (lưu với 6 chữ số thập phân, chia cho 100)
    uint256 public saleQuota; // Hạn mức cổ phần có thể bán trong đợt hiện tại

    uint256 public totalUSDTPurchased; // Tổng USDT user đã nạp để mua eStock
    uint256 public totalUSDTReceived; // Tổng USDT hoa hồng từ hợp đồng khác gửi về
    uint256 public totalUSDTWithdrawn; // Tổng USDT user đã rút về ví

    mapping(address => uint256) public userUSDTBalance; // Tổng lợi nhuận USDT user có thể rút
    mapping(address => uint256) public userUSDTWithdrawn; // Tổng USDT user đã claim về ví
    mapping(address => uint256) public lastTotalUSDTReceived; // Tổng USDT cuối cùng user đã rút
    mapping(address => bool) public isAdmin;
    address public treeCommissionContract;

    event ExchangeRateUpdated(uint256 newRate);
    event SaleQuotaUpdated(uint256 newQuota);
    event StockPurchased(address indexed buyer, uint256 amount, uint256 usdtSpent);
    event ProfitReceived(address indexed source, uint256 amount);
    event USDTWithdrawn(address indexed user, uint256 amount);
    event StockTransferred(address indexed from, address indexed to, uint256 amount);
    event USDTPurchaseWithdrawn(address indexed owner, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 _exchangeRate,
        uint256 _saleQuota,
        address _usdtAddress,
        address _historyFactory
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply * (10 ** decimals())); // Phát hành token ban đầu
        exchangeRate = _exchangeRate;
        saleQuota = _saleQuota;
        usdtToken = IERC20(_usdtAddress); // Gán USDT contract

        historyFactory = TransactionHistoryFactory(_historyFactory);
        updateTransactionHistory();
        isAdmin[msg.sender] = true;
    }
    modifier onlyTreeCommission() {
        require(msg.sender == treeCommissionContract, "Not authorized");
        _;
    }
    modifier onlyAdmin(){
        require(isAdmin[msg.sender] == true, "only Admin");
        _;
    }
    function setTreeCom (address _treeCom) external onlyOwner {
        treeCommissionContract = _treeCom;
    }
    function setAdmin(address _admin, bool isOk) external onlyOwner {
        isAdmin[_admin] = isOk;
    }

    // mỗi đầu tháng cần gọi lại hàm này
    function updateTransactionHistory() public {
        uint256 currentMonth = historyFactory.getCurrentMonth();
        if (currentMonth > lastUpdatedMonth) {
            // Nếu sang tháng mới, tạo contract lịch sử mới
            currentHistory = historyFactory.createNewHistory();
            lastUpdatedMonth = currentMonth;
        }
    }

    /// @dev Cập nhật tỷ giá quy đổi (chỉ Owner có thể thay đổi)
    function setExchangeRate(uint256 newRate) external onlyAdmin {
        require(newRate > 0, "Rate must be greater than 0");
        exchangeRate = newRate;
        emit ExchangeRateUpdated(newRate);
    }

    /// @dev Cập nhật hạn mức bán eStock
    function setSaleQuota(uint256 newQuota) external onlyAdmin {
        saleQuota = newQuota;
        emit SaleQuotaUpdated(newQuota);
    }

    /// @dev Cập nhật số dư hoa hồng của user trước khi thay đổi cổ phần
    function updateUserCommission(address user) internal {
        uint256 userStock = balanceOf(user);
        uint256 totalStock = totalSupply();
        if (userStock == 0 || totalStock == 0) return; // Không có cổ phần thì không có lợi nhuận

        uint256 newProfit = totalUSDTReceived - lastTotalUSDTReceived[user];
        uint256 userProfit = (newProfit * userStock) / totalStock;
        userUSDTBalance[user] += userProfit; // ✅ Chỉ cộng vào tổng lợi nhuận user
        lastTotalUSDTReceived[user] = totalUSDTReceived;
    }

    /// @dev User mua eStock bằng USDT
    function buyStock(uint256 usdtAmount, uint256 expectedRate) external {
        require(usdtAmount > 0, "Must send USDT to buy stock");
        require(exchangeRate == expectedRate, "Exchange rate changed");

        // 🟢 Rút lợi nhuận trước khi mua
        updateUserCommission(msg.sender);

        uint256 stockAmount = (usdtAmount * exchangeRate) / (1e6 * 100) * 1e18;
        require(saleQuota >= stockAmount, "Not enough stock in this sale");
        require(balanceOf(owner()) >= stockAmount, "Not enough stock available");

        // ✅ Chuyển USDT vào hợp đồng
        uint256 balanceBefore = usdtToken.balanceOf(address(this));
        require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");
        uint256 receivedUSDT = usdtToken.balanceOf(address(this)) - balanceBefore;
        require(receivedUSDT >= usdtAmount - 1e6 && receivedUSDT <= usdtAmount + 1e6, "Incorrect USDT transfer amount");

        // ✅ Ghi nhận dòng tiền từ user mua stock
        totalUSDTPurchased += usdtAmount;

        saleQuota -= stockAmount;
        _transfer(owner(), msg.sender, stockAmount);

        TransactionHistory(currentHistory).recordTransaction("BUY", msg.sender, address(this), stockAmount);

        // ghi nhận cho smart contract 
        TransactionHistory(currentHistory).recordTransaction("SELL", address(this), msg.sender, usdtAmount);
        
        emit StockPurchased(msg.sender, stockAmount, usdtAmount);
    }

    /// @dev Nhận lợi nhuận từ hợp đồng khác bằng USDT(onlyTreecom)
    function receiveProfitFromContract(uint256 amount) external onlyTreeCommission {
        require(amount > 0, "Amount must be greater than 0");
        require(usdtToken.transferFrom(msg.sender, address(this), amount), "USDT transfer failed");

        totalUSDTReceived += amount;

        TransactionHistory(currentHistory).recordTransaction("REWARD", msg.sender, address(0), amount);
        emit ProfitReceived(msg.sender, amount);
    }

    /// @dev Rút hoa hồng USDT (chỉ cập nhật số dư, không gửi ngay)
    function withdrawUSDTCommission() public {
        updateUserCommission(msg.sender);

        TransactionHistory(currentHistory).recordTransaction("WITHDRAW", msg.sender, address(0), userUSDTBalance[msg.sender]);
        emit USDTWithdrawn(msg.sender, userUSDTBalance[msg.sender]);
    }

    /// @dev User claim USDT từ lợi nhuận về ví cá nhân
    function claimUSDT(uint256 amount) external {
        uint256 availableAmount = userUSDTBalance[msg.sender] - userUSDTWithdrawn[msg.sender];
        require(amount > 0 && amount <= availableAmount, "Insufficient USDT balance");

        userUSDTWithdrawn[msg.sender] += amount;
        totalUSDTWithdrawn += amount;

        require(usdtToken.transfer(msg.sender, amount), "USDT transfer failed");

        TransactionHistory(currentHistory).recordTransaction("CLAIM", msg.sender, address(0), amount);

        emit USDTWithdrawn(msg.sender, amount);
    }

    /// @dev Admin rút USDT từ user mua stock
    function withdrawUSDTPurchased(uint256 amount) external onlyAdmin {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= totalUSDTPurchased, "Not enough USDT from purchases");

        totalUSDTPurchased -= amount;
        require(usdtToken.transfer(owner(), amount), "USDT transfer failed");

        emit USDTPurchaseWithdrawn(owner(), amount);
    }

    /// @dev Chuyển eStock giữa các user (bắt buộc rút lợi nhuận trước)
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(balanceOf(msg.sender) >= amount, "Not enough balance");
        
        // 🟢 Bắt buộc rút lợi nhuận trước khi chuyển stock
        updateUserCommission(msg.sender);
        updateUserCommission(recipient);

        _transfer(msg.sender, recipient, amount);

        TransactionHistory(currentHistory).recordTransaction("TRANSFER", msg.sender, recipient, amount);
        emit StockTransferred(msg.sender, recipient, amount);
        return true;
    }
}

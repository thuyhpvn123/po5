pragma solidity ^0.8.20;

// import "./struct/EcomStruct.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libs/utils.sol";
import "./interfaces/IEcomProduct.sol";
import "./interfaces/IEcomUser.sol";
import "./interfaces/IEcomOrder.sol";

contract EcomInfoContract {
    uint256 public totalSystemFavorite;
    uint256 public totalSystemAddedToCart;
    uint256 public totalSystemPurchasePrice;
    uint256 public totalSystemVisitors;
    uint256 public totalCommentAndFAQ;
    uint256 public totalSystemProductShare;

    mapping(address => uint256) public totalRetailerFavorite;
    mapping(address => uint256) public totalRetailerAddedToCart;

    // List Payout List Shipping
    ListTrackUser[] public listTrackUserSystem;
    mapping(address => ListTrackUser[]) public mListTrackUserRetailer;

    mapping(uint256 => uint256[]) public mProductSearchTrend; //  productID => timestamp[] // each timestamp = each count
    mapping(uint256 => uint256[]) public mProductPurchaseTrend; // productID => timestamp[]

    AddedToCartAndWishList[] public listTrackUserActivitySystem;
    mapping(address => AddedToCartAndWishList[])
        public listTrackUserActivityRetailer; //retailer => ...

    mapping(uint256 => uint256) public mProductViewCount; // productID => count

    BestSeller[] public bestSellers;
    mapping(address => Purchase[]) public mPurchases;
    mapping(string => Purchase[]) public mCountryPurchases; //country =>
    uint256[] public systemPurchases;

    mapping(address => bool) public mAdmin;
    address[] public admins;
    address public owner;

    IEcomOrder public EcomOrder;
    IEcomProduct public EcomProduct;
    IEcomUser public EcomUser;

    constructor() payable {
        owner = msg.sender;
        mAdmin[msg.sender] = true;
        admins.push(msg.sender);
    }

    function setAdmin(address user) public onlyAddress(owner) returns (bool) {
        mAdmin[user] = true;
        admins.push(user);
        return true;
    }

    function SetEcomProduct(
        address _ecomProduct
    ) public onlyAddress(owner) returns (bool) {
        EcomProduct = IEcomProduct(_ecomProduct);
        return true;
    }

    function SetEcomOrder(
        address _ecomOrder
    ) public onlyAddress(owner) returns (bool) {
        EcomOrder = IEcomOrder(_ecomOrder);
        return true;
    }

    function SetEcomUser(
        address _ecomUser
    ) public onlyAddress(owner) returns (bool) {
        EcomUser = IEcomUser(_ecomUser);
        return true;
    }

    modifier onlyAddress(address user) {
        require(
            msg.sender == user,
            '{"from": "EcomProduct.sol","code": 55, "message": "You are not allowed."}'
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            mAdmin[msg.sender],
            '{"from": "EcomProduct.sol","code": 53, "message": "You are not allowed."}'
        );
        _;
    }

    function createListTrackUser(
        createListTrackUserParams memory params
    ) public {
        address[] memory retailers = EcomProduct.getRetailersByProductIds(
            params.productIds
        );
        bytes memory names = getRetailersUsername(retailers);
        ListTrackUser memory newListTrackUser = ListTrackUser(
            params.orderID,
            params.trackType,
            params.customer,
            names,
            block.timestamp,
            params.productIds,
            params.quantities
        );

        listTrackUserSystem.push(newListTrackUser);
        for (uint i = 0; i < params.productIds.length; i++) {
            Product memory tempProduct = EcomProduct.getProduct(
                params.productIds[i]
            );
            (UserInfo memory info, ) = EcomUser.getUserInfo(
                tempProduct.params.retailer
            );
            ListTrackUser memory retailerTrackUser = ListTrackUser(
                params.orderID,
                params.trackType,
                params.customer,
                abi.encode(info.fullName),
                block.timestamp,
                new uint256[](params.productIds.length),
                new uint256[](params.productIds.length)
            );
            retailerTrackUser.productIds[i] = params.productIds[i];
            retailerTrackUser.quantities[i] = params.quantities[i];
            mListTrackUserRetailer[tempProduct.params.retailer].push(
                retailerTrackUser
            );
        }
    }

    function deleteListTrackUser(string memory _orderID) public {
        uint256 tempRetailerLength;
        address[] memory tempRetailers = new address[](
            listTrackUserSystem.length
        );

        // Deleting from listTrackUserSystem
        for (uint i = 0; i < listTrackUserSystem.length; i++) {
            if (Utils.equal(listTrackUserSystem[i].orderID, _orderID)) {
                tempRetailerLength = listTrackUserSystem[i].productIds.length;
                for (uint j = 0; j < tempRetailerLength; j++) {
                    Product memory tempProduct = EcomProduct.getProduct(
                        listTrackUserSystem[i].productIds[j]
                    );
                    tempRetailers[j] = tempProduct.params.retailer;
                }
                listTrackUserSystem[i] = listTrackUserSystem[
                    listTrackUserSystem.length - 1
                ];
                listTrackUserSystem.pop();
                break;
            }
        }
        // Deleting from mListTrackUserRetailer
        for (uint i = 0; i < tempRetailers.length; i++) {
            address retailer = tempRetailers[i];
            ListTrackUser[] storage trackUsers = mListTrackUserRetailer[
                retailer
            ];
            for (uint j = 0; j < trackUsers.length; j++) {
                if (Utils.equal(trackUsers[j].orderID, _orderID)) {
                    trackUsers[j] = trackUsers[trackUsers.length - 1];
                    trackUsers.pop();
                    break;
                }
            }
        }
    }

    function trackUserActivity(
        address user,
        uint256 _productID,
        uint256 quantity,
        address retailer,
        TrackActivityType activityType,
        bool isSystem
    ) external {
        // If the retailer above is 0, it's the admin
        // else it the retailer
        AddedToCartAndWishList[] storage listTrackUserActivity = isSystem
            ? listTrackUserActivitySystem
            : listTrackUserActivityRetailer[retailer];

        bool found = false;

        for (uint i = 0; i < listTrackUserActivity.length; i++) {
            if (listTrackUserActivity[i].customer == user) {
                found = true;
                bool foundProduct = false;
                for (
                    uint j = 0;
                    j < listTrackUserActivity[i].productIds.length;
                    j++
                ) {
                    if (listTrackUserActivity[i].productIds[j] == _productID) {
                        listTrackUserActivity[i].addedAt[j] = block.timestamp;
                        listTrackUserActivity[i].quantities[j] = quantity;
                        foundProduct = true;
                        break;
                    }
                }

                if (!foundProduct) {
                    listTrackUserActivity[i].productIds.push(_productID);
                    listTrackUserActivity[i].addedAt.push(block.timestamp);
                    listTrackUserActivity[i].quantities.push(quantity);
                }

                break;
            }
        }

        if (!found) {
            AddedToCartAndWishList memory newActivity = createNewUserActivity(
                _productID,
                quantity,
                activityType
            );
            listTrackUserActivity.push(newActivity);
        }
    }

    function createNewUserActivity(
        uint256 _productID,
        uint256 _quantity,
        TrackActivityType activityType
    ) internal view returns (AddedToCartAndWishList memory) {
        uint256[] memory productIds = new uint256[](1);
        uint256[] memory quantities = new uint256[](1);
        uint256[] memory addedAt = new uint256[](1);
        productIds[0] = _productID;
        quantities[0] = _quantity;
        addedAt[0] = block.timestamp;
        AddedToCartAndWishList memory newActivity = AddedToCartAndWishList(
            msg.sender,
            uint8(activityType),
            productIds,
            quantities,
            addedAt
        );

        return newActivity;
    }

    function removeUserActivity(
        address user,
        uint256 _productID,
        address retailer,
        bool isSystem
    ) external {
        AddedToCartAndWishList[] storage _trackUserActivity = isSystem
            ? listTrackUserActivitySystem
            : listTrackUserActivityRetailer[retailer];

        for (uint i = 0; i < _trackUserActivity.length; i++) {
            if (_trackUserActivity[i].customer == user) {
                for (
                    uint j = 0;
                    j < _trackUserActivity[i].productIds.length;
                    j++
                ) {
                    if (_trackUserActivity[i].productIds[j] == _productID) {
                        removeUserActivityItem(_trackUserActivity[i], j);
                        if (_trackUserActivity[i].productIds.length == 0) {
                            removeUserFromActivityList(_trackUserActivity, i);
                        }
                        return;
                    }
                }
            }
        }
    }

    function removeUserActivityItem(
        AddedToCartAndWishList storage activity,
        uint index
    ) internal {
        if (index >= activity.productIds.length) return;

        for (uint i = index; i < activity.productIds.length - 1; i++) {
            activity.productIds[i] = activity.productIds[i + 1];
            activity.quantities[i] = activity.quantities[i + 1];
            activity.addedAt[i] = activity.addedAt[i + 1];
        }
        activity.productIds.pop();
        activity.quantities.pop();
        activity.addedAt.pop();
    }

    function removeUserFromActivityList(
        AddedToCartAndWishList[] storage _trackUserActivity,
        uint index
    ) internal {
        if (index >= _trackUserActivity.length) return;

        for (uint i = index; i < _trackUserActivity.length - 1; i++) {
            _trackUserActivity[i] = _trackUserActivity[i + 1];
        }
        _trackUserActivity.pop();
    }

    // ======================= UPDATE VIEW FUNCTION===============================
    function updateViewCount(uint256 _productID) public {
        mProductViewCount[_productID]++;
        mProductSearchTrend[_productID].push(block.timestamp);
    }

    function updateWebsiteVisitors() public {
        totalSystemVisitors++;
    }

    function updateProductShare() public {
        totalSystemProductShare++;
    }

    function increaseTotalCommentAndFaq() public {
        totalCommentAndFAQ++;
    }

    function decreaseTotalCommentAndFaq() public {
        require(
            totalCommentAndFAQ > 0,
            getErrorMessage(1, "Invalid count total comment and faq")
        );
        totalCommentAndFAQ--;
    }

    function increaseTotalAddedToCart(address _retailer) external {
        totalSystemAddedToCart++;
        totalRetailerAddedToCart[_retailer]++;
    }

    function decreaseTotalAddedToCart(address _retailer) external {
        require(
            totalSystemAddedToCart > 0,
            getErrorMessage(1, "Invalid count: total system added to cart")
        );
        require(
            totalRetailerAddedToCart[_retailer] > 0,
            getErrorMessage(2, "Invalid count: retailer added to cart")
        );
        totalSystemAddedToCart--;
        totalRetailerAddedToCart[_retailer]--;
    }

    function increaseTotalFavorite(address _retailer) external {
        totalSystemFavorite++;
        totalRetailerFavorite[_retailer]++;
    }

    function decreaseTotalFavorite(address _retailer) external {
        require(
            totalSystemFavorite > 0,
            getErrorMessage(1, "Invalid count: total system favorite")
        );
        require(
            totalRetailerFavorite[_retailer] > 0,
            getErrorMessage(2, "Invalid count: retailer favorite")
        );
        totalSystemFavorite--;
        totalRetailerFavorite[_retailer]--;
    }

    function increasePurchases(address user, uint256 _productID) external {
        bool foundPurchase = false;
        for (uint8 i = 0; i < mPurchases[user].length; i++) {
            if (mPurchases[user][i].productID == _productID) {
                mPurchases[user][i].buyAt = block.timestamp;
                foundPurchase = true;
                break;
            }
        }
        if (!foundPurchase) {
            Purchase memory newPurchase = Purchase(_productID, block.timestamp);
            mPurchases[user].push(newPurchase);
        }
        systemPurchases.push(block.timestamp);
    }

    function increaseBestSeller(uint256 _productID) external {
        bool foundBestSeller = false;
        for (uint8 i = 0; i < bestSellers.length; i++) {
            if (bestSellers[i].productID == _productID) {
                bestSellers[i].sold++;
                foundBestSeller = true;
                break;
            }
        }
        if (!foundBestSeller) {
            BestSeller memory newBestSeller = BestSeller(
                _productID,
                1,
                block.timestamp
            );
            bestSellers.push(newBestSeller);
        }
    }

    function increaseCountryPurchases(
        string calldata _country,
        Purchase memory _purchase
    ) external {
        mCountryPurchases[_country].push(_purchase);
    }

    function increaseProductPurchaseTrend(uint256 _productID) external {
        mProductPurchaseTrend[_productID].push(block.timestamp);
    }

    // =========================GET========================================================

    function getSystemFavorite() public view onlyAdmin returns (uint256) {
        return totalSystemFavorite;
    }

    function getSystemAddedToCart() public view onlyAdmin returns (uint256) {
        return totalSystemAddedToCart;
    }

    function getSystemInfo()
        public
        view
        onlyAdmin
        returns (uint256 totalVistors, uint256 totalCfs, uint256 totalShares)
    {
        return (
            totalSystemVisitors,
            totalCommentAndFAQ,
            totalSystemProductShare
        );
    }

    // msg.sender here will be the retailer
    function getRetailerAddedToCart() public view returns (uint256) {
        return totalRetailerAddedToCart[msg.sender];
    }

    function getRetailerFavorite() public view returns (uint256) {
        return totalRetailerFavorite[msg.sender];
    }

    function getListTrackUser()
        public
        view
        onlyAdmin
        returns (ListTrackUser[] memory)
    {
        return listTrackUserSystem;
    }

    function getListTrackUserRetailer()
        public
        view
        returns (ListTrackUser[] memory)
    {
        return mListTrackUserRetailer[msg.sender];
    }

    function getListTrackUserActivitySystem()
        public
        view
        onlyAdmin
        returns (AddedToCartAndWishList[] memory)
    {
        return listTrackUserActivitySystem;
    }

    function getListTrackUserActivityRetailer()
        public
        view
        returns (AddedToCartAndWishList[] memory)
    {
        return listTrackUserActivityRetailer[msg.sender];
    }

    function getSystemProductPurchase()
        public
        view
        onlyAdmin
        returns (uint256[] memory)
    {
        return systemPurchases;
    }

    function getRetailersUsername(
        address[] memory _retailers
    ) internal view returns (bytes memory) {
        string[] memory names = new string[](_retailers.length);
        for (uint i; i < _retailers.length; i++) {
            (UserInfo memory info, ) = EcomUser.getUserInfo(_retailers[i]);
            names[i] = info.fullName;
        }
        return abi.encode(names);
    }

    function getListTrackAdmin()
        public
        view
        returns (
            ListTrackUser[] memory _listTracks,
            uint256 _favorites,
            uint256 _addedToCarts,
            AddedToCartAndWishList[] memory _totalCartWishList,
            uint256[] memory _systemPurchases
        )
    {
        _listTracks = getListTrackUser();
        _favorites = getSystemFavorite();
        _addedToCarts = getSystemAddedToCart();
        _totalCartWishList = getListTrackUserActivitySystem();
        _systemPurchases = getSystemProductPurchase();
    }

    function getListTrackRetailer()
        public
        view
        returns (
            ListTrackUser[] memory _listTracks,
            uint256 _favorites,
            uint256 _addedToCarts,
            AddedToCartAndWishList[] memory _totalCartWishList
        )
    {
        _listTracks = getListTrackUserRetailer();
        _favorites = getRetailerFavorite();
        _addedToCarts = getRetailerAddedToCart();
        _totalCartWishList = getListTrackUserActivityRetailer();
    }

    function getRecentPurchases() public view returns (Purchase[] memory) {
        return mPurchases[msg.sender];
    }

    function getBestSeller() public view returns (BestSeller[] memory) {
        return bestSellers;
    }

    function getProductTrend(
        uint256 _productID
    ) public view returns (uint256[] memory) {
        return mProductSearchTrend[_productID];
    }

    function getProductPurchaseTrend(
        uint256 _productID
    ) public view returns (uint256[] memory) {
        return mProductPurchaseTrend[_productID];
    }

    function getTotalProductViewCount()
        public
        view
        returns (
            uint256[] memory _productIds,
            uint256[] memory _productCount,
            uint256[] memory _time
        )
    {
        Product[] memory products = EcomProduct.getProducts();
        uint256[] memory productIds = new uint256[](products.length);
        uint256[] memory productCount = new uint256[](products.length);
        _time = new uint256[](products.length);
        for (uint i = 0; i < products.length; i++) {
            productIds[i] = products[i].id;
            productCount[i] = mProductViewCount[products[i].id];
            if (mProductSearchTrend[products[i].id].length > 0) {
                _time[i] = mProductSearchTrend[products[i].id][
                    mProductSearchTrend[products[i].id].length - 1
                ];
            } else {
                _time[i] = 0;
            }
        }
        return (productIds, productCount, _time);
    }

    function getUserPurchaseInfo(
        address _user
    )
        public
        view
        onlyAdmin
        returns (
            Order[] memory _orders,
            Cart memory _cart,
            Favorite[] memory _productIds
        )
    {
        _orders = EcomOrder.getUserOrders(_user);
        _cart = EcomOrder.getUserCartInfo(_user);
        _productIds = EcomProduct.getUserFavorites(_user);
    }

    function getOrderHistoryDetail()
        public
        view
        returns (
            Order[] memory _orders,
            PaymentHistory[] memory _payments,
            Purchase[] memory _purchases
        )
    {
        _orders = EcomOrder.getUserOrders(msg.sender);
        _payments = EcomUser.getUserPaymentHistoryInfo(msg.sender);
        _purchases = getRecentPurchases();
    }

    function getErrorMessage(
        uint256 code,
        string memory message
    ) public pure returns (string memory) {
        string memory codeStr = Strings.toString(code);

        return
            string(
                abi.encodePacked(
                    '{"from": "EcomInfo.sol",',
                    '"code": ',
                    codeStr,
                    ", ",
                    '"message": "',
                    message,
                    '"}'
                )
            );
    }
}

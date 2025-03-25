// SPDX-License-Identifier: No
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libs/utils.sol";
import "./interfaces/ITreeCom.sol";
import "./interfaces/IEcomProduct.sol";
import "./interfaces/IEcomInfo.sol";
import "./interfaces/IEcomUser.sol";
// import "forge-std/console.sol";
contract EcomOrderContract  {
    event eCreateShipping(
        uint256 id,
        uint256 orderID,
        address userAddress,
        string firstName,
        string lastName,
        string email,
        string country,
        string city,
        string stateOrProvince,
        string postalCode,
        string phone,
        string addressDetail
    );
    event eCreateOrder(bytes32 orderCode);
    event eExecuteOrder(uint256 id);

    mapping(address => Cart) public mUserCart;
    
    // each order by id
    mapping(uint256 => Order) public mOrder;
    // orders of user;
    mapping(address => uint256[]) public mOrders;
    // all orders id
    uint256[] internal orders;
    mapping(address => bytes32) public mAddToOrderCode;
    mapping(bytes32 => uint256) private orderCodes;


    mapping(address => uint256[]) public mUserShareLink; // user => shareLinkID
    mapping(uint256 => ShareLink) public mShareLink;

    // orderInfo for POS to call ExecuteOrder;
    mapping(uint256 => DecodedParams) public mOrderInfo;

    // ShippingInfo
    mapping(uint256 => ShippingInfo) public mShippingInfo;
    mapping(uint256 => uint256) public mShippingInfoByOrder;
    mapping(address => uint256[]) public mShippingInfoByAddress;

    uint256 shareLinkID;
    uint256 shippingID;
    uint256 orderID;
    uint256 orderInfoID;
    uint256 cartID;
    uint256 cartItemID;

    // Ecom
    IEcomProduct public EcomProduct;
    IEcomUser public EcomUser;
    IEcomInfo public EcomInfo;

    ITreeCom public TreeCom;
    IERC20 public USDT;
    address public owner;
    address public POS;
    address public MasterPool;
    constructor() payable {
        owner = msg.sender;
    }

    modifier onlyAddress(address user) {
        require(
            msg.sender == user,
            '{"from": "EcomOrder.sol","code": 55, "message": "You are not allowed."}'
        );
        _;
    }

    function SetPos(address _pos) public onlyAddress(owner) returns (bool) {
        POS = _pos;
        return true;
    }

    function SetUsdt(address _usdt) public onlyAddress(owner) returns (bool) {
        USDT = IERC20(_usdt);
        return true;
    }

    function SetMasterPool(
        address _masterPool
    ) public onlyAddress(owner) returns (bool) {
        MasterPool = _masterPool;
        return true;
    }

    function SetTreeCom(
        address _treecom
    ) external onlyAddress(owner) returns (bool) {
        TreeCom = ITreeCom(_treecom);
        return true;
    }

    function SetEcomProduct(address _ecomProduct) public onlyAddress(owner) returns (bool){
        EcomProduct = IEcomProduct(_ecomProduct);
        return true;
    }

    function SetEcomInfo(address _ecomInfo) public onlyAddress(owner) returns (bool){
        EcomInfo = IEcomInfo(_ecomInfo);
        return true;
    }

    function SetEcomUser(address _ecomUser) public onlyAddress(owner) returns (bool){
        EcomUser = IEcomUser(_ecomUser);
        return true;
    }

    function createShippingInfo(
        ShippingParams memory shippingParams,
        uint256 _orderID,
        address user
    ) public {
        shippingID++;
        ShippingInfo memory newShippingInfo = ShippingInfo(
            shippingID,
            _orderID,
            user,
            shippingParams
        );
        mShippingInfo[shippingID] = newShippingInfo;
        mShippingInfoByOrder[_orderID] = shippingID;
        mShippingInfoByAddress[user].push(shippingID); // Update in next version (Push OrderId not whole struct)
        emit eCreateShipping(
            shippingID,
            _orderID,
            user,
            shippingParams.firstName,
            shippingParams.lastName,
            shippingParams.email,
            shippingParams.country,
            shippingParams.city,
            shippingParams.stateOrProvince,
            shippingParams.postalCode,
            shippingParams.phone,
            shippingParams.addressDetail
        );
    }


    function createCart(CartItem memory cartItem) public {
        cartID++;
        Cart storage newCart = mUserCart[msg.sender];
        newCart.id = cartID;
        newCart.owner = msg.sender;
        newCart.items.push(cartItem);
    }

    function addItemToCart(
        uint256 _productID,
        bytes32 _variantID,
        uint256 _quantity
    ) public returns (CartItem memory){
        Product memory product = EcomProduct.getProduct(_productID);
        Variant memory variant = EcomProduct.getVariant(_productID, _variantID);
        require(product.id != 0, getErrorMessage(3, "Product not found"));
        require(
            variant.variantID != bytes32(0),
            getErrorMessage(6, "Variant not found")
        );
        require(
            _quantity <= variant.priceOptions.quantity,
            getErrorMessage(5, "Insufficient quantity available for purchase")
        );
        cartItemID++;
        CartItem memory newCartItem = CartItem(
            cartItemID,
            _productID,
            _quantity,
            _variantID,
            block.timestamp
        );
        if (mUserCart[msg.sender].id == 0) {
            createCart(newCartItem); // create the cart if it not exists
        } else {
            bool exists = false;

            for (uint i = 0; i < mUserCart[msg.sender].items.length; i++) {
                // Check if the productID and variantID pair already exists in the cart
                if (
                    mUserCart[msg.sender].items[i].productID == _productID &&
                    mUserCart[msg.sender].items[i].variantID == _variantID
                ) {
                    exists = true;
                    break;
                }
            }

            require(
                !exists,
                getErrorMessage(6, "Product and variant already exists in cart")
            );

            mUserCart[msg.sender].items.push(newCartItem); // Add new item to the cart if not exists
        }
        EcomInfo.trackUserActivity(
            msg.sender,
            _productID,
            _quantity,
            address(0),
            TrackActivityType.CART,
            true
        );
        EcomInfo.trackUserActivity(
            msg.sender,
            _productID,
            _quantity,
            product.params.retailer,
            TrackActivityType.CART,
            false
        );
        EcomInfo.increaseTotalAddedToCart(product.params.retailer);
        return newCartItem;
    }

    function addItemsToCart(
        AddItemToCartParams[] memory params
    ) public returns (CartItem[] memory _items) {
        CartItem[] memory items = new CartItem[](params.length);
        for (uint i = 0; i < params.length; i++) {
            items[i] = addItemToCart(
                params[i]._productID,
                params[i]._variantID,
                params[i].quantity
            );
        }
        return items;
    }

    function updateItemInCart(
        uint256 itemID,
        uint256 quantity
    ) public returns (CartItem memory _item) {
        require(
            quantity > 0,
            getErrorMessage(6, "Quantity must be greater than 0")
        );
        Cart storage cart = mUserCart[msg.sender];
        require(cart.id != 0, getErrorMessage(7, "Cart does not exist"));

        bool itemFound = false;
        for (uint i = 0; i < cart.items.length; i++) {
            if (cart.items[i].id == itemID) {
                Variant memory variant = EcomProduct.getVariant(cart.items[i].productID, cart.items[i].variantID);
                require(variant.priceOptions.quantity >= quantity,
                    getErrorMessage(
                        8,
                        "Insufficient quantity available for purchase"
                    )
                );
                cart.items[i].quantity = quantity;
                _item = cart.items[i];
                itemFound = true;
                break;
            }
        }

        require(itemFound, getErrorMessage(9, "Item not found in cart"));
        return _item;
    }

    function updateItemsToCart(
        UpdateItemsToCartParams[] memory params
    ) public returns (CartItem[] memory _items) {
        CartItem[] memory items = new CartItem[](params.length);
        for (uint i = 0; i < params.length; i++) {
            items[i] = updateItemInCart(params[i].itemID, params[i].quantity);
        }
        return items;
    }

    function _deleteItemInCart(address user, uint256 itemID) private {
        uint256 indexToDelete;
        bool found = false;
        for (uint256 i = 0; i < mUserCart[user].items.length; i++) {

            if (mUserCart[user].items[i].id == itemID) {
                indexToDelete = i;
                found = true;
                break;
            }
        }

        require(
            found,
            '{"from": "EcomProduct.sol","code": 10, "message":"The cart item does not exist in the cart"}'
        );
        // Ensure the index is within bounds
        require(
            indexToDelete < mUserCart[user].items.length,
            '{"from": "EcomProduct.sol","code": 11, "message":"Index out of bounds"}'
        );

        // if (!isFavorite(user, mUserCart[user].items[indexToDelete].productID)) {
            EcomInfo.removeUserActivity(
                user,
                mUserCart[user].items[indexToDelete].productID,
                address(0),
                true
            );
            EcomInfo.removeUserActivity(
                user,
                mUserCart[user].items[indexToDelete].productID,
                EcomProduct.getProduct(mUserCart[user].items[indexToDelete].productID)
                    .params
                    .retailer,
                false
            );
        // }

        EcomInfo.decreaseTotalAddedToCart(
            EcomProduct.getProduct(mUserCart[user].items[indexToDelete].productID)
                    .params
                    .retailer
        );
        if (indexToDelete < mUserCart[user].items.length - 1) {
            for (
                uint256 i = indexToDelete;
                i < mUserCart[user].items.length - 1;
                i++
            ) {
                mUserCart[user].items[i] = mUserCart[user].items[i + 1];
            }
        }

        require(
            mUserCart[user].items.length > 0,
            '{"from": "EcomProduct.sol","code": 12, "message":"Cart is already empty"}'
        );

        mUserCart[user].items.pop();
    }

    function deleteItemInCart(uint256 itemID) public {
        _deleteItemInCart(msg.sender, itemID);
    }

    function deleteItemsInCart(uint256[] memory itemIds) public returns (bool) {
        for (uint i = 0; i < itemIds.length; i++) {
            _deleteItemInCart(msg.sender, itemIds[i]);
        }
        return true;
    }

    function deleteItemInCartBySmc(address user, uint256 itemID) internal {
        _deleteItemInCart(user, itemID);
    }

    // function ProcessOrder(
    //     CreateOrderParams[] memory params,
    //     uint256 totalPriceWithoutDiscount,
    //     address user
    // )
    //     internal
    //     view
    //     returns (
    //         uint256[] memory productIds,
    //         bytes32[] memory variantIds,
    //         uint256[] memory quantities,
    //         uint256[] memory diffPrices,
    //         uint256[] memory prices,
    //         uint256[] memory rewards,
    //         uint256[] memory cartItemIds,
    //         uint256 totalPrice
    //     )
    // {
    //     bool isVIP = TreeCom.isVIPOrPromoter(user); // Kiểm tra user có VIP không
    //     uint256 totalParams = params.length;

    //     productIds = new uint256[](totalParams);
    //     variantIds = new bytes32[](totalParams);
    //     quantities = new uint256[](totalParams);
    //     cartItemIds = new uint256[](totalParams);
    //     prices = new uint256[](totalParams);
    //     // Tạo thêm mảng để lưu thông tin giá đầy đủ
    //     diffPrices = new uint256[](totalParams);
    //     rewards = new uint256[](totalParams);

    //     for (uint i = 0; i < totalParams; i++) {
    //         bool cartItemExists = false;
    //         for (uint j = 0; j < mUserCart[user].items.length; j++) {
    //             if (mUserCart[user].items[j].id == params[i].cartItemId) {
    //                 cartItemExists = true;
    //                 break;
    //             }
    //         }

    //         require(
    //             cartItemExists,
    //             '{"from": "EcomProduct.sol","code": 13, "message": "cartItemId does not exist in the cart"}'
    //         );
    //         // If this require pop up, this must be FE error
    //         require(
    //             EcomProduct.getProduct(params[i].productID).params.isApprove,
    //             getErrorMessage(15, "This product has not been approved.")
    //         );
    //         Variant memory productVarient = EcomProduct.getVariant(params[i].productID, params[i].variantID);
    //         uint256 diffPrice = 0;
    //         uint256 productPrice;

    //         if (isVIP) {
    //             productPrice = productVarient.priceOptions.vipPrice;
    //         } else {
    //             productPrice = productVarient.priceOptions.memberPrice;
    //             diffPrice = productPrice - productVarient.priceOptions.vipPrice;

    //             require(
    //                 diffPrice > 0,
    //                 '{"from": "EcomProduct.sol","code": 13, "message": "wrong diffPrice"}'
    //             );

    //         }
    //         totalPrice += (productPrice * params[i].quantity);
    //         require(
    //             params[i].quantity <= productVarient.priceOptions.quantity,
    //             getErrorMessage(
    //                 13,
    //                 "Requested quantity exceeds available stock"
    //             )
    //         );

    //         productIds[i] = params[i].productID;
    //         variantIds[i] = params[i].variantID;
    //         quantities[i] = params[i].quantity;
    //         diffPrices[i] = diffPrice;
    //         prices[i] = productPrice;
    //         rewards[i] = productVarient.priceOptions.reward;
    //         cartItemIds[i] = params[i].cartItemId;
    //     }
    // }
struct ProcessOrderResult {
    uint256[] productIds;
    bytes32[] variantIds;
    uint256[] quantities;
    uint256[] diffPrices;
    uint256[] prices;
    uint256[] rewards;
    uint256[] cartItemIds;
    uint256 totalPrice;
}

function ProcessOrder(
    CreateOrderParams[] memory params,
    // uint256 totalPriceWithoutDiscount,
    address user
)
    internal
    view
    returns (ProcessOrderResult memory result)
{
    bool isVIP = TreeCom.isVIPOrPromoter(user); // Check if user is VIP
    uint256 totalParams = params.length;

    result.productIds = new uint256[](totalParams);
    result.variantIds = new bytes32[](totalParams);
    result.quantities = new uint256[](totalParams);
    result.cartItemIds = new uint256[](totalParams);
    result.prices = new uint256[](totalParams);
    result.diffPrices = new uint256[](totalParams);
    result.rewards = new uint256[](totalParams);

    for (uint i = 0; i < totalParams; i++) {
        bool cartItemExists = false;
        for (uint j = 0; j < mUserCart[user].items.length; j++) {
            if (mUserCart[user].items[j].id == params[i].cartItemId) {
                cartItemExists = true;
                break;
            }
        }

        require(
            cartItemExists,
            '{"from": "EcomProduct.sol","code": 13, "message": "cartItemId does not exist in the cart"}'
        );

        require(
            EcomProduct.getProduct(params[i].productID).params.isApprove,
            getErrorMessage(15, "This product has not been approved.")
        );

        Variant memory productVarient = EcomProduct.getVariant(params[i].productID, params[i].variantID);
        uint256 diffPrice = 0;
        uint256 productPrice;

        if (isVIP) {
            productPrice = productVarient.priceOptions.vipPrice;
        } else {
            productPrice = productVarient.priceOptions.memberPrice;
            // diffPrice = productPrice - productVarient.priceOptions.vipPrice;

            require(
                // diffPrice > 0,
                productPrice < productVarient.priceOptions.vipPrice,
                '{"from": "EcomProduct.sol","code": 13, "message": "wrong diffPrice"}'
            );
        }

        result.totalPrice += (productPrice * params[i].quantity);
        require(
            params[i].quantity <= productVarient.priceOptions.quantity,
            getErrorMessage(13, "Requested quantity exceeds available stock")
        );

        result.productIds[i] = params[i].productID;
        result.variantIds[i] = params[i].variantID;
        result.quantities[i] = params[i].quantity;
        result.diffPrices[i] = diffPrice;
        result.prices[i] = productPrice;
        result.rewards[i] = productVarient.priceOptions.reward;
        result.cartItemIds[i] = params[i].cartItemId;
    }
}

    function ExecuteOrder(
        CreateOrderParams[] memory params,
        ShippingParams memory shippingParams,
        orderDetails memory details
    ) external returns (bytes32) {
        require(
            params.length > 0,
            '{"from": "EcomOrder.sol","code": 11, "message":"Order have no item"}'
        );
        require(
            params.length < 100,
            '{"from": "EcomOrder.sol","code": 11, "message":"Order have max item"}'
        );
        require(
            details.paymentType == PaymentType.METANODE,
            getErrorMessage(
                12,
                "Invalid payment type, payment type should me metanode"
            )
        );

        address parent = EcomUser.getUserParent(msg.sender);
        require(
            parent != address(0),
            '{"from": "EcomOrder.sol","code": 12, "message":"User not exist"}'
        );

        orderID++;

        // (
        //     uint256[] memory productIds,
        //     bytes32[] memory variantIds,
        //     uint256[] memory quantities,
        //     uint256[] memory diffPrices,
        //     uint256[] memory prices,
        //     uint256[] memory rewards,
        //     uint256[] memory cartItemIds,
        //     uint256 totalPrice
        // ) = ProcessOrder(params, details.totalPriceWithoutDiscount, msg.sender);
        // ProcessOrderResult memory rt = ProcessOrder(params, details.totalPriceWithoutDiscount, msg.sender);
        ProcessOrderResult memory rt = ProcessOrder(params,  msg.sender);

        Order memory newOrder = Order({
            orderID: orderID,
            user: parent,
            buyer: msg.sender,
            discountID: 0,
            productIds: rt.productIds,
            variantIds: rt.variantIds,
            quantities: rt.quantities,
            diffPrices: rt.diffPrices,
            prices: rt.prices,
            rewards: rt.rewards,
            cartItemIds: rt.cartItemIds,
            totalPrice: rt.totalPrice,
            checkoutType: uint8(details.checkoutType),
            orderStatus: details.checkoutType == CheckoutType.STORAGE
                ? uint8(OrderStatus.STORAGE)
                : uint8(OrderStatus.INTRANSIT),
            codeRef: details.codeRef,
            afterDiscountPrice: 0,
            shippingPrice: 0,
            paymentType: uint8(details.paymentType),
            createdAt: block.timestamp
        });

        mOrder[orderID] = newOrder;

        {
            if (details.checkoutType == CheckoutType.RECEIVE) {
                createShippingInfo(shippingParams, orderID, msg.sender);
            }
        }

        bytes32 orderCode = keccak256(abi.encode(block.timestamp, block.number, msg.sender, orderID));

        emit eCreateOrder(orderCode);
        mAddToOrderCode[msg.sender] = orderCode;

        if (newOrder.cartItemIds.length > 0) {
            for (uint i = 0; i < newOrder.cartItemIds.length; i++) {
                // delete item in cart
                // deleteItemInCartBySmc(newOrder.user, newOrder.cartItemIds[i]);
                deleteItemInCartBySmc(msg.sender, newOrder.cartItemIds[i]);
            }
        }

        mOrders[newOrder.user].push(orderID);
        orders.push(orderID);

        orderCodes[orderCode] = orderID;
        return orderCode;
    }

    function getOrderCode(bytes32 orderCode) external view returns (uint256) {
        return orderCodes[orderCode];
    }
    
    // xác nhận thanh toán từ bên smart contract po5
    function ConfirmPaymentForOrderCode(
        bytes32 orderCode
    ) external onlyAddress(address(TreeCom)) {
        uint256 _orderID = orderCodes[orderCode];
        require(_orderID > 0, "wrong order ID");
        Order memory newOrder = mOrder[_orderID];

        require(newOrder.cartItemIds.length > 0, "not found order");

        for (uint8 i = 0; i < newOrder.productIds.length; i++) {
            Variant memory tempVariant = EcomProduct.getVariant(newOrder.productIds[i], newOrder.variantIds[i]); 
            
            tempVariant.priceOptions.quantity =
                tempVariant.priceOptions.quantity -
                newOrder.quantities[i];
            require(
                tempVariant.priceOptions.quantity >= 0,
                '{"from": "EcomProduct.sol","code": 14, "message":"updated quantity of product must >= 0"}'
            );

            // tempProduct.updatedAt = block.timestamp;
            // update quantity in product
            // will update sold and quantity
            EcomProduct.updateProductQuantity(
                newOrder.productIds[i],
                newOrder.variantIds[i],
                tempVariant.priceOptions.quantity,
                newOrder.quantities[i]
            );
            // increase for bestseller
            EcomInfo.increaseBestSeller(newOrder.productIds[i]);
            EcomInfo.increasePurchases(newOrder.user, newOrder.productIds[i]);
            if (newOrder.checkoutType != uint8(CheckoutType.STORAGE)) {
                ShippingInfo memory info = getShippingInfoByOrderID(_orderID);
                Purchase memory purchase = Purchase(
                    newOrder.productIds[i],
                    block.timestamp
                );
                EcomInfo.increaseCountryPurchases(info.params.country,purchase);
            }
            EcomInfo.increaseProductPurchaseTrend(newOrder.productIds[i]);
        }

        PaymentHistory memory newPaymentHistory = PaymentHistory(
            newOrder.paymentType,
            newOrder.totalPrice,
            newOrder.buyer
        );
        EcomUser.addUserPayment(newOrder.user, newPaymentHistory);
        EcomUser.sendExecuteOrderNotification(
            newOrder.orderID,
            mOrder[_orderID].user,
            EcomProduct.getRetailersByProductIds(newOrder.productIds)
        );
        emit eExecuteOrder(_orderID);
    }

    function GetOrderInfoFromOrderCode(bytes32 _orderCode) public view returns (Order memory res){
        uint256 orderId = orderCodes[_orderCode];
        res = mOrder[orderId];
    }

    // function CreateParamsForExecuteOrder(
    //     CreateOrderParams[] memory params,
    //     ShippingParams memory shippingParams,
    //     address user,
    //     orderDetails memory details
    // ) public returns (uint256) {
    //     orderInfoID++;
    //     DecodedParams storage newOrderInfo = mOrderInfo[orderInfoID];

    //     for (uint256 i = 0; i < params.length; i++) {
    //         newOrderInfo.params.push(params[i]);
    //     }

    //     // Copy other fields to storage
    //     newOrderInfo.shippingParams = shippingParams;
    //     newOrderInfo.user = user;
    //     newOrderInfo.details = details;

    //     return orderInfoID;
    // }

    function GetOrderInfo(
        uint256 _id
    ) public view returns (DecodedParams memory) {
        return mOrderInfo[_id];
    }

    function _deleteParamsForExecuteOrder(
        uint256 _orderInfoID
    ) internal returns (bool) {
        delete mOrderInfo[_orderInfoID];
        return true;
    }

    function CheckCallData(
        bytes memory callData
    ) public view returns (bool) {
        uint256 _orderInfoID = abi.decode(callData, (uint256));
        // Check if the orderInfo exists by verifying a known field (e.g., user address)
        if (mOrderInfo[_orderInfoID].user != address(0)) {
            return true;
        } else {
            return false;
        }
    }

    // function ExecuteOrder(
    //   bytes memory _callData,
    //   bytes32 _orderId,
    //   uint256 _paymentAmount
    // ) public override onlyAddress(POS) returns (bool) {
    //     bool exists = CheckCallData(_callData);
    //     require(
    //         exists,
    //         '{"from": "EcomProduct.sol","code": 60 , "message":"Invalid call data"}'
    //     );
    //     uint256 _orderInfoID = abi.decode(_callData, (uint256));
    //     DecodedParams memory decodedParams = mOrderInfo[_orderInfoID];

    //     return _executeOrder(decodedParams, _orderId, _orderInfoID, _paymentAmount);
    // }

    // function _executeOrder(
    //     DecodedParams memory decodedParams,
    //     bytes32 _idPayment,
    //     uint256 _orderInfoID,
    //     uint256 paymentAmount
    // ) internal returns (bool) {
    //     require(
    //         decodedParams.params.length > 0,
    //         '{"from": "EcomProduct.sol","code": 11, "message":"Order have no item"}'
    //     );
    //     require(
    //         decodedParams.params.length < 100,
    //         '{"from": "EcomProduct.sol","code": 11, "message":"Order have max item"}'
    //     );
    //     require(
    //         decodedParams.details.checkoutType != CheckoutType.STORAGE,
    //         getErrorMessage(12, "Order by visa should be Receive only")
    //     );
    //     orderID++;
    //     EcomUser.CheckUserExists(decodedParams.user);
        
    //     (
    //         uint256[] memory productIds,
    //         bytes32[] memory variantIds,
    //         uint256[] memory quantities,
    //         uint256[] memory diffPrices,
    //         uint256[] memory prices,
    //         uint256[] memory rewards,
    //         uint256[] memory cartItemIds,
    //         uint256 totalPrice
    //     ) = ProcessOrder(
    //             decodedParams.params,
    //             decodedParams.details.totalPriceWithoutDiscount,
    //             decodedParams.user
    //         );

    //     require(
    //         paymentAmount >= totalPrice,
    //         '{"from": "EcomProduct.sol","code": 56, "message":"invalid payment amount"}'
    //     );

    //     {
    //         Order memory newOrder;

    //         newOrder.orderID = orderID;
    //         newOrder.user = decodedParams.user;
    //         newOrder.buyer = msg.sender;
    //         newOrder.discountID = 0;
    //         newOrder.productIds = productIds;
    //         newOrder.variantIds = variantIds;
    //         newOrder.quantities = quantities;
    //         newOrder.diffPrices: diffPrices,
    //         newOrder.prices: prices,
    //         newOrder.rewards: rewards,
    //         newOrder.cartItemIds = cartItemIds;
    //         newOrder.totalPrice = totalPrice;
    //         newOrder.checkoutType = uint8(decodedParams.details.checkoutType);
    //         newOrder.orderStatus = decodedParams.details.checkoutType ==
    //             CheckoutType.STORAGE
    //             ? uint8(OrderStatus.STORAGE)
    //             : uint8(OrderStatus.INTRANSIT);
    //         newOrder.codeRef = decodedParams.details.codeRef;
    //         newOrder.afterDiscountPrice = 0;
    //         newOrder.shippingPrice = 0;
    //         newOrder.paymentType = uint8(decodedParams.details.paymentType);
    //         newOrder.createdAt = block.timestamp;
    //         mOrder[orderID] = newOrder;

    //         if (decodedParams.details.checkoutType == CheckoutType.RECEIVE) {
    //             createShippingInfo(
    //                 decodedParams.shippingParams,
    //                 orderID,
    //                 decodedParams.user
    //             );
    //         }
    //     }

    //     emit eCreateOrder(orderID);

    //     require(
    //         mOrder[orderID].paymentType == uint8(PaymentType.VISA),
    //         '{"from": "EcomProduct.sol","code": 52, "message": "Payment type must be visa"}'
    //     );

    //     updateProductsAndCommissions(mOrder[orderID], _idPayment);

    //     {
    //         if (mOrder[orderID].cartItemIds.length > 0) {
    //             for (
    //                 uint i = 0;
    //                 i < mOrder[orderID].cartItemIds.length;
    //                 i++
    //             ) {
    //                 // delete item in cart
    //                 deleteItemInCartBySmc(
    //                     mOrder[orderID].user,
    //                     mOrder[orderID].cartItemIds[i]
    //                 );
    //             }
    //         }
    //         mOrder[orderID].orderStatus = 1; //Intransit
    //         mOrders[mOrder[orderID].user].push(orderID);
    //         orders.push(orderID);
    //         PaymentHistory memory newPaymentHistory = PaymentHistory(
    //             mOrder[orderID].paymentType,
    //             mOrder[orderID].totalPrice,
    //             mOrder[orderID].buyer
    //         );
    //         EcomUser.addUserPayment(mOrder[orderID].user, newPaymentHistory);
    //     }
    //     EcomUser.sendExecuteOrderNotification(
    //         orderID,
    //         mOrder[orderID].user,
    //         EcomProduct.getRetailersByProductIds(mOrder[orderID].productIds)
    //     );
    //     _deleteParamsForExecuteOrder(_orderInfoID);
    //     return true;
    // }

    // function updateProductsAndCommissions(
    //     Order memory newOrder,
    //     bytes32 _idPayment
    // ) internal {
    //     address coderefer = TreeCom.GetRefCodeOwner(newOrder.codeRef);
    //     for (uint8 i = 0; i < newOrder.productIds.length; i++) {
    //         Variant memory tempVariant = EcomProduct.getVariant(newOrder.productIds[i], newOrder.variantIds[i]);
            
    //         transferComIn.buyer = coderefer;
    //         transferComIn.price = newOrder.prices[i];
    //         transferComIn.reward = newOrder.rewards[i];
    //         transferComIn.diff = newOrder.diffPrices[i];
    //         transferComIn.idPayment = _idPayment;
    //         TreeCom.TransferCommssionSave(transferComIn);

    //         if (tempVariant.priceOptions.quantity - newOrder.quantities[i] > 0) {
    //             tempVariant.priceOptions.quantity -= newOrder.quantities[i];
    //         } else {
    //             tempVariant.priceOptions.quantity = 0;
    //         }

    //         EcomProduct.updateProductQuantity(
    //             newOrder.productIds[i],
    //             newOrder.variantIds[i],
    //             tempVariant.priceOptions.quantity,
    //             newOrder.quantities[i]
    //         );
    //         EcomInfo.increaseBestSeller(newOrder.productIds[i]);
    //         EcomInfo.increasePurchases(newOrder.user, newOrder.productIds[i]);

    //         if (newOrder.checkoutType != uint8(CheckoutType.STORAGE)) {
    //             ShippingInfo memory info = getShippingInfoByOrderID(
    //                 orderID
    //             );
    //             Purchase memory purchase = Purchase(
    //                 newOrder.productIds[i],
    //                 block.timestamp
    //             );
    //            EcomInfo.increaseCountryPurchases(info.params.country,purchase);
    //         }
    //         EcomInfo.increaseProductPurchaseTrend(newOrder.productIds[i]);
    //     }
    // }

    // function ExecuteOrderStorage(
    //     uint256 _shareLinkID,
    //     address user,
    //     ShippingParams memory shippingParams,
    //     PaymentType paymentType
    // ) public returns (uint256){
    //   require(
    //         mShareLink[_shareLinkID].ID > 0 &&
    //             !mShareLink[_shareLinkID].isExecuted,
    //         "invalid shareLink or share link already executed"
    //     );
    //     require(
    //         mShareLink[_shareLinkID].expiredTime >= block.timestamp,
    //         "this share link is expired"
    //     );
    //     EcomUser.CheckUserExists(user);
    //     EcomUser.CheckUserExists(msg.sender);

    //     orderID++;
    //     createShippingInfo(shippingParams, orderID, user);

    //     (
    //         uint256[] memory productIds,
    //         bytes32[] memory variantIds,
    //         uint256[] memory quantities,
    //         uint256[] memory diffPrices,
    //         uint256[] memory prices,
    //         uint256[] memory rewards,
    //         uint256 totalPrice
    //     ) = processOrderByStorageOrder(_shareLinkID);

    //     mOrder[orderID] = Order({
    //         orderID: orderID,
    //         user: user,
    //         buyer: msg.sender,
    //         discountID: 0,
    //         productIds: productIds,
    //         variantIds: variantIds,
    //         quantities: quantities,
    //         diffPrices: diffPrices,
    //         prices: prices,
    //         rewards: rewards,
    //         cartItemIds: new uint256[](0),
    //         afterPrices: new uint256[](0),
    //         totalPrice: totalPrice,
    //         checkoutType: uint8(CheckoutType.RECEIVE),
    //         orderStatus: uint8(OrderStatus.AWAITING),
    //         codeRef: bytes32(0),
    //         afterDiscountPrice: 0,
    //         shippingPrice: 0,
    //         paymentType: uint8(paymentType),
    //         createdAt: block.timestamp
    //     });

    //     emit eCreateOrder(orderID);
    //     USDT.transferFrom(
    //         msg.sender,
    //         mShareLink[_shareLinkID].owner,
    //         totalPrice
    //     );
    //     for (uint i = 0; i < mOrder[orderID].productIds.length; i++) {
    //         Product memory tempProduct = EcomProduct.getProduct(
    //             mOrder[orderID].productIds[i]
    //         );
    //         //increase for bestseller
    //         EcomInfo.increaseBestSeller(tempProduct.id);
    //         EcomInfo.increasePurchases(mOrder[orderID].user, tempProduct.id);
    //         EcomInfo.increaseProductPurchaseTrend(tempProduct.id);
    //     }
    //     mOrder[orderID].orderStatus = 1; //Intransit
    //     mOrders[mOrder[orderID].user].push(orderID);
    //     orders.push(orderID);
    //     EcomUser.addUserPayment(mOrder[orderID].user, PaymentHistory(
    //             mOrder[orderID].paymentType,
    //             mOrder[orderID].totalPrice,
    //             msg.sender
    //     ));
    //     EcomUser.sendNotificationStorageOrder(orderID, user, mShareLink[_shareLinkID].owner);
    //     mShareLink[_shareLinkID].isExecuted = true;
    //     return orderID;
    // }

    // function processOrderByStorageOrder(
    //     uint256 _shareLinkID
    // )
    //     internal
    //     view
    //     returns (
    //         uint256[] memory productIds,
    //         bytes32[] memory variantIds,
    //         uint256[] memory quantities,
    //         uint256[] memory prices,
    //         uint256[] memory rewards,
    //         uint256[] memory cartItemIds,
    //         uint256 totalPrice
    //     )
    // {
    //     ShareLink storage shareLink = mShareLink[_shareLinkID];
    //     require(
    //         shareLink.ID != 0,
    //         '{"from": "EcomProduct.sol","code": 14, "message":"updated quantity of product must >= 0"}'
    //     );

    //     uint256 paramsLength;
    //     for (uint i = 0; i < shareLink.params.length; i++) {
    //         paramsLength += shareLink.params[i].productIds.length;
    //     }

    //     productIds = new uint256[](paramsLength);
    //     quantities = new uint256[](paramsLength);
    //     variantIds = new bytes32[](paramsLength);
    //     prices = new uint256[](paramsLength);

    //     uint256 index = 0;
    //     for (uint i = 0; i < shareLink.params.length; i++) {
    //         for (uint j = 0; j < shareLink.params[i].productIds.length; j++) {
    //             productIds[index] = (shareLink.params[i].productIds[j]);
    //             quantities[index] = (shareLink.params[i].quantities[j]);
    //             variantIds[index] = (shareLink.params[i].variantIds[j]);
    //             prices[index] = (shareLink.params[i].prices[j]);
    //             totalPrice +=
    //                 shareLink.params[i].prices[j] *
    //                 shareLink.params[i].quantities[j];
    //             index++;
    //         }
    //     }
    // }

    function createShareLink(
        ShareLinkParams[] memory params,
        uint256 expiredTime
    ) public returns (uint256) {
        require(
            params.length > 0,
            getErrorMessage(45, "Share link params must not empty")
        );
        // check if parentOrder ID exists and have product exists, quantity...
        // delete quantity from parentID
        checkValidShareLinkParams(params);
        // Pass
        shareLinkID++;
        for (uint i = 0; i < params.length; i++) {
            mShareLink[shareLinkID].params.push(params[i]);
        }
        mShareLink[shareLinkID].ID = shareLinkID;
        mShareLink[shareLinkID].expiredTime = expiredTime;
        mShareLink[shareLinkID].owner = msg.sender;
        // mShareLink.isExecuted = false by default
        mUserShareLink[msg.sender].push(shareLinkID);
        return shareLinkID;
    }

    function updateShareLink(
        uint256 _shareLinkID,
        ShareLinkParams[] memory params,
        uint256 expiredTime
    ) public returns (bool) {
        ShareLink storage shareLink = mShareLink[_shareLinkID];

        require(
            shareLink.owner == msg.sender,
            '{"from": "EcomProduct.sol","code": 1002, "message":"You are not owner of the sharelink"}'
        );
        require(
            shareLink.ID > 0 && !shareLink.isExecuted,
            '{"from": "EcomProduct.sol","code": 1003, "message":"Invalid sharelink or already executed"}'
        );

        // revert all data to parent order
        recoverParentOrder(shareLink);

        delete shareLink.params;
        // check if sharelink params valid and decrease from parentOrder
        checkValidShareLinkParams(params);
        // check increase or decrease quantity, update to parent order
        // only allow update params, expiredTime

        for (uint i = 0; i < params.length; i++) {
            shareLink.params.push(params[i]);
        }

        shareLink.expiredTime = expiredTime;
        return true;
    }

    function deleteShareLink(uint256 _shareLinkID) public returns (bool) {
        ShareLink storage shareLink = mShareLink[_shareLinkID];
        require(
            shareLink.owner == msg.sender,
            '{"from": "EcomProduct.sol","code": 1002, "message":"You are not owner of the sharelink"}'
        );
        require(
            shareLink.ID > 0,
            '{"from": "EcomProduct.sol","code": 1003, "message":"Invalid sharelink"}'
        );

        if (!shareLink.isExecuted) {
            recoverParentOrder(shareLink);
        }

        for (uint i = 0; i < mUserShareLink[msg.sender].length; i++) {
            if (mUserShareLink[msg.sender][i] == _shareLinkID) {
                mUserShareLink[msg.sender][i] = mUserShareLink[msg.sender][
                    mUserShareLink[msg.sender].length - 1
                ];
                mUserShareLink[msg.sender].pop();
                break;
            }
        }
        delete mShareLink[_shareLinkID];
        return true;
    }

    function deleteMultipleShareLink(
        uint256[] memory _shareLinkIds
    ) public returns (bool) {
        for (uint i; i < _shareLinkIds.length; i++) {
            deleteShareLink(_shareLinkIds[i]);
        }
        return true;
    }

    function checkValidShareLinkParams(
        ShareLinkParams[] memory params
    ) internal returns (bool) {
        for (uint i = 0; i < params.length; i++) {
            Order storage parentOrder = mOrder[params[i].parentOrderID];

            require(
                parentOrder.orderID != 0,
                '{"from": "EcomProduct.sol","code": 1002, "message":"Order does not exists"}'
            );
            require(
                msg.sender == parentOrder.user,
                '{"from": "EcomProduct.sol","code": 1003, "message":"You are not owner of the order"}'
            );

            require(
                parentOrder.checkoutType == uint8(CheckoutType.STORAGE),
                '{"from": "EcomProduct.sol","code": 1003, "message":"Order is not storage order"}'
            );
            // check productIds in params exists in parent order
            for (uint j = 0; j < params[i].productIds.length; j++) {
                uint256 productId = params[i].productIds[j];
                uint256 quantity = params[i].quantities[j];
                bytes32 variantID = params[i].variantIds[j];
                bool productExists;
                for (uint k = 0; k < parentOrder.productIds.length; k++) {
                    if (
                        parentOrder.productIds[k] == productId &&
                        parentOrder.variantIds[k] == variantID
                    ) {
                        require(
                            parentOrder.quantities[k] >= quantity,
                            "not enough quantity in parent order"
                        );
                        parentOrder.quantities[k] -= quantity;
                        productExists = true;
                        break;
                    }
                }
                require(
                    productExists,
                    "product ID does not exist in parent order"
                );
            }
        }
        return true;
    }

    function recoverParentOrder(
        ShareLink storage shareLink
    ) internal returns (bool) {
        for (uint i = 0; i < shareLink.params.length; i++) {
            ShareLinkParams storage oldParams = shareLink.params[i];
            Order storage parentOrder = mOrder[oldParams.parentOrderID];

            for (uint j = 0; j < oldParams.productIds.length; j++) {
                uint256 productId = oldParams.productIds[j];
                uint256 quantity = oldParams.quantities[j];
                bytes32 variantID = oldParams.variantIds[j];
                for (uint k = 0; k < parentOrder.productIds.length; k++) {
                    if (
                        parentOrder.productIds[k] == productId &&
                        parentOrder.variantIds[k] == variantID
                    ) {
                        parentOrder.quantities[k] += quantity; // Revert the quantity to the parent order
                        break;
                    }
                }
            }
        }
        return true;
    }
    // ==========================================================================
    function getErrorMessage(
        uint256 code,
        string memory message
    ) public pure returns (string memory) {
        string memory codeStr = Strings.toString(code);

        return
            string(
                abi.encodePacked(
                    '{"from": "EcomOrder.sol",',
                    '"code": ',
                    codeStr,
                    ", ",
                    '"message": "',
                    message,
                    '"}'
                )
            );
    }

    function getShippingInfoByOrderID(
        uint256 _orderID
    ) public view returns (ShippingInfo memory) {
        return mShippingInfo[mShippingInfoByOrder[_orderID]];
    }

    function getOrder(uint256 _orderID) public view returns (Order memory) {
        return mOrder[_orderID];
    }

    function getOrders() public view returns (Order[] memory res) {
        res = new Order[](orders.length);
        for (uint256 i = 0; i < orders.length; i++) {
            res[i] = mOrder[orders[i]];
        }
    }

    function getUserOrders(address _user) public view returns (Order[] memory res){
        uint256[] memory orderIds = mOrders[_user];
        res = new Order[](orderIds.length);
        for (uint256 i = 0; i < res.length; i++) {
            res[i] = mOrder[orderIds[i]];
        }
    } 

    function getUserCart() public view returns (Cart memory) {
        return mUserCart[msg.sender];
    }

    function getUserCartInfo(address _user) public view returns (Cart memory){
        return mUserCart[_user];
    }

    function getShareLink(uint256 _id) public view returns (ShareLink memory) {
        return mShareLink[_id];
    }

    function getShareLinks() public view returns (ShareLink[] memory) {
        ShareLink[] memory shareLinks = new ShareLink[](
            mUserShareLink[msg.sender].length
        );
        uint256[] storage shareLinkIds = mUserShareLink[msg.sender];
        for (uint i = 0; i < shareLinkIds.length; i++) {
            shareLinks[i] = mShareLink[shareLinkIds[i]];
        }
        return shareLinks;
    }

    function getUserShareLinks(address _user) public view returns (ShareLink[] memory){
        ShareLink[] memory shareLinks = new ShareLink[](
            mUserShareLink[_user].length
        );
        uint256[] storage shareLinkIds = mUserShareLink[_user];
        for (uint i = 0; i < shareLinkIds.length; i++) {
            shareLinks[i] = mShareLink[shareLinkIds[i]];
        }
        return shareLinks;
    }
}

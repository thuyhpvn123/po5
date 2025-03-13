// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libs/utils.sol";
import "./interfaces/ITreeCom.sol";
import "./interfaces/INoti.sol";
import "./interfaces/IEcomUser.sol";
import "./interfaces/IEcomInfo.sol";
import "./interfaces/IEcomOrder.sol";

contract EcomUserContract {
    event eRegisterRetailer(string username, address user, string phoneNumber);

    address public owner;

    mapping(address => bool) public mAdmin;
    address[] public admins;

    mapping(address => UserInfo) public mUserInfo;
    mapping(address => AddressInfo[]) public mUserAddressInfo;
    mapping(address => NotificationSetting) public userNotificationSettings;
    mapping(address => PaymentHistory[]) public mUserPaymentHistory;

    address[] public userList;

    ITreeCom public TreeCom;
    INoti public Notification;
    IEcomOrder public EcomOrder;
    IEcomInfo public EcomInfo;
    string public NOTIFIER = "ECOM";
    constructor() payable {
        owner = msg.sender;
        setUser(msg.sender, ROLE.ADMIN);
    }

    function SetNotification(
        address _noti
    ) public onlyAddress(owner) returns (bool) {
        Notification = INoti(_noti);
        return true;
    }

    function SetEcomOrder(address _ecomOrder) public onlyAddress(owner) returns (bool){
        EcomOrder = IEcomOrder(_ecomOrder);
        return true;
    }

    function SetEcomInfo(address _ecomInfo) public onlyAddress(owner) returns (bool){
        EcomInfo = IEcomInfo(_ecomInfo);
        return true;
    }


    modifier onlyAddress(address user) {
        require(
            msg.sender == user,
            '{"from": "EcomUser.sol","code": 55, "message": "You are not allowed."}'
        );
        _;
    }

    function SetTreeCom(
        address _po5
    ) external onlyAddress(owner) returns (bool) {
        TreeCom = ITreeCom(_po5);
        return true;
    }
     
    function setAdmin(address user) public onlyAddress(owner) returns (bool) {
        mAdmin[user] = true;
        admins.push(user);
        setUser(user, ROLE.ADMIN);
        return true;
    }

    function setRetailer(
        address _user
    ) public onlyAddress(owner) returns (bool) {
        setUser(_user, ROLE.RETAILER);
        return true;
    }

    function setUser(address _user, ROLE _role) internal {
        mUserInfo[_user].user = _user;
        mUserInfo[_user].role = _role;
        mUserInfo[_user].createdAt = block.timestamp;
        userList.push(_user);
    }

    function deleteAdmin(
        address user
    ) public onlyAddress(owner) returns (bool) {
        mAdmin[user] = false;
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == user) {
                admins[i] = admins[admins.length - 1];
                admins.pop();
                break;
            }
        }
        return true;
    }

    function setCustomerNotificationSetting(
        bool _email,
        bool _orderUpdate,
        bool _promotion,
        bool _createProduct
    ) public returns (bool) {
        require(
            mUserInfo[msg.sender].role == ROLE.CUSTOMER,
            '{"from": "EcomUser.sol","code": 51, "message": "You are not a customer."}'
        );

        userNotificationSettings[msg.sender] = NotificationSetting(
            _email,
            _orderUpdate,
            _promotion,
            _createProduct,
            false,
            false
        );

        return true;
    }

    function setRetailerNotificationSetting(
        bool _email,
        bool _orderUpdate,
        bool _promotion,
        bool _createProduct,
        bool _customerOrderUpdate,
        bool _commentUpdate
    ) public returns (bool) {
        require(
            mUserInfo[msg.sender].role == ROLE.RETAILER,
            '{"from": "EcomUser.sol","code": 51, "message": "You are not a retailer."}'
        );

        userNotificationSettings[msg.sender] = NotificationSetting(
            _email,
            _orderUpdate,
            _promotion,
            _createProduct,
            _customerOrderUpdate,
            _commentUpdate
        );

        return true;
    }

    function setAdminNotificationSetting(
        bool _email,
        bool _orderUpdate,
        bool _promotion,
        bool _createProduct,
        bool _customerOrderUpdate,
        bool _commentUpdate
    ) public onlyAddress(owner) returns (bool) {
        userNotificationSettings[msg.sender] = NotificationSetting(
            _email,
            _orderUpdate,
            _promotion,
            _createProduct,
            _customerOrderUpdate,
            _commentUpdate
        );

        return true;
    }

    function registerRetailer(
        string memory _username,
        string memory _phoneNumber
    ) public onlyAddress(owner) returns (bool) {
        require(
            mUserInfo[msg.sender].role != ROLE.RETAILER,
            '{"from": "EcomUser.sol","code": 1, "message": "The user is already registered as a retailer."}'
        );

        emit eRegisterRetailer(_username, msg.sender, _phoneNumber);

        mUserInfo[msg.sender].fullName = _username;
        mUserInfo[msg.sender].phoneNumber = _phoneNumber;
        mUserInfo[msg.sender].role = ROLE.RETAILER;
        mUserInfo[msg.sender].user = msg.sender;
        mUserInfo[msg.sender].createdAt = block.timestamp;
        userList.push(msg.sender);

        return true;
    }

    function register(registerParams memory params) public returns (bool) {
        require(
            bytes(params.fullName).length > 0,
            '{"from": "EcomUser.sol","code": 47,"message": "Invalid username"}'
        );

        require(
            mUserInfo[msg.sender].createdAt == 0,
            '{"from": "EcomUser.sol","code": 102, "message": "User exists"}'
        );

        require(
            params.parent != address(0),
            '{"from": "EcomUser.sol","code": 101, "message": "Parent empty"}'
        );
        require(
            // TreeCom.isPromoter(params.parent),
            TreeCom.isVIPOrPromoter(params.parent),
            '{"from": "EcomUser.sol","code": 101, "message": "Parent not exists"}'
        );

        mUserInfo[msg.sender].user = msg.sender;
        mUserInfo[msg.sender].fullName = params.fullName;
        mUserInfo[msg.sender].parent = params.parent;
        mUserInfo[msg.sender].email = params.email;
        mUserInfo[msg.sender].gender = params.gender;
        mUserInfo[msg.sender].dateOfBirth = params.dateOfBirth;
        mUserInfo[msg.sender].phoneNumber = params.phoneNumber;
        mUserInfo[msg.sender].role = ROLE.CUSTOMER;
        mUserInfo[msg.sender].createdAt = block.timestamp;
        userList.push(msg.sender);

        return true;
    }

    function updateUserInfo(
        registerParams memory params,
        AddressInfo[] memory addressesInfo
    ) public returns (bool) {
        require(
            mUserInfo[msg.sender].user != address(0),
            '{"from": "EcomUser.sol","code": 43,"message": "Invalid user"}'
        );

        mUserInfo[msg.sender].fullName = params.fullName;
        mUserInfo[msg.sender].email = params.email;
        mUserInfo[msg.sender].gender = params.gender;
        mUserInfo[msg.sender].dateOfBirth = params.dateOfBirth;
        mUserInfo[msg.sender].phoneNumber = params.phoneNumber;

        delete mUserAddressInfo[msg.sender];
        for (uint256 i = 0; i < addressesInfo.length; i++) {
            mUserAddressInfo[msg.sender].push(addressesInfo[i]);
        }

        return true;
    }

    function updateUserImage(string calldata image) public returns (bool) {
        mUserInfo[msg.sender].image = image;
        return true;
    }

    function deleteUser() public returns (bool) {
        delete mUserInfo[msg.sender];
        delete mUserAddressInfo[msg.sender];

        for (uint256 i = 0; i < userList.length; i++) {
            if (userList[i] == msg.sender) {
                userList[i] = userList[userList.length - 1];
                userList.pop();
            }
        }
        return true;
    }

    function adminDeleteUser(address _user) public onlyAddress(owner) returns (bool){
        delete mUserInfo[_user];
        delete mUserAddressInfo[_user];

        for (uint256 i = 0; i < userList.length; i++) {
            if (userList[i] == _user) {
                userList[i] = userList[userList.length - 1];
                userList.pop();
            }
        }
        return true;
    }

    function sendNotification(
        bytes memory data,
        uint8 dataStruct,
        string memory title,
        string memory body,
        address _to,
        string memory notificationType
    ) public {
        NotificationSetting memory settings = userNotificationSettings[_to];

        bool send = false;

        if (
            keccak256(abi.encodePacked(notificationType)) ==
            keccak256(abi.encodePacked("CreateProduct")) &&
            settings.CreateProduct
        ) {
            send = true;
        } else if (
            keccak256(abi.encodePacked(notificationType)) ==
            keccak256(abi.encodePacked("OrderUpdate")) &&
            settings.OrderUpdate
        ) {
            send = true;
        } else if (
            keccak256(abi.encodePacked(notificationType)) ==
            keccak256(abi.encodePacked("PromotionalProgram")) &&
            settings.PromotionalProgram
        ) {
            send = true;
        } else if (
            keccak256(abi.encodePacked(notificationType)) ==
            keccak256(abi.encodePacked("CustomerOrderUpdate")) &&
            settings.CustomerOrderUpdate
        ) {
            send = true;
        } else if (
            keccak256(abi.encodePacked(notificationType)) ==
            keccak256(abi.encodePacked("CommentUpdate")) &&
            settings.CommentUpdate
        ) {
            send = true;
        }

        if (send) {
            NotiParams memory params = NotiParams(
                NOTIFIER,
                data,
                dataStruct,
                title,
                body
            );
            Notification.AddNoti(params, _to);
        }
    }

    function sendMultipleNotification(
        bytes memory data,
        uint8 dataStruct,
        string memory title,
        string memory body,
        address[] memory _to,
        string memory notificationType
    ) public {
        address[] memory allowedRecipients = new address[](_to.length);
        uint256 count = 0;

        for (uint256 i = 0; i < _to.length; i++) {
            NotificationSetting memory settings = userNotificationSettings[
                _to[i]
            ];
            // if user's notification setting is true
            if (
                keccak256(abi.encodePacked(notificationType)) ==
                keccak256(abi.encodePacked("CreateProduct")) &&
                settings.CreateProduct
            ) {
                allowedRecipients[count] = _to[i];
                count++;
            } else if (
                keccak256(abi.encodePacked(notificationType)) ==
                keccak256(abi.encodePacked("OrderUpdate")) &&
                settings.OrderUpdate
            ) {
                allowedRecipients[count] = _to[i];
                count++;
            } else if (
                keccak256(abi.encodePacked(notificationType)) ==
                keccak256(abi.encodePacked("PromotionalProgram")) &&
                settings.PromotionalProgram
            ) {
                allowedRecipients[count] = _to[i];
                count++;
            } else if (
                keccak256(abi.encodePacked(notificationType)) ==
                keccak256(abi.encodePacked("CustomerOrderUpdate")) &&
                settings.CustomerOrderUpdate
            ) {
                allowedRecipients[count] = _to[i];
                count++;
            } else if (
                keccak256(abi.encodePacked(notificationType)) ==
                keccak256(abi.encodePacked("CommentUpdate")) &&
                settings.CommentUpdate
            ) {
                allowedRecipients[count] = _to[i];
                count++;
            }
        }

        if (count > 0) {
            address[] memory filteredRecipients = new address[](count);
            for (uint256 j = 0; j < count; j++) {
                filteredRecipients[j] = allowedRecipients[j];
            }

            NotiParams memory params = NotiParams(
                NOTIFIER,
                data,
                dataStruct,
                title,
                body
            );
            Notification.AddMultipleNoti(params, filteredRecipients);
        }
    }

    function sendCreateProductNotification(
        uint256 _productID,
        bool isFlashSale,
        address retailer
    ) external {
        sendMultipleNotification(
            abi.encodePacked(_productID),
            0,
            "Introducing New Product!",
            "We are excited to introduce a new product! Don't miss the chance to experience the latest products. Check it out now for more details.",
            userList,
            "CreateProduct"
        );
        // Send to the retailer
        sendNotification(
            abi.encodePacked(_productID),
            0,
            "New Product Post Successful!",
            "Your new product has been successfully posted! Check it out now on your store page and get ready to attract more customers.",
            retailer,
            "CreateProduct"
        );
        // Send to the admin
        sendNotification(
            abi.encodePacked(_productID),
            0,
            "New Product Post Successful!",
            "A new product has been successfully posted by a retailer! Check it out on the website and ensure everything is in order",
            owner,
            "CreateProduct"
        );

        if (isFlashSale) {
            sendMultipleNotification(
                abi.encodePacked(_productID),
                0,
                "Flash Sale Starts Now!",
                "Epic Savings Await! Our Flash Sale is here with jaw-dropping discounts!",
                userList,
                "PromotionalProgram"
            );
        }
    }
    
    function sendExecuteOrderNotification(
        uint256 _orderID,
        address _buyer,
        address[] memory _retailers
    ) external {
        sendNotification(
            abi.encodePacked(_orderID),
            0,
            "New Purchase",
            "Your order has been successfully placed! We will process and ship your order as soon as possible. Thank you for trusting and shopping.",
            _buyer,
            "OrderUpdate"
        );
        sendMultipleNotification(
            abi.encodePacked(_orderID),
            0,
            "New Purchase",
            "Your customer has successfully placed an order for your product! Thank you for partnering with us",
            _retailers,
            "CustomerOrderUpdate"
        );
        // send notification to Admin
        sendNotification(
            abi.encodePacked(_orderID),
            0,
            "New Order Received",
            "An order has been successfully placed by a customer for one of your products. Please review the order details to ensure everything is in order",
            owner,
            "CustomerOrderUpdate"
        );
    }

    function sendNotificationStorageOrder(
        uint256 _orderID,
        address _user,
        address _owner
    ) external {
        sendNotification(
            abi.encodePacked(_orderID),
            0,
            "New Purchase",
            "Your customer has successfully placed an order for your product! Thank you for partnering with us.",
            _owner,
            "CustomerOrderUpdate"
        );
        sendNotification(
            abi.encodePacked(_orderID),
            0,
            "Purchase Successful",
            "Your order has been successfully placed! We will process and ship your order as soon as possible. Thank you for trusting and shopping.",
            _user,
            "OrderUpdate"
        );
        sendNotification(
            abi.encodePacked(_orderID),
            0,
            "A Purchase Successful",
            "An order has been successfully placed by a customer for one of your products. Please review the order details to ensure everything is in order",
            owner,
            "CustomerOrderUpdate"
        );
    }

    function addUserPayment(address _user, PaymentHistory memory _payment)external {
        mUserPaymentHistory[_user].push(_payment);
    }
    // ====================GETTER==================================================

    function getUser()
        public
        view
        returns (UserInfo memory info, AddressInfo[] memory addresses)
    {
        return (mUserInfo[msg.sender], mUserAddressInfo[msg.sender]);
    }

    function getUserInfo(
        address _user
    )
        public
        view
        returns (UserInfo memory info, AddressInfo[] memory addresses)
    {
        return (mUserInfo[_user], mUserAddressInfo[_user]);
    }

    // CustomerManagement
    function getUsersInfo()
        public
        view
        returns (UserInfo[] memory infos, uint256[] memory purchases)
    {
        uint256 length = userList.length;
        infos = new UserInfo[](length);
        purchases = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            infos[i] = mUserInfo[userList[i]];
            purchases[i] = mUserPaymentHistory[userList[i]].length;
        }
    }


    // TODO: CustomerManagementPagination

    // AgentManagement
    // function getAgentsInfo()
    //     public
    //     returns (
    //         UserInfo[] memory infos,
    //         uint256[] memory productPosted,
    //         uint256[] memory solds
    //     )
    // {
    //     uint256 retailerCount = 0;

    //     for (uint256 i = 0; i < userList.length; i++) {
    //         if (mUserInfo[userList[i]].role == ROLE.RETAILER) {
    //             retailerCount++;
    //         }
    //     }
    //     infos = new UserInfo[](retailerCount);
    //     productPosted = new uint256[](retailerCount);
    //     solds = new uint256[](retailerCount);
    //     uint256 retailerIndex = 0;

    //     for (uint256 i = 0; i < userList.length; i++) {
    //         if (mUserInfo[userList[i]].role == ROLE.RETAILER) {
    //             infos[retailerIndex] = mUserInfo[userList[i]];
    //             Product[] memory products = ProductEcom.getRetailerProduct(
    //                 userList[i]
    //             );
    //             productPosted[i] = products.length;
    //             for (uint256 j = 0; j < products.length; j++) {
    //                 solds[i] += products[j].params.sold;
    //             }
    //             retailerIndex++;
    //         }
    //     }
    // }

    // TODO: pagination for product
    // function getRetailerInfomation(address _user) public returns (
    //   UserInfo memory info,
    //   AddressInfo[] memory addresses,
    //   PaymentHistory[] memory payment,
    //   ProductInfo[] memory productInfos
    // ){
    //     (info, addresses) = getUserInfo(_user);
    //     payment = mUserPaymentHistory[_user];
    //     productInfos = ProductEcom.getRetailerProductsInfo(_user);
    // }
    //

    function getUserParent(address _user) external view returns (address) {
        return mUserInfo[_user].parent;
    }

    function IsRetailer(address _user) external view returns (bool){
        return mUserInfo[_user].role == ROLE.RETAILER;
    }

    function getUserRole(address _user) external view returns (ROLE){
        require(mUserInfo[msg.sender].user != address(0), getErrorMessage(2, "User must register to get role"));
        return mUserInfo[_user].role;
    }

    function getUserPaymentHistory()
        public
        view
        returns (PaymentHistory[] memory)
    {
        return mUserPaymentHistory[msg.sender];
    }

    function getUserPaymentHistoryInfo(address _user)
        public
        view
        returns (PaymentHistory[] memory)
    {
        return mUserPaymentHistory[_user];
    }

    function getNotificationSetting(
        address _user
    ) public view returns (NotificationSetting memory) {
        return userNotificationSettings[_user];
    }

    function getErrorMessage(
        uint256 code,
        string memory message
    ) public pure returns (string memory) {
        string memory codeStr = Strings.toString(code);

        return
            string(
                abi.encodePacked(
                    '{"from": "EcomUser.sol",',
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

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import "./interfaces/IEcomProduct.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libs/utils.sol";
import "./interfaces/IEcomOrder.sol";
import "./interfaces/IEcomUser.sol";
import "./interfaces/IEcomInfo.sol";
// import "forge-std/console.sol";
contract EcomProductContract  {
    event eRegisterRetailer(string username, address user, string phoneNumber);
    event eCreateProduct(uint256 id, createProductParams params);
    event eUpdateProduct(uint256 id, createProductParams params);
    event eDeleteProduct(uint256 productID);
    event eCreateCategory(uint256 id, string name, string description);
    event eEditCategory(uint256 id, string name, string description);
    event eDeleteCategory(uint256 id);
    event eSetRetailer(address retailer);

    address public owner;
    // mapping(address => bool) public mController;

    mapping(address => mapping(uint256 => bool)) public mIsCorrectRetailer; // retailer => product => true;
    // Product
    mapping(uint256 => Product) public mProduct; // productID => Product
    uint256[] public products; //productIds
    bytes[] public brands;
    mapping(bytes => bool) public mBrand;

    mapping(uint256 => mapping(bytes32 => Variant)) public mVariant;
    mapping(uint256 => bytes32[]) public mProductVariant; // productID => variants
    mapping(uint256 => mapping(bytes32 => Attribute[]))
        public mVariantAttributes; // productID => variantID => attribute

    mapping(bytes32 => Attribute) public mAttribute;

    mapping(address => uint256[]) public mRetailerProduct; // retailer => productIds;
    // Category
    mapping(uint256 => Category) public mCategory; // categoryID => Category
    uint256[] public categories;

    mapping(uint256 => bytes32[]) public mCategoryAttributes;
    // only add to Order to mOrders if isExecuted = true;
    // this is user history order
    // Rating
    mapping(uint256 => Rating) public mRate;
    mapping(uint256 => uint256[]) public mProductRate; // productID => ratingID
    mapping(address => mapping(uint256 => RateValue)) public mUserRating; //user => productID => isRating?

    // Comment
    mapping(uint256 => uint256[]) public mCommentOfProduct; //ProductID => commentID
    mapping(uint256 => Comment) public mComment; //commentID => Comment

    // bua
    mapping(uint256 => mapping(uint256 => uint256)) public mReviewRate; // productID => commentID => rate (star);
    // FAQ
    mapping(uint256 => FAQ) public mFAQ;
    mapping(uint256 => uint256[]) public mProductFAQ; // productID => FAQ
    uint256[] public faqs; // PO5 FAQ

    // Favorite
    mapping(address => mapping(uint256 => bool)) public mFavorite; //user => product => favorite = true?
    mapping(address => Favorite[]) public mUserFavorites; //user => favorite products;

    // Admin
    // mapping(address => bool) public mAdmin;
    // address[] public admins;

    mapping(address => mapping(uint256 => bool))
        public userConfirmedBuyThisProduct;

    uint256 public productID;
    uint256 public categoryID;

    uint256 public ratingID;
    uint256 public commentID;
    uint256 public faqID;

    IEcomUser public EcomUser;
    IEcomOrder public EcomOrder;
    IEcomInfo public EcomInfo;

    constructor() payable {
        // mAdmin[msg.sender] = true;
        // admins.push(msg.sender);
        owner = msg.sender;
    }

    // function SetController(
    //     address _controller
    // ) public onlyAddress(owner) returns (bool) {
    //     mController[_controller] = true;
    //     return true;
    // }

    function SetEcomOrder(
        address _ecomOrder
    ) public onlyAddress(owner) returns (bool) {
        EcomOrder = IEcomOrder(_ecomOrder);
        return true;
    }

    function SetEcomInfo(
        address _ecomInfo
    ) public onlyAddress(owner) returns (bool) {
        EcomInfo = IEcomInfo(_ecomInfo);
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

    modifier onlyRateFrom1To5(uint rate) {
        require(
            rate >= 1 && rate <= 5,
            '{"from": "EcomProduct.sol","code": 54, "message": "Rate value must be between 1 and 5."}'
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            EcomUser.IsAdmin(msg.sender),
            // mAdmin[msg.sender],
            '{"from": "EcomProduct.sol","code": 53, "message": "You are not ADMIN."}'
        );
        _;
    }

    modifier onlyController() {
        require(
            // mController[msg.sender],
            EcomUser.IsController(msg.sender),
            '{"from": "EcomProduct.sol","code": 52, "message": "You are not controller."}'
        );
        _;
    }

    modifier onlyControllerOrRetailer() {
        require(
            EcomUser.IsController(msg.sender) || EcomUser.IsRetailer(msg.sender),
            getErrorMessage(55, "Only controller or retailer")
        );
        _;
    }

    // function setAdmin(address user) public onlyAddress(owner) returns (bool) {
    //     mAdmin[user] = true;
    //     admins.push(user);
    //     return true;
    // }

    // function deleteAdmin(
    //     address user
    // ) public onlyAddress(owner) returns (bool) {
    //     mAdmin[user] = false;
    //     for (uint256 i = 0; i < admins.length; i++) {
    //         if (admins[i] == user) {
    //             admins[i] = admins[admins.length - 1];
    //             admins.pop();
    //             break;
    //         }
    //     }
    //     return true;
    // }

    function createProduct(
        createProductParams memory params,
        VariantParams[] memory _variants
    ) public onlyControllerOrRetailer returns (uint256) {
        productID++;
        {
            require(params.retailPrice/1e6 >0 && params.vipPrice/1e6 >0 && params.memberPrice/1e6 >0,"price not big enough");
            require(
                mCategory[params.categoryID].id != 0,
                getErrorMessage(2, "Category not found")
            );

            require(
                EcomUser.IsRetailer(params.retailer),
                getErrorMessage(44, "User must be retailer")
            );

            require(
                _variants.length > 0,
                getErrorMessage(44, "Invalid variants length")
            );

            for (uint256 i = 0; i < _variants.length; i++) {
                require(
                    _variants[i].priceOptions.reward <=
                        ((_variants[i].priceOptions.memberPrice * 50000) /
                            130) /
                            825,
                    getErrorMessage(42, "Invalid reward and member price")
                );
                require(
                    _variants[i].priceOptions.vipPrice >
                        _variants[i].priceOptions.memberPrice,
                    getErrorMessage(37, "Invalid vipPrice and memberPrice")
                );
            }
        }
        {
            for (uint256 i = 0; i < _variants.length; i++) {
                // HASH the attributes of the product to avoid duplicate attr and have the same price
                Variant memory newVariant;
                bytes32 attributesHash = hashAttributes(_variants[i].attrs);
                newVariant.variantID = attributesHash;
                newVariant.priceOptions = _variants[i].priceOptions;
                mProductVariant[productID].push(attributesHash);
                mVariant[productID][attributesHash] = newVariant;
                // wild things happen all the time
                for (uint256 j = 0; j < _variants[i].attrs.length; j++) {
                    // tips and trick for copy
                    mVariantAttributes[productID][attributesHash].push();

                    bytes32 attrID = keccak256(abi.encode(_variants[i].attrs[j]));

                    mVariantAttributes[productID][attributesHash][j] = _variants[i].attrs[j];
                    mVariantAttributes[productID][attributesHash][j].id = attrID;
                    
                    mAttribute[attrID] = _variants[i].attrs[j];
                    mAttribute[attrID].id = attrID;
                    bool foundAttr;
                    for (uint256 m = 0; m < mCategoryAttributes[params.categoryID].length; m++){
                        if (attrID == mCategoryAttributes[params.categoryID][m]){
                            foundAttr = true;
                            break;
                        }
                    }
                    if (!foundAttr){
                        mCategoryAttributes[params.categoryID].push(attrID);
                    }
                }

                for (uint256 k = 0; k < i; k++) {
                    // 1 product have many variants
                    // 1 variants have many attributes
                    // those attributes must not be the same
                    // if a variant already have color : red, size: big
                    // another variant can't be the same, must be more or less or different
                    require(
                        mProductVariant[productID][k] != attributesHash,
                        getErrorMessage(
                            60,
                            "Duplicate variant attributes detected"
                        )
                    );
                }
            }
        }
        Product memory newProduct = Product(
            productID,
            params,
            block.timestamp,
            block.timestamp
        );
        bytes memory brand = abi.encode(params.brandName);
        if (!mBrand[brand]) {
            mBrand[brand] = true;
            brands.push(brand);
        }
        mProduct[productID] = newProduct;
        products.push(productID);
        mRetailerProduct[params.retailer].push(productID);

        mIsCorrectRetailer[params.retailer][productID] = true;
        EcomUser.sendCreateProductNotification(
            productID,
            params.isFlashSale,
            params.retailer
        );

        emit eCreateProduct(productID, params);
        return productID;
    }

    function updateProduct(
        uint256 _productID,
        createProductParams memory params,
        VariantParams[] memory _variants
    ) public onlyControllerOrRetailer returns (bool) {
        // Only controller able to call to this function
        // The retailer should be control by controller side
        // If the retailer is not correct from this product, dont allow it
        require(
            mProduct[_productID].id != 0,
            getErrorMessage(2, "Product not found")
        );

        require(
            mIsCorrectRetailer[params.retailer][_productID],
            getErrorMessage(
                44,
                "User is not the correct retailer for this product"
            )
        );

        require(
            mCategory[params.categoryID].id != 0,
            getErrorMessage(2, "Category not found")
        );

        require(
            _variants.length > 0,
            getErrorMessage(44, "Invalid variants length")
        );

        bytes32[] storage variantHashes = mProductVariant[_productID];
        for (uint256 i = 0; i < variantHashes.length; i++) {
            delete mVariant[_productID][variantHashes[i]];
            delete mVariantAttributes[_productID][variantHashes[i]];
        }
        delete mProductVariant[_productID];
        for (uint256 i = 0; i < _variants.length; i++) {
            require(
                _variants[i].priceOptions.reward <=
                    ((_variants[i].priceOptions.memberPrice * 50000) / 130) /
                        825,
                getErrorMessage(42, "Invalid reward and member price")
            );
            require(
                _variants[i].priceOptions.vipPrice >
                    _variants[i].priceOptions.memberPrice,
                getErrorMessage(37, "Invalid vipPrice and memberPrice")
            );

            Variant memory newVariant;
            bytes32 attributesHash = hashAttributes(_variants[i].attrs);
            newVariant.variantID = attributesHash;
            newVariant.priceOptions = _variants[i].priceOptions;
            mProductVariant[_productID].push(attributesHash);
            mVariant[_productID][attributesHash] = newVariant;

            for (uint256 j = 0; j < _variants[i].attrs.length; j++) {
                mVariantAttributes[_productID][attributesHash].push();
                mVariantAttributes[_productID][attributesHash][j] = _variants[i]
                    .attrs[j];
            }

            for (uint256 k = 0; k < i; k++) {
                require(
                    mProductVariant[_productID][k] != attributesHash,
                    getErrorMessage(60, "Duplicate variant attributes detected")
                );
            }
        }

        // Update product details
        mProduct[_productID].params = params;
        mProduct[_productID].updatedAt = block.timestamp;

        emit eUpdateProduct(_productID, params);
        return true;
    }

    function updateProductQuantity(
        uint256 _productID,
        bytes32 _variantID,
        uint256 updatedQuantity,
        uint256 _sold
    ) external {
        require(
            mVariant[_productID][_variantID].variantID != bytes32(0),
            getErrorMessage(51, "Invalid variantID")
        );

        mProduct[_productID].updatedAt = block.timestamp;
        mVariant[_productID][_variantID]
            .priceOptions
            .quantity = updatedQuantity;
        mProduct[_productID].params.sold += _sold;
    }

    function updateProductImages(
        uint256 _productID,
        bytes[] memory _images
    ) public onlyControllerOrRetailer returns (bool) {
        require(
            mIsCorrectRetailer[msg.sender][_productID],
            getErrorMessage(25, "You are not this product retailer")
        );
        mProduct[_productID].params.images = _images;
        return true;
    }

    function deleteProduct(
        uint256 _productID
    ) public onlyControllerOrRetailer returns (bool) {
        _deleteProduct(_productID);
        return true;
    }

    function _deleteProduct(uint256 _productID) internal {
        require(
            mProduct[_productID].id != 0,
            getErrorMessage(2, "Product not found")
        );
        address retailer = mProduct[_productID].params.retailer;

        bytes32[] storage variantHashes = mProductVariant[_productID];
        for (uint256 i = 0; i < variantHashes.length; i++) {
            delete mVariant[_productID][variantHashes[i]];
            delete mVariantAttributes[_productID][variantHashes[i]];
        }
        delete mProductVariant[_productID];
        delete mProduct[_productID];

        for (uint256 i = 0; i < products.length; i++) {
            if (products[i] == _productID) {
                products[i] = products[products.length - 1];
                products.pop();
                break;
            }
        }

        removeProductFromRetailer(retailer, _productID);

        delete mIsCorrectRetailer[retailer][_productID];

        emit eDeleteProduct(_productID);
    }

    function removeProductFromRetailer(
        address retailer,
        uint256 _productID
    ) internal {
        uint256[] storage retailerProducts = mRetailerProduct[retailer];
        for (uint256 i = 0; i < retailerProducts.length; i++) {
            if (retailerProducts[i] == _productID) {
                retailerProducts[i] = retailerProducts[
                    retailerProducts.length - 1
                ];
                retailerProducts.pop();
                break;
            }
        }
    }

    function adminAcceptProduct(
        uint256 _productID
    ) public onlyAdmin returns (bool) {
        require(
            mProduct[_productID].id != 0 &&
                !mProduct[_productID].params.isApprove,
            getErrorMessage(27, "Product does not exist or status is approved")
        );
        mProduct[_productID].params.isApprove = true;
        return true;
    }

    function adminRejectProduct(
        uint256 _productID
    ) public onlyAdmin returns (bool) {
        require(
            mProduct[_productID].id != 0 &&
                !mProduct[_productID].params.isApprove,
            getErrorMessage(27, "Product does not exist or status is approved")
        );
        _deleteProduct(_productID);
        return true;
    }

    function createCategory(
        string memory _name,
        string memory _description
    ) public onlyAdmin {
        categoryID++;
        Category memory newCategory = Category(categoryID, _name, _description);
        categories.push(categoryID);
        mCategory[categoryID] = newCategory;
        emit eCreateCategory(
            categoryID,
            newCategory.name,
            newCategory.description
        );
    }

    function editCategory(
        uint256 _id,
        string memory _name,
        string memory _description
    ) public onlyAdmin {
        require(
            mCategory[_id].id > 0,
            '{"from": "EcomProduct.sol","code": 2, "message":"Category not found"}'
        );
        mCategory[_id] = Category(_id, _name, _description);

        emit eEditCategory(_id, _name, _description);
    }

    function deleteCategory(uint256 _id) public onlyAdmin {
        for (uint256 i = 0; i < products.length; i++) {
            require(
                mProduct[products[i]].params.categoryID != _id,
                '{"from": "EcomProduct.sol","code": 4, "message":"Cannot delete category: Products still exist in this category"}'
            );
        }

        require(
            mCategory[_id].id != 0,
            '{"from": "EcomProduct.sol","code": 2, "message":"Category not found"}'
        );

        uint256 indexToDelete;
        for (uint256 i = 0; i < categories.length; i++) {
            if (_id == categories[i]) {
                indexToDelete = i;
                break;
            }
        }

        for (uint256 i = indexToDelete; i < categories.length - 1; i++) {
            categories[i] = categories[i + 1];
        }
        categories.pop();

        delete mCategory[_id];
        emit eDeleteCategory(_id);
    }

    // Purpose: This function prevent 1 product have same attributes
    // so it maybe like: Shirt, Color : Red, Size : M
    // avoid the same attribute but maybe different price
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

    function createFavorite(uint256 _productID) public {
        Product memory tempProduct = getProduct(_productID);
        require(
            !mFavorite[msg.sender][_productID],
            '{"from": "EcomProduct.sol","code": 20, "message":"user already favorite this product"}'
        );
        mFavorite[msg.sender][_productID] = true;
        mUserFavorites[msg.sender].push(Favorite(_productID, block.timestamp));

        //System activity
        EcomInfo.trackUserActivity(
            msg.sender,
            _productID,
            1,
            address(0),
            TrackActivityType.WISHLIST,
            true
        );
        //Retailer tracl activity
        EcomInfo.trackUserActivity(
            msg.sender,
            _productID,
            1,
            tempProduct.params.retailer,
            TrackActivityType.WISHLIST,
            false
        );

        EcomInfo.increaseTotalFavorite(tempProduct.params.retailer);
    }

    function createFavorites(uint256[] memory _productIds) public {
        for (uint i = 0; i < _productIds.length; i++) {
            createFavorite(_productIds[i]);
        }
    }

    function deleteFavorite(uint256 _productID) public {
        Product memory tempProduct = getProduct(_productID);
        require(
            mFavorite[msg.sender][_productID],
            '{"from": "EcomProduct.sol","code": 21, "message": "user not favorite this product"}'
        );
        delete mFavorite[msg.sender][_productID];
        bool found;
        for (uint8 i = 0; i < mUserFavorites[msg.sender].length; i++) {
            if (mUserFavorites[msg.sender][i].productID == _productID) {
                mUserFavorites[msg.sender][i] = mUserFavorites[msg.sender][
                    mUserFavorites[msg.sender].length - 1
                ];
                mUserFavorites[msg.sender].pop();
                found = true;
                break;
            }
        }

        // if (!isInCart(msg.sender, _productID)) {
        EcomInfo.removeUserActivity(msg.sender, _productID, address(0), true);
        EcomInfo.removeUserActivity(
            msg.sender,
            _productID,
            getProduct(_productID).params.retailer,
            false
        );
        // }
        EcomInfo.decreaseTotalFavorite(tempProduct.params.retailer);
        require(
            found,
            '{"from": "EcomProduct.sol","code": 24, "message": "favorite not found"}'
        );
    }

    function deleteFavorites(uint256[] memory _productIds) public {
        for (uint i = 0; i < _productIds.length; i++) {
            deleteFavorite(_productIds[i]);
        }
    }

    function createRating(
        uint256 _productID,
        uint rateValue
    ) public onlyRateFrom1To5(rateValue) returns (bool) {
        require(
            mProduct[_productID].id > 0,
            '{"from": "EcomProduct.sol","code": 3, "message": "Product not found"}'
        );
        require(
            !mUserRating[msg.sender][_productID].isRated,
            '{"from": "EcomProduct.sol","code": 27, "message": "Product already rated"}'
        );
        ratingID++;
        Rating memory newRating = Rating(
            ratingID,
            msg.sender,
            rateValue,
            block.timestamp
        );

        mRate[ratingID] = newRating;
        mProductRate[_productID].push(ratingID);
        mUserRating[msg.sender][_productID].isRated = true;
        mUserRating[msg.sender][_productID].rateValue = rateValue;
        return true;
    }

    function createRatingForRetailer(
        uint256 _productID,
        uint256 _commentID,
        uint256 _rate
    ) public onlyRateFrom1To5(_rate) returns (bool) {
        require(
            mProduct[_productID].id > 0,
            '{"from": "EcomProduct.sol","code": 3, "message": "Product not found"}'
        );

        mReviewRate[_productID][_commentID] = _rate;
        return true;
    }

    function editRating(
        uint256 _productID,
        uint256 _ratingID,
        uint rateValue
    ) public onlyRateFrom1To5(rateValue) returns (bool) {
        require(
            mRate[_ratingID].id > 0,
            '{"from": "EcomProduct.sol","code": 28, "message": "Rating does not exists"}'
        );

        require(
            mUserRating[msg.sender][_productID].isRated,
            '{"from": "EcomProduct.sol","code": 28, "message": "Not rated"}'
        );

        // Update the rating value
        mRate[_ratingID].rateValue = rateValue;
        mUserRating[msg.sender][_productID].rateValue = rateValue;

        return true;
    }

    function deleteRating(
        uint256 _productID,
        uint256 _ratingID
    ) public returns (bool) {
        require(
            mRate[_ratingID].id > 0,
            '{"from": "EcomProduct.sol","code": 28, "message": "Rating does not exist"}'
        );

        require(
            mRate[_ratingID].user == msg.sender,
            '{"from": "EcomProduct.sol","code": 29, "message": "Only the user who rated can delete"}'
        );

        require(
            mUserRating[msg.sender][_productID].isRated,
            '{"from": "EcomProduct.sol","code": 28, "message": "Not rated"}'
        );

        // Delete the rating
        delete mRate[_ratingID];
        delete mUserRating[msg.sender][_productID];
        // Remove the rating ID from mProductRate
        uint256[] storage productRatings = mProductRate[_productID];
        for (uint256 i = 0; i < productRatings.length; i++) {
            if (productRatings[i] == _ratingID) {
                productRatings[i] = productRatings[productRatings.length - 1];
                productRatings.pop();
                break;
            }
        }
        return true;
    }

    function createComment(
        uint256 _productID,
        CommentType commentType,
        string memory content,
        string memory name
    ) public returns (uint256) {
        require(
            mProduct[_productID].id > 0,
            '{"from": "EcomProduct.sol","code": 3, "message": "Product not found"}'
        );
        commentID++;
        Comment memory newComment = Comment(
            commentID,
            msg.sender,
            name,
            content,
            uint8(commentType),
            block.timestamp,
            block.timestamp,
            _productID
        );
        mCommentOfProduct[_productID].push(commentID);
        mComment[commentID] = newComment;
        {
            // length 2 because when comment, only retailer and admin receive
            address[] memory receivers = new address[](2);
            receivers[0] = mProduct[_productID].params.retailer;
            receivers[1] = owner;
            string memory productId = Strings.toString(_productID);
            EcomUser.sendMultipleNotification(
                // abi.encodePacked(_productID),
                // 0,
                string(abi.encodePacked("Customer Feedback Received!",productId)),
                "You've received new feedback about your product! Check customer feedback and respond",
                receivers,
                "CommentUpdate"
            );
        }
        EcomInfo.increaseTotalCommentAndFaq();
        return commentID;
    }

    function createComments(
        uint256 _productID,
        createCommentParams[] memory params
    ) public returns (bool) {
        for (uint i = 0; i < params.length; i++) {
            uint256 _id = createComment(
                _productID,
                params[i].commentType,
                params[i].content,
                params[i].name
            );
            if (params[i].commentType == CommentType.REVIEW) {
                createRatingForRetailer(_productID, _id, params[i].rate);
            }
        }
        return true;
    }

    function editComment(
        // uint256 _productID,
        uint256 _commentID,
        string memory content
    ) public {
        require(
            mComment[_commentID].id > 0,
            '{"from": "EcomProduct.sol","code": 29, "message":"Comment not found"}'
        );

        mComment[_commentID].message = content;
        mComment[_commentID].updatedAt = block.timestamp;
    }

    function editComments(
        // uint256 _productID,
        editCommentsParam[] memory params
    ) public onlyController {
        for (uint i = 0; i < params.length; i++) {
            // editComment(_productID, params[i].commentID, params[i].content);
                        editComment(params[i].commentID, params[i].content);

        }
    }

    function deleteComment(uint256 _productID, uint256 _commentID) public {
        require(
            mComment[_commentID].id > 0,
            '{"from": "EcomProduct.sol","code": 29, "message":"Comment not found"}'
        );

        uint256[] storage commentIds = mCommentOfProduct[_productID];
        for (uint256 i = 0; i < commentIds.length; i++) {
            if (commentIds[i] == _commentID) {
                commentIds[i] = commentIds[commentIds.length - 1];
                commentIds.pop();
                break;
            }
        }

        delete mComment[_commentID];
        EcomInfo.decreaseTotalCommentAndFaq();
    }

    function createFAQProduct(
        uint256 _productID,
        string memory _title,
        string memory _content
    ) internal returns (bool) {
        faqID++;
        require(
            mProduct[_productID].id > 0,
            '{"from": "EcomProduct.sol","code": 3, "message": "Product not found"}'
        );
        FAQ memory newFAQ = FAQ(faqID, _title, _content);
        mFAQ[faqID] = newFAQ;
        mProductFAQ[_productID].push(faqID);
        EcomInfo.increaseTotalCommentAndFaq();
        return true;
    }

    function createFAQsProduct(
        uint256 _productID,
        createFaqParams[] memory params
    ) public onlyController returns (bool) {
        for (uint i = 0; i < params.length; i++) {
            createFAQProduct(_productID, params[i].title, params[i].content);
        }
        return true;
    }

    function editFAQProduct(
        // uint256 _productID,
        uint256 _faqID,
        string memory _title,
        string memory _content
    ) internal {
        require(
            mFAQ[_faqID].id > 0,
            '{"from": "EcomProduct.sol","code": 31, "message":"FAQ not found"}'
        );
        mFAQ[_faqID].title = _title;
        mFAQ[_faqID].content = _content;
    }

    function editFAQProducts(
        // uint256 _productID,
        editFAQsProductParam[] memory params
    ) public onlyController {
        for (uint i = 0; i < params.length; i++) {
            editFAQProduct(
                // _productID,
                params[i].faqID,
                params[i].title,
                params[i].content
            );
        }
    }

    function deleteFAQProduct(
        uint256 _productID,
        uint256 _faqID
    ) public returns (bool) {
        require(mFAQ[_faqID].id > 0, "FAQ does not exist");

        // Find and remove FAQ from all product FAQ associations
        uint256[] storage faqIDs = mProductFAQ[_productID];
        for (uint256 i = 0; i < faqIDs.length; i++) {
            if (faqIDs[i] == _faqID) {
                // Remove the FAQ ID from the array
                faqIDs[i] = faqIDs[faqIDs.length - 1];
                faqIDs.pop();
                break;
            }
        }
        // Delete the FAQ
        delete mFAQ[_faqID];
        EcomInfo.decreaseTotalCommentAndFaq();
        return true;
    }

    function createFAQPO5(
        string memory title,
        string memory content
    ) public onlyAddress(owner) returns (bool) {
        faqID++;
        FAQ memory newFAQ = FAQ(faqID, title, content);
        mFAQ[faqID] = newFAQ;
        faqs.push(faqID);
        EcomInfo.increaseTotalCommentAndFaq();
        return true;
    }

    function createFAQsPO5(
        createFaqParams[] memory params
    ) public onlyAddress(owner) returns (bool) {
        for (uint i = 0; i < params.length; i++) {
            createFAQPO5(params[i].title, params[i].content);
        }

        return true;
    }

    function editFAQPO5(
        uint256 _id,
        string memory _title,
        string memory _content
    ) public onlyAddress(owner) returns (bool) {
        require(
            mFAQ[_id].id > 0,
            '{"from": "EcomProduct.sol","code": 31, "message":"FAQ not found"}'
        );
        mFAQ[_id].content = _content;
        mFAQ[_id].title = _title;

        return true;
    }

    function deleteFAQPO5(
        uint256 _id
    ) public onlyAddress(owner) returns (bool) {
        for (uint256 i = 0; i < faqs.length; i++) {
            if (faqs[i] == _id) {
                faqs[i] = faqs[faqs.length - 1];
                faqs.pop();
                break;
            }
        }

        delete mFAQ[_id];
        EcomInfo.decreaseTotalCommentAndFaq();
        return true;
    }

    // ============================================================================

    function getErrorMessage(
        uint256 code,
        string memory message
    ) public pure returns (string memory) {
        string memory codeStr = Strings.toString(code);

        return
            string(
                abi.encodePacked(
                    '{"from": "EcomProduct.sol",',
                    '"code": ',
                    codeStr,
                    ", ",
                    '"message": "',
                    message,
                    '"}'
                )
            );
    }

    function getVariant(
        uint256 _productID,
        bytes32 _variantID
    ) public view returns (Variant memory) {
        return mVariant[_productID][_variantID];
    }

    function getProduct(
        uint256 _productID
    ) public view returns (Product memory) {
        return mProduct[_productID];
    }

    function getRetailersByProductIds(
        uint256[] memory _productIds
    ) external view returns (address[] memory) {
        address[] memory retailers = new address[](_productIds.length);
        for (uint i; i < _productIds.length; i++) {
            retailers[i] = mProduct[_productIds[i]].params.retailer;
        }

        return retailers;
    }

    function getCategories() public view returns (Category[] memory) {
        uint256[] storage categoryIds = categories;
        Category[] memory res = new Category[](categoryIds.length);
        for (uint256 i = 0; i < categoryIds.length; i++) {
            res[i] = mCategory[categoryIds[i]];
        }
        return res;
    }

    function getProducts() public view returns (Product[] memory) {
        uint256[] storage productIds = products;
        Product[] memory res = new Product[](productIds.length);
        for (uint256 i = 0; i < productIds.length; i++) {
            res[i] = mProduct[productIds[i]];
        }
        return res;
    }

    function getProductInfo(
        uint256 _productId
    ) public view returns (ProductInfo memory productInfo) {
        Product memory product = mProduct[_productId];

        bytes32[] memory variantIds = mProductVariant[_productId];
        uint256 length = variantIds.length;

        Variant[] memory variants = new Variant[](length);
        Attribute[][] memory attributes = new Attribute[][](length);

        for (uint256 i = 0; i < length; i++) {
            bytes32 variantId = variantIds[i];
            variants[i] = mVariant[_productId][variantId];
            attributes[i] = mVariantAttributes[_productId][variantId];
        }

        productInfo = ProductInfo({
            product: product,
            variants: variants,
            attributes: attributes
        });
    }

    function getAllProductInfo()
        public
        view
        returns (ProductInfo[] memory productsInfo)
    {
        uint256 length = products.length;
        productsInfo = new ProductInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            productsInfo[i] = getProductInfo(products[i]);
        }
    }

    function getAllProductInfoPagination(
        getProductManagementParams memory params
    ) public view returns (ProductInfo[] memory productsInfo, bool isMore) {
        uint256 length = products.length;
        uint256 count = 0;
        ProductInfo[] memory filteredProducts = new ProductInfo[](length);
        // get het ra
        if (params._retailer != address(0)) {}

        for (uint256 i = 0; i < length; i++) {
            // filter no thoi
            bool matches = true;
            if (params._productType != EProductType.ALL) {
                // neu no ko phai all thi phai di filter
                // Check cac truong hop khong hop le, neu no ko hop le thi ko su dung
                if (
                    (params._productType == EProductType.FLASHSALE &&
                        !mProduct[products[i]].params.isFlashSale) ||
                    (params._productType == EProductType.NEWPRODUCT &&
                        mProduct[products[i]].createdAt <
                        block.timestamp - 7 days)
                ) {
                    matches = false;
                }
            }

            if (params._status != EStatus.ALL) {
                // Neu ko phai all thi filter
                // Check cac truong hop khong hop le, neu no ko hop le thi ko su dung
                if (
                    (params._status == EStatus.PENDING &&
                        mProduct[products[i]].params.isApprove) ||
                    (params._status == EStatus.APPROVE &&
                        !mProduct[products[i]].params.isApprove)
                ) {
                    matches = false;
                }
            }

            if (params._retailer != address(0)) {
                if (mProduct[products[i]].params.retailer != params._retailer) {
                    matches = false;
                }
            }
            // Filter by term (product name)
            if (bytes(params._term).length > 0) {
                if (
                    !Utils.contains(
                        params._term,
                        mProduct[products[i]].params.name
                    )
                ) {
                    matches = false;
                }
            }

            if (params._from > 0 || params._to > 0) {
                if (
                    (params._from > 0 &&
                        mProduct[products[i]].createdAt < params._from) ||
                    (params._to > 0 &&
                        mProduct[products[i]].createdAt > params._to)
                ) {
                    matches = false;
                }
            }

            if (matches) {
                filteredProducts[count] = getProductInfo(products[i]);
                count++;
            }
        }

        ProductInfo[] memory finalFilteredProducts = new ProductInfo[](count);
        for (uint256 i = 0; i < count; i++) {
            finalFilteredProducts[i] = filteredProducts[i];
        }

        bool isPriceASC = (params._price == EPrice.ASC);
        bool isDateASC = (params._datePost == EDatePost.ASC);

        finalFilteredProducts = sortProductInfo(
            finalFilteredProducts,
            isPriceASC,
            isDateASC
        );
        uint256 start = params.page * params.perPage;
        uint256 end = start + params.perPage;

        if (end > count) {
            end = count;
        }

        uint256 resultLength = end - start;
        productsInfo = new ProductInfo[](resultLength);

        for (uint256 i = start; i < end; i++) {
            productsInfo[i - start] = finalFilteredProducts[i];
        }

        isMore = end < count;
    }

    function sortProductInfo(
        ProductInfo[] memory infos,
        bool isPriceASC,
        bool isDateASC
    ) internal pure returns (ProductInfo[] memory) {
        uint256 length = infos.length;
        if (length < 2) {
            return infos;
        }
        ProductInfo memory p1;
        ProductInfo memory p2;
        ProductInfo memory temp;
        uint256 price1;
        uint256 price2;
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                bool shouldSwap = false;
                p1 = infos[j];
                p2 = infos[j + 1];

                if (isDateASC) {
                    if (p1.product.createdAt > p2.product.createdAt) {
                        shouldSwap = true;
                    }
                } else {
                    if (p1.product.createdAt < p2.product.createdAt) {
                        shouldSwap = true;
                    }
                }

                if (isPriceASC) {
                    price1 = findMinPrice(p1);
                    price2 = findMinPrice(p2);
                    if (
                        (isDateASC && price1 > price2) ||
                        (!isDateASC && price1 < price2)
                    ) {
                        shouldSwap = true;
                    }
                } else {
                    price1 = findMaxPrice(p1);
                    price2 = findMaxPrice(p2);
                    if (
                        (isDateASC && price1 < price2) ||
                        (!isDateASC && price1 > price2)
                    ) {
                        shouldSwap = true;
                    }
                }

                if (shouldSwap) {
                    temp = infos[j];
                    infos[j] = infos[j + 1];
                    infos[j + 1] = temp;
                }
            }
        }

        return infos;
    }

    function findMaxPrice(
        ProductInfo memory info
    ) internal pure returns (uint256) {
        uint256 maxPrice = 0;

        Pricing memory price;
        for (uint256 i = 0; i < info.variants.length; i++) {
            price = info.variants[i].priceOptions;
            if (price.vipPrice > maxPrice) {
                maxPrice = price.vipPrice;
            }
        }
        return maxPrice;
    }

    function findMinPrice(
        ProductInfo memory info
    ) internal pure returns (uint256) {
        uint256 minPrice = type(uint256).max;
        Pricing memory price;
        for (uint256 i = 0; i < info.variants.length; i++) {
            price = info.variants[i].priceOptions;
            if (price.vipPrice < minPrice) {
                minPrice = price.vipPrice;
            }
        }
        return minPrice;
    }

    function getAllRetailerProductInfo(
        address _retailer
    ) public view returns (ProductInfo[] memory productsInfo) {
        uint256 length = mRetailerProduct[_retailer].length;
        productsInfo = new ProductInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            productsInfo[i] = getProductInfo(mRetailerProduct[_retailer][i]);
        }
    }

    function getCategory(
        uint256 _categoryID
    ) public view returns (Category memory) {
        return mCategory[_categoryID];
    }

    function getAttributesByCategory(
        uint256 _categoryID
    ) public view returns (Attribute[] memory attrs) {
        uint256 length = mCategoryAttributes[_categoryID].length;
        attrs = new Attribute[](length);

        for (uint256 i = 0; i < length; i++) {
            attrs[i] = mAttribute[mCategoryAttributes[_categoryID][i]];
        }
    }

    function getBrands() public view returns (bytes[] memory) {
        return brands;
    }

    function getFavorite(uint256 _productID) public view returns (bool) {
        return mFavorite[msg.sender][_productID];
    }

    function getFavorites() public view returns (Favorite[] memory) {
        return mUserFavorites[msg.sender];
    }

    function getUserFavorites(
        address _user
    ) public view returns (Favorite[] memory) {
        return mUserFavorites[_user];
    }

    function getAllComments(
        uint256 _productID
    ) public view returns (Comment[] memory) {
        uint256[] storage commentIds = mCommentOfProduct[_productID];
        Comment[] memory comments = new Comment[](commentIds.length);

        for (uint256 i = 0; i < commentIds.length; i++) {
            comments[i] = mComment[commentIds[i]];
        }

        return comments;
    }

    function getComment(uint256 _id) public view returns (Comment memory) {
        return mComment[_id];
    }

    function getProductFAQ(
        uint256 _productID
    ) public view returns (FAQ[] memory) {
        uint256[] storage faqIDs = mProductFAQ[_productID];
        FAQ[] memory productFAQs = new FAQ[](faqIDs.length);

        for (uint256 i = 0; i < faqIDs.length; i++) {
            productFAQs[i] = mFAQ[faqIDs[i]];
        }

        return productFAQs;
    }

    function getPO5FAQ() public view returns (FAQ[] memory) {
        FAQ[] memory productFAQs = new FAQ[](faqs.length);

        for (uint256 i = 0; i < faqs.length; i++) {
            productFAQs[i] = mFAQ[faqs[i]];
        }

        return productFAQs;
    }

    function getProductRate(
        uint256 _productID
    ) public view returns (Rating[] memory) {
        uint256[] storage ratingIDs = mProductRate[_productID];
        Rating[] memory res = new Rating[](ratingIDs.length);

        for (uint256 i = 0; i < ratingIDs.length; i++) {
            res[i] = mRate[ratingIDs[i]];
        }

        return res;
    }

    function getUserRate(
        uint256 _productID
    ) public view returns (RateValue memory) {
        return mUserRating[msg.sender][_productID];
    }

    function getFlashSaleProduct() public view returns (Product[] memory) {
        uint256 flashSaleCount = 0;
        for (uint i; i < products.length; i++) {
            if (mProduct[products[i]].params.isFlashSale) {
                flashSaleCount++;
            }
        }

        Product[] memory flashSaleProducts = new Product[](flashSaleCount);
        uint256 flashSaleIndex = 0;
        for (uint j = 0; j < products.length; j++) {
            if (mProduct[products[j]].params.isFlashSale) {
                flashSaleProducts[flashSaleIndex] = mProduct[products[j]];
                flashSaleIndex++;
            }
        }

        return flashSaleProducts;
    }

    function getProductDetails(
        uint256 _productID
    )
        public
        view
        returns (
            Comment[] memory _comments,
            Rating[] memory _rating,
            FAQ[] memory _faqs,
            uint256[] memory _productPurchaseTrend,
            uint256[] memory _productTrend,
            uint256[] memory _rates
        )
    {
        _comments = getAllComments(_productID);
        _rates = getProductReviewRate(
            _productID,
            mCommentOfProduct[_productID]
        );
        _rating = getProductRate(_productID);
        _faqs = getProductFAQ(_productID);
        _productPurchaseTrend = EcomInfo.getProductPurchaseTrend(_productID);
        _productTrend = EcomInfo.getProductTrend(_productID);
    }

    function getProductReviewRate(
        uint256 _productID,
        uint256[] memory commentIds
    ) public view returns (uint256[] memory rates) {
        rates = new uint256[](commentIds.length);
        for (uint256 i = 0; i < commentIds.length; i++) {
            rates[i] = mReviewRate[_productID][commentIds[i]];
        }
    }

    function getRetailerProduct(
        address _retailer
    ) public view returns (Product[] memory) {
        uint256[] storage _productIds = mRetailerProduct[_retailer];
        Product[] memory res = new Product[](_productIds.length);
        for (uint256 i = 0; i < _productIds.length; i++) {
            res[i] = mProduct[_productIds[i]];
        }
        return res;
    }
    function initiatePrductDemo(address retailer,uint _categoryID)external {
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
            categoryID: _categoryID,
            description: "A sample product",
            retailPrice: 1000 * 10**6,
            vipPrice: 1200 * 10**6,
            memberPrice: 1100 * 10**6,
            reward: 10,
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
        createProduct(params, variants);
    }
}

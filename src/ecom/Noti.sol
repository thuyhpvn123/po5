// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/INoti.sol";
contract NotificationManager {
    address public owner;
    event DeviceTokenRegistered(
        address indexed dapp,
        address indexed user,
        string encryptedToken,
        uint8 platform
    );

    event NotificationSent(
        address indexed dapp,
        address indexed user,
        string title,
        string body,
        uint atTime
    );

    mapping(address => mapping(address => bool)) public mDappUserToPermission;

    mapping(address => bool) public mSystemDApps;
    address[] public systemDApps;
    mapping(address => address[]) public mUserToDApps;
    mapping(address => bool) public isAdmin;
    modifier onlyAdmin() {
        require(isAdmin[msg.sender] == true, "Only admin can perform this action");
        _;
    }

    modifier onlyAuthorizedDApp(address user) {
        require(
            mSystemDApps[msg.sender] || mDappUserToPermission[msg.sender][user],
            "DApp not authorized to send notifications"
        );
        _;
    }
    modifier onlyOwner {
        require(
           msg.sender == owner,
            "only owner"
        );
        _;
    }
    constructor() payable {
        owner = msg.sender; // Gán admin ban đầu
        isAdmin[msg.sender]= true;
    }
    function SetAdmin(address _newAdmin, bool add) external onlyOwner{
        isAdmin[_newAdmin] = add;
    }
    function addSystemDApp(address dapp) external onlyAdmin {
        mSystemDApps[dapp] = true;
        systemDApps.push(dapp);
    }

    function removeSystemDApp(address dapp) external onlyAdmin {
        mSystemDApps[dapp] = false;
        for(uint i;i<systemDApps.length;i++){
            if (dapp == systemDApps[i]){
                systemDApps[i] = systemDApps[systemDApps.length - 1];
            }
            systemDApps.pop();
        }
    }
    function getAllSystemDApps()external view returns(address[] memory){
        return systemDApps;
    }
    function registerDeviceToken(address dapp, string calldata encryptedToken,PlatformEnum _platform) external {
        mDappUserToPermission[dapp][msg.sender] = true; // Gán quyền cho DApp
        emit DeviceTokenRegistered(dapp, msg.sender, encryptedToken,uint8(_platform));
        mUserToDApps[msg.sender].push(dapp);
    }

    function revokeDAppPermission(address dapp) external {
        require(
            mDappUserToPermission[dapp][msg.sender],
            "Device token not registered for this DApp"
        );
        mDappUserToPermission[dapp][msg.sender] = false;
        address[] storage dapps = mUserToDApps[msg.sender];
        for(uint i;i<dapps.length;i++){
            if (dapp == dapps[i]){
                dapps[i] = dapps[dapps.length - 1];
            }
            dapps.pop();
        }
    }
    function getAllDAppsPermissionByUser(address _user) external view returns(address[] memory list){
        address[] storage dapps = mUserToDApps[_user];
        list = new address[](dapps.length);
        for(uint i; i< dapps.length;i++){
            list[i] = dapps[i];
        }
    }

    function AddNoti(
        NotiParams memory params,
        address _to
    ) public onlyAuthorizedDApp(_to) returns(bool) {
        emit NotificationSent(
            msg.sender, 
            _to, 
            params.title,
            params.body,
            block.timestamp
        );
        return true;
    }
      function AddMultipleNoti(
        NotiParams memory params,
        address[] memory _to
    ) external {  
        require(_to.length >0,"to list is empty");     
        for (uint i =0 ;i<_to.length;i++) {
            AddNoti(params,_to[i]);
        }
    }

}
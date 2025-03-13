// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ActiveCodeGenerator {
    function generateActiveCode() internal view returns (uint256) {
        uint256 minute = (block.timestamp / 60) % 60;
        uint256 second = block.timestamp % 60;
        uint256 compressedTime = (minute * 60) + second;
        uint256 encodedTime = (compressedTime * 9999) / 3540;
        uint256 randomPart = (uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 9000) + 1000;
        uint256 interleaved = _interleaveDigits(encodedTime, randomPart);
        uint256 checksum = _calculateChecksum(interleaved);
        return (interleaved * 10) + checksum;
    }

    function verifyChecksum(uint256 activeCode) internal pure returns (bool) {
        require(activeCode >= 100000000 && activeCode <= 999999999, "Invalid activation code format");
        uint256 checksum = activeCode % 10;
        uint256 interleaved = activeCode / 10;
        uint256 calculatedChecksum = _calculateChecksum(interleaved);
        return (checksum == calculatedChecksum);
    }

    function _interleaveDigits(uint256 encodedTime, uint256 randomPart) private pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < 4; i++) {
            uint256 timeDigit = (encodedTime / (10**i)) % 10;
            uint256 randomDigit = (randomPart / (10**i)) % 10;
            result += (randomDigit * (10**(i * 2 + 1))) + (timeDigit * (10**(i * 2)));
        }
        return result;
    }

    function _calculateChecksum(uint256 interleaved) private pure returns (uint256) {
        return _digitSum(interleaved) % 10;
    }

    function _digitSum(uint256 value) private pure returns (uint256) {
        uint256 sum = 0;
        while (value > 0) {
            sum += value % 10;
            value /= 10;
        }
        return sum;
    }
}

contract MerchantActiveCode {
    using ActiveCodeGenerator for *;
    address public owner;
    
    struct Merchant {
        string domain;
        string installUrl;
        string bundleId;
        string platform;
        uint256 createTime;
    }
    
    struct Device {
        string IP;
        string screenSize;
        string os;
        string versionOs;
        string refCode;
        uint256 activeCode;
        uint256 timestamp;
    }
    
    mapping(address => Merchant) public merchants;
    mapping(address => Device) public devices;
    mapping(uint256 => address) public activeCodeToDevice;
    mapping(string => uint256[]) private activeCodeByIP;

    
    event MerchantRegistered(address indexed merchant, string domain);
    event MerchantUpdated(address indexed merchant, string domain);
    event MerchantRemoved(address indexed merchant);
    event DeviceRegistered(address indexed device, uint256 activeCode);
    event ActiveCodeUsed(address indexed user, uint256 activeCode);
    mapping(address => bool) public isAdmin;
    modifier onlyOwner() {
        require(msg.sender == owner, "Only Owner");
        _;
    }
    modifier onlyAdmin() {
        require(isAdmin[msg.sender] == true , "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
        isAdmin[0xB50b908fFd42d2eDb12b325e75330c1AaAf35dc0] = true;
    }
    function setAdmin(address _admin)external onlyAdmin{
        isAdmin[_admin] = true;
    }
    function addMerchant(address _merchant, string memory _domain, string memory _installUrl, string memory _bundleId, string memory _platform) external onlyAdmin {
        require(merchants[_merchant].createTime == 0, "Merchant already exists");
        merchants[_merchant] = Merchant({
            domain: _domain,
            installUrl: _installUrl,
            bundleId: _bundleId,
            platform: _platform,
            createTime: block.timestamp
        });
        emit MerchantRegistered(msg.sender, _domain);
    }
    
    function updateMerchant(string memory _domain, string memory _installUrl, string memory _bundleId, string memory _platform) external {
        require(merchants[msg.sender].createTime > 0, "Merchant not found");
        merchants[msg.sender].domain = _domain;
        merchants[msg.sender].installUrl = _installUrl;
        merchants[msg.sender].bundleId = _bundleId;
        merchants[msg.sender].platform = _platform;
        emit MerchantUpdated(msg.sender, _domain);
    }
    
    function removeMerchant(address _merchant) external onlyAdmin {
        require(merchants[_merchant].createTime > 0, "Merchant not found");
        delete merchants[_merchant];
        emit MerchantRemoved(_merchant);
    }


    // 
    
    function registerDevice(string memory _IP, string memory _screenSize, string memory _os, string memory _versionOs, string memory _refCode) external returns (uint256) {
        uint256 activeCode = ActiveCodeGenerator.generateActiveCode();
        devices[msg.sender] = Device({
            IP: _IP,
            screenSize: _screenSize,
            os: _os,
            versionOs: _versionOs,
            refCode: _refCode,
            activeCode: activeCode,
            timestamp: block.timestamp
        });
        activeCodeToDevice[activeCode] = msg.sender;
        activeCodeByIP[_IP].push(activeCode);

        emit DeviceRegistered(msg.sender, activeCode);

        return activeCode;
    }
    
    function getRegisterDevice() external view returns (uint256) {
        return devices[msg.sender].activeCode;
    }
    
    function getActiveCodesByDeviceInfo(
        string memory _IP, 
        string memory _screenSize, 
        string memory _os, 
        string memory _versionOs
    ) external view returns (uint256[] memory) {
        uint256[] storage codes = activeCodeByIP[_IP];
        uint256[] memory matchingCodes = new uint256[](codes.length);
        uint256 count = 0;

        for (uint256 i = 0; i < codes.length; i++) {
            address deviceOwner = activeCodeToDevice[codes[i]];
            Device storage deviceInfo = devices[deviceOwner];

            // So sánh trực tiếp screenSize, os, versionOs
            if (
                compareStrings(deviceInfo.screenSize, _screenSize) &&
                compareStrings(deviceInfo.os, _os) &&
                compareStrings(deviceInfo.versionOs, _versionOs)
            ) {
                matchingCodes[count] = codes[i];
                count++;
            }
        }

        // Cắt mảng kết quả để chỉ lấy đúng số lượng hợp lệ
        assembly {
            mstore(matchingCodes, count)
        }

        return matchingCodes;
    }

    // Hàm so sánh chuỗi đơn giản
    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        bytes memory aBytes = bytes(a);
        bytes memory bBytes = bytes(b);

        if (aBytes.length != bBytes.length) {
            return false;
        }

        for (uint256 i = 0; i < aBytes.length; i++) {
            if (aBytes[i] != bBytes[i]) {
                return false;
            }
        }

        return true;
        // return (bytes(a).length == bytes(b).length) && (keccak256(bytes(a)) == keccak256(bytes(b)));
    }

    function getActiveCodeInfo(uint256 _activeCode) external view returns (Merchant memory, Device memory) {

        // check active Code
        require(ActiveCodeGenerator.verifyChecksum(_activeCode), "Active code not exists");
        
        address deviceOwner = activeCodeToDevice[_activeCode];
        require(deviceOwner != address(0), "Active code not found");
        return (merchants[deviceOwner], devices[deviceOwner]);
    }

    
    function useActiveCodeInfo(uint256 _activeCode) external {

        // check active Code
        require(ActiveCodeGenerator.verifyChecksum(_activeCode), "Active code not exists");

        address deviceOwner = activeCodeToDevice[_activeCode];
        require(deviceOwner != address(0), "Active code not found");

        string memory ip = devices[deviceOwner].IP;

        // Xoá activeCode khỏi danh sách theo IP
        uint256[] storage codes = activeCodeByIP[ip];
        for (uint256 i = 0; i < codes.length; i++) {
            if (codes[i] == _activeCode) {
                codes[i] = codes[codes.length - 1]; // Thay thế bằng phần tử cuối cùng
                codes.pop(); // Xoá phần tử cuối
                break;
            }
        }
        
        delete devices[deviceOwner];
        delete activeCodeToDevice[_activeCode];
        emit ActiveCodeUsed(deviceOwner, _activeCode);
    }
    
    function removeExpiredData() external onlyAdmin {
        address deviceOwner = msg.sender;
        if (block.timestamp - devices[deviceOwner].timestamp > 15 minutes) {
            delete devices[deviceOwner];
        }
    }
}

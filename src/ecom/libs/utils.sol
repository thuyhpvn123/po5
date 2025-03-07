// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Utils {
    /// @dev Checks if a substring exists within a given string.
    /// @param what The substring to search for.
    /// @param where The string to search within.
    /// @return bool True if the substring is found, false otherwise.
    function contains(
        string memory what,
        string memory where
    ) internal pure returns (bool) {
        bytes memory whatBytes = bytes(what);
        bytes memory whereBytes = bytes(where);

        require(whereBytes.length >= whatBytes.length);

        bool found = false;
        for (uint i = 0; i <= whereBytes.length - whatBytes.length; i++) {
            bool flag = true;
            for (uint j = 0; j < whatBytes.length; j++)
                if (
                    toLowerCase(whereBytes[i + j]) != toLowerCase(whatBytes[j])
                ) {
                    flag = false;
                    break;
                }
            if (flag) {
                found = true;
                break;
            }
        }
        return found;
    }

    function toLowerCase(bytes1 _b) internal pure returns (bytes1) {
        if (uint8(_b) >= 65 && uint8(_b) <= 90) {
            return bytes1(uint8(_b) + 32);
        }
        return _b;
    }

    /**
     * @dev Returns true if the two strings are equal.
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol
     */
    function equal(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return
            bytes(a).length == bytes(b).length &&
            keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

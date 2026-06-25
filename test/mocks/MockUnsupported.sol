// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC165 } from "@openzeppelin/interfaces/IERC165.sol";

contract MockUnsupported is IERC165 {
    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockNoDataReverter {
  fallback() external payable {
    assembly {
      revert(0, 0)
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error Unauthorized();
error PriceNotMet(string , uint256 amount);
error NotUniqueAddress(address sender);
error totalSupplyExceeded(string);
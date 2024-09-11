// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error Unauthorized();
error PriceNotMet(uint256 councilMintPrice,uint256 publicMintPrice, uint256 amount);
error NotUniqueAddress(address sender);
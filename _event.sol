// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

event PepitoCouncilMintStarted(uint256 indexed expiration, uint256 mintPrice);
event PriceUpdated(uint256 time, uint256 indexed councilMintPrice, uint256 indexed publicMintPrice);
event teamUpdated(address[3] team);
event metadataChanged(bytes);
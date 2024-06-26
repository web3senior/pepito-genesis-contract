// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./_pausable.sol";
import "./_event.sol";
import "./_error.sol";

/// @title Pepito Genesis 🐸
/// @author Aratta Labs
/// @notice Pepito Genesis Contract
/// @dev You will find the deployed contract addresses in the README.md file
/// @custom:security-contact atenyun@gmail.com
contract PepitoGenesis is LSP8IdentifiableDigitalAsset("Pepito Genesis", "PEP", msg.sender, 2, 0), Pausable {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;

    uint256 public constant MAX_SUPPLY = 2424;
    mapping(string => uint256) public price;
    address public pepito_vault;
    address[3] public team;
    uint256 public councilMintExpiration;
    uint8 vaultPercentage;
    bytes public rawMetadata;
    uint256 public teamMintCounter = 0;

    struct MintPool {
        address sender;
        bytes32 tokenId;
        uint256 dt;
        string referral;
    }

    MintPool[] public mintPool;

    constructor() {
        //address[3] memory _team
        // Initial metadata
        rawMetadata = unicode'{"LSP4Metadata":{"name":"PEPITO GENESIS","description":"Mint your PEPITO GENESIS NFT today to join us on an adventure into the world of PEPITO, 2424 PEPITO Spawn looking for a home. For more information check out our roadmap displayed on https://pepitolyx.com and anything else drop us a message on either CG or Twitter.","links":[{"title":"Website","url":"https://pepitolyx.com"},{"title":"Mint","url":"https://genesis.pepitolyx.com"},{"title":"Common Ground","url":"https://app.cg/c/Pepito"},{"title":"𝕏","url":"https://x.com/pepitolyx"},{"title":"Telegram","url":"https://t.me/pepitolyx"}],"attributes":[{"key":"Stage","value":"0"},{"key":"Type","value":"Spawn"},{"key":"Background","value":""},{"key":"Skin","value":""},{"key":"Eyes","value":""},{"key":"Tattoos","value":""},{"key":"Clothes","value":""},{"key":"Headgear","value":""},{"key":"Accessory","value":""}],"icon":[{"width":512,"height":512,"url":"ipfs://QmdrcEfQnWZhisc2bF4544xdJGHBQhWLaoGBXZSvrvSTxT","verification":{"method":"keccak256(bytes)","data":"0xeb14faa594192b57a2c4edb6ae212c1a6b3848409176e7c900141132d9902c85"}}],"backgroundImage":[],"assets":[],"images":[[{"width":500,"height":500,"url":"ipfs://QmY8Z5yaoSsTY8DnpcqryJSjt4s1ehktCtJd2pKAwv4JsW","verification":{"method":"keccak256(bytes)","data":"0x0f7ea5085e1ce038e3f51f97fa25434262b9d5808b1faf24bb41d6a289a92b20"}}]]}}';

        // Expire in 24h (10% discount)
        price["council_mint"] = 1.9 ether;
        price["public_mint"] = 2.11 ether;

        // Add vault percentage
        vaultPercentage = 40;

        team = [0xd64Deb40240209473f676945c2ed2bfA2CeF2B7d,0x41be92E41B9d8E320330bad6607168aDB833fcD5,0x0D5C8B7cC12eD8486E1E0147CC0c3395739F138d];
        pepito_vault = 0xC99Be60cC96631E9BEF68b7C68Fb7124E62F3EDF;

        // Set the council mint expiration
        councilMintExpiration = block.timestamp + 1 days;
        emit PepitoCouncilMintStarted((block.timestamp + 1 days), price["council_mint"]);
    }

    function getMetadata() public view returns (bytes memory) {
        bytes memory verfiableURI = bytes.concat(hex"00006f357c6a0020", keccak256(rawMetadata), abi.encodePacked("data:application/json;base64,", Base64.encode(rawMetadata)));
        return verfiableURI;
    }

    ///@notice Retrieve the mint price
    function getCurrentPrice() public view returns (uint256) {
        return (councilMintExpiration > block.timestamp) ? price["council_mint"] : price["public_mint"];
    }

    ///@notice Update metadata
    function updateMetadata(bytes memory _metadata) public onlyOwner {
        rawMetadata = _metadata;

        if (mintPool.length > 0) {
            for (uint256 i = 1; i < mintPool.length; i++) {
                // Update LSP8 metadata
                _setDataForTokenId(mintPool[i - 1].tokenId, 0x9afb95cacc9f95858ec44aa8c3b685511002e30ae54415823f406128b85b238e, getMetadata());
            }
            emit metadataChanged(_metadata);
        }
    }

    /// @notice Update the mint price
    function updatePrice(uint256 _councilPrice, uint256 _publicPrice) public onlyOwner {
        price["council_mint"] = _councilPrice;
        price["public_mint"] = _publicPrice;

        emit PriceUpdated(block.timestamp, _councilPrice, _publicPrice);
    }

    // Update team wallet addresses
    function updateTeam(address[3] memory _team) public onlyOwner {
        team = _team;
        emit teamUpdated(_team);
    }

    ///@notice Public Mint
    function handleMint(uint256 _count, string memory _referral) public payable whenNotPaused returns (bytes32[] memory tokenId) {
        if (totalSupply() + 1 > MAX_SUPPLY) revert SupplyingLimitExceeded(totalSupply(), MAX_SUPPLY);

        // Check council mint expiration
        if (msg.value < ((councilMintExpiration > block.timestamp) ? price["council_mint"] * _count : price["public_mint"] * _count)) revert PriceNotMet(price["council_mint"], price["public_mint"], msg.value);

        bytes32[] memory tokenIds = new bytes32[](_count);

        for (uint256 i = 0; i < _count; i++) {
            _tokenIdCounter.increment();
            bytes32 _tokenId = bytes32(_tokenIdCounter.current());
            _mint({to: msg.sender, tokenId: _tokenId, force: true, data: ""});

            // Set LSP8 metadata
            _setDataForTokenId(_tokenId, 0x9afb95cacc9f95858ec44aa8c3b685511002e30ae54415823f406128b85b238e, getMetadata());

            // Add user to the minter pool
            mintPool.push(MintPool(msg.sender, _tokenId, block.timestamp, _referral));

            tokenIds[i] = _tokenId;
        }

        // Distribute the mint price between the team & vault
        uint256 vaultAmount = calcPercentage(msg.value, vaultPercentage);
        (bool success, ) = pepito_vault.call{value: vaultAmount}("");
        require(success, "Failed to send Ether to Pepito vault");

        uint256 teamAmount = calcPercentage(msg.value, 20);
        (bool success1, ) = team[0].call{value: teamAmount}("");
        require(success1, "Failed to send Ether to team 0");

        (bool success2, ) = team[1].call{value: teamAmount}("");
        require(success2, "Failed to send Ether to team 1");

        (bool success3, ) = team[2].call{value: teamAmount}("");
        require(success3, "Failed to send Ether to team 2");

        return tokenIds;
    }

    ///@notice Team Mint
    function teamMint(address[] memory _to, string memory _referral) public whenNotPaused onlyOwner returns (bytes32[] memory tokenId) {
        if (totalSupply() + 1 > MAX_SUPPLY) revert SupplyingLimitExceeded(totalSupply(), MAX_SUPPLY);
        if (teamMintCounter >= 222) revert TeamMintExceeded(teamMintCounter, 222);

        bytes32[] memory tokenIds = new bytes32[](_to.length);
        for (uint256 i = 0; i < _to.length; i++) {
            _tokenIdCounter.increment();
            bytes32 _tokenId = bytes32(_tokenIdCounter.current());
            _mint({to: _to[i], tokenId: _tokenId, force: true, data: ""});

            // Set LSP8 metadata
            _setDataForTokenId(_tokenId, 0x9afb95cacc9f95858ec44aa8c3b685511002e30ae54415823f406128b85b238e, getMetadata());

            // Add user to the minter pool
            mintPool.push(MintPool(_to[i], _tokenId, block.timestamp, _referral));

            tokenIds[i] = _tokenId;

            teamMintCounter++;
        }

        return tokenIds;
    }

    ///@notice Calculate percentage
    ///@param amount The total amount
    ///@param bps The precentage
    ///@return percentage
    function calcPercentage(uint256 amount, uint256 bps) public pure returns (uint256) {
        require((amount * bps) >= 100);
        return (amount * bps) / 100;
    }

    ///@notice Withdraw the balance from this contract to the owner's address
    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Failed");
    }

    ///@notice Transfer balance from this contract to input address
    function transferBalance(address payable _to, uint256 _amount) public onlyOwner {
        // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed");
    }

    /// @notice Return the balance of this contract
    function getBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    /// @notice Pause mint
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpause mint
    function unpause() public onlyOwner {
        _unpause();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {_LSP4_TOKEN_TYPE_TOKEN, _LSP4_TOKEN_TYPE_COLLECTION, _LSP4_METADATA_KEY} from "@lukso/lsp4-contracts/contracts/LSP4Constants.sol";
import {ILSP8IdentifiableDigitalAsset as ILSP8} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/ILSP8IdentifiableDigitalAsset.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import "./_event.sol";
import "./_error.sol";
import {CONTRACT_STAGE2} from "./_constant.sol";
import "./_pausable.sol";

/// @title Pepito Genesis
/// @author Aratta Labs
/// @notice Pepito Genesis stage 2-3
/// @dev You will find the deployed contract addresses in the repo
/// @custom:emoji 🐸
/// @custom:security-contact atenyun@gmail.com
contract PepitoGenesis is LSP8IdentifiableDigitalAsset("Pepitoverse", "PVS", msg.sender, _LSP4_TOKEN_TYPE_COLLECTION, _LSP4_TOKEN_TYPE_TOKEN), Pausable {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;
    Counters.Counter public _shopCounter;
    mapping(string => address) public wallet;
    ILSP8 GENESIS_CONTRACT_STAGE2 = ILSP8(CONTRACT_STAGE2);

    struct PepitoversePool {
        address sender;
        bytes32 tokenId;
        uint256 dt;
    }

    PepitoversePool[] public pepitoversePool;

    struct shopStruct {
        string name;
        string trait;
        uint256 price;
        uint8 maxSupply;
        uint8 totalSupply;
        string metadata;
    }

    struct shopListStruct {
        bytes32 id;
        string name;
        string trait;
        uint256 price;
        uint8 maxSupply;
        uint8 totalSupply;
        string metadata;
    }

    mapping(bytes32 => shopStruct) public shop;

    constructor() {
        // Add default wallet addresses
        wallet["jxn"] = 0xd64Deb40240209473f676945c2ed2bfA2CeF2B7d;
        wallet["punk"] = 0x41be92E41B9d8E320330bad6607168aDB833fcD5;
        wallet["amir"] = 0x0D5C8B7cC12eD8486E1E0147CC0c3395739F138d;
        wallet["council"] = 0x88b7A1a6d3Fd946Af18fEdB11EEffb6322eb79E2;
        wallet["buyback"] = 0x4aCabF64AeF8ca056D35367BCaFa1cD78a17Bf1C;
    }

    /// @notice Generate verifiable metdata for LSP8 standard
    function getMetadata(string memory _rawMetadata) public pure returns (bytes memory) {
        bytes memory verfiableURI = bytes.concat(hex"00006f357c6a0020", keccak256(bytes(_rawMetadata)), abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(_rawMetadata))));
        return verfiableURI;
    }

    /// @notice Update wallet
    function updateWallet(string memory _name, address _wallet) public onlyOwner {
        wallet[_name] = _wallet;

        // Log price updated
        emit WalletUpdate(_name, _wallet, block.timestamp);
    }

    /// @notice Add shop
    function addShop(
        string memory _name,
        string memory _trait,
        uint256 _price,
        uint8 _maxSupply,
        string memory _metadata
    ) public onlyOwner returns (bytes32) {
        _shopCounter.increment();
        shop[bytes32(_shopCounter.current())] = shopStruct(_name, _trait, _price, _maxSupply, 0, _metadata);
        return bytes32(_shopCounter.current());
    }

    /// @notice Update shop
    function updateShop(
        bytes32 _shopId,
        string memory _name,
        string memory _trait,
        uint256 _price,
        uint8 _maxSupply,
        string memory _metadata
    ) public onlyOwner {
        shop[_shopId].name = _name;
        shop[_shopId].trait = _trait;
        shop[_shopId].price = _price;
        shop[_shopId].maxSupply = _maxSupply;
        shop[_shopId].metadata = _metadata;
    }

    /// @notice Get shop items
    function getShopList() public view returns (shopListStruct[] memory) {
        uint256 totaShop = _shopCounter.current();
        shopListStruct[] memory result = new shopListStruct[](totaShop);

        for (uint256 i = 0; i < totaShop; i++) {
            bytes32 itemId = bytes32(i + 1);
            result[i] = shopListStruct(itemId, shop[itemId].name, shop[itemId].trait, shop[itemId].price, shop[itemId].maxSupply, shop[itemId].totalSupply, shop[itemId].metadata);
        }

        return result;
    }

    ///@notice Metamorphosis Evolve
    function ShopEvolve(
        bytes32 _shopId,
        bytes32 _tokenId,
        string memory _rawMetadata
    ) public payable whenNotPaused returns (bytes32) {
        if (tokenOwnerOf(_tokenId) != _msgSender()) revert Unauthorized();
        if (msg.value < shop[_shopId].price) revert PriceNotMet(shop[_shopId].name, msg.value);
        if (shop[_shopId].totalSupply == shop[_shopId].maxSupply) revert totalSupplyExceeded(shop[_shopId].name);

        // Set token's metadata
        _setDataForTokenId(_tokenId, _LSP4_METADATA_KEY, getMetadata(_rawMetadata));

        shop[_shopId].totalSupply = shop[_shopId].totalSupply + 1;

        // Transfer $
        (bool success1, ) = wallet["jxn"].call{value: calcPercentage(msg.value, 23)}("");
        require(success1, "Failed to send Ether");
        (bool success2, ) = wallet["punk"].call{value: calcPercentage(msg.value, 23)}("");
        require(success2, "Failed to send Ether");
        (bool success3, ) = wallet["amir"].call{value: calcPercentage(msg.value, 23)}("");
        require(success3, "Failed to send Ether");
        (bool success4, ) = wallet["council"].call{value: calcPercentage(msg.value, 25)}("");
        require(success4, "Failed to send Ether");
        (bool success5, ) = wallet["buyback"].call{value: calcPercentage(msg.value, 6)}("");
        require(success5, "Failed to send Ether");

        // Return the last token's id
        return _tokenId;
    }

    ///@notice calcPercentage percentage
    ///@param amount The total amount
    ///@param bps The precentage
    ///@return percentage
    function calcPercentage(uint256 amount, uint256 bps) public pure returns (uint256) {
        require((amount * bps) >= 100);
        return (amount * bps) / 100;
    }

    ///@notice Metamorphosis Evolve
    function MetamorphosisEvolve(bytes32 _tokenId, string memory _rawMetadata) public whenNotPaused returns (bytes32) {
        if (GENESIS_CONTRACT_STAGE2.tokenOwnerOf(_tokenId) != _msgSender()) revert Unauthorized();

        // Burn the entered token id by sending to address(1) - Metamorphosis 🐸
        GENESIS_CONTRACT_STAGE2.transfer(_msgSender(), address(1), _tokenId, true, "");

        // Mint a new token - Anuran
        _tokenIdCounter.increment();
        bytes32 newTokenId = bytes32(_tokenIdCounter.current());
        _mint({to: _msgSender(), tokenId: newTokenId, force: true, data: ""});

        // Set token's metadata
        _setDataForTokenId(newTokenId, _LSP4_METADATA_KEY, getMetadata(_rawMetadata));

        // Add user to the evolution pool
        pepitoversePool.push(PepitoversePool(_msgSender(), _tokenId, block.timestamp));

        // Return the last token's id
        return newTokenId;
    }

    function getTokenOperator(bytes32 _tokenId) public view returns (address[] memory) {
        return GENESIS_CONTRACT_STAGE2.getOperatorsOf(_tokenId);
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

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VoucherIncubator is ERC721Enumerable, Ownable {
    struct IncubatorVoucher {
        uint256 tokenID;
        uint256 redeemableEggs;
        uint256 IssuanceDate;
        bool premintPaid;
    }

    string voucherArt = "ipfs://QmavoG8o8mXwYJFNJY3fbDD4b3uXUdSu7V2WvPG8r35y36";

    address public EGGCONTRACT;

    constructor(address _initEGGCONTRACT)
        ERC721("Oneverse Incubator Vouchers", "OV-INCUB")
    {
        EGGCONTRACT = _initEGGCONTRACT;
    }

    IncubatorVoucher[] public VoucherList;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    bool public premintEnabled = false;
    uint256 premintPrice = 100e18;

    event newVoucherMinted(
        address indexed newVoucherHolder,
        uint256 indexed amountofRedeemableEggs
    );

    function changeEggContract(address _newEggContractAddress)
        external
        onlyOwner
    {
        EGGCONTRACT = _newEggContractAddress;
    }

    function enablePremint() external onlyOwner {
        premintEnabled = true;
    }

    function changeArt(string memory _newLinkvoucherArt) external onlyOwner {
        voucherArt = _newLinkvoucherArt;
    }

    function withdrawErc20(IERC20 token) external onlyOwner {
        require(
            token.transfer(msg.sender, token.balanceOf(address(this))),
            "Transfer failed"
        );
    }

    function mintVoucherNFT(uint256 _amountOfTickets, address _receiver)
        internal
    {
        uint256 newItemId = _tokenIds.current();

        for (uint256 i = 0; i < _amountOfTickets; i++) {
            _safeMint(_receiver, newItemId);

            _tokenIds.increment();
            newItemId = _tokenIds.current();

            VoucherList.push(
                IncubatorVoucher(newItemId, 1, block.timestamp, false)
            );
        }
    }

    function giveVoucherIncubator(uint256 _amountOfTickets, address _receiver)
        external
    {
        require(msg.sender == EGGCONTRACT, "Not the Egg Contract Calling!");
        mintVoucherNFT(_amountOfTickets, _receiver);
    }

    function mintVoucherNFT(uint256 _amountOfTickets) external onlyOwner {
        uint256 newItemId = _tokenIds.current();

        for (uint256 i = 0; i < _amountOfTickets; i++) {
            _safeMint(msg.sender, newItemId);

            _tokenIds.increment();
            newItemId = _tokenIds.current();

            VoucherList.push(
                IncubatorVoucher(newItemId, 1, block.timestamp, false)
            );
        }
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        IncubatorVoucher memory VoucherAttributes = VoucherList[_tokenId];

        string memory eggsRedeemable = Strings.toString(
            VoucherAttributes.redeemableEggs
        );

        string memory title;
        string memory picture = voucherArt;
        string memory dateofcreation = Strings.toString(
            VoucherAttributes.IssuanceDate
        );

        string memory premintstatus = "no";

        title = "Egg Incubator Voucher";

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        title,
                        " #: ",
                        Strings.toString(_tokenId),
                        '", "description": "Redeemable for an Incubator!", "image": "',
                        picture,
                        '", "attributes": [ { "trait_type": "Incubators Redeemable", "value": ',
                        eggsRedeemable,
                        '}, { "display_type" : "Date" ,"trait_type": "Issuance Date", "value": ',
                        dateofcreation,
                        '}, { "trait_type": "Redeemed", "value": ',
                        '"',
                        premintstatus,
                        '"',
                        "} ]}"
                    )
                )
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }
}

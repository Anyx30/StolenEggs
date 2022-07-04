// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WhitelistVoucher is ERC721Enumerable, Ownable {
    IERC20 GravToken;
    struct EggVoucher {
        uint256 tokenID;
        uint256 redeemableEggs;
        uint256 IssuanceDate;
        bool premintPaid;
    }

    string oneEggArt = "ipfs://QmavoG8o8mXwYJFNJY3fbDD4b3uXUdSu7V2WvPG8r35y36";
    string threeEggArt =
        "ipfs://QmYDEt18Pgdyorac1vCccrcjvsAHWETwsswrE2G3ea3E5Y";
    string fiveEggArt = "ipfs://QmT7K6rKtnH1ZFEZKdVeUce16LZ8sSEYXGmyro2EuZFdjg";

    string paid_oneEggArt =
        "ipfs://QmfQzbHA3bGGM4vQE52yRw87tDaP5CAyJb1uXyyyqnfWjt";
    string paid_threeEggArt =
        "ipfs://QmbK5y4y8a8Qw1Zow6PGuDRPAr4UGQR3JQEL4nYWLGvBay";
    string paid_fiveEggArt =
        "ipfs://QmdHkBG39uZcqfKn31aQUHeYh1kx3R396VpE5x26NUoR9D";

    constructor(address _gravTokenAddress)
        ERC721("Oneverse Egg Vouchers", "OV-EGG")
    {
        GravToken = IERC20(_gravTokenAddress);
    }

    EggVoucher[] public VoucherList;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    bool public premintEnabled = false;
    uint256 premintPrice = 100e18;

    event newVoucherMinted(
        address indexed newVoucherHolder,
        uint256 indexed amountofRedeemableEggs
    );

    function enablePremint() external onlyOwner {
        premintEnabled = true;
    }

    function changeArt(
        bool _paid,
        string memory _newLinkOneEgg,
        string memory _newLinkThreeEgg,
        string memory _newLinkFiveEgg
    ) external onlyOwner {
        if (_paid) {
            paid_oneEggArt = _newLinkOneEgg;
            paid_threeEggArt = _newLinkThreeEgg;
            paid_fiveEggArt = _newLinkFiveEgg;
        } else {
            oneEggArt = _newLinkOneEgg;
            threeEggArt = _newLinkThreeEgg;
            fiveEggArt = _newLinkFiveEgg;
        }
    }

    function changeMintingPrice(uint256 _newPremintPrice) external onlyOwner {
        premintPrice = _newPremintPrice;
    }

    function withdrawErc20(IERC20 token) external onlyOwner {
        require(
            token.transfer(msg.sender, token.balanceOf(address(this))),
            "Transfer failed"
        );
    }

    function mintWhitelistVoucherNFT(
        uint256 _voucherSize,
        uint256 _amountOfTickets
    ) external  {
        uint256 newItemId = _tokenIds.current();

        for (uint256 i = 0; i < _amountOfTickets; i++) {
            _safeMint(msg.sender, newItemId);

            _tokenIds.increment();
            newItemId = _tokenIds.current();

            VoucherList.push(
                EggVoucher(newItemId, _voucherSize, block.timestamp, false)
            );

            emit newVoucherMinted(msg.sender, _voucherSize);
        }
    }

    function checkRedeemableEggs(uint256 _tokenId)
        external
        view
        returns (uint256)
    {
        return VoucherList[_tokenId].redeemableEggs;
    }

    function checkIfPreminted(uint256 _tokenId) external view returns (bool) {
        return VoucherList[_tokenId].premintPaid;
    }

    //@TODO Frontend approveTokenTransfer

    function premint(uint256[] calldata _tokenID) external {
        require(premintEnabled, "premint isnt enabled yet, come back later");
        for (uint256 i = 0; i < _tokenID.length; i++) {
            require(
                ownerOf(_tokenID[i]) == msg.sender,
                "You dont own that Voucher!"
            );
            uint256 price = VoucherList[_tokenID[i]].redeemableEggs *
                premintPrice;

            require(
                GravToken.transferFrom(msg.sender, address(this), price),
                "Not Enough Tokens!"
            );

            VoucherList[_tokenID[i]].premintPaid = true;
        }
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        EggVoucher memory VoucherAttributes = VoucherList[_tokenId];

        string memory eggsRedeemable = Strings.toString(
            VoucherAttributes.redeemableEggs
        );

        string memory title;
        string memory picture;
        string memory dateofcreation = Strings.toString(
            VoucherAttributes.IssuanceDate
        );

        string memory premintstatus;
        if (VoucherAttributes.premintPaid) {
            premintstatus = "yes";
        } else {
            premintstatus = "no";
        }

        //@TODO add new art from Kledson if preminted.
        if (VoucherAttributes.premintPaid) {
            if (VoucherAttributes.redeemableEggs == 1) {
                title = "Tier One Voucher Ticket";
                picture = paid_oneEggArt;
            } else if (VoucherAttributes.redeemableEggs == 3) {
                title = "Tier Two Voucher Ticket";
                picture = paid_threeEggArt;
            } else if (VoucherAttributes.redeemableEggs == 5) {
                title = "Tier Three Voucher Ticket";
                picture = paid_fiveEggArt;
            }
        } else {
            if (VoucherAttributes.redeemableEggs == 1) {
                title = "Tier One Voucher Ticket";
                picture = oneEggArt;
            } else if (VoucherAttributes.redeemableEggs == 3) {
                title = "Tier Two Voucher Ticket";
                picture = threeEggArt;
            } else if (VoucherAttributes.redeemableEggs == 5) {
                title = "Tier Three Voucher Ticket";
                picture = fiveEggArt;
            }
        }

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        title,
                        " #: ",
                        Strings.toString(_tokenId),
                        '", "description": "Redeemable for Eggs!", "image": "',
                        picture,
                        '", "attributes": [ { "trait_type": "Eggs Redeemable", "value": ',
                        eggsRedeemable,
                        '}, { "display_type" : "Date" ,"trait_type": "Issuance Date", "value": ',
                        dateofcreation,
                        '}, { "trait_type": "Preminted", "value": ',
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

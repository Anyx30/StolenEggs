//SPDX-License-Identifier: UNLICENSED

/// @title SpaceBank P2P Escrow Contract
/// @author Ace (EzTools)
/// @notice P2P Escrow contract for ERC20,ERC721 and ERC1155 Trade

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "hardhat/console.sol";

contract SpaceBankEscrow is Ownable,ReentrancyGuard,ERC1155Holder{

    IERC20 GSM;
    IERC20 xGSM;

    struct NFTItem{
        address[] _contract;
        uint[] tokenId;
    }

    struct TokenItem{
        address[] _contract;
        uint[] tokenAmount;
    }

    struct MultiItem{
        address[] _contract;
        uint[] tokenId;
        uint[] tokenAmount;
    }

    struct Items{
        NFTItem NFTItems;
        TokenItem TokenItems;
        MultiItem MultiItems;
    }

    struct Partner{
        address recepientAddress;
        uint sharePercent;
        uint gsmBalance;
        uint xgsmBalance;
        uint nativeBalance;
    }

    struct EscrowItem{
        address party1;
        address party2;
        NFTItem selfItem0;
        TokenItem selfItem1;
        MultiItem selfItem2;
        NFTItem offeredItems0;
        TokenItem offeredItems1;
        MultiItem offeredItems2;
        uint[3] feeCollected;
    }

    uint[3] Fees = [10 ether,10 ether,10 ether]; //ONE, GSM, xGSM

    mapping(uint=>EscrowItem) public idToTrade;
    mapping(uint=>uint[2]) public tradePosition;
    mapping(address=>uint[]) public userTrades;
    mapping(address=>Partner) public partnerMapping;

    uint public tradeId;

    uint public GSMFeeCollected;
    uint public xGSMFeeCollected;
    uint public nativeFeeCollected;

    constructor(address _gsm, address _xgsm) {
        GSM = IERC20(_gsm);
        xGSM = IERC20(_xgsm);
    }

    function initiateTrade(Items memory items0, Items memory items1, address party2, uint8 feeChoice) external payable{
        require(party2 != address(0),"Party2 can't be 0 address");
        uint[3] memory userLength = [items0.NFTItems._contract.length,items0.TokenItems._contract.length,items0.MultiItems._contract.length];
        uint[3] memory buyerLength = [items1.NFTItems._contract.length,items1.TokenItems._contract.length,items1.MultiItems._contract.length];

        require(sum(userLength) > 0,"No items offered");
        require(sum(buyerLength) > 0,"No items asked");
        require(verify(items0),"Length mismatch");
        require(verify(items1),"Length mismatch");

        uint totalUser = sum(userLength) + sum(buyerLength);

        uint[3] memory _feePaid = payFees(totalUser, msg.value,feeChoice);

        tradeId++;

        transferItems(items0, msg.sender, address(this));        

        idToTrade[tradeId] = EscrowItem(msg.sender,party2,items0.NFTItems,items0.TokenItems,items0.MultiItems,items1.NFTItems,items1.TokenItems,items1.MultiItems,_feePaid);
        tradePosition[tradeId] = [userTrades[msg.sender].length,userTrades[party2].length];
        userTrades[msg.sender].push(tradeId);
        userTrades[party2].push(tradeId);

    }

    function acceptTrade(uint _tradeId,uint8 feeChoice) external payable{
        EscrowItem storage Item = idToTrade[_tradeId];
        require(msg.sender == Item.party2,"Not designated party");

        uint[3] memory userLength = [Item.selfItem0._contract.length,Item.selfItem1._contract.length,Item.selfItem2._contract.length];
        uint[3] memory buyerLength = [Item.offeredItems0._contract.length,Item.offeredItems1._contract.length,Item.offeredItems2._contract.length];

        uint[3] memory fee = payFees(sum(userLength) + sum(buyerLength), msg.value, feeChoice);

        //@dev Transfer items
        transferItems(Items(Item.offeredItems0,Item.offeredItems1,Item.offeredItems2), msg.sender, Item.party1);
        transferItems(Items(Item.selfItem0,Item.selfItem1,Item.selfItem2), address(this), msg.sender);

        //@dev add fees 
        addToFees(Item.feeCollected,_tradeId,true);
        addToFees(fee,_tradeId,false);

        //@dev remove trades
        popTrade(_tradeId);
        delete idToTrade[_tradeId];
    } 

    function rejectOrCancelTrade(uint _tradeId) external nonReentrant{
        EscrowItem storage Item = idToTrade[_tradeId];
        require(msg.sender == Item.party2 || msg.sender == Item.party1,"Not designated parties");
        transferItems(Items(Item.selfItem0,Item.selfItem1,Item.selfItem2), address(this), Item.party1);
        refundFees(Item.feeCollected, Item.party1);
        popTrade(_tradeId);
        delete idToTrade[_tradeId];
    }

    function popTrade(uint _trade) private{
        EscrowItem storage Item = idToTrade[_trade];
        uint[2] memory positions = tradePosition[_trade];
        
        //party1
        uint lastItem0 = userTrades[Item.party1][userTrades[Item.party1].length - 1];
        userTrades[Item.party1][positions[0]] = lastItem0;
        uint partyCode = Item.party1 == idToTrade[lastItem0].party1 ? 0 : 1;
        tradePosition[lastItem0][partyCode] = positions[0];

        //part2
        uint lastItem1 = userTrades[Item.party2][userTrades[Item.party2].length - 1];
        userTrades[Item.party2][positions[1]] = lastItem1;
        partyCode = Item.party2 == idToTrade[lastItem1].party1 ? 0 : 1;
        tradePosition[lastItem0][partyCode] = positions[0];

        userTrades[Item.party1].pop();
        userTrades[Item.party2].pop();
    }


    function transferItems(Items memory items,address _from,address _to) private {
        uint[3] memory userLength = [items.NFTItems._contract.length,items.TokenItems._contract.length,items.MultiItems._contract.length];

        //Transfer NFTs
        for(uint i=0;i<userLength[0];i++){
            IERC721 NFT = IERC721(items.NFTItems._contract[i]);
            console.log("Expected owner:-", NFT.ownerOf(items.NFTItems.tokenId[i]));
            require(NFT.ownerOf(items.NFTItems.tokenId[i]) == _from ,"Not owner");
            NFT.transferFrom(_from,_to,items.NFTItems.tokenId[i]);
        }

        //Transfer Tokens
        for(uint i=0;i<userLength[1];i++){
            IERC20 Token = IERC20(items.TokenItems._contract[i]);
            require(items.TokenItems.tokenAmount[i] != 0,"Amount can't be 0");
            if(_from != address(this))
            Token.transferFrom(_from, _to, items.TokenItems.tokenAmount[i]);
            else
            Token.transfer(_to, items.TokenItems.tokenAmount[i]);
        }

        //Transfer Multi
        for(uint i=0;i<userLength[2];i++){
            IERC1155 Multi = IERC1155(items.MultiItems._contract[i]);
            require(items.MultiItems.tokenAmount[i] != 0,"Amount can't be 0");
            Multi.safeTransferFrom(_from, _to, items.MultiItems.tokenId[i], items.MultiItems.tokenAmount[i], "");
        }
    }

    function payFees(uint _amount,uint _value,uint8 feeChoice) private returns(uint[3] memory feePaid){
        if(feeChoice == 0){
            require(_value == _amount*Fees[0],"Fee not paid");
            feePaid[0] = _amount*Fees[0];
        }
        else if(feeChoice == 1){
            console.log("Pay fees", _amount*Fees[1]);
            require(GSM.transferFrom(msg.sender, address(this), _amount*Fees[1]),"Fee not paid");
            feePaid[1] = _amount*Fees[1];
        }
        else if(feeChoice == 2){
            require(xGSM.transferFrom(msg.sender,address(this),_amount*Fees[2]),"Fee not paid");
            feePaid[2] = _amount*Fees[2];
        }
        else{
            revert("Invalid choice");
        }
    }

    function addToFees(uint[3] memory fees,uint _tradeId,bool self) private{

        EscrowItem storage items = idToTrade[_tradeId];
        NFTItem memory nftItems;
        TokenItem memory tokenItems;
        MultiItem memory multiItems;

        uint[3] memory partnerShare;

        if(self){
            nftItems = items.selfItem0;
            tokenItems = items.selfItem1;
            multiItems = items.selfItem2;
        }
        else{
            nftItems = items.offeredItems0;
            tokenItems = items.offeredItems1;
            multiItems = items.offeredItems2;
        }

        uint[3] memory userLength = [nftItems._contract.length,tokenItems._contract.length,multiItems._contract.length];
        
        
        if(fees[0] != 0){

        for(uint i=0;i<userLength[0];i++){
            if(partnerMapping[nftItems._contract[i]].recepientAddress != address(0)){
                uint share = Fees[0] * partnerMapping[nftItems._contract[i]].sharePercent/100;
                partnerMapping[nftItems._contract[i]].nativeBalance += share;
                partnerShare[0] += share;
            }
        }

        for(uint i=0;i<userLength[1];i++){
            if(partnerMapping[tokenItems._contract[i]].recepientAddress != address(0)){
                uint share = Fees[0] * partnerMapping[tokenItems._contract[i]].sharePercent/100;
                partnerMapping[tokenItems._contract[i]].nativeBalance += share;
                partnerShare[0] += share;
            }
        }

        for(uint i=0;i<userLength[2];i++){
            if(partnerMapping[multiItems._contract[i]].recepientAddress != address(0)){
                uint share = Fees[0] * partnerMapping[tokenItems._contract[i]].sharePercent/100;
                partnerMapping[tokenItems._contract[i]].nativeBalance += share;
                partnerShare[0] += share;
            }
        }  
            nativeFeeCollected += fees[0] - partnerShare[0];
        }
        else if(fees[1] != 0){
        for(uint i=0;i<userLength[0];i++){
            if(partnerMapping[nftItems._contract[i]].recepientAddress != address(0)){
                uint share = Fees[1] * partnerMapping[nftItems._contract[i]].sharePercent/100;
                partnerMapping[nftItems._contract[i]].gsmBalance += share;
                partnerShare[1] += share;
            }
        }

        for(uint i=0;i<userLength[1];i++){
            if(partnerMapping[tokenItems._contract[i]].recepientAddress != address(0)){
                uint share = Fees[1] * partnerMapping[tokenItems._contract[i]].sharePercent/100;
                partnerMapping[tokenItems._contract[i]].gsmBalance += share;
                partnerShare[1] += share;
            }
        }

        for(uint i=0;i<userLength[2];i++){
            if(partnerMapping[multiItems._contract[i]].recepientAddress != address(0)){
                uint share = Fees[1] * partnerMapping[tokenItems._contract[i]].sharePercent/100;
                partnerMapping[tokenItems._contract[i]].gsmBalance += share;
                partnerShare[1] += share;
            }
        }  
            GSMFeeCollected += fees[1] - partnerShare[1];
        }
        else if (fees[2] != 0)
        {
        for(uint i=0;i<userLength[0];i++){
            if(partnerMapping[nftItems._contract[i]].recepientAddress != address(0)){
                uint share = Fees[2] * partnerMapping[nftItems._contract[i]].sharePercent/100;
                partnerMapping[nftItems._contract[i]].xgsmBalance += share;
                partnerShare[2] += share;
            }
        }

        for(uint i=0;i<userLength[2];i++){
            if(partnerMapping[tokenItems._contract[i]].recepientAddress != address(0)){
                uint share = Fees[2] * partnerMapping[tokenItems._contract[i]].sharePercent/100;
                partnerMapping[tokenItems._contract[i]].xgsmBalance += share;
                partnerShare[2] += share;
            }
            }

        for(uint i=0;i<userLength[2];i++){
            if(partnerMapping[multiItems._contract[i]].recepientAddress != address(0)){
                uint share = Fees[2] * partnerMapping[tokenItems._contract[i]].sharePercent/100;
                partnerMapping[tokenItems._contract[i]].xgsmBalance += share;
                partnerShare[2] += share;
            }
        }  
            xGSMFeeCollected += fees[2];
        }
    }

    function refundFees(uint[3] memory _fees,address _to) private {
        if(_fees[0] != 0){
            payable(_to).transfer(_fees[0]);            
        }
        else if(_fees[1] != 0){
            GSM.transfer(_to,_fees[1]);
        }
        else{
            xGSM.transfer(_to,_fees[2]);
        }
    }

    function sum(uint[3] memory items) private pure returns(uint){
        uint amount = 0;
        for(uint i=0;i<3;i++){
            amount += items[i];
        }
        return amount;
    }

    function verify(Items memory item) private pure returns(bool){
        bool verified = true;
        if(item.NFTItems._contract.length != item.NFTItems.tokenId.length){
            verified = false;
        }
        else if (item.TokenItems._contract.length != item.TokenItems.tokenAmount.length){
            verified = false;
        }
        else if(item.MultiItems._contract.length != item.MultiItems.tokenId.length){
            verified = false;
        }
        else if(item.MultiItems._contract.length != item.MultiItems.tokenAmount.length){
            verified = false;
        }
        return verified;
    }

    function editFee(uint[3] memory _fee) external onlyOwner{
        Fees = _fee;
    }

    function setxGSM(address _xgsm) external onlyOwner{
        xGSM = IERC20(_xgsm);
    }

    function setGSM(address _gsm) external onlyOwner{
        GSM = IERC20(_gsm);
    }

    function addPartner(address _contract, Partner memory _partner) external onlyOwner{
        partnerMapping[_contract] = _partner;
    }

    function editPartner(address _newRecepient, uint _share,address _contract) external onlyOwner{
        partnerMapping[_contract].recepientAddress = _newRecepient;
        partnerMapping[_contract].sharePercent = _share;
    }

    function collectPartnerFee(address _contract) external nonReentrant{
        require(partnerMapping[_contract].recepientAddress == msg.sender,"Not recepient");
        uint GSMAmount = partnerMapping[_contract].gsmBalance;
        partnerMapping[_contract].gsmBalance = 0;
        GSM.transferFrom(address(this), msg.sender, GSMAmount);

        uint xGSMAmount = partnerMapping[_contract].xgsmBalance;
        partnerMapping[_contract].xgsmBalance = 0;
        xGSM.transferFrom(address(this),msg.sender,xGSMAmount);

        uint nativeAmount = partnerMapping[_contract].nativeBalance;
        partnerMapping[_contract].nativeBalance = 0;
        payable(msg.sender).transfer(nativeAmount);
    }

    function collectFees() external onlyOwner{
        uint GSMAmount = GSMFeeCollected;
        GSMFeeCollected = 0;
        GSM.transferFrom(address(this), msg.sender, GSMAmount);

        uint xGSMAmount = xGSMFeeCollected;
        xGSMFeeCollected = 0;
        xGSM.transferFrom(address(this),msg.sender,xGSMAmount);

        uint nativeAmount = nativeFeeCollected;
        nativeFeeCollected = 0;
        payable(msg.sender).transfer(nativeAmount);
    }
}


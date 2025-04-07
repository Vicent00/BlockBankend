// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

interface IRoyaltyInfo {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

contract FeeRoyaltyManager is Ownable {
    // Comisión del marketplace (en basis points, 1 basis point = 0.01%)
    uint256 public marketplaceFeeBps;
    
    // Dirección donde se envían las comisiones del marketplace
    address public feeRecipient;

    // Eventos
    event MarketplaceFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event RoyaltiesPaid(address indexed token, address indexed creator, uint256 amount);

    constructor(uint256 _marketplaceFeeBps, address _feeRecipient) Ownable(msg.sender) {
        require(_marketplaceFeeBps <= 10000, "FeeRoyaltyManager: Fee cannot exceed 100%");
        marketplaceFeeBps = _marketplaceFeeBps;
        feeRecipient = _feeRecipient;
    }

    // Función para calcular y distribuir comisiones y regalías
    function calculateAndDistributeFees(
        address paymentToken,
        uint256 salePrice,
        address nftContract,
        uint256 tokenId
    ) external returns (uint256 sellerAmount) {
        // Calcular comisión del marketplace
        uint256 marketplaceFee = (salePrice * marketplaceFeeBps) / 10000;
        
        // Calcular regalías si el contrato NFT implementa EIP-2981
        uint256 royaltyAmount = 0;
        address royaltyReceiver = address(0);
        
        try IRoyaltyInfo(nftContract).royaltyInfo(tokenId, salePrice) returns (
            address receiver,
            uint256 amount
        ) {
            royaltyReceiver = receiver;
            royaltyAmount = amount;
        } catch {
            // El contrato no implementa EIP-2981, no hay regalías
        }

        // Calcular el monto final para el vendedor
        sellerAmount = salePrice - marketplaceFee - royaltyAmount;

        // Emitir eventos
        if (royaltyAmount > 0) {
            emit RoyaltiesPaid(paymentToken, royaltyReceiver, royaltyAmount);
        }

        return sellerAmount;
    }

    // Función para actualizar la comisión del marketplace
    function updateMarketplaceFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 10000, "FeeRoyaltyManager: Fee cannot exceed 100%");
        uint256 oldFee = marketplaceFeeBps;
        marketplaceFeeBps = newFeeBps;
        emit MarketplaceFeeUpdated(oldFee, newFeeBps);
    }

    // Función para actualizar el destinatario de las comisiones
    function updateFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "FeeRoyaltyManager: Invalid recipient");
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    // Función para obtener la comisión del marketplace
    function getMarketplaceFee(uint256 salePrice) external view returns (uint256) {
        return (salePrice * marketplaceFeeBps) / 10000;
    }
} 
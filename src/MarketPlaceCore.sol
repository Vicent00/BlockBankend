// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./NFTModule.sol";
import "./PaymentManager.sol";
import "./FeeRoyaltyManager.sol";

contract MarketplaceCore is ReentrancyGuard, Ownable {
    // Referencias a los módulos
    NFTModule public nftModule;
    PaymentManager public paymentManager;
    FeeRoyaltyManager public feeRoyaltyManager;

    // Estructura para almacenar información de un listado
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        address paymentToken; // address(0) para ETH
        bool isActive;
        bool isAuction;
        uint256 auctionEndTime;
        uint256 highestBid;
        address highestBidder;
    }

    // Mapping de ID de listado a Listing
    mapping(uint256 => Listing) public listings;
    uint256 public listingCount;

    // Eventos
    event ListingCreated(uint256 indexed listingId, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event ListingCancelled(uint256 indexed listingId);
    event PurchaseMade(uint256 indexed listingId, address indexed buyer, uint256 price);
    event BidPlaced(uint256 indexed listingId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed listingId, address indexed winner, uint256 finalPrice);

    constructor(
        address _nftModule,
        address _paymentManager,
        address _feeRoyaltyManager
    ) Ownable(msg.sender) {
        nftModule = NFTModule(_nftModule);
        paymentManager = PaymentManager(_paymentManager);
        feeRoyaltyManager = FeeRoyaltyManager(_feeRoyaltyManager);
    }

    // Función para crear un nuevo listado
    function createListing(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken,
        bool isAuction,
        uint256 auctionDuration
    ) external {
        // Verificar propiedad del NFT
        require(
            nftModule.verifyOwnership(nftContract, tokenId, msg.sender),
            "Marketplace: Not the owner"
        );

        // Verificar aprobación
        require(
            nftModule.verifyApproval(nftContract, tokenId, address(this)),
            "Marketplace: Not approved"
        );

        // Tomar el NFT en custodia
        nftModule.takeCustody(nftContract, tokenId, msg.sender);

        // Crear nuevo listing
        uint256 listingId = listingCount++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            paymentToken: paymentToken,
            isActive: true,
            isAuction: isAuction,
            auctionEndTime: isAuction ? block.timestamp + auctionDuration : 0,
            highestBid: 0,
            highestBidder: address(0)
        });

        emit ListingCreated(listingId, msg.sender, nftContract, tokenId, price);
    }

    // Función para comprar un NFT listado
    function buyNFT(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        
        // Verificar que el listado existe y está activo
        require(listing.isActive, "Marketplace: Listing not active");
        require(!listing.isAuction, "Marketplace: Cannot buy auction item directly");

        // Procesar pago
        uint256 sellerAmount = feeRoyaltyManager.calculateAndDistributeFees(
            listing.paymentToken,
            listing.price,
            listing.nftContract,
            listing.tokenId
        );

        if (listing.paymentToken == address(0)) {
            // Pago en ETH
            require(msg.value >= listing.price, "Marketplace: Insufficient ETH sent");
            paymentManager.processPayment{value: msg.value}(
                listing.paymentToken,
                msg.sender,
                listing.seller,
                sellerAmount
            );
        } else {
            // Pago en ERC-20
            paymentManager.processPayment(
                listing.paymentToken,
                msg.sender,
                listing.seller,
                sellerAmount
            );
        }

        // Transferir NFT
        nftModule.transferNFT(
            listing.nftContract,
            listing.tokenId,
            address(this),
            msg.sender
        );

        // Marcar listado como inactivo
        listing.isActive = false;

        emit PurchaseMade(listingId, msg.sender, listing.price);
    }

    // Función para colocar una oferta en una subasta
    function placeBid(uint256 listingId, uint256 amount) external nonReentrant {
        Listing storage listing = listings[listingId];
        
        // Verificar que el listado existe y es una subasta activa
        require(listing.isActive, "Marketplace: Listing not active");
        require(listing.isAuction, "Marketplace: Not an auction");
        require(block.timestamp < listing.auctionEndTime, "Marketplace: Auction ended");
        require(amount > listing.highestBid, "Marketplace: Bid too low");

        // Procesar pago
        if (listing.paymentToken == address(0)) {
            // Pago en ETH
            require(msg.value >= amount, "Marketplace: Insufficient ETH sent");
            paymentManager.processPaymentWithHold{value: msg.value}(
                listing.paymentToken,
                msg.sender,
                amount
            );
        } else {
            // Pago en ERC-20
            paymentManager.processPaymentWithHold(
                listing.paymentToken,
                msg.sender,
                amount
            );
        }

        // Devolver la oferta anterior si existe
        if (listing.highestBidder != address(0)) {
            paymentManager.processPayment(
                listing.paymentToken,
                address(this),
                listing.highestBidder,
                listing.highestBid
            );
        }

        // Actualizar highestBid y highestBidder
        listing.highestBid = amount;
        listing.highestBidder = msg.sender;

        emit BidPlaced(listingId, msg.sender, amount);
    }

    // Función para finalizar una subasta
    function endAuction(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        
        // Verificar que la subasta ha terminado
        require(listing.isActive, "Marketplace: Listing not active");
        require(listing.isAuction, "Marketplace: Not an auction");
        require(block.timestamp >= listing.auctionEndTime, "Marketplace: Auction not ended");
        require(listing.highestBidder != address(0), "Marketplace: No bids");

        // Calcular comisiones y regalías
        uint256 sellerAmount = feeRoyaltyManager.calculateAndDistributeFees(
            listing.paymentToken,
            listing.highestBid,
            listing.nftContract,
            listing.tokenId
        );

        // Transferir fondos al vendedor
        paymentManager.processPayment(
            listing.paymentToken,
            address(this),
            listing.seller,
            sellerAmount
        );

        // Transferir NFT al ganador
        nftModule.transferNFT(
            listing.nftContract,
            listing.tokenId,
            address(this),
            listing.highestBidder
        );

        // Marcar listado como inactivo
        listing.isActive = false;

        emit AuctionEnded(listingId, listing.highestBidder, listing.highestBid);
    }

    // Función para cancelar un listado
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        
        // Verificar que el llamante es el vendedor
        require(listing.seller == msg.sender, "Marketplace: Not the seller");
        require(listing.isActive, "Marketplace: Listing not active");

        // Marcar listado como inactivo
        listing.isActive = false;

        // Devolver NFT al vendedor
        nftModule.releaseCustody(
            listing.nftContract,
            listing.tokenId,
            listing.seller
        );

        emit ListingCancelled(listingId);
    }
}


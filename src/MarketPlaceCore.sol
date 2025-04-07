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
        uint256 minBidIncrement;      // Incremento mínimo para nuevas ofertas
        uint256 lastBidTime;          // Timestamp de la última oferta
        bytes32 highestBidHash;       // Hash de la oferta más alta (commit)
        mapping(address => bytes32) pendingBids;  // Ofertas pendientes por revelar
        mapping(address => uint256) bidCommitments; // Timestamps de los commits
    }

    // Constantes para protección contra front-running
    uint256 public constant MIN_BID_INCREMENT_PERCENT = 5;     // 5% de incremento mínimo
    uint256 public constant MIN_TIME_BETWEEN_BIDS = 3 minutes; // Tiempo mínimo entre ofertas
    uint256 public constant COMMIT_REVEAL_WINDOW = 10 minutes; // Ventana para revelar ofertas
    uint256 public constant MIN_AUCTION_DURATION = 1 days;     // Duración mínima de subasta

    // Mapping de ID de listado a Listing
    mapping(uint256 => Listing) public listings;
    uint256 public listingCount;

    // Eventos
    event ListingCreated(uint256 indexed listingId, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event ListingCancelled(uint256 indexed listingId);
    event PurchaseMade(uint256 indexed listingId, address indexed buyer, uint256 price);
    event BidCommitted(uint256 indexed listingId, address indexed bidder, bytes32 commitment);
    event BidRevealed(uint256 indexed listingId, address indexed bidder, uint256 amount);
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
        require(
            !isAuction || auctionDuration >= MIN_AUCTION_DURATION,
            "Marketplace: Auction duration too short"
        );

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
        Listing storage newListing = listings[listingId];
        newListing.seller = msg.sender;
        newListing.nftContract = nftContract;
        newListing.tokenId = tokenId;
        newListing.price = price;
        newListing.paymentToken = paymentToken;
        newListing.isActive = true;
        newListing.isAuction = isAuction;
        newListing.auctionEndTime = isAuction ? block.timestamp + auctionDuration : 0;
        newListing.highestBid = 0;
        newListing.highestBidder = address(0);
        newListing.minBidIncrement = (price * MIN_BID_INCREMENT_PERCENT) / 100;
        newListing.lastBidTime = 0;

        emit ListingCreated(listingId, msg.sender, nftContract, tokenId, price);
    }

    // Función para comprometer una oferta (commit)
    function commitBid(uint256 listingId, bytes32 commitment) external {
        Listing storage listing = listings[listingId];
        
        require(listing.isActive, "Marketplace: Listing not active");
        require(listing.isAuction, "Marketplace: Not an auction");
        require(block.timestamp < listing.auctionEndTime, "Marketplace: Auction ended");
        require(
            block.timestamp >= listing.lastBidTime + MIN_TIME_BETWEEN_BIDS,
            "Marketplace: Too soon for new bid"
        );

        listing.pendingBids[msg.sender] = commitment;
        listing.bidCommitments[msg.sender] = block.timestamp;

        emit BidCommitted(listingId, msg.sender, commitment);
    }

    // Función para revelar una oferta
    function revealBid(
        uint256 listingId,
        uint256 amount,
        bytes32 nonce
    ) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        
        require(listing.isActive, "Marketplace: Listing not active");
        require(listing.isAuction, "Marketplace: Not an auction");
        require(block.timestamp < listing.auctionEndTime, "Marketplace: Auction ended");

        // Verificar que el commit existe y está dentro de la ventana de tiempo
        bytes32 commitment = listing.pendingBids[msg.sender];
        require(commitment != bytes32(0), "Marketplace: No bid committed");
        require(
            block.timestamp <= listing.bidCommitments[msg.sender] + COMMIT_REVEAL_WINDOW,
            "Marketplace: Reveal window expired"
        );

        // Verificar que el hash coincide
        require(
            keccak256(abi.encodePacked(msg.sender, amount, nonce)) == commitment,
            "Marketplace: Invalid bid reveal"
        );

        // Verificar incremento mínimo
        require(
            amount >= listing.highestBid + listing.minBidIncrement,
            "Marketplace: Bid increment too low"
        );

        // Procesar el pago
        if (listing.paymentToken == address(0)) {
            require(msg.value >= amount, "Marketplace: Insufficient ETH sent");
            paymentManager.processPaymentWithHold{value: msg.value}(
                listing.paymentToken,
                msg.sender,
                amount
            );
        } else {
            paymentManager.processPaymentWithHold(
                listing.paymentToken,
                msg.sender,
                amount
            );
        }

        // Devolver la oferta anterior
        if (listing.highestBidder != address(0)) {
            paymentManager.processPayment(
                listing.paymentToken,
                address(this),
                listing.highestBidder,
                listing.highestBid
            );
        }

        // Actualizar estado
        listing.highestBid = amount;
        listing.highestBidder = msg.sender;
        listing.lastBidTime = block.timestamp;
        delete listing.pendingBids[msg.sender];
        delete listing.bidCommitments[msg.sender];

        emit BidRevealed(listingId, msg.sender, amount);
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


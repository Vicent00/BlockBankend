# BlockBankend NFT MarketPlace

## 📝 Description

This NFT marketplace is a decentralized platform built on Arbitrum that enables the buying, selling, and auctioning of NFTs with support for ETH and ERC-20 token payments. The system implements advanced features such as front-running protection, fee and royalty management, and a secure NFT custody system.


![Marketplace Architecture](WEB3notransparent.png)


## 📜 Contracts Deployed on Arbitrum

| Contract | Address |
|----------|-----------|
| MarketplaceCore | [0xB4ae89e0635F6bdF92F64C76d53964e1060e11b4](https://arbiscan.io/address/0xB4ae89e0635F6bdF92F64C76d53964e1060e11b4) |
| NFTModule | [0x1140D367432f720879b817F404c577620B765531](https://arbiscan.io/address/0x1140D367432f720879b817F404c577620B765531) |
| PaymentManager | [0x46B7bA6D27869624B013705a9C433feefb15bE69](https://arbiscan.io/address/0x46B7bA6D27869624B013705a9C433feefb15bE69) |
| FeeRoyaltyManager | [0x45994782c576AB76592E5CaE528151d0E56D65e9](https://arbiscan.io/address/0x45994782c576AB76592E5CaE528151d0E56D65e9) |

## 🚀 Key Features

- ✅ Direct NFT sales
- 🏷️ Auction system with commit-reveal mechanism
- 💰 Support for ETH and ERC-20 tokens
- 🛡️ Front-running protection
- 📊 Fee and royalty system
- 🔒 Secure NFT custody
- ⚡ Optimized for Arbitrum

## 🏗️ System Architecture

The marketplace is composed of 4 main contracts:

1. **MarketplaceCore**: Main contract that coordinates all operations
2. **NFTModule**: Manages NFT custody and transfers
3. **PaymentManager**: Handles payments and funds
4. **FeeRoyaltyManager**: Manages fees and royalties

## 🔒 Security Implementation

### 1. Reentrancy Protection
```solidity
contract MarketplaceCore is ReentrancyGuard {
    // All critical functions are protected by nonReentrant modifier
    function buyNFT(uint256 listingId) external nonReentrant {
        // Implementation
    }
}
```
- Uses OpenZeppelin's ReentrancyGuard
- Prevents reentrancy attacks in all critical functions
- Ensures atomic operations for payments and transfers

### 2. Front-Running Protection
```solidity
// Commit-Reveal Pattern for Auctions
function commitBid(uint256 listingId, bytes32 commitment) external {
    require(block.timestamp >= listing.startTime, "Auction not started");
    require(block.timestamp <= listing.endTime, "Auction ended");
    // Store commitment
}

function revealBid(uint256 listingId, uint256 amount, bytes32 nonce) external {
    require(keccak256(abi.encodePacked(amount, nonce)) == commitment, "Invalid reveal");
    // Process bid
}
```
- Implements commit-reveal pattern for auctions
- Prevents bid sniping and front-running
- Minimum time between bids (3 minutes)
- Minimum bid increment (5%)

### 3. Secure Custody Management
```solidity
contract NFTModule is Ownable {
    // Secure NFT custody during listings
    function takeCustody(address nftContract, uint256 tokenId) external onlyOwner {
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
    }
}
```
- NFTs held in custody during listings
- Only authorized contracts can manage custody
- Secure transfer mechanisms

### 4. Payment Security
```solidity
contract PaymentManager is ReentrancyGuard {
    // Secure payment processing
    function processPayment(address token, address from, address to, uint256 amount) internal {
        if (token == address(0)) {
            // Handle ETH
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // Handle ERC-20
            IERC20(token).transferFrom(from, to, amount);
        }
    }
}
```
- Secure handling of both ETH and ERC-20 tokens
- Protected against reentrancy
- Proper error handling

### 5. Access Control
```solidity
contract FeeRoyaltyManager is Ownable {
    // Only owner can modify critical parameters
    function setFeeRate(uint256 newRate) external onlyOwner {
        require(newRate <= MAX_FEE_RATE, "Fee too high");
        feeRate = newRate;
    }
}
```
- Role-based access control
- Owner-only critical functions
- Parameter validation

## 🛡️ Protected Against Common Attacks

### 1. Reentrancy Attacks
- Protected by ReentrancyGuard
- Checks-Effects-Interactions pattern
- Atomic operations

### 2. Front-Running
- Commit-reveal pattern for auctions
- Minimum time between operations
- Hidden bid amounts

### 3. Denial of Service (DoS)
- Gas optimization
- Batch operations where possible
- Proper error handling

### 4. Integer Overflow/Underflow
- SafeMath operations
- Input validation
- Range checks

### 5. Unauthorized Access
- Role-based access control
- Proper ownership management
- Function visibility control

## 📊 Operation Flow

### 1. NFT Listing
```mermaid
sequenceDiagram
    Seller->>NFTModule: Verify ownership
    NFTModule->>MarketplaceCore: Approval
    MarketplaceCore->>NFTModule: Take custody
    MarketplaceCore->>MarketplaceCore: Create listing
```

### 2. Direct Sale
```mermaid
sequenceDiagram
    Buyer->>MarketplaceCore: Initiate purchase
    MarketplaceCore->>FeeRoyaltyManager: Calculate fees
    MarketplaceCore->>PaymentManager: Process payment
    PaymentManager->>Seller: Transfer funds
    MarketplaceCore->>NFTModule: Transfer NFT
```

### 3. Auction System
```mermaid
sequenceDiagram
    Bidder->>MarketplaceCore: Commit bid
    MarketplaceCore->>MarketplaceCore: Wait 3 min
    Bidder->>MarketplaceCore: Reveal bid
    MarketplaceCore->>PaymentManager: Hold funds
    MarketplaceCore->>MarketplaceCore: Update highest bid
```

## 🛠️ How to Deploy

1. **Initial Setup**
```bash
# Install dependencies
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts

# Configure .env
PRIVATE_KEY=0x...
ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc
ARBISCAN_API_KEY=...
```

2. **Compilation**
```bash
forge build
```

3. **Deployment**
```bash
forge script script/DeployMarketplace.s.sol:DeployMarketplace \
    --rpc-url https://arb1.arbitrum.io/rpc \
    --broadcast \
    --verify \
    --legacy \
    -vvvv
```

## 🔍 Code Explanation

### MarketplaceCore
The main contract that coordinates all operations:
- Listing management
- Auction system
- Integration with other modules

#### Key Functions
```solidity
function createListing(
    address nftContract,
    uint256 tokenId,
    uint256 price,
    address paymentToken,
    bool isAuction,
    uint256 auctionDuration
) external nonReentrant {
    // Implementation
}

function buyNFT(uint256 listingId) external payable nonReentrant {
    // Implementation
}
```

### NFTModule
Handles NFT custody and transfers:
- Ownership verification
- Secure transfers
- Approval management

#### Key Functions
```solidity
function verifyOwnership(
    address nftContract,
    uint256 tokenId,
    address owner
) external view returns (bool) {
    // Implementation
}

function transferNFT(
    address nftContract,
    uint256 tokenId,
    address from,
    address to
) external onlyOwner {
    // Implementation
}
```

### PaymentManager
Manages payments:
- Support for ETH and ERC-20
- Fund holding
- Payment distribution

#### Key Functions
```solidity
function processPayment(
    address token,
    address from,
    address to,
    uint256 amount
) internal nonReentrant {
    // Implementation
}

function withdrawFunds(
    address token,
    uint256 amount
) external nonReentrant {
    // Implementation
}
```

### FeeRoyaltyManager
Manages fees and royalties:
- Fee calculation
- Royalty distribution
- Rate configuration

#### Key Functions
```solidity
function calculateFees(
    uint256 amount
) external view returns (uint256 fee, uint256 royalty) {
    // Implementation
}

function distributeFees(
    address token,
    uint256 amount,
    address seller,
    address creator
) external nonReentrant {
    // Implementation
}
```

## 📚 Technical Documentation

### Important Constants
```solidity
uint256 public constant MIN_BID_INCREMENT_PERCENT = 5;     // 5% minimum increment
uint256 public constant MIN_TIME_BETWEEN_BIDS = 3 minutes; // Time between bids
uint256 public constant COMMIT_REVEAL_WINDOW = 10 minutes; // Reveal window
uint256 public constant MIN_AUCTION_DURATION = 1 days;     // Minimum duration
uint256 public constant MAX_FEE_RATE = 1000;              // 10% maximum fee
```

### Events
```solidity
event ListingCreated(uint256 indexed listingId, address indexed seller, ...);
event PurchaseMade(uint256 indexed listingId, address indexed buyer, ...);
event BidCommitted(uint256 indexed listingId, address indexed bidder, ...);
event AuctionEnded(uint256 indexed listingId, address indexed winner, ...);
event FeeUpdated(uint256 newFeeRate);
event RoyaltyPaid(address indexed creator, uint256 amount);
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

## 📧 Contact

Vicent00 - [@email](https://mailto:hello@vicenteaguilar.com)

Project Link: [https://github.com/Vicent00/BlockBankend](https://github.com/Vicent00/BlockBankend)

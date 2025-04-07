# NFT Marketplace Core Contract

This smart contract implements a decentralized NFT marketplace with support for both fixed-price sales and auctions. The contract is built on Solidity 0.8.26 and uses OpenZeppelin's ReentrancyGuard and Ownable contracts for security.

## Features

- Fixed-price NFT listings
- Auction system with commit-reveal mechanism
- Support for both ETH and ERC-20 token payments
- Fee and royalty distribution system
- Front-running protection
- Secure custody management for NFTs

## Core Components

The contract integrates with three main modules:
- `NFTModule`: Handles NFT ownership verification and transfers
- `PaymentManager`: Manages payment processing and custody
- `FeeRoyaltyManager`: Handles fee calculations and royalty distributions

## Key Functions

### Listing Management

#### `createListing`
```solidity
function createListing(
    address nftContract,
    uint256 tokenId,
    uint256 price,
    address paymentToken,
    bool isAuction,
    uint256 auctionDuration
)
```
Creates a new NFT listing with the following features:
- Verifies NFT ownership and approval
- Takes NFT into marketplace custody
- Supports both fixed-price and auction listings
- Minimum auction duration of 1 day
- Configurable payment token (ETH or ERC-20)

### Auction System

#### `commitBid`
```solidity
function commitBid(uint256 listingId, bytes32 commitment)
```
Implements the commit-reveal pattern for auction bids:
- Prevents front-running by hiding bid amounts
- Requires minimum time between bids (3 minutes)
- Stores bid commitments with timestamps

#### `revealBid`
```solidity
function revealBid(uint256 listingId, uint256 amount, bytes32 nonce)
```
Reveals previously committed bids:
- Verifies bid commitment matches revealed amount
- Enforces minimum bid increment (5%)
- Processes payments and updates highest bid
- Returns previous highest bid to the bidder

### Purchase Functions

#### `buyNFT`
```solidity
function buyNFT(uint256 listingId)
```
Handles fixed-price NFT purchases:
- Processes payments through PaymentManager
- Distributes fees and royalties
- Transfers NFT to buyer
- Supports both ETH and ERC-20 payments

#### `endAuction`
```solidity
function endAuction(uint256 listingId)
```
Finalizes auction listings:
- Verifies auction has ended
- Distributes final payments
- Transfers NFT to winning bidder
- Handles fee and royalty distribution

### Listing Management

#### `cancelListing`
```solidity
function cancelListing(uint256 listingId)
```
Allows sellers to cancel their listings:
- Verifies seller ownership
- Returns NFT to original owner
- Marks listing as inactive

## Security Features

- Reentrancy protection using OpenZeppelin's ReentrancyGuard
- Commit-reveal pattern for auction bids
- Minimum time between bids (3 minutes)
- Minimum bid increment (5%)
- Secure custody management for NFTs
- Proper payment handling for both ETH and ERC-20 tokens

## Events

The contract emits the following events:
- `ListingCreated`: When a new listing is created
- `ListingCancelled`: When a listing is cancelled
- `PurchaseMade`: When an NFT is purchased
- `BidCommitted`: When a bid is committed in an auction
- `BidRevealed`: When a bid is revealed in an auction
- `AuctionEnded`: When an auction is finalized

## Constants

- `MIN_BID_INCREMENT_PERCENT`: 5% minimum bid increment
- `MIN_TIME_BETWEEN_BIDS`: 3 minutes between bids
- `COMMIT_REVEAL_WINDOW`: 10 minutes to reveal bids
- `MIN_AUCTION_DURATION`: 1 day minimum auction duration

## Flujo de Contratos y Funcionamiento

### 1. Estructura General
El marketplace está compuesto por 4 contratos principales que interactúan entre sí:

1. **MarketplaceCore**: Contrato principal que coordina todas las operaciones
2. **NFTModule**: Gestiona la custodia y transferencia de NFTs
3. **PaymentManager**: Maneja los pagos y fondos
4. **FeeRoyaltyManager**: Administra comisiones y regalías

### 2. Flujo de Listado y Venta

#### 2.1 Listado de NFT
1. El vendedor llama a `createListing` en MarketplaceCore
2. MarketplaceCore verifica con NFTModule:
   - Propiedad del NFT
   - Aprobación para transferencia
3. NFTModule toma el NFT en custodia
4. Se crea el listado con los detalles de precio y tipo (subasta o precio fijo)

#### 2.2 Venta Directa (Precio Fijo)
1. Comprador llama a `buyNFT`
2. MarketplaceCore:
   - Verifica que el listado está activo
   - Solicita a FeeRoyaltyManager calcular comisiones
   - Envía el pago a PaymentManager
3. PaymentManager:
   - Procesa el pago (ETH o ERC-20)
   - Distribuye fondos al vendedor y comisiones
4. NFTModule transfiere el NFT al comprador

#### 2.3 Subasta
1. **Fase de Ofertas**:
   - Los postores llaman a `commitBid` con un hash de su oferta
   - Deben esperar 3 minutos entre ofertas
   - Tienen 10 minutos para revelar su oferta

2. **Revelación de Ofertas**:
   - Los postores llaman a `revealBid`
   - Se verifica que la oferta sea mayor que la anterior + 5%
   - PaymentManager retiene los fondos de la oferta más alta
   - Se devuelven los fondos de la oferta anterior

3. **Finalización de Subasta**:
   - Cualquiera puede llamar a `endAuction` después del tiempo límite
   - FeeRoyaltyManager calcula comisiones finales
   - PaymentManager distribuye los fondos
   - NFTModule transfiere el NFT al ganador

### 3. Gestión de Fondos

1. **ETH**:
   - Los fondos se envían directamente al contrato
   - PaymentManager los distribuye según las reglas establecidas

2. **ERC-20**:
   - Los tokens deben ser aprobados previamente
   - PaymentManager maneja las transferencias de tokens
   - Se distribuyen según las reglas de comisiones

### 4. Seguridad y Protecciones

1. **ReentrancyGuard**:
   - Previene ataques de reentrada en todas las funciones críticas
   - Protege especialmente las operaciones de pago

2. **Commit-Reveal**:
   - Protege contra front-running en subastas
   - Las ofertas se revelan después de un tiempo mínimo

3. **Custodia de NFTs**:
   - NFTs se mantienen en custodia durante el listado
   - Solo se transfieren después de confirmación de pago
   - Se pueden devolver al vendedor si se cancela el listado

### 5. Eventos y Seguimiento

El contrato emite eventos en cada paso importante:
- Creación de listados
- Ofertas en subastas
- Compras directas
- Finalización de subastas
- Cancelaciones

Estos eventos permiten:
- Seguimiento de transacciones
- Construcción de interfaces de usuario
- Auditoría de operaciones
- Análisis de mercado

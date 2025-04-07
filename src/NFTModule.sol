// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTModule is IERC721Receiver {
    // Mapping para verificar si un NFT está en custodia
    mapping(address => mapping(uint256 => bool)) public isInCustody;

    // Eventos
    event NFTCustodyChanged(
        address indexed nftContract,
        uint256 indexed tokenId,
        bool inCustody
    );

    // Función para verificar la propiedad de un NFT
    function verifyOwnership(
        address nftContract,
        uint256 tokenId,
        address supposedOwner
    ) external view returns (bool) {
        return IERC721(nftContract).ownerOf(tokenId) == supposedOwner;
    }

    // Función para verificar la aprobación de un NFT
    function verifyApproval(
        address nftContract,
        uint256 tokenId,
        address operator
    ) external view returns (bool) {
        return
            IERC721(nftContract).getApproved(tokenId) == operator ||
            IERC721(nftContract).isApprovedForAll(
                IERC721(nftContract).ownerOf(tokenId),
                operator
            );
    }

    // Función para transferir un NFT
    function transferNFT(
        address nftContract,
        uint256 tokenId,
        address from,
        address to
    ) external {
        require(
            this.verifyOwnership(nftContract, tokenId, from),
            "NFTModule: Not the owner"
        );
        require(
            this.verifyApproval(nftContract, tokenId, msg.sender),
            "NFTModule: Not approved"
        );

        IERC721(nftContract).safeTransferFrom(from, to, tokenId);
    }

    // Función para tomar un NFT en custodia
    function takeCustody(
        address nftContract,
        uint256 tokenId,
        address from
    ) external {
        require(
            this.verifyOwnership(nftContract, tokenId, from),
            "NFTModule: Not the owner"
        );
        require(
            this.verifyApproval(nftContract, tokenId, msg.sender),
            "NFTModule: Not approved"
        );

        IERC721(nftContract).safeTransferFrom(from, address(this), tokenId);
        isInCustody[nftContract][tokenId] = true;
        emit NFTCustodyChanged(nftContract, tokenId, true);
    }

    // Función para liberar un NFT de la custodia
    function releaseCustody(
        address nftContract,
        uint256 tokenId,
        address to
    ) external {
        require(
            isInCustody[nftContract][tokenId],
            "NFTModule: NFT not in custody"
        );

        IERC721(nftContract).safeTransferFrom(address(this), to, tokenId);
        isInCustody[nftContract][tokenId] = false;
        emit NFTCustodyChanged(nftContract, tokenId, false);
    }

    // Implementación requerida por IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

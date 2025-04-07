// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../src/MarketPlaceCore.sol";
import "../src/NFTModule.sol";
import "../src/PaymentManager.sol";
import "../src/FeeRoyaltyManager.sol";

contract DeployMarketplace is Script {
    // Estructura para almacenar las direcciones desplegadas
    struct DeployedAddresses {
        address nftModule;
        address paymentManager;
        address feeManager;
        address marketplace;
    }

    // Evento para registrar las direcciones desplegadas
    event Deployed(
        address nftModule,
        address paymentManager,
        address feeManager,
        address marketplace
    );

    function run() external returns (DeployedAddresses memory) {
        // Recuperar la private key del ambiente
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Variables para almacenar las direcciones
        DeployedAddresses memory addresses;

        // Comenzar la transmisión de la transacción
        vm.startBroadcast(deployerPrivateKey);

        // 1. Desplegar módulos
        console.log("Desplegando NFTModule...");
        NFTModule nftModule = new NFTModule();
        addresses.nftModule = address(nftModule);
        
        console.log("Desplegando PaymentManager...");
        PaymentManager paymentManager = new PaymentManager();
        addresses.paymentManager = address(paymentManager);
        
        console.log("Desplegando FeeRoyaltyManager...");
        FeeRoyaltyManager feeManager = new FeeRoyaltyManager(250, address(0)); // 2.5% de comisión
        addresses.feeManager = address(feeManager);

        // 2. Desplegar MarketplaceCore
        console.log("Desplegando MarketplaceCore...");
        MarketplaceCore marketplace = new MarketplaceCore(
            address(nftModule),
            address(paymentManager),
            address(feeManager)
        );
        addresses.marketplace = address(marketplace);

        // 3. Configurar permisos
        console.log("Configurando permisos...");
        Ownable(address(nftModule)).transferOwnership(address(marketplace));
        Ownable(address(paymentManager)).transferOwnership(address(marketplace));
        Ownable(address(feeManager)).transferOwnership(address(marketplace));

        // Emitir evento con las direcciones
        emit Deployed(
            address(nftModule),
            address(paymentManager),
            address(feeManager),
            address(marketplace)
        );

        // Finalizar la transmisión
        vm.stopBroadcast();

        // Imprimir las direcciones desplegadas
        console.log("=== Contratos Desplegados ===");
        console.log("NFTModule:", address(nftModule));
        console.log("PaymentManager:", address(paymentManager));
        console.log("FeeRoyaltyManager:", address(feeManager));
        console.log("MarketplaceCore:", address(marketplace));
        console.log("========================");

        return addresses;
    }

    // Función auxiliar para verificar el despliegue
    function verify(DeployedAddresses memory addresses) public view {
        require(addresses.nftModule != address(0), "NFTModule no desplegado");
        require(addresses.paymentManager != address(0), "PaymentManager no desplegado");
        require(addresses.feeManager != address(0), "FeeManager no desplegado");
        require(addresses.marketplace != address(0), "Marketplace no desplegado");

        // Verificar que los permisos se configuraron correctamente
        require(
            NFTModule(addresses.nftModule).owner() == addresses.marketplace,
            "NFTModule: ownership incorrecto"
        );
        require(
            PaymentManager(addresses.paymentManager).owner() == addresses.marketplace,
            "PaymentManager: ownership incorrecto"
        );
        require(
            FeeRoyaltyManager(addresses.feeManager).owner() == addresses.marketplace,
            "FeeManager: ownership incorrecto"
        );

        console.log("Verificacion completada exitosamente!");
    }
} 
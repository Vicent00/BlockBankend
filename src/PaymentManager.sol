// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract PaymentManager is ReentrancyGuard {
    // Mapping para almacenar los saldos pendientes de retiro
    mapping(address => mapping(address => uint256)) public pendingWithdrawals; // token => user => amount

    // Eventos
    event PaymentProcessed(address indexed token, address indexed from, address indexed to, uint256 amount);
    event Withdrawal(address indexed token, address indexed user, uint256 amount);

    // Función para procesar un pago
    function processPayment(
        address paymentToken,
        address from,
        address to,
        uint256 amount
    ) external nonReentrant payable{
        if (paymentToken == address(0)) {
            // Pago en ETH
            require(msg.value >= amount, "PaymentManager: Insufficient ETH sent");
            if (msg.value > amount) {
                // Devolver el exceso
                payable(from).transfer(msg.value - amount);
            }
            payable(to).transfer(amount);
        } else {
            // Pago en ERC-20
            require(
                IERC20(paymentToken).transferFrom(from, to, amount),
                "PaymentManager: ERC20 transfer failed"
            );
        }
        emit PaymentProcessed(paymentToken, from, to, amount);
    }

    // Función para procesar un pago y retener fondos
    function processPaymentWithHold(
        address paymentToken,
        address from,
        uint256 amount
    ) external nonReentrant payable {
        if (paymentToken == address(0)) {
            // Pago en ETH
            require(msg.value >= amount, "PaymentManager: Insufficient ETH sent");
            if (msg.value > amount) {
                // Devolver el exceso
                payable(from).transfer(msg.value - amount);
            }
            pendingWithdrawals[paymentToken][from] += amount;
        } else {
            // Pago en ERC-20
            require(
                IERC20(paymentToken).transferFrom(from, address(this), amount),
                "PaymentManager: ERC20 transfer failed"
            );
            pendingWithdrawals[paymentToken][from] += amount;
        }
        emit PaymentProcessed(paymentToken, from, address(this), amount);
    }

    // Función para retirar fondos retenidos
    function withdraw(address paymentToken) external nonReentrant {
        uint256 amount = pendingWithdrawals[paymentToken][msg.sender];
        require(amount > 0, "PaymentManager: No funds to withdraw");

        pendingWithdrawals[paymentToken][msg.sender] = 0;

        if (paymentToken == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            require(
                IERC20(paymentToken).transfer(msg.sender, amount),
                "PaymentManager: ERC20 transfer failed"
            );
        }

        emit Withdrawal(paymentToken, msg.sender, amount);
    }

    // Función para verificar el saldo de un token
    function getBalance(
        address paymentToken,
        address user
    ) external view returns (uint256) {
        if (paymentToken == address(0)) {
            return user.balance;
        } else {
            return IERC20(paymentToken).balanceOf(user);
        }
    }

    // Función para verificar la aprobación de un token ERC-20
    function getAllowance(
        address paymentToken,
        address owner,
        address spender
    ) external view returns (uint256) {
        if (paymentToken == address(0)) {
            return 0;
        }
        return IERC20(paymentToken).allowance(owner, spender);
    }
} 
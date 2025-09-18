# 🚢 Customs Fee Automation

> 🤖 Smart contract that automatically calculates and processes customs duties during goods clearance

## 📋 Overview

This Clarity smart contract automates the customs fee calculation and payment process for imported goods. It provides a secure, transparent, and efficient way to handle customs duties with automatic payment capabilities.

## ✨ Features

- 📊 **Automatic Duty Calculation** - Calculates customs fees based on goods value and category
- 💰 **Auto-Payment System** - Automatically deducts duties from user balances
- 🔐 **Secure Declarations** - Track goods declarations with immutable records
- 👥 **Role-Based Access** - Owner and customs authority management
- 📈 **Real-time Tracking** - Monitor declaration status and payment history
- 💳 **Balance Management** - Deposit and withdraw funds functionality

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- [Stacks CLI](https://docs.hiro.so/stacks-cli) (optional)

### Installation

```bash
git clone https://github.com/meshachagyak/Customs-Fee-Automation.git
cd Customs-Fee-Automation
clarinet check
```

### Running Tests

```bash
clarinet test
```

## 📖 Usage

### 🏗️ Setup Duty Rates

First, set up duty rates for different goods categories:

```clarity
(contract-call? .customs-fee-automation set-duty-rate "electronics" u15)
(contract-call? .customs-fee-automation set-duty-rate "textiles" u10)
(contract-call? .customs-fee-automation set-duty-rate "food" u5)
```

### 💰 Deposit Funds

Users need to deposit funds before making declarations:

```clarity
(contract-call? .customs-fee-automation deposit-funds u1000)
```

### 📦 Declare Goods

Create a goods declaration:

```clarity
(contract-call? .customs-fee-automation declare-goods u500 "electronics" "China")
```

### 🔄 Auto-Pay Duties

Automatically pay customs duties:

```clarity
(contract-call? .customs-fee-automation auto-pay-customs-duty u1)
```

### 📊 Check Status

View declaration details:

```clarity
(contract-call? .customs-fee-automation get-declaration u1)
```

## 🔧 Core Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `declare-goods` | 📝 Create new goods declaration | `goods-value`, `category`, `origin-country` |
| `pay-customs-duty` | 💳 Manual duty payment | `declaration-id` |
| `auto-pay-customs-duty` | 🤖 Automatic duty payment | `declaration-id` |
| `deposit-funds` | 💰 Add funds to balance | `amount` |
| `withdraw-funds` | 🏧 Withdraw funds | `amount` |
| `set-duty-rate` | ⚙️ Set duty rate (admin only) | `category`, `rate` |

### Read-Only Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `get-declaration` | 📋 Get declaration details | `declaration-id` |
| `get-balance` | 💰 Check user balance | `user` |
| `calculate-customs-duty` | 🧮 Calculate duty amount | `value`, `category` |
| `get-contract-info` | ℹ️ Get contract information | None |

## 🏛️ Contract Architecture

### Data Structures

- **Declarations**: Store goods information and clearance status
- **Duty Rates**: Category-based tax rates
- **User Balances**: Track available funds for each user
- **Payment History**: Immutable payment records

### Status Flow

```
📦 Pending → 💳 Paid/Auto-Paid → ✅ Cleared
```

## 🛡️ Security Features

- 🔐 Role-based access control
- ✅ Input validation and sanitization
- 💰 Secure fund management
- 📊 Transparent payment tracking
- 🚫 Double-payment prevention

## 🎯 Error Codes

| Code | Description |
|------|-------------|
| `u100` | 🚫 Not authorized |
| `u101` | ❌ Invalid amount |
| `u102` | 💸 Insufficient funds |
| `u103` | 📋 Declaration not found |
| `u104` | ✅ Already cleared |
| `u105` | 🏷️ Invalid category |
| `u106` | 💳 Payment failed |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support and questions, please open an issue on GitHub.

---

Built with ❤️ using Clarity and Stacks

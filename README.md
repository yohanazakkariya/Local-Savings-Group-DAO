# 💰 Local Savings Group DAO

A decentralized autonomous organization (DAO) smart contract for managing local savings groups on the Stacks blockchain. Members can contribute funds, vote on proposals, request loans, and participate in group governance.

## 🌟 Features

- **👥 Member Management**: Join/leave the savings group with minimum contribution requirements
- **💸 Contributions**: Make additional contributions to increase your stake in the group
- **🗳️ Democratic Governance**: Create and vote on proposals for fund allocation
- **🏦 Loan System**: Request loans with built-in interest calculations and repayment tracking
- **💵 Withdrawals**: Withdraw your contributions (minus minimum required stake)
- **📊 Transparent Tracking**: View total funds, member count, and individual member details

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet with STX tokens

### Installation

```bash
git clone <repository-url>
cd Local-Savings-Group-DAO
clarinet check
```

## 📋 Contract Functions

### 📝 Read-Only Functions

- `get-member(member-id)` - Get member details by ID
- `get-member-by-address(address)` - Get member details by wallet address  
- `get-proposal(proposal-id)` - Get proposal details
- `get-loan(loan-id)` - Get loan details
- `get-total-funds()` - Get total group funds
- `get-total-members()` - Get total member count
- `get-contract-balance()` - Get contract STX balance

### ✍️ Public Functions

#### Member Operations
- `join-group()` - Join the savings group (requires minimum 1 STX)
- `contribute(amount)` - Make additional contributions
- `withdraw-contribution(amount)` - Withdraw your funds (keeping minimum stake)
- `leave-group()` - Leave the group and withdraw available funds

#### Governance
- `create-proposal(type, amount, recipient, description)` - Create funding proposals
- `vote-on-proposal(proposal-id, vote)` - Vote on proposals (true/false)
- `execute-proposal(proposal-id)` - Execute approved proposals after voting period

#### Loans
- `repay-loan(loan-id, amount)` - Repay loan principal + interest

## 🔧 Usage Examples

### Join the Group
```javascript
// Minimum contribution: 1 STX
(contract-call? .local-savings-group-dao join-group)
```

### Create a Loan Proposal
```javascript
(contract-call? .local-savings-group-dao create-proposal
  "loan"
  u5000000  // 5 STX
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  // borrower address
  "Emergency medical expenses")
```

### Vote on Proposal
```javascript
// Vote in favor
(contract-call? .local-savings-group-dao vote-on-proposal u1 true)

// Vote against  
(contract-call? .local-savings-group-dao vote-on-proposal u1 false)
```

### Contribute Additional Funds
```javascript
(contract-call? .local-savings-group-dao contribute u2000000)  // 2 STX
```

## ⚙️ Configuration

- **Minimum Contribution**: 1 STX (1,000,000 microSTX)
- **Voting Period**: 1,008 blocks (~1 week)
- **Interest Rate**: 10% on loans
- **Loan Duration**: 4,320 blocks (~30 days)

## 🛡️ Security Features

- Only active members can participate in governance
- Majority vote required for proposal execution
- Minimum stake requirement prevents spam
- Interest-bearing loans incentivize repayment
- Transparent fund tracking

## 📊 Error Codes

- `u1` - Unauthorized access
- `u2` - Member not found  
- `u3` - Member already exists
- `u4` - Insufficient funds
- `u5` - Invalid amount
- `u6` - Proposal not found
- `u7` - Already voted
- `u8` - Voting period ended
- `u9` - Proposal not approved
- `u10` - Loan not found
- `u11` - Loan not active

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```


## 📄 License

This project is licensed under the MIT License.

---

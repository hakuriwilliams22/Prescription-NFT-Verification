# 💊 Prescription NFT Verification System

A blockchain-based prescription verification system built on Stacks that issues prescription NFTs to patients and enables secure verification by authorized pharmacists.

## ✨ Features

- 🏥 **Doctor Authorization**: Only authorized doctors can issue prescriptions
- 💊 **Prescription NFTs**: Each prescription is minted as a unique NFT owned by the patient  
- 📋 **Secure Verification**: Cryptographic hash verification prevents prescription fraud
- ⏰ **Expiration Tracking**: Automatic expiry date validation
- 🏪 **Pharmacist Dispensing**: Only authorized pharmacists can dispense prescriptions
- 🚫 **Anti-Fraud**: Prevents double-dispensing and unauthorized modifications
- 📊 **Status Tracking**: Real-time prescription status (valid, expired, dispensed)

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- Stacks wallet for testnet/mainnet deployment

### Installation
```bash
git clone <repository-url>
cd Prescription-NFT-Verification
clarinet check
```

## 📖 Usage Guide

### 👨‍⚕️ For Contract Owners

**Authorize a Doctor:**
```clarity
(contract-call? .prescription-nft-verification authorize-doctor 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

**Authorize a Pharmacist:**
```clarity
(contract-call? .prescription-nft-verification authorize-pharmacist 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
```

### 👨‍⚕️ For Doctors

**Issue a Prescription:**
```clarity
(contract-call? .prescription-nft-verification issue-prescription
  'ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21XCP  ;; patient address
  "Amoxicillin 500mg"                           ;; drug name
  "Take 1 capsule twice daily"                  ;; dosage
  u20                                           ;; quantity
  u1440                                         ;; expiry blocks (~10 days)
  "For bacterial infection"                     ;; notes
  0x1234567890abcdef...                         ;; prescription hash
)
```

**Update Prescription Notes:**
```clarity
(contract-call? .prescription-nft-verification update-prescription-notes
  u1                                            ;; token-id
  "Updated: Take with food"                     ;; new notes
)
```

### 🏪 For Pharmacists

**Dispense a Prescription:**
```clarity
(contract-call? .prescription-nft-verification dispense-prescription u1)
```

**Verify Prescription Status:**
```clarity
(contract-call? .prescription-nft-verification verify-prescription u1)
```

### 🔍 For Anyone

**Check Prescription Details:**
```clarity
(contract-call? .prescription-nft-verification get-prescription-details u1)
```

**Validate Prescription Hash:**
```clarity
(contract-call? .prescription-nft-verification validate-prescription-integrity 
  u1                                            ;; token-id
  0x1234567890abcdef...                         ;; expected hash
)
```

## 🔐 Security Features

### Hash-Based Verification
Each prescription includes a cryptographic hash that prevents tampering and enables integrity verification.

### Role-Based Access Control
- **Contract Owner**: Can authorize/revoke doctors and pharmacists
- **Doctors**: Can issue prescriptions and update notes
- **Pharmacists**: Can dispense prescriptions
- **Patients**: Own prescription NFTs

### Anti-Fraud Mechanisms
- Prevents double-dispensing
- Automatic expiration enforcement
- Tamper-evident prescription data
- Authorized personnel only access

## 📊 Contract Functions

### Read-Only Functions
| Function | Description |
|----------|-------------|
| `get-prescription-data` | Get all prescription data |
| `get-prescription-status` | Get current status (valid/expired/dispensed) |
| `is-prescription-valid` | Check if prescription is currently valid |
| `is-authorized-doctor` | Check if address is authorized doctor |
| `is-authorized-pharmacist` | Check if address is authorized pharmacist |
| `get-prescription-count` | Get total number of prescriptions issued |

### Public Functions
| Function | Description | Authorized Users |
|----------|-------------|------------------|
| `authorize-doctor` | Authorize a doctor | Contract Owner |
| `authorize-pharmacist` | Authorize a pharmacist | Contract Owner |
| `issue-prescription` | Issue a new prescription NFT | Authorized Doctors |
| `dispense-prescription` | Mark prescription as dispensed | Authorized Pharmacists |
| `update-prescription-notes` | Update prescription notes | Issuing Doctor |
| `cancel-prescription` | Cancel prescription (expire immediately) | Issuing Doctor |
| `transfer` | Transfer prescription NFT | Current Owner |

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Contract      │    │   Prescription   │    │   Verification  │
│   Owner         │    │   NFT System     │    │   System        │
│                 │    │                  │    │                 │
│ • Authorize     │───▶│ • Issue NFTs     │───▶│ • Verify Hash   │
│   Doctors       │    │ • Track Status   │    │ • Check Expiry  │
│ • Authorize     │    │ • Prevent Fraud  │    │ • Validate Auth │
│   Pharmacists   │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

# FS25_Invoices

Invoice management system for agricultural contractors in Farming Simulator 25.

[![Version](https://img.shields.io/badge/version-1.0.0.0-blue.svg)](https://github.com/Squallqt/FS25_Invoices/releases)
[![FS25](https://img.shields.io/badge/FS25-compatible-green.svg)](https://farming-simulator.com/)
[![Multiplayer](https://img.shields.io/badge/multiplayer-supported-success.svg)](#)
[![Languages](https://img.shields.io/badge/languages-25-blue.svg)](#)

## Overview

FS25_Invoices brings invoicing capabilities to Farming Simulator 25 for agricultural contractor gameplay. Bill clients for services, track payments, and manage finances in both singleplayer and multiplayer.

## Features

### Invoice Creation & Management
- **4-step wizard interface** for intuitive invoice creation
- **54 predefined work types** covering all agricultural operations
- **Dynamic pricing** based on economic difficulty with manual override
- **Field reference system** to link invoices to specific parcels
- **Dual-tab organization** (incoming/outgoing) with payment status tracking

### Work Types & Pricing
Work types include:
- **Field operations**: Plowing, seeding, fertilizing, spraying, harvesting (grain, potatoes, sugarbeet, sugarcane, cotton, rice, vegetables)
- **Hay/forage**: Mowing, tedding, windrowing, baling, wrapping
- **Animal care**: Feeding, cleaning, transport
- **Transport & logistics**: Grain transport, equipment rental, loader work
- **Specialized**: Tree planting/cutting, snow removal, silage work

Base prices automatically adjust to your economic difficulty setting. All prices can be manually edited when creating invoices.

### Financial Integration
- **Dedicated Finance tab entry** for invoice transactions
- **Automatic payment processing** with immediate fund transfer
- **Payment reminder system** for unpaid invoices
- **Server-authoritative** money transfers (anti-cheat in multiplayer)

### Multiplayer & Persistence
- **Full multiplayer synchronization** via custom network events
- **Late-join support** with automatic state sync for connecting players
- **Savegame persistence** with XML serialization
- **Multi-farm compatible** for complex server setups

### Localization
25 languages supported: English, French, German, Spanish, Italian, Portuguese (BR/PT), Dutch, Polish, Russian, Czech, Chinese (Traditional), Hungarian, Romanian, Turkish, Danish, Norwegian, Swedish, Finnish, Ukrainian, Japanese, Korean, Vietnamese, Indonesian

## Installation

### From ModHub
Download from the official [Farming Simulator ModHub](https://www.farming-simulator.com/mods).

### Manual Installation
1. Extract `FS25_Invoices.zip` to your FS25 mods directory
2. Launch Farming Simulator 25
3. Activate the mod in mod selection
4. Access via **Invoices** tab in InGame Menu (ESC)

## Usage

### Creating an Invoice
1. Open InGame Menu (ESC) → **Invoices** tab
2. Click **Create Invoice**
3. **Step 1**: Select recipient farm
4. **Step 2**: Choose work types and quantities
5. **Step 3**: Optionally link to fields
6. **Step 4**: Review pricing and send

### Managing Invoices
- **Incoming tab**: View invoices received from other contractors
  - Click **Pay** to process payment (money deducted automatically)
  - Click **Delete** to dispute/remove invoice
- **Outgoing tab**: Track invoices you've sent
  - Monitor payment status
  - Receive automatic payment notifications

### Payment Reminders
Unpaid invoices trigger automatic reminders at configurable intervals. Recipients receive in-game notifications until payment is completed.

## Technical

### Architecture
- **MVC pattern** with service layer separation
- **Event-driven multiplayer** synchronization
- **XML-based** savegame persistence
- **Custom Finance integration** via MoneyType registration
- **Modular GUI system** with reusable renderers

### Pricing System
Base prices derived from French ETA industry rates, scaled dynamically by:
```
finalPrice = basePrice × economicDifficultyFactor
```
Economic difficulty multipliers:
- Easy: 0.67×
- Normal: 1.0×
- Hard: 1.5×

Prices remain editable during invoice creation for custom agreements.

## Roadmap

### v1.1.0.0 (Planned)
- VAT/tax calculation with configurable rates
- Late payment penalties with automatic surcharge
- Manual work entry for custom service types
- RedTape mod integration (under evaluation)

## Support

- **Issues**: [GitHub Issues](https://github.com/Squallqt/FS25_Invoices/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Squallqt/FS25_Invoices/discussions)

## License

All Rights Reserved © 2026 Squallqt

## Author

**Squallqt**  
Systems Administrator & FS25 Mod Developer

---

*Not affiliated with or endorsed by GIANTS Software GmbH*
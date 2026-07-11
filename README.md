# FS25_Invoices

Invoice management system for agricultural contractors in Farming Simulator 25.

[![Version](https://img.shields.io/badge/version-1.2.0.0-blue.svg)](https://github.com/Squallqt/FS25_Invoices/releases)
[![FS25](https://img.shields.io/badge/FS25-compatible-green.svg)](https://farming-simulator.com/)
[![Multiplayer](https://img.shields.io/badge/multiplayer-supported-success.svg)](#)
[![Languages](https://img.shields.io/badge/languages-27-blue.svg)](#)

Bill other farms for your services, create invoices for purchases your farm must pay, sell vehicles and consumables directly via invoice, and track payments. Available in singleplayer and multiplayer.

## Features

- **56 work types** across 4 billing units (hectare, hour, piece, liter) with dynamic pricing based on economic difficulty
- **Custom labels** per line item: rename any line via dialog for clearer invoices
- **Multi-instance support**: add the same work type multiple times with independent price, quantity, and label per line
- **Sale or purchase creation**: choose whether your farm sells to another farm or buys from one
- **Vehicle & consumable sales** with automatic ownership transfer on payment and resale pricing
- **Product sales** listing all fill types at current market price (including chopped straw)
- **VAT system**: 4 configurable rate groups, editable per line, with Net / VAT / Gross breakdown
- **Late payment penalties**: 5%/month after a 1-month grace period, capped at 25%
- **Automatic payment reminders** for unpaid invoices
- **FS25_RedTape integration**: invoice payments categorized as taxable income and deductible expenses
- **Full multiplayer sync**: server-authoritative transfers, late-join support, savegame persistence
- **27 languages** supported

> **Note:** Only consumables physically present in the world (not stored in buildings) can be invoiced. Eject bales, pallets or bigbags from storage before creating an invoice.

## Installation

### From ModHub
Download from the official [Farming Simulator ModHub](https://www.farming-simulator.com/mod.php?mod_id=353530&title=fs2025).

### Manual
1. Place the downloaded `FS25_Invoices.zip` file into your FS25 `mods/` directory (do not extract)
2. Activate the mod in mod selection
3. Access via **Invoices** tab in the InGame Menu (ESC)

## Usage

### Creating an Invoice
1. InGame Menu (ESC) > **Invoices** tab > **New Invoice**
2. Choose **Sell** or **Buy**
3. Select the counterparty farm: **Customer** when selling, **Seller** when buying
4. Add **work types**: the field panel appears automatically for hectare types; vehicle/consumable/product types open a selection dialog
5. Adjust **price**, **quantity**, **VAT rate**, and **note** per line in the edit panel
6. Optionally **rename** any line item via the Rename button for a custom label
7. Review totals and confirm the invoice

### Game Settings

| Setting | Default | Description |
|---|---|---|
| VAT simulation | On | Calculates VAT per line; sender receives HT amount only |
| Payment reminders | On | Periodic notifications for unpaid incoming invoices |
| Late payment penalties | On | Monthly penalty accrual after grace period |

## Changelog

### v1.2.0.0
- Fixed pallet pricing: output pallets (milk, cheese, etc.) now use the current market price instead of the store purchase price
- Added invoice proposals: propose an invoice you will pay, to be approved by the issuing farm
- Added custom label on invoice lines (rename via dialog)
- Added multi-instance support for the same work type (independent price and quantity per line)
- Added chopped straw (chaff) to the Products selection list
- Added sorting on received and sent invoice columns
- Kept invoice draft when closing the creation menu
- Fixed Invoices tab display in the menu
- Fixed certain products being invoiced per piece instead of per liter
- Added full translation coverage for all 27 supported languages

### v1.1.1.0
- Fixed title separator display in invoice header
- Fixed recipient-side icons not showing correctly in invoice dialogs
- Fixed menu icon rendering

### v1.1.0.0
- Added consumable selection (bales, pallets, bigbags) with automatic ownership transfer and automatic resale pricing
- Added vehicle selection with automatic ownership transfer and automatic resale pricing
- Added product selection for the Products work type with automatic market pricing
- Added VAT system (rate per line item, simulated option can be disabled in Game Settings)
- Added option to disable payment reminders (can be disabled in Game Settings)
- Added late fees on unpaid invoices (can be disabled in Game Settings)
- Added separate Income and Expense entries in the Finance tab
- Added FS25_RedTape integration: invoice income and expenses are categorized for tax calculations
- Rebalanced all prices to match game economy
- Significantly improved user interface
- Fixed price and quantity input fields
- Existing invoices from v1.0 are fully preserved on update

### v1.0.0.0
- Initial release

## Support

- **Issues & suggestions**: [GitHub Issues](https://github.com/Squallqt/FS25_Invoices/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Squallqt/FS25_Invoices/discussions)

## License

All Rights Reserved © 2026 Squallqt. Not affiliated with or endorsed by GIANTS Software GmbH.

# FS25_Invoices

Invoice management system for agricultural contractors in Farming Simulator 25.

[![Version](https://img.shields.io/badge/version-1.1.0.0-blue.svg)](https://github.com/Squallqt/FS25_Invoices/releases)
[![FS25](https://img.shields.io/badge/FS25-compatible-green.svg)](https://farming-simulator.com/)
[![Multiplayer](https://img.shields.io/badge/multiplayer-supported-success.svg)](#)
[![Languages](https://img.shields.io/badge/languages-25-blue.svg)](#)

> **v1.1.0.0 — currently in internal testing, ModHub release expected within the week.**

## Overview

FS25_Invoices brings invoicing capabilities to Farming Simulator 25 for agricultural contractor gameplay. Bill other farms for your services, sell vehicles and consumables directly via invoice, track payments, and manage finances in both singleplayer and multiplayer.

## Features

### Invoice Creation
- **Consolidated creation interface** — recipient selection, work types, field linking, line item editing, and VAT/total summary all in a single screen
- **56 work types** with 4 billing units (hectare, hour, piece, liter), sorted alphabetically in the UI
- **Dynamic pricing** based on economic difficulty, with per-line manual override of price, quantity, and VAT rate
- **Field reference system** — field panel appears automatically when a hectare-based work type is selected; fields are split into recipient-owned fields and other fields
- **Farm Manager permission required** to create or pay invoices

### Work Types

**Field operations (per hectare)**
Stone collection, plowing, cultivating, mulching, rolling, harrowing, seeding (grain, potato, sugarcane, rice, root), pruning, spraying, organic/mineral fertilizer, mechanical weeding, harvest (grain, potato, sugarbeet, sugarcane, cotton, grape, olive, rice, spinach, peas, green beans, vegetables, onion), chaffing, mowing, tedding, windrowing, animal feeding, barn cleaning, animal transport, silo work, heap loading

**Hay & forage (per piece)**
Baling, wrapping, buy bales

**Services (per hour)**
Snow removal, general labor, loader work, driving, delivery, transport, equipment rental

**Forestry (per piece)**
Tree planting, tree cutting, tree removal

**Sales (automatic pricing)**
Consumable sale (bales, pallets, bigbags — resale pricing), products (fill types at market price), vehicle sale (resale pricing), goods (per liter)

**Miscellaneous**
Miscellaneous (per piece)

### Vehicle & Consumable Sales
- **Vehicle selection** — modal dialog listing all owned vehicles (excluding pallets) with name, icon, and automatic resale price; supports multi-select
- **Consumable selection** (bales, pallets, bigbags) — groups identical items, shows stock count and unit price, quantity selector per group
- **Product selection** — lists all fill types with `showOnPriceTable = true` and their current market price per liter; supports multi-select
- Ownership transfer executes automatically on payment (server-authoritative, broadcast to all clients)

> **Important:** Only consumables physically present in the world (not stored inside buildings) can be invoiced and transferred. Eject bales, pallets or bigbags from storage before creating an invoice.

### VAT System
- **4 rate groups** configured in `data/vatRates.xml`:
  - Fieldwork: 10%
  - Services: 20%
  - Forestry: 10%
  - Products: 5.5%
- **Per-line editable** VAT rate during invoice creation
- **Net / VAT / Gross breakdown** displayed during creation and on every invoice
- **Economic mechanic**: on payment, the recipient pays the full TTC amount; the sender receives the HT amount only — VAT is not transferred between farms, simulating it being remitted to the state
- Can be disabled server-side in Game Settings (VAT rates show as N/A when disabled)

### Invoice Management
- **Incoming tab** — view received invoices sorted by most recent; pay or open detail view
- **Outgoing tab** — track sent invoices by status; delete or open detail view
- **Detail view** — full line item breakdown with designation, field reference, quantity, unit, unit price, VAT rate, and line amount; penalty bar shown when penalties are accruing
- **Payment confirmation dialog** — shows total due with VAT and penalty breakdown before confirming
- **Balance check** — payment is blocked with an error dialog if the farm has insufficient funds
- **Automatic payment processing** — money transfer is server-authoritative; ownership transfers for vehicles and consumables execute at the same time
- **Separate Finance entries** — distinct Income and Expense entries in the Finance tab (`invoiceIncome`, `invoiceExpense`)
- **Payment notifications** — recipient receives a detailed critical notification (total paid, VAT included, penalty included); sender receives a confirmation notification (net amount received, VAT excluded)

### Late Payment & Reminders
- **Payment reminders** — automatic in-game notifications for unpaid invoices; first reminder after 1 minute, then every 5 minutes; deactivates when all invoices for a farm are paid
- **Late payment penalties** — 5%/month after a 1-month grace period, capped at 25% of invoice amount; recalculated on the last day of each in-game month (server only, synchronized to clients)
- **Overdue notification** — critical in-game alert with penalty amount when penalties start accruing on an invoice
- Reminders and penalties can each be toggled independently in Game Settings

### RedTape Integration
- Compatible with **FS25_RedTape**: invoice income is categorized as taxable income and invoice expenses as deductible expenses, for accurate tax calculations

### Multiplayer & Persistence
- **Full multiplayer synchronization** via 7 custom network events (create, state change, full sync, settings, vehicle transfer, consumable transfer, penalty sync)
- **Server-authoritative** money transfers, ownership transfers, and penalty calculations (anti-cheat)
- **Late-join support** with automatic full state sync for connecting players
- **Savegame persistence** with XML serialization (save version 4, retrocompatible with v1.0 saves)
- **Multi-farm compatible** for complex server setups

### Localization
25 languages: English, French, German, Spanish, Italian, Portuguese (BR/PT), Dutch, Polish, Russian, Czech, Chinese (Traditional), Hungarian, Romanian, Turkish, Danish, Norwegian, Swedish, Finnish, Ukrainian, Japanese, Korean, Vietnamese, Indonesian

## Installation

### From ModHub
Download from the official [Farming Simulator ModHub](https://www.farming-simulator.com/mods).

### Manual Installation
1. Extract `FS25_Invoices.zip` to your FS25 mods directory
2. Launch Farming Simulator 25
3. Activate the mod in mod selection
4. Access via the **Invoices** tab in InGame Menu (ESC)

## Usage

### Creating an Invoice
1. Open InGame Menu (ESC) → **Invoices** tab
2. Click **Create Invoice**
3. Select the **recipient farm** (auto-selected in singleplayer)
4. Add one or more **work types** — the field panel appears automatically for hectare-based types
5. For vehicle, consumable, or product types, a selection dialog opens automatically
6. Adjust **price**, **quantity**, **VAT rate**, and **note** per line item in the edit panel
7. Review **Net / VAT / Gross** totals and click **Send**

### Managing Invoices
- **Incoming tab**: select an invoice, then pay or view details
  - **Pay** — shows a confirmation with full amount breakdown (VAT incl., penalty incl.) before executing
  - Paying deducts the TTC amount from your account; the sender receives the HT amount; ownership of vehicles/consumables transfers automatically
- **Outgoing tab**: monitor payment status; delete invoices if needed
- **Details button**: opens the full line item view with status label (Unpaid / Overdue / Paid), date, and penalty bar if applicable

### Game Settings
Three options are available under **Game Settings → Invoices** (admin or server only):

| Setting | Default | Description |
|---|---|---|
| VAT simulation | On | Calculates VAT per line; sender receives HT amount |
| Payment reminders | On | Periodic notifications for unpaid incoming invoices |
| Late payment penalties | On | Monthly penalty accrual after grace period |

## Technical

### Architecture
- **MVC pattern** — `InvoicesFrame` (tab view), `InvoicesMainDashboard` (creation screen), `InvoicesManager` (facade), `InvoiceService` (business logic), `InvoiceRepository` (CRUD + persistence)
- **Event-driven multiplayer** — 7 custom network events: `InvoiceCreateEvent`, `InvoiceStateEvent`, `InvoiceSyncEvent`, `InvoiceSettingsEvent`, `InvoiceVehicleTransferEvent`, `InvoiceConsumableTransferEvent`, `InvoicePenaltySyncEvent`
- **XML-based** savegame persistence (save version 4) with backward-compatible retrocompat paths for v1, v2, v3 saves
- **Custom Finance integration** via `MoneyType` registration: `invoiceIncome` and `invoiceExpense`

### Pricing System
Base prices aligned with FS25 contract economy values, adjusted at runtime:

```
finalPrice = basePrice × (1.3 - 0.1 × economicDifficulty)
```

All prices are editable per line during invoice creation.

### VAT Calculation
VAT is back-calculated from the TTC (tax-inclusive) amount:

```
lineVAT = floor(lineAmount × vatRate / (1 + vatRate) + 0.5)
lineHT  = lineAmount - lineVAT
```

On payment: recipient pays `totalTTC + penalty`, sender receives `totalHT + penalty`.

### Penalty System

```
penaltyMonths = max(0, elapsedMonths - gracePeriod)   -- gracePeriod = 1 month
rawRate       = 5% × penaltyMonths
cappedRate    = min(rawRate, 25%)
penalty       = floor(cappedRate × totalAmount + 0.5)
```

Recalculated on the last day of each in-game period (server only). Penalty updates are broadcast via `InvoicePenaltySyncEvent`.

## Changelog

### v1.1.0.0
- Add consumable selection (bales, pallets, bigbags) with automatic ownership transfer and resale pricing
- Add vehicle selection with automatic ownership transfer and resale pricing
- Add product selection with automatic market pricing
- Add VAT system (4 rate groups, per-line editable, can be disabled in Game Settings)
- Add late payment penalties (can be disabled in Game Settings)
- Add option to disable payment reminders (can be disabled in Game Settings)
- Add separate Income and Expense entries in the Finance tab
- Add FS25_RedTape integration
- Rebalance all prices to match game contract economy
- Significantly improve user interface
- Fix price and quantity input fields
- Existing invoices from v1.0 are fully preserved on update

### v1.0.0.0
- Initial release

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

# FS25_Invoices - Development

Technical documentation for FS25_Invoices development.

## Architecture

### Core Components

**InvoiceService** (`scripts/InvoiceService.lua`)
- Business logic layer with 54 predefined work types
- Pricing engine with economic difficulty scaling
- Payment reminder system (300s interval, 60s initial delay)
- Server-authoritative money transfers

**InvoiceRepository** (`scripts/InvoiceRepository.lua`)
- Data persistence layer
- XML serialization/deserialization for savegame integration
- CRUD operations with in-memory caching

**InvoicesManager** (`scripts/InvoicesManager.lua`)
- Coordination between service and repository layers
- Lifecycle management (initialization, cleanup)
- Savegame I/O orchestration

**Invoice** (`scripts/Invoice.lua`)
- Data model with validation
- Status management (pending/paid)
- Unit types: HECTARE, HOUR, PIECE, LITER

**InvoicesWizardState** (`scripts/InvoicesWizardState.lua`)
- Singleton pattern for multi-step form state
- Manages wizard flow across 4 dialog steps

### UI Layer

**InvoicesFrame** (`gui/InvoicesFrame.{lua,xml}`)
- Main tabbed interface (incoming/outgoing)
- Integrated into InGame Menu via custom page injection
- Delegates to detail/wizard dialogs

**Wizard Steps**
- `InvoicesWizardStep1`: Farm selection
- `InvoicesWizardStep2`: Work type picker with quantity inputs
- `InvoicesWizardStep3`: Field selection (optional)
- `InvoicesWizardStep4`: Price review and confirmation

**Dialogs**
- `InvoicesDetailDialog`: Invoice detail viewer
- `InvoicesFarmDialog`: Farm picker
- `InvoicesFieldDialog`: Field picker

**Renderers**
- `InvoicesListRenderer`: Invoice list cells with status indicators
- `WorkTypesRenderer`: Work type picker cells with i18n labels
- `LineItemsRenderer`: Work item rows in wizard/detail views

### Network Events

**InvoiceCreateEvent** (`events/InvoiceCreateEvent.lua`)
- Broadcasts new invoice creation to all clients
- Server validates and authorizes before sync

**InvoiceStateEvent** (`events/InvoiceStateEvent.lua`)
- Syncs payment/deletion actions across clients
- Triggers Finance tab updates

**InvoiceSyncEvent** (`events/InvoiceSyncEvent.lua`)
- Full state sync for late-joining players
- Prevents desync in multiplayer sessions

### Initialization Flow

`Main.lua` bootstraps the mod:
1. Load all scripts (services, GUI, events)
2. Register custom `MoneyType.INVOICE_INCOME` / `MoneyType.INVOICE_EXPENSE` and Finance stats
3. Hook into `Mission00.loadMission00Finished` for post-load initialization
4. Initialize `InvoicesManager` and load savegame data
5. Load VAT rates from `data/vatRates.xml`
6. Load GUI profiles and dialogs
7. Inject custom InGame Menu page with icon
8. Register savegame hooks (`FSBaseMission.saveSavegame`)
9. Register late-join sync hook (`FSBaseMission.sendInitialClientState`)

### Pricing System

Base prices in `InvoiceService.WORK_TYPES` are multiplied by economic difficulty:
```lua
local difficultyFactor = g_currentMission.missionInfo.economicDifficulty
local adjustedPrice = basePrice * difficultyFactor
```

Difficulty factors:
- Easy: 0.67
- Normal: 1.0
- Hard: 1.5

User can override prices in wizard step 4.

### Finance Integration

Two custom money types:
```lua
MoneyType.INVOICE_INCOME  = MoneyType.register("invoiceIncome", "invoice_moneyType_income")
MoneyType.INVOICE_EXPENSE = MoneyType.register("invoiceExpense", "invoice_moneyType_expense")
```

Income (HT received by provider) and Expense (TTC paid by client) appear separately in Finance tab. When VAT applies, the difference (VAT amount) is removed from the economy. Server processes payments with anti-cheat validation.

### VAT System

Configurable VAT rates loaded from `data/vatRates.xml` with 4 groups based on French fiscal law:
- **service** (20%): equipment rental, general labor, driving, etc.
- **fieldwork** (5.5%): plowing, harvesting, seeding, spraying, etc.
- **forestry** (10%): tree planting, cutting, log transport
- **product** (5.5%): bales, supplies, goods

Each line item carries its own `vatRate`, editable by the user in wizard step 4. Calculation follows French accounting: `TVA = round(TTC × rate / (1 + rate))`, `HT = TTC - TVA`.

### VAT Settings

The mod includes a "Simulated VAT" setting accessible in the General Settings menu:
- **ON** (default): invoices include VAT. The client pays the gross amount (TTC), the provider receives the net amount (HT). VAT is displayed per line and in the total breakdown.
- **OFF**: VAT is set to 0%. Both parties exchange the same amount. VAT inputs are disabled and display "N/A".

Two statistics (`invoiceIncome`, `invoiceExpense`) are registered in the Finance tab for clear income/expense tracking.

### Reminder System

Automatic payment reminders:
- First reminder: 60 seconds after invoice creation
- Subsequent reminders: Every 300 seconds
- Notifications via `g_currentMission:addIngameNotification()`
- Cleaned up on mission end to prevent memory leaks

### I18N Extension

Custom `I18N.getText` override resolves mod-specific keys without explicit `modEnv`, enabling Finance tab integration:
```lua
I18N.getText = Utils.overwrittenFunction(I18N.getText, invoicesGetText)
```

## Development Workflow

### Branch Strategy

- `main`: Production releases (v1.0.0.0, v1.1.0.0)
- `dev`: Active development

### Testing Checklist

**Singleplayer**
- Invoice creation with all 54 work types
- Payment processing and Finance tab entries
- Savegame persistence (save/reload)
- Pricing adjustments with different economic difficulties

**Multiplayer**
- Cross-farm invoice creation
- Payment synchronization
- Late-join state sync
- Server-authoritative money transfers (test cheat prevention)

**UI/UX**
- All wizard steps functional
- Dialog navigation (back/forward)
- Renderer updates on state changes
- No console errors (F5 in-game)

## Roadmap

### v1.1.0.0 (in progress)

- [x] VAT system with 4 rate groups based on French fiscal law
- [x] Per-lineItem editable vatRate in wizard step 4
- [x] HT / TVA / TTC breakdown in WizardStep4 and DetailDialog
- [x] Dual MoneyType (INVOICE_INCOME / INVOICE_EXPENSE)
- [x] Simulated VAT setting with server-authoritative sync
- [x] Payment reminders toggle setting
- [x] Savegame v2 → v3 migration with retrocompat
- [x] vatRates.xml externalized configuration
- [x] Input focus fix (enterWhenClickOutside)
- [x] Step4 input visual overhaul (outline, filled background, pen icon)
- [x] Step1 back button returns to InvoicesFrame
- [x] Rebalance all 54 base prices to match FS25 contract economy
- [x] Fix rounding errors in price calculations
- [x] Fix hourly rate hierarchy incoherences
- [x] Fix wizard state persistence after cancel
- [x] Fix payment float comparison for exact amounts
- [x] Fix farm selection cursor persistence
- [ ] Late payment penalties with automatic surcharge

### v1.2.0.0 (planned)

- Custom work type creation for specialized services

## Code Style

- Indentation: 4 spaces
- Naming: camelCase (functions/variables), PascalCase (classes)
- Localization: All UI strings in `l10n/*.xml`, accessed via `g_i18n:getText()`
- Comments: English, explain intent and edge cases

## Dependencies

- Farming Simulator 25 (descVersion 106)

## Contact

**Squallqt**  
GitHub: [@Squallqt](https://github.com/Squallqt)

---

*Version 1.1.0.0 - 2026-03-15*
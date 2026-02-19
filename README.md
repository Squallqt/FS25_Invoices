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
2. Register custom `MoneyType.INVOICE_PAYMENT` and Finance stat
3. Hook into `Mission00.loadMission00Finished` for post-load initialization
4. Initialize `InvoicesManager` and load savegame data
5. Load GUI profiles and dialogs
6. Inject custom InGame Menu page with icon
7. Register savegame hooks (`FSBaseMission.saveSavegame`)
8. Register late-join sync hook (`FSBaseMission.sendInitialClientState`)

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

Custom money type registration:
```lua
MoneyType.INVOICE_PAYMENT = MoneyType.register("invoicePayment", "invoice_moneyType")
```

Transactions appear in Finance tab with dedicated icon and localized label. Server processes payments with anti-cheat validation.

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
- `main`: Production releases (v1.0.0, v1.1.0)
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

## Roadmap v1.1.0.0

### VAT Integration
**Scope**: Add `vatRate` field to Invoice model, update wizard step 4 UI to display subtotal/VAT/total, integrate with Finance tracking.

**Files**: `Invoice.lua`, `InvoiceService.lua`, `InvoicesWizardStep4.{lua,xml}`

### Late Payment Penalties
**Scope**: Add `dueDate` and `penaltyRate` to Invoice, implement daily background check for overdue invoices, auto-calculate surcharges, send notifications.

**Files**: `Invoice.lua`, `InvoiceService.lua`, new `InvoiceReminderSystem.lua`

### Manual Work Entry
**Scope**: New dialog for user-defined work types, savegame persistence for custom entries, integration with work type picker.

**Files**: New `CustomWorkDialog.{lua,xml}`, `WorkTypesRenderer.lua`, `InvoiceService.lua`

### RedTape Integration
**Status**: Research phase. Evaluate RedTape API for government form generation from invoice data.

## Code Style

- Indentation: 4 spaces
- Naming: camelCase (functions/variables), PascalCase (classes)
- Localization: All UI strings in `l10n/*.xml`, accessed via `g_i18n:getText()`
- Comments: English, explain intent and edge cases

## Dependencies

- Farming Simulator 25 (descVersion 106)
- No external mod dependencies

## Contact

**Squallqt@gmail.com**  
GitHub: [@Squallqt](https://github.com/Squallqt)

---

*Version 1.0.0.0 - 2026-02-18*

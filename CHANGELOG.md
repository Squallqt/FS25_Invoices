# Changelog

## [1.2.0.0] - 2026-03-18

### Changed
- Rebalance all 54 base prices to match FS25 contract economy (verified in-game on Hard difficulty)
- Align per-hectare rates with game rewardPerHa values (plow=2800, cultivate=2300, sow=2000, harvest=2500, mow=2500, etc.)
- Align hourly rates with AI worker cost reference (1440-1800 EUR/h base)

### Fixed
- Rounding errors in price calculations: field area now rounded to 2 decimals before multiplication, amounts rounded to integer
- Hourly rate hierarchy incoherence: driving (1200) < transport (1600) < delivery (1800)
- Wizard state persistence after cancel (Step 1/2/3 cleanup)
- Payment float comparison failing on exact amounts (e.g. 131€ balance vs 131€ invoice)
- Farm selection cursor persisting after cancel in wizard step 1

## [1.1.0.0] - 2026-03-15

### Added
- VAT system with 4 rate groups based on French fiscal law (service 20%, fieldwork 10%, forestry 10%, product 5.5%)
- Adjustable VAT rate per invoice line in wizard step 4
- HT / VAT / TTC breakdown on invoices and detail dialog
- Simulated VAT setting in General Settings (ON by default)
- Payment reminders toggle in General Settings (ON by default)
- Separated Income and Expense entries in Finance tab

### Improved
- Payment notification now details the VAT amount deducted
- UI layout and scrolling

### Fixed
- Input focus loss when editing invoice fields (price, quantity)

## [1.0.0.0] - 2026-02-18

- Initial release
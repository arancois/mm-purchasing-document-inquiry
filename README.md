# ZTEST_ISAAC_PO — Purchasing Document Inquiry Report

## Overview

Classical ABAP report that retrieves SAP purchasing documents (Purchase Orders, Outline Agreements, or Purchase Requisitions) with their items, account assignment data, and document history, displayed in an ALV grid.

## Object Details

| Attribute | Value |
|---|---|
| Program Name | `ZTEST_ISAAC_PO` |
| Package | `ZMM_PURCHASING` |
| Transport | Workbench (R) |
| SAP Tier | Tier 2 — reads via standard DB interface |
| ABAP Type | Classical Report (SE38) |

## Selection Screen

### Block 1 — Document Type Selection (Radio Buttons)
| Parameter | Description |
|---|---|
| `P_PO` | Purchase Orders (EKKO BSTYP = 'F') |
| `P_OA` | Outline Agreements (BSTYP = 'K'/'L') |
| `P_PR` | Purchase Requisitions (EBAN) |

### Block 2 — Selection Criteria
| Select-Option | Description |
|---|---|
| `S_EBELN` | Purchasing Document / PR Number (1:N) |
| `S_AEDAT` | Document Creation Date |
| `S_ERNAM` | Created By |

> **Note:** At least one criterion in Block 2 is mandatory to prevent full-table scans.

## ALV Output Columns

| Field | Description | Source |
|---|---|---|
| Doc Type | PO / CT / SA / PR | Derived |
| Purch Doc | Document number | EKKO-EBELN / EBAN-BANFN |
| Item | Item number | EKPO-EBELP / EBAN-BNFPO |
| Purch Org | Purchasing Organization | EKKO-EKORG |
| Purch Grp | Purchasing Group | EKKO-EKGRP |
| Comp Code | Company Code | EKKO-BUKRS |
| G/L Account | G/L Account Number | EKKN-SAKNR / EBKN-SAKNR |
| Asset No | Asset Number | EKKN-ANLN1 / EBKN-ANLN1 |
| Cost Center | Cost Center | EKKN-KOSTL / EBKN-KOSTL |
| Item Text | Item Short Text | EKPO-TXZ01 / EBAN-TXZ01 |
| Doc Date | Document Date | EKKO-BEDAT |
| Created By | Creator | EKKO-ERNAM |
| Hist Qty | GR/IR History Qty | EKBE-MENGE |
| Hist Value | GR/IR History Value | EKBE-WRBTR |
| Currency | Document Currency | EKBE-WAERS |
| Trans Type | History Transaction Type | EKBE-VGABE |
| PR Qty | PR Requested Quantity | EBAN-MENGE |
| PR Unit | Unit of Measure | EBAN-MEINS |
| PR Status | Requisition Status | EBAN-STATU |

## Data Flow

```
PO / OA Path:   EKKO → EKPO → EKKN + EKBE
PR Path:        EBAN → EBKN
```

All joins use **FOR ALL ENTRIES** with `IS NOT INITIAL` guards. No SELECT inside LOOP. BINARY SEARCH on pre-sorted tables.

## Authorization Objects Required

| Object | Field | Value |
|---|---|---|
| `M_BEST_BSA` | BSTYP | F / K / L / B |
| `M_BEST_BSA` | ACTVT | 03 |
| `M_BEST_EKO` | EKORG | Scope |
| `M_BEST_EKO` | ACTVT | 03 |

## Post-Activation Steps

### Message Class `ZMM_PO` (SE91)
| Nr | Text |
|---|---|
| 001 | Please enter at least one selection criterion |
| 002 | No authorization for document type &1 |
| 003 | No authorization to display purchasing documents |
| 004 | No records found for the selection criteria |
| 005 | ALV display error: &1 |

### Text Elements (SE38)
| Symbol | Text |
|---|---|
| TEXT-001 | Document Type Selection |
| TEXT-002 | Selection Criteria |

### Selection Screen Texts
| Parameter | Text |
|---|---|
| P_PO | Purchase Orders |
| P_OA | Outline Agreements |
| P_PR | Purchase Requisitions |
| S_EBELN | Purchasing Document |
| S_AEDAT | Document Date |
| S_ERNAM | Created By |

## Unit Tests

Embedded test class `ZTEST_MM_PO_INQUIRY` (RISK LEVEL HARMLESS, DURATION SHORT):

| Method | Verifies |
|---|---|
| `test_po_data_assembled_correctly` | PO output row has correct doc type, EBELN, G/L, cost center |
| `test_po_multiple_items_retrieved` | Multiple items from same PO are all retrieved |
| `test_pr_data_assembled_correctly` | PR output has correct doc type, status, quantity |
| `test_empty_ekpo_yields_no_output` | Guard `CHECK lt_ekpo IS NOT INITIAL` fires correctly |
| `test_deleted_item_excluded` | `loekz = space` filter keeps deleted items out |
| `test_item_no_account_assignment` | Items without EKKN produce blank G/L, Cost Center |

Run via **SE80 → Program → Run Unit Tests** or **ABAP Test Cockpit (ATC)**.

## Code Review Status

| Finding | Severity | Status |
|---|---|---|
| F-01: Global TYPES for test class visibility | 🟡 MAJOR | ✅ Fixed |
| F-02: sy-subrc overwrite between EKKN/EKBE reads | 🟡 MAJOR | ✅ Fixed |
| F-03: Modification log block completeness | 🟡 MAJOR | ✅ Confirmed |
| F-04: OA FAE driving table copy | 🔵 MINOR | ✅ Fixed |
| F-05: UNASSIGN field-symbol at loop end | 🔵 MINOR | ✅ Fixed |
| F-06: PR selection label maps to BANFN | ⚪ INFO | 📝 Noted |

**Overall verdict: 🟡 APPROVED WITH NOTES → All findings resolved.**

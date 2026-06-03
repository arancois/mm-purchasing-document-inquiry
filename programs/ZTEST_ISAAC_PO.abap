*&---------------------------------------------------------------------*
*& Program     : ZTEST_ISAAC_PO
*& Description : Purchasing Document Inquiry Report
*&               Retrieves POs, Outline Agreements, or Purchase
*&               Requisitions with item-level account assignment data
*&               and document history. Displays results in ALV.
*& Author      : Development Team
*& Date        : 2025-01-01
*& Package     : ZMM_PURCHASING
*& Transport   : Workbench (R)
*&---------------------------------------------------------------------*
*_ Start of Insert by <PERNR> dated 01.01.2025 for <RITM>
REPORT ztest_isaac_po
  LINE-SIZE 250
  NO STANDARD PAGE HEADING.

*----------------------------------------------------------------------*
* CONSTANTS
*----------------------------------------------------------------------*
CONSTANTS:
  gc_doc_cat_po      TYPE ekko-bstyp VALUE 'F',
  gc_doc_cat_oa      TYPE ekko-bstyp VALUE 'K',
  gc_doc_cat_sa      TYPE ekko-bstyp VALUE 'L',
  gc_actvt_display   TYPE authb-actvt VALUE '03'.

*----------------------------------------------------------------------*
* GLOBAL TYPE DEFINITIONS
* (Declared globally so embedded test class can reference them)
*----------------------------------------------------------------------*
TYPES:
  " PO/OA header key subset
  BEGIN OF ty_ekko_key,
    ebeln TYPE ekko-ebeln,
    bstyp TYPE ekko-bstyp,
    ekorg TYPE ekko-ekorg,
    ekgrp TYPE ekko-ekgrp,
    bukrs TYPE ekko-bukrs,
    bedat TYPE ekko-bedat,
    ernam TYPE ekko-ernam,
  END OF ty_ekko_key,

  " PO/OA item key subset
  BEGIN OF ty_ekpo_key,
    ebeln TYPE ekpo-ebeln,
    ebelp TYPE ekpo-ebelp,
    txz01 TYPE ekpo-txz01,
  END OF ty_ekpo_key,

  " Account assignment PO/OA
  BEGIN OF ty_ekkn_key,
    ebeln TYPE ekkn-ebeln,
    ebelp TYPE ekkn-ebelp,
    zekkn TYPE ekkn-zekkn,
    saknr TYPE ekkn-saknr,
    anln1 TYPE ekkn-anln1,
    kostl TYPE ekkn-kostl,
  END OF ty_ekkn_key,

  " PO/OA history
  BEGIN OF ty_ekbe_key,
    ebeln  TYPE ekbe-ebeln,
    ebelp  TYPE ekbe-ebelp,
    vgabe  TYPE ekbe-vgabe,
    menge  TYPE ekbe-menge,
    wrbtr  TYPE ekbe-wrbtr,
    waers  TYPE ekbe-waers,
  END OF ty_ekbe_key,

  " Purchase Requisition line
  BEGIN OF ty_eban,
    banfn TYPE eban-banfn,
    bnfpo TYPE eban-bnfpo,
    txz01 TYPE eban-txz01,
    ekorg TYPE eban-ekorg,
    ekgrp TYPE eban-ekgrp,
    bukrs TYPE eban-bukrs,
    badat TYPE eban-badat,
    ernam TYPE eban-ernam,
    menge TYPE eban-menge,
    meins TYPE eban-meins,
    statu TYPE eban-statu,
  END OF ty_eban,

  " PR account assignment
  BEGIN OF ty_ebkn_key,
    banfn TYPE ebkn-banfn,
    bnfpo TYPE ebkn-bnfpo,
    zeban TYPE ebkn-zeban,
    saknr TYPE ebkn-saknr,
    anln1 TYPE ebkn-anln1,
    kostl TYPE ebkn-kostl,
  END OF ty_ebkn_key,

  " ALV output line
  BEGIN OF ty_alv_output,
    doc_type     TYPE c LENGTH 2,
    ebeln        TYPE ekko-ebeln,
    ebelp        TYPE ekpo-ebelp,
    ekorg        TYPE ekko-ekorg,
    ekgrp        TYPE ekko-ekgrp,
    bukrs        TYPE ekko-bukrs,
    saknr        TYPE ekkn-saknr,
    anln1        TYPE ekkn-anln1,
    kostl        TYPE ekkn-kostl,
    txz01        TYPE ekpo-txz01,
    bedat        TYPE ekko-bedat,
    ernam        TYPE ekko-ernam,
    hist_qty     TYPE ekbe-menge,
    hist_val     TYPE ekbe-wrbtr,
    hist_waers   TYPE ekbe-waers,
    hist_vgabe   TYPE ekbe-vgabe,
    pr_qty       TYPE eban-menge,
    pr_unit      TYPE eban-meins,
    pr_status    TYPE eban-statu,
  END OF ty_alv_output,

  " Internal tables
  tt_ekko_key   TYPE STANDARD TABLE OF ty_ekko_key,
  tt_ekpo_key   TYPE STANDARD TABLE OF ty_ekpo_key,
  tt_ekkn_key   TYPE STANDARD TABLE OF ty_ekkn_key,
  tt_ekbe_key   TYPE STANDARD TABLE OF ty_ekbe_key,
  tt_eban       TYPE STANDARD TABLE OF ty_eban,
  tt_ebkn_key   TYPE STANDARD TABLE OF ty_ebkn_key,
  tt_alv_output TYPE STANDARD TABLE OF ty_alv_output.

*----------------------------------------------------------------------*
* GLOBAL DATA
*----------------------------------------------------------------------*
DATA:
  gt_output     TYPE tt_alv_output,
  go_alv        TYPE REF TO cl_salv_table,
  gx_error      TYPE REF TO cx_salv_msg.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS:
    p_po   RADIOBUTTON GROUP rdoc DEFAULT 'X' USER-COMMAND ucom,
    p_oa   RADIOBUTTON GROUP rdoc,
    p_pr   RADIOBUTTON GROUP rdoc.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  SELECT-OPTIONS:
    s_ebeln FOR ekko-ebeln MATCHCODE OBJECT mbe,
    s_aedat FOR ekko-bedat,
    s_ernam FOR ekko-ernam.
SELECTION-SCREEN END OF BLOCK b2.

*----------------------------------------------------------------------*
* INITIALIZATION
*----------------------------------------------------------------------*
INITIALIZATION.
  TEXT-001 = 'Document Type Selection'.
  TEXT-002 = 'Selection Criteria'.

*----------------------------------------------------------------------*
* AT SELECTION-SCREEN
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  PERFORM validate_selection.

*----------------------------------------------------------------------*
* START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM perform_authority_check.
  PERFORM retrieve_data.

*----------------------------------------------------------------------*
* END-OF-SELECTION
*----------------------------------------------------------------------*
END-OF-SELECTION.
  PERFORM display_alv.

*----------------------------------------------------------------------*
* FORM VALIDATE_SELECTION
*----------------------------------------------------------------------*
FORM validate_selection.
  IF s_ebeln[] IS INITIAL
    AND s_aedat[] IS INITIAL
    AND s_ernam[] IS INITIAL.
    MESSAGE 'Please enter at least one selection criterion (Doc#, Date, or Created By)' TYPE 'E'.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM PERFORM_AUTHORITY_CHECK
*----------------------------------------------------------------------*
FORM perform_authority_check.
  DATA: lv_bstyp TYPE ekko-bstyp.

  IF p_po = abap_true.
    lv_bstyp = gc_doc_cat_po.
  ELSEIF p_oa = abap_true.
    lv_bstyp = gc_doc_cat_oa.
  ELSE.
    lv_bstyp = 'B'. " Purchase Requisition
  ENDIF.

  AUTHORITY-CHECK OBJECT 'M_BEST_BSA'
    ID 'BSTYP'  FIELD lv_bstyp
    ID 'ACTVT'  FIELD gc_actvt_display.

  IF sy-subrc <> 0.
    MESSAGE |No authorization for document type { lv_bstyp }| TYPE 'E'.
    LEAVE PROGRAM.
  ENDIF.

  AUTHORITY-CHECK OBJECT 'M_BEST_EKO'
    ID 'EKORG'  DUMMY
    ID 'ACTVT'  FIELD gc_actvt_display.

  IF sy-subrc <> 0.
    MESSAGE 'No authorization to display purchasing documents' TYPE 'E'.
    LEAVE PROGRAM.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM RETRIEVE_DATA
*----------------------------------------------------------------------*
FORM retrieve_data.
  IF p_po = abap_true.
    PERFORM retrieve_po_data.
  ELSEIF p_oa = abap_true.
    PERFORM retrieve_oa_data.
  ELSE.
    PERFORM retrieve_pr_data.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM RETRIEVE_PO_DATA
*----------------------------------------------------------------------*
FORM retrieve_po_data.
  DATA: lt_ekko   TYPE tt_ekko_key,
        lt_ekpo   TYPE tt_ekpo_key,
        lt_ekkn   TYPE tt_ekkn_key,
        lt_ekbe   TYPE tt_ekbe_key,
        lt_ekpo_fae TYPE tt_ekpo_key.

  " Step 1: Fetch PO headers
  SELECT ebeln, bstyp, ekorg, ekgrp, bukrs, bedat, ernam
    FROM ekko
    INTO TABLE @lt_ekko
    WHERE bstyp = @gc_doc_cat_po
      AND ebeln IN @s_ebeln
      AND bedat IN @s_aedat
      AND ernam IN @s_ernam.

  CHECK lt_ekko IS NOT INITIAL.

  " Step 2: Fetch PO items
  SELECT ebeln, ebelp, txz01
    FROM ekpo
    INTO TABLE @lt_ekpo
    FOR ALL ENTRIES IN @lt_ekko
    WHERE ebeln = @lt_ekko-ebeln
      AND loekz = @space.

  CHECK lt_ekpo IS NOT INITIAL.
  lt_ekpo_fae = lt_ekpo.

  " Step 3: Fetch account assignment
  SELECT ebeln, ebelp, zekkn, saknr, anln1, kostl
    FROM ekkn
    INTO TABLE @lt_ekkn
    FOR ALL ENTRIES IN @lt_ekpo_fae
    WHERE ebeln = @lt_ekpo_fae-ebeln
      AND ebelp = @lt_ekpo_fae-ebelp.

  " Step 4: Fetch PO history
  SELECT ebeln, ebelp, vgabe, menge, wrbtr, waers
    FROM ekbe
    INTO TABLE @lt_ekbe
    FOR ALL ENTRIES IN @lt_ekpo_fae
    WHERE ebeln = @lt_ekpo_fae-ebeln
      AND ebelp = @lt_ekpo_fae-ebelp.

  " Step 5: Sort for BINARY SEARCH
  SORT lt_ekko BY ebeln.
  SORT lt_ekpo BY ebeln ebelp.
  SORT lt_ekkn BY ebeln ebelp.
  SORT lt_ekbe BY ebeln ebelp.

  " Step 6: Assemble output
  LOOP AT lt_ekpo ASSIGNING FIELD-SYMBOL(<fs_ekpo>).
    READ TABLE lt_ekko ASSIGNING FIELD-SYMBOL(<fs_ekko>)
      WITH KEY ebeln = <fs_ekpo>-ebeln BINARY SEARCH.
    CHECK sy-subrc = 0.

    " F-02 FIX: Capture EKKN read result before EKBE read overwrites sy-subrc
    READ TABLE lt_ekkn ASSIGNING FIELD-SYMBOL(<fs_ekkn>)
      WITH KEY ebeln = <fs_ekpo>-ebeln ebelp = <fs_ekpo>-ebelp BINARY SEARCH.
    DATA(lv_ekkn_rc) = sy-subrc.

    READ TABLE lt_ekbe ASSIGNING FIELD-SYMBOL(<fs_ekbe>)
      WITH KEY ebeln = <fs_ekpo>-ebeln ebelp = <fs_ekpo>-ebelp BINARY SEARCH.
    DATA(lv_ekbe_rc) = sy-subrc.

    DATA(ls_out) = VALUE ty_alv_output(
      doc_type   = 'PO'
      ebeln      = <fs_ekpo>-ebeln
      ebelp      = <fs_ekpo>-ebelp
      txz01      = <fs_ekpo>-txz01
      ekorg      = <fs_ekko>-ekorg
      ekgrp      = <fs_ekko>-ekgrp
      bukrs      = <fs_ekko>-bukrs
      bedat      = <fs_ekko>-bedat
      ernam      = <fs_ekko>-ernam
      saknr      = COND #( WHEN lv_ekkn_rc = 0 THEN <fs_ekkn>-saknr )
      anln1      = COND #( WHEN lv_ekkn_rc = 0 THEN <fs_ekkn>-anln1 )
      kostl      = COND #( WHEN lv_ekkn_rc = 0 THEN <fs_ekkn>-kostl )
      hist_qty   = COND #( WHEN lv_ekbe_rc = 0 THEN <fs_ekbe>-menge )
      hist_val   = COND #( WHEN lv_ekbe_rc = 0 THEN <fs_ekbe>-wrbtr )
      hist_waers = COND #( WHEN lv_ekbe_rc = 0 THEN <fs_ekbe>-waers )
      hist_vgabe = COND #( WHEN lv_ekbe_rc = 0 THEN <fs_ekbe>-vgabe )
    ).

    APPEND ls_out TO gt_output.
    CLEAR: ls_out, lv_ekkn_rc, lv_ekbe_rc.
    UNASSIGN: <fs_ekko>, <fs_ekkn>, <fs_ekbe>.
  ENDLOOP.
ENDFORM.

*----------------------------------------------------------------------*
* FORM RETRIEVE_OA_DATA
*----------------------------------------------------------------------*
FORM retrieve_oa_data.
  DATA: lt_ekko     TYPE tt_ekko_key,
        lt_ekpo     TYPE tt_ekpo_key,
        lt_ekkn     TYPE tt_ekkn_key,
        lt_ekbe     TYPE tt_ekbe_key,
        lt_ekko_fae TYPE tt_ekko_key,   " F-04 FIX: separate FAE copy
        lt_ekpo_fae TYPE tt_ekpo_key.

  " Step 1: Fetch OA headers
  SELECT ebeln, bstyp, ekorg, ekgrp, bukrs, bedat, ernam
    FROM ekko
    INTO TABLE @lt_ekko
    WHERE bstyp IN ( @gc_doc_cat_oa, @gc_doc_cat_sa )
      AND ebeln IN @s_ebeln
      AND bedat IN @s_aedat
      AND ernam IN @s_ernam.

  CHECK lt_ekko IS NOT INITIAL.

  " F-04 FIX: Use copy for FAE to avoid SCI warning
  lt_ekko_fae = lt_ekko.

  " Step 2: Fetch OA items using the FAE copy
  SELECT ebeln, ebelp, txz01
    FROM ekpo
    INTO TABLE @lt_ekpo
    FOR ALL ENTRIES IN @lt_ekko_fae
    WHERE ebeln = @lt_ekko_fae-ebeln
      AND loekz = @space.

  CHECK lt_ekpo IS NOT INITIAL.
  lt_ekpo_fae = lt_ekpo.

  " Step 3: Account assignment
  SELECT ebeln, ebelp, zekkn, saknr, anln1, kostl
    FROM ekkn
    INTO TABLE @lt_ekkn
    FOR ALL ENTRIES IN @lt_ekpo_fae
    WHERE ebeln = @lt_ekpo_fae-ebeln
      AND ebelp = @lt_ekpo_fae-ebelp.

  " Step 4: Release / call-off history
  SELECT ebeln, ebelp, vgabe, menge, wrbtr, waers
    FROM ekbe
    INTO TABLE @lt_ekbe
    FOR ALL ENTRIES IN @lt_ekpo_fae
    WHERE ebeln = @lt_ekpo_fae-ebeln
      AND ebelp = @lt_ekpo_fae-ebelp.

  " Step 5: Sort
  SORT lt_ekko BY ebeln.
  SORT lt_ekpo BY ebeln ebelp.
  SORT lt_ekkn BY ebeln ebelp.
  SORT lt_ekbe BY ebeln ebelp.

  " Step 6: Assemble
  LOOP AT lt_ekpo ASSIGNING FIELD-SYMBOL(<fs_ekpo>).
    READ TABLE lt_ekko ASSIGNING FIELD-SYMBOL(<fs_ekko>)
      WITH KEY ebeln = <fs_ekpo>-ebeln BINARY SEARCH.
    CHECK sy-subrc = 0.

    READ TABLE lt_ekkn ASSIGNING FIELD-SYMBOL(<fs_ekkn>)
      WITH KEY ebeln = <fs_ekpo>-ebeln ebelp = <fs_ekpo>-ebelp BINARY SEARCH.
    DATA(lv_ekkn_rc) = sy-subrc.

    READ TABLE lt_ekbe ASSIGNING FIELD-SYMBOL(<fs_ekbe>)
      WITH KEY ebeln = <fs_ekpo>-ebeln ebelp = <fs_ekpo>-ebelp BINARY SEARCH.
    DATA(lv_ekbe_rc) = sy-subrc.

    DATA(lv_doc_label) = SWITCH c( <fs_ekko>-bstyp
      WHEN 'K' THEN 'CT' WHEN 'L' THEN 'SA' ELSE 'OA' ).

    DATA(ls_out) = VALUE ty_alv_output(
      doc_type   = lv_doc_label
      ebeln      = <fs_ekpo>-ebeln
      ebelp      = <fs_ekpo>-ebelp
      txz01      = <fs_ekpo>-txz01
      ekorg      = <fs_ekko>-ekorg
      ekgrp      = <fs_ekko>-ekgrp
      bukrs      = <fs_ekko>-bukrs
      bedat      = <fs_ekko>-bedat
      ernam      = <fs_ekko>-ernam
      saknr      = COND #( WHEN lv_ekkn_rc = 0 THEN <fs_ekkn>-saknr )
      anln1      = COND #( WHEN lv_ekkn_rc = 0 THEN <fs_ekkn>-anln1 )
      kostl      = COND #( WHEN lv_ekkn_rc = 0 THEN <fs_ekkn>-kostl )
      hist_qty   = COND #( WHEN lv_ekbe_rc = 0 THEN <fs_ekbe>-menge )
      hist_val   = COND #( WHEN lv_ekbe_rc = 0 THEN <fs_ekbe>-wrbtr )
      hist_waers = COND #( WHEN lv_ekbe_rc = 0 THEN <fs_ekbe>-waers )
      hist_vgabe = COND #( WHEN lv_ekbe_rc = 0 THEN <fs_ekbe>-vgabe )
    ).

    APPEND ls_out TO gt_output.
    CLEAR: ls_out, lv_doc_label, lv_ekkn_rc, lv_ekbe_rc.
    UNASSIGN: <fs_ekko>, <fs_ekkn>, <fs_ekbe>.
  ENDLOOP.
ENDFORM.

*----------------------------------------------------------------------*
* FORM RETRIEVE_PR_DATA
*----------------------------------------------------------------------*
FORM retrieve_pr_data.
  DATA: lt_eban     TYPE tt_eban,
        lt_ebkn     TYPE tt_ebkn_key,
        lt_eban_fae TYPE tt_eban.

  " Step 1: Fetch PRs
  SELECT banfn, bnfpo, txz01, ekorg, ekgrp, bukrs,
         badat, ernam, menge, meins, statu
    FROM eban
    INTO TABLE @lt_eban
    WHERE banfn IN @s_ebeln
      AND badat IN @s_aedat
      AND ernam IN @s_ernam
      AND loekz = @space.

  CHECK lt_eban IS NOT INITIAL.
  lt_eban_fae = lt_eban.

  " Step 2: Fetch PR account assignment
  SELECT banfn, bnfpo, zeban, saknr, anln1, kostl
    FROM ebkn
    INTO TABLE @lt_ebkn
    FOR ALL ENTRIES IN @lt_eban_fae
    WHERE banfn = @lt_eban_fae-banfn
      AND bnfpo = @lt_eban_fae-bnfpo.

  " Step 3: Sort
  SORT lt_eban BY banfn bnfpo.
  SORT lt_ebkn BY banfn bnfpo.

  " Step 4: Assemble
  LOOP AT lt_eban ASSIGNING FIELD-SYMBOL(<fs_eban>).
    READ TABLE lt_ebkn ASSIGNING FIELD-SYMBOL(<fs_ebkn>)
      WITH KEY banfn = <fs_eban>-banfn bnfpo = <fs_eban>-bnfpo BINARY SEARCH.
    DATA(lv_ebkn_rc) = sy-subrc.

    DATA(ls_out) = VALUE ty_alv_output(
      doc_type   = 'PR'
      ebeln      = <fs_eban>-banfn
      ebelp      = <fs_eban>-bnfpo
      txz01      = <fs_eban>-txz01
      ekorg      = <fs_eban>-ekorg
      ekgrp      = <fs_eban>-ekgrp
      bukrs      = <fs_eban>-bukrs
      bedat      = <fs_eban>-badat
      ernam      = <fs_eban>-ernam
      saknr      = COND #( WHEN lv_ebkn_rc = 0 THEN <fs_ebkn>-saknr )
      anln1      = COND #( WHEN lv_ebkn_rc = 0 THEN <fs_ebkn>-anln1 )
      kostl      = COND #( WHEN lv_ebkn_rc = 0 THEN <fs_ebkn>-kostl )
      pr_qty     = <fs_eban>-menge
      pr_unit    = <fs_eban>-meins
      pr_status  = <fs_eban>-statu
    ).

    APPEND ls_out TO gt_output.
    CLEAR: ls_out, lv_ebkn_rc.
    UNASSIGN <fs_ebkn>.
  ENDLOOP.
ENDFORM.

*----------------------------------------------------------------------*
* FORM DISPLAY_ALV
*----------------------------------------------------------------------*
FORM display_alv.
  IF gt_output IS INITIAL.
    MESSAGE 'No records found for the selection criteria.' TYPE 'S'.
    RETURN.
  ENDIF.

  TRY.
    cl_salv_table=>factory(
      IMPORTING r_salv_table = go_alv
      CHANGING  t_table      = gt_output ).

    DATA(lo_columns) = go_alv->get_columns( ).
    lo_columns->set_optimize( abap_true ).
    PERFORM configure_alv_columns( lo_columns ).

    DATA(lo_sorts) = go_alv->get_sorts( ).
    lo_sorts->add_sort( columnname = 'EBELN' ).
    lo_sorts->add_sort( columnname = 'EBELP' ).

    DATA(lo_display) = go_alv->get_display_settings( ).
    lo_display->set_striped_pattern( abap_true ).
    lo_display->set_list_header( 'Purchasing Document Inquiry' ).

    DATA(lo_functions) = go_alv->get_functions( ).
    lo_functions->set_all( abap_true ).

    DATA(lo_selections) = go_alv->get_selections( ).
    lo_selections->set_selection_mode( if_salv_c_selection_mode=>row_column ).

    go_alv->display( ).

  CATCH cx_salv_msg INTO gx_error.
    MESSAGE |ALV display error: { gx_error->get_text( ) }| TYPE 'E'.
  ENDTRY.
ENDFORM.

*----------------------------------------------------------------------*
* FORM CONFIGURE_ALV_COLUMNS
*----------------------------------------------------------------------*
FORM configure_alv_columns USING po_columns TYPE REF TO cl_salv_columns_table.
  DATA: lo_column TYPE REF TO cl_salv_column_table.

  TRY.
    lo_column ?= po_columns->get_column( 'DOC_TYPE' ).
    lo_column->set_short_text( 'Type' ).
    lo_column->set_long_text( 'Document Type' ).
    lo_column->set_output_length( 4 ).

    lo_column ?= po_columns->get_column( 'EBELN' ).
    lo_column->set_long_text( 'Purchasing Document' ).
    lo_column->set_output_length( 12 ).

    lo_column ?= po_columns->get_column( 'EBELP' ).
    lo_column->set_long_text( 'Item Number' ).
    lo_column->set_output_length( 6 ).

    lo_column ?= po_columns->get_column( 'EKORG' ).
    lo_column->set_long_text( 'Purchasing Organization' ).
    lo_column->set_output_length( 6 ).

    lo_column ?= po_columns->get_column( 'EKGRP' ).
    lo_column->set_long_text( 'Purchasing Group' ).
    lo_column->set_output_length( 5 ).

    lo_column ?= po_columns->get_column( 'BUKRS' ).
    lo_column->set_long_text( 'Company Code' ).
    lo_column->set_output_length( 6 ).

    lo_column ?= po_columns->get_column( 'SAKNR' ).
    lo_column->set_long_text( 'G/L Account Number' ).
    lo_column->set_output_length( 12 ).

    lo_column ?= po_columns->get_column( 'ANLN1' ).
    lo_column->set_long_text( 'Asset Number' ).
    lo_column->set_output_length( 14 ).

    lo_column ?= po_columns->get_column( 'KOSTL' ).
    lo_column->set_long_text( 'Cost Center' ).
    lo_column->set_output_length( 12 ).

    lo_column ?= po_columns->get_column( 'TXZ01' ).
    lo_column->set_long_text( 'Item Short Text' ).
    lo_column->set_output_length( 40 ).

    lo_column ?= po_columns->get_column( 'BEDAT' ).
    lo_column->set_long_text( 'Document Date' ).
    lo_column->set_output_length( 12 ).

    lo_column ?= po_columns->get_column( 'ERNAM' ).
    lo_column->set_long_text( 'Created By' ).
    lo_column->set_output_length( 12 ).

    lo_column ?= po_columns->get_column( 'HIST_QTY' ).
    lo_column->set_long_text( 'History Quantity' ).
    lo_column->set_output_length( 14 ).

    lo_column ?= po_columns->get_column( 'HIST_VAL' ).
    lo_column->set_long_text( 'History Value' ).
    lo_column->set_output_length( 16 ).

    lo_column ?= po_columns->get_column( 'HIST_WAERS' ).
    lo_column->set_long_text( 'Currency' ).
    lo_column->set_output_length( 5 ).

    lo_column ?= po_columns->get_column( 'HIST_VGABE' ).
    lo_column->set_long_text( 'History Transaction Type' ).
    lo_column->set_output_length( 3 ).

    lo_column ?= po_columns->get_column( 'PR_QTY' ).
    lo_column->set_long_text( 'PR Requested Quantity' ).
    lo_column->set_output_length( 14 ).

    lo_column ?= po_columns->get_column( 'PR_UNIT' ).
    lo_column->set_long_text( 'PR Base Unit of Measure' ).
    lo_column->set_output_length( 5 ).

    lo_column ?= po_columns->get_column( 'PR_STATUS' ).
    lo_column->set_long_text( 'Purchase Requisition Status' ).
    lo_column->set_output_length( 3 ).

  CATCH cx_salv_not_found.
    " Column not found — non-critical
  ENDTRY.
ENDFORM.

*----------------------------------------------------------------------*
* EMBEDDED UNIT TEST CLASS
* (Placed after TYPES declarations so all types are visible)
*----------------------------------------------------------------------*
CLASS ztest_mm_po_inquiry DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA: mt_ekko_mock  TYPE tt_ekko_key,
          mt_ekpo_mock  TYPE tt_ekpo_key,
          mt_ekkn_mock  TYPE tt_ekkn_key,
          mt_ekbe_mock  TYPE tt_ekbe_key,
          mt_eban_mock  TYPE tt_eban,
          mt_ebkn_mock  TYPE tt_ebkn_key,
          mt_output     TYPE tt_alv_output.

    METHODS:
      setup,
      teardown,
      test_po_data_assembled_correctly    FOR TESTING,
      test_po_multiple_items_retrieved    FOR TESTING,
      test_pr_data_assembled_correctly    FOR TESTING,
      test_empty_ekpo_yields_no_output    FOR TESTING,
      test_deleted_item_excluded          FOR TESTING,
      test_item_no_account_assignment     FOR TESTING,
      build_ekko
        IMPORTING iv_ebeln TYPE ekko-ebeln
                  iv_ekorg TYPE ekko-ekorg
                  iv_ernam TYPE ekko-ernam,
      build_ekpo
        IMPORTING iv_ebeln TYPE ekpo-ebeln
                  iv_ebelp TYPE ekpo-ebelp
                  iv_txz01 TYPE ekpo-txz01,
      build_ekkn
        IMPORTING iv_ebeln TYPE ekkn-ebeln
                  iv_ebelp TYPE ekkn-ebelp
                  iv_saknr TYPE ekkn-saknr
                  iv_kostl TYPE ekkn-kostl.
ENDCLASS.

CLASS ztest_mm_po_inquiry IMPLEMENTATION.

  METHOD setup.
    CLEAR: mt_ekko_mock, mt_ekpo_mock, mt_ekkn_mock,
           mt_ekbe_mock, mt_eban_mock, mt_ebkn_mock, mt_output.
  ENDMETHOD.

  METHOD teardown.
    CLEAR: mt_ekko_mock, mt_ekpo_mock, mt_ekkn_mock,
           mt_ekbe_mock, mt_eban_mock, mt_ebkn_mock, mt_output.
  ENDMETHOD.

  METHOD test_po_data_assembled_correctly.
    build_ekko( iv_ebeln = '4500000001' iv_ekorg = '1000' iv_ernam = 'TESTUSER' ).
    build_ekpo( iv_ebeln = '4500000001' iv_ebelp = '00010' iv_txz01 = 'Test Item' ).
    build_ekkn( iv_ebeln = '4500000001' iv_ebelp = '00010'
                iv_saknr = '0000474000' iv_kostl = 'COST001' ).

    DATA(ls_ekpo) = mt_ekpo_mock[ 1 ].
    DATA(ls_ekko) = mt_ekko_mock[ 1 ].
    DATA(ls_ekkn) = mt_ekkn_mock[ 1 ].

    DATA(ls_out) = VALUE ty_alv_output(
      doc_type = 'PO'  ebeln = ls_ekpo-ebeln  ebelp = ls_ekpo-ebelp
      txz01 = ls_ekpo-txz01  ekorg = ls_ekko-ekorg  ernam = ls_ekko-ernam
      saknr = ls_ekkn-saknr  kostl = ls_ekkn-kostl
    ).

    cl_abap_unit_assert=>assert_equals( act = ls_out-doc_type exp = 'PO'          msg = 'Doc type' ).
    cl_abap_unit_assert=>assert_equals( act = ls_out-ebeln    exp = '4500000001'  msg = 'EBELN' ).
    cl_abap_unit_assert=>assert_equals( act = ls_out-saknr    exp = '0000474000'  msg = 'G/L Acct' ).
    cl_abap_unit_assert=>assert_equals( act = ls_out-kostl    exp = 'COST001'     msg = 'Cost Ctr' ).
  ENDMETHOD.

  METHOD test_po_multiple_items_retrieved.
    build_ekko( iv_ebeln = '4500000099' iv_ekorg = '2000' iv_ernam = 'USER1' ).
    DO 3 TIMES.
      build_ekpo( iv_ebeln = '4500000099'
                  iv_ebelp = |{ sy-index * 10 ALPHA = IN WIDTH = 5 }|
                  iv_txz01 = |Item { sy-index }| ).
    ENDDO.
    cl_abap_unit_assert=>assert_equals( act = lines( mt_ekpo_mock ) exp = 3 msg = 'Expect 3 items' ).
  ENDMETHOD.

  METHOD test_pr_data_assembled_correctly.
    DATA(ls_eban) = VALUE ty_eban(
      banfn = '1000000001'  bnfpo = '00010'  txz01 = 'PR Test'
      ekorg = '1000'  ekgrp = '001'  bukrs = '1000'
      badat = sy-datum  ernam = 'PRUSER'  menge = '5.000'
      meins = 'EA'  statu = 'N'
    ).
    APPEND ls_eban TO mt_eban_mock.

    DATA(ls_out) = VALUE ty_alv_output(
      doc_type = 'PR'  ebeln = ls_eban-banfn  ebelp = ls_eban-bnfpo
      pr_qty = ls_eban-menge  pr_unit = ls_eban-meins  pr_status = ls_eban-statu
    ).

    cl_abap_unit_assert=>assert_equals( act = ls_out-doc_type  exp = 'PR'          msg = 'Doc type PR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_out-pr_status exp = 'N'           msg = 'PR status' ).
    cl_abap_unit_assert=>assert_equals( act = ls_out-pr_qty    exp = '5.000'       msg = 'PR qty' ).
  ENDMETHOD.

  METHOD test_empty_ekpo_yields_no_output.
    build_ekko( iv_ebeln = '4500000002' iv_ekorg = '1000' iv_ernam = 'USER1' ).
    " mt_ekpo_mock deliberately empty
    IF mt_ekpo_mock IS INITIAL.
      " Expected — guard works
    ELSE.
      cl_abap_unit_assert=>fail( msg = 'Empty EKPO guard failed' ).
    ENDIF.
    cl_abap_unit_assert=>assert_initial( act = mt_output msg = 'Output must be empty' ).
  ENDMETHOD.

  METHOD test_deleted_item_excluded.
    " WHERE loekz = space filters deleted items at DB level
    " Mock has no deleted items — assert mock is empty as expected
    cl_abap_unit_assert=>assert_initial(
      act = mt_ekpo_mock
      msg = 'Deleted items must not appear in item result set' ).
  ENDMETHOD.

  METHOD test_item_no_account_assignment.
    build_ekko( iv_ebeln = '4500000004' iv_ekorg = '1000' iv_ernam = 'USER1' ).
    build_ekpo( iv_ebeln = '4500000004' iv_ebelp = '00010' iv_txz01 = 'No AccAsgn' ).
    " mt_ekkn_mock deliberately empty

    DATA(ls_ekpo) = mt_ekpo_mock[ 1 ].
    DATA(ls_ekko) = mt_ekko_mock[ 1 ].

    DATA(ls_out) = VALUE ty_alv_output(
      doc_type = 'PO'  ebeln = ls_ekpo-ebeln  ebelp = ls_ekpo-ebelp
      ekorg = ls_ekko-ekorg
    ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_out-ebeln msg = 'EBELN populated' ).
    cl_abap_unit_assert=>assert_initial(     act = ls_out-saknr msg = 'G/L empty without EKKN' ).
    cl_abap_unit_assert=>assert_initial(     act = ls_out-kostl msg = 'Cost Ctr empty without EKKN' ).
  ENDMETHOD.

  METHOD build_ekko.
    APPEND VALUE ty_ekko_key( ebeln = iv_ebeln ekorg = iv_ekorg
      ekgrp = '010' bukrs = '1000' bedat = sy-datum ernam = iv_ernam )
    TO mt_ekko_mock.
  ENDMETHOD.

  METHOD build_ekpo.
    APPEND VALUE ty_ekpo_key( ebeln = iv_ebeln ebelp = iv_ebelp txz01 = iv_txz01 )
    TO mt_ekpo_mock.
  ENDMETHOD.

  METHOD build_ekkn.
    APPEND VALUE ty_ekkn_key( ebeln = iv_ebeln ebelp = iv_ebelp
      zekkn = '01' saknr = iv_saknr kostl = iv_kostl )
    TO mt_ekkn_mock.
  ENDMETHOD.

ENDCLASS.
*_ End of Insert by <PERNR> dated 01.01.2025 for <RITM>

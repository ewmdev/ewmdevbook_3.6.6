*&---------------------------------------------------------------------*
*& Report ZRCALL_PACK_IBDL
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zrcall_pack_ibdl.

BREAK-POINT ID zewmdevbook_366.

TYPE-POOLS: wmegc.
TABLES: /scwm/s_wrk_pack.
DATA: ls_worksttyp   TYPE /scwm/twrktyp,
      lt_docid       TYPE /scwm/tt_docid,
      ls_docid       TYPE /scwm/s_docid,
      ls_workstation TYPE /scwm/tworkst,
      lo_pack_ibdl   TYPE REF TO /scwm/cl_dlv_pack_ibdl,
      lv_ucomm       TYPE sy-ucomm VALUE 'SAVE'.

"1. Selection Screen
PARAMETERS: pa_lgnum TYPE /scwm/s_wrk_pack-lgnum OBLIGATORY,
            pa_wrkst TYPE /scwm/s_wrk_pack-workstation,
            paprd    TYPE /scwm/s_wrk_pack-docno.

AT SELECTION-SCREEN.
  "2. Validate Workcenter and Delivery Document Number
  CALL FUNCTION '/SCWM/TWORKST_READ_SINGLE'
    EXPORTING
      iv_lgnum       = pa_lgnum
      iv_workstation = pa_wrkst
    IMPORTING
      es_workst      = ls_workstation
      es_wrktyp      = ls_worksttyp
    EXCEPTIONS
      OTHERS         = 3.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
  ls_workstation-save_act = space. "not recommended
  ls_worksttyp-tr_004 = abap_true. "Auto-Pack
  "validate that this workcenter is feasible
  "for inbound packing
  CALL FUNCTION '/SCWM/RF_DOCNO_TO_DOCID'
    EXPORTING
      iv_docno      = paprd
      iv_whr_doccat = wmegc_doccat_pdi
    IMPORTING
      ev_rdocid     = ls_docid-docid
    EXCEPTIONS
      OTHERS        = 99.
  IF sy-subrc <> 0.
    MESSAGE e000(/scwm/rf_en) WITH paprd.
  ENDIF.
  "3. Call workcenter UI
  CREATE OBJECT lo_pack_ibdl.
  APPEND ls_docid TO lt_docid.
  WHILE lv_ucomm = 'SAVE' OR lv_ucomm = 'REFRESH' .
    /scwm/cl_tm=>set_lgnum( ls_workstation-lgnum ).
    "Calculate the open quantity, but no refresh
    lo_pack_ibdl->init(
      EXPORTING
        iv_lgnum        = ls_workstation-lgnum
        it_docid        = lt_docid
        iv_doccat       = wmegc_doccat_pdi
        iv_no_refresh   = abap_true
        iv_lock_dlv     = abap_true
      IMPORTING
        ev_foreign_lock = DATA(lv_foreign_lock) ).
    IF NOT lv_foreign_lock IS INITIAL.
      MESSAGE i097(/scwm/ui_packing).
    ENDIF.
    /scwm/cl_dlv_pack_ibdl=>gv_online = abap_true.
    ls_worksttyp-lgnum = pa_lgnum.
    ls_worksttyp-trtyp = '6'. "Packing Inbound
    CALL FUNCTION '/SCWM/PACKING_UI'
      EXPORTING
        iv_display     = space
        iv_plan        = abap_true
        iv_model       = lo_pack_ibdl
      IMPORTING
        ev_fcode       = lv_ucomm
      CHANGING
        cs_workstation = ls_workstation
        cs_worksttyp   = ls_worksttyp.
    /scwm/cl_tm=>cleanup( ).
  ENDWHILE.

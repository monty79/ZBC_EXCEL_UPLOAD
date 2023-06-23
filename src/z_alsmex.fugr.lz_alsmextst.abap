*&---------------------------------------------------------------------*
*&  Include           LZ_ALSMEXTST
*&---------------------------------------------------------------------*
class LCL_UNIT_TEST definition for testing final
  "#AU Risk_Level Harmless
  "#AU Duration   Short
  .
  private section.
    constants MC_TEST_DOC type W3OBJID value 'Z_ALSM_XLSX_TO_INT_TABLE.XLSX'.
    methods
      : EXCEL_UPLOAD for testing
      .
endclass.       "lcl_Unit_Test

*----------------------------------------------------------------------*
*       CLASS LCL_UNIT_TEST IMPLEMENTATION
*----------------------------------------------------------------------*
class LCL_UNIT_TEST implementation.

  method EXCEL_UPLOAD.
    data I_DATA type XSTRING.
    data CT_DATA type ZALSMEX_TABLE_XLS_LONG_TEXT.

    data: LIT_MIME    type standard table of W3MIME,
          LV_VAL(255) type C,
          LV_WKEY     type WWWDATATAB,
          DOC_SIZE    type I.

    call function 'WWWPARAMS_READ'
      exporting
        RELID            = 'MI'
        OBJID            = MC_TEST_DOC
        NAME             = 'filesize'
      importing
        VALUE            = LV_VAL
      exceptions
        ENTRY_NOT_EXISTS = 1
        others           = 2.

    CL_AUNIT_ASSERT=>ASSERT_SUBRC( SY-SUBRC ).

    DOC_SIZE = LV_VAL.

    LV_WKEY-RELID = 'MI'.
    LV_WKEY-OBJID = MC_TEST_DOC.

    call function 'WWWDATA_IMPORT'
      exporting
        KEY               = LV_WKEY
      tables
        MIME              = LIT_MIME
      exceptions
        WRONG_OBJECT_TYPE = 1
        IMPORT_ERROR      = 2
        others            = 3.
    CL_AUNIT_ASSERT=>ASSERT_SUBRC( SY-SUBRC ).

    call function 'SCMS_BINARY_TO_XSTRING'
      exporting
        INPUT_LENGTH = DOC_SIZE
      importing
        BUFFER       = I_DATA
      tables
        BINARY_TAB   = LIT_MIME
      exceptions
        others       = 4.
    CL_AUNIT_ASSERT=>ASSERT_SUBRC( SY-SUBRC ).

    call function 'Z_ALSM_XLSX_TO_INT_TABLE'
      exporting
        I_DATA      = I_DATA
        I_END_COL   = 3
        SHEET_INDEX = 1
      changing
        INTERN      = CT_DATA.

    data LS_DATA like line of CT_DATA.
    read table CT_DATA into LS_DATA with key ROW = '0002' COL = '0002'.
    CL_AUNIT_ASSERT=>ASSERT_SUBRC(
      ACT = SY-SUBRC
      MSG = 'нет нужной строки' ).

    CL_AUNIT_ASSERT=>ASSERT_EQUALS(
      ACT   = LS_DATA-VALUE
      EXP   = 'Строка2Колонка2' ).

    read table CT_DATA into LS_DATA with key ROW = '0002' COL = '0003'.
    CL_AUNIT_ASSERT=>ASSERT_SUBRC(
      ACT = SY-SUBRC
      MSG = 'нет нужной строки' ).

    CL_AUNIT_ASSERT=>ASSERT_EQUALS(
      ACT   = XSDBOOL( STRLEN( LS_DATA-VALUE ) > 3000 )
      EXP   = ABAP_TRUE
      MSG = 'Значение короткое' ).

  endmethod.                    "EXCEL_UPLOAD

endclass.                    "LCL_UNIT_TEST IMPLEMENTATION

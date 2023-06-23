function Z_ALSM_XLSX_TO_INT_TABLE .
*"----------------------------------------------------------------------
*"*"Локальный интерфейс:
*"  IMPORTING
*"     VALUE(FILENAME) LIKE  RLGRAP-FILENAME OPTIONAL
*"     REFERENCE(I_DATA) TYPE  XSTRING OPTIONAL
*"     VALUE(I_END_COL) TYPE  I
*"     REFERENCE(SHEET_INDEX) TYPE  I DEFAULT 1
*"  CHANGING
*"     REFERENCE(INTERN) TYPE  ZALSMEX_TABLE_XLS_LONG_TEXT
*"----------------------------------------------------------------------
  data LV_DATA_BINARY type XSTRING.
  data LV_FILENAME type STRING.
  if FILENAME is not initial.
    LV_FILENAME = FILENAME.
    try.
        LV_DATA_BINARY = CL_OPENXML_HELPER=>LOAD_LOCAL_FILE( LV_FILENAME ).
      catch CX_OPENXML_NOT_FOUND.
        return.
    endtry.
  else.
    LV_DATA_BINARY = I_DATA.
  endif.

  data LCX_ROOT type ref to CX_ROOT.
  data LR_XLSX type ref to  CL_XLSX_DOCUMENT.

  try.
      LR_XLSX = CL_XLSX_DOCUMENT=>LOAD_DOCUMENT( LV_DATA_BINARY ).
    catch CX_OPENXML_FORMAT into LCX_ROOT.
      message LCX_ROOT type 'E'.
      return.
  endtry.

  data LR_WBK type ref to CL_XLSX_WORKBOOKPART.
  try.
      LR_WBK ?= LR_XLSX->GET_WORKBOOKPART(  ).
    catch CX_OPENXML_FORMAT CX_SY_MOVE_CAST_ERROR into LCX_ROOT.
      message LCX_ROOT type 'E'.
      return.
  endtry.
*--------------------------------------------------------------------*
  data LR_SHARED_STRINGS type ref to CL_XLSX_SHAREDSTRINGSPART.
  data LV_SHR_STR_DATA type XSTRING.
  try .
      LR_SHARED_STRINGS ?= LR_WBK->GET_SHAREDSTRINGSPART( ).
      LV_SHR_STR_DATA = LR_SHARED_STRINGS->GET_DATA( ).
    catch CX_SY_MOVE_CAST_ERROR into LCX_ROOT.
      message LCX_ROOT type 'E'.
      return.
  endtry.

  data: L_SHARED_STR_XML      type XSTRING,
        LR_SHARED_STR_DOM     type ref to IF_IXML_DOCUMENT,
        LR_SHARED_STR_NODESET type ref to IF_IXML_NODE.

  " удалим лишние namespaces из тегов для удобства поиска
  call transformation ZXLSX_SHSTR_REMOVE_NAMESPACES
    source xml LV_SHR_STR_DATA
    result xml L_SHARED_STR_XML.

  call function 'SDIXML_XML_TO_DOM'
    exporting
      XML           = L_SHARED_STR_XML
    importing
      DOCUMENT      = LR_SHARED_STR_DOM
    exceptions
      INVALID_INPUT = 1
      others        = 2.
  if SY-SUBRC = 0.
    " сделаем NODESET, потому что только так его можно передать в виде параметра
    LR_SHARED_STR_NODESET = LR_SHARED_STR_DOM->CLONE( ).
  endif.

*--------------------------------------------------------------------*
  data LR_SHEET_COLL type ref to CL_OPENXML_PARTCOLLECTION.
  data LR_SHEET type ref to CL_XLSX_WORKSHEETPART.
  data LV_SHEET_DATA type XSTRING .
  try.
      LR_SHEET_COLL =  LR_WBK->GET_WORKSHEETPARTS(  ).
      LR_SHEET ?= LR_SHEET_COLL->GET_PART( SHEET_INDEX - 1 ).
      if LR_SHEET is BOUND.
        LV_SHEET_DATA = LR_SHEET->GET_DATA( ).
      ENDIF.
    catch CX_SY_MOVE_CAST_ERROR into LCX_ROOT.
      message LCX_ROOT type 'E'.
      return.
  endtry.

  types " структура таблицы соответствий имени колонки и ее номера
  : begin of LTY_COLS
  ,   COL type NUMC4
  ,   INDEX type STRING
  , end of LTY_COLS
  .
  data LT_COLS type standard table of LTY_COLS.
  data LS_COL like line of LT_COLS.

  define ADD_COL.
    LS_COL-COL = &1.
    LS_COL-INDEX = &2.
    append LS_COL to LT_COLS.
  end-of-definition.
  ADD_COL " можно было заполнить программно
  :   01 'A'  ,   02 'B'  ,   03 'C'  ,   04 'D'  ,   05 'E'  ,   06 'F'
  ,   07 'G'  ,   08 'H'  ,   09 'I'  ,   10 'J'  ,   11 'K'  ,   12 'L'
  ,   13 'M'  ,   14 'N'  ,   15 'O'  ,   16 'P'  ,   17 'Q'  ,   18 'R'
  ,   19 'S'  ,   20 'T'  ,   21 'U'  ,   22 'V'  ,   23 'W'  ,   24 'X'
  ,   25 'Y'  ,   26 'Z'  ,   27 'AA' ,   28 'AB' ,   29 'AC' ,   30 'AD'
  ,   31 'AE' ,   32 'AF' ,   33 'AG' ,   34 'AH' ,   35 'AI'
  .
  data LR_COLS_NODESET type ref to IF_IXML_NODE.
  data LR_DATA_AS_DOM type ref to  IF_IXML_ELEMENT.
  data LR_DOCUMENT type ref to IF_IXML_DOCUMENT.
  data LR_IXML type ref to IF_IXML.

  LR_IXML = CL_IXML=>CREATE( ).
  LR_DOCUMENT = LR_IXML->CREATE_DOCUMENT( ).

  call function 'SDIXML_DATA_TO_DOM'
    exporting
      NAME         = 'LT_COLS'
      DATAOBJECT   = LT_COLS[]
    importing
      DATA_AS_DOM  = LR_DATA_AS_DOM
    changing
      DOCUMENT     = LR_DOCUMENT
    exceptions
      ILLEGAL_NAME = 1
      others       = 2.
  if SY-SUBRC = 0
    and LR_DATA_AS_DOM is not initial.
    LR_DOCUMENT->SET_DECLARATION( SPACE ).
    LR_DOCUMENT->APPEND_CHILD( LR_DATA_AS_DOM ). " без этого Nodeset почему-то не создавался
    LR_COLS_NODESET = LR_DOCUMENT->CLONE( ).
  else.
    return.
  endif.

  data LR_EXC type ref to CX_XSLT_EXCEPTION.
  try.
      call transformation ZXLSX_SHEET_DATA_TO_TAB
        parameters P_SHARED_STRING = LR_SHARED_STR_NODESET
                   P_COLS          = LR_COLS_NODESET
        source xml LV_SHEET_DATA
        result LT_DATA = INTERN.
    catch CX_XSLT_EXCEPTION into LR_EXC.
      message LR_EXC type 'E'.
      return.
  endtry.
endfunction.

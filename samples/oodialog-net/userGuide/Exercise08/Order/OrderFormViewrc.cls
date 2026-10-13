/* OrderFormView.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with OrderFormView.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "OrderFormView_IDD_ORDFORM_CUST_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 206, 127, "", "", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 16, 37, 53, 8, "", "Customer Name:")
  self~createEdit(IDC_CUSTDTLS_NAME, 79, 32, 100, 14, "DISABLED", "IDC_CUSTDTLS_NAME")
  self~createEdit(IDC_CUSTDTLS_NUM, 79, 11, 53, 14, "", "IDC_CUSTDTLS_NUM")
  self~createStatic(IDC_STATIC, 16, 16, 59, 8, "", "Customer Number:")
  self~createPushButton(IDC_CUSTDTLS_FIND, 145, 11, 50, 14, "DISABLED", "Find Customer")
  self~createEdit(IDC_CUSTDTLS_ADDR, 80, 55, 100, 35, "MULTILINE DISABLED", "IDC_CUSTDTLS_ADDR")
  self~createStatic(IDC_STATIC, 16, 57, 60, 8, "", "Customer Address:")
  self~createStatic(IDC_STATIC, 16, 99, 62, 8, "", "Customer Discount:")
  self~createEdit(IDC_CUSTDTLS_DISC, 80, 96, 40, 14, "DISABLED", "IDC_CUSTDTLS_DISC")

::class "OrderFormView_IDD_ORDFORM_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 272, 278, "Order Form", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createDateTimePicker(IDC_ORDFORM_DATE, 185, 9, 70, 15, "")
  self~createEdit(IDC_ORDFORM_ORDNO, 50, 9, 40, 14, "", "IDC_ORDFORM_ORDNO")
  self~createStatic(IDC_STATIC, 10, 12, 32, 8, "", "Order No.")
  self~createStatic(IDC_STATIC, 158, 12, 16, 8, "", "Date")
  self~createStatic(IDC_STATIC, 116, 194, 35, 8, "", "Total Cost:")
  self~createStatic(IDC_STATIC, 116, 208, 29, 8, "", "Discount")
  self~createPushButton(IDC_ORDFORM_PLACEORDER, 200, 244, 50, 14, "", "Place Order")
  self~createStatic(IDC_STATIC, 116, 222, 13, 8, "", "Tax")
  self~createStatic(IDC_ORDFORM_TOTDISC, 164, 208, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_ORDFORM_TOTTAX, 164, 222, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_ORDFORM_ORDTOT, 215, 222, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_ORDFORM_TOTCOST, 215, 194, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_ORDFORM_TOTDISCCOST, 215, 208, 40, 8, "RIGHT", "0.00")
  self~createTab(IDC_ORDFORM_TABS, 15, 35, 245, 150, "")
  self~createPushButton(IDC_CANCEL, 132, 244, 46, 14, "", "Cancel Order")

::class "OrderFormView_IDD_ORDFORM_ORDLINES_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 240, 132, "", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createListView(IDC_ORDLINES_LIST, 5, 5, 230, 90, "REPORT")
  self~createEdit(IDC_ORDLINES_PRODNO, 7, 103, 40, 14, "", "IDC_ORDLINES_PRODNO")
  self~createStatic(IDC_STATIC, 9, 119, 39, 8, "", "Product No.")
  self~createEdit(IDC_ORDLINES_QTY, 62, 103, 38, 14, "", "IDC_ORDLINES_QTY")
  self~createStatic(IDC_STATIC, 65, 119, 27, 8, "", "Quantity")
  self~createPushButton(IDC_ORDLINES_ADD, 122, 105, 50, 14, "DEFAULT", "Add OrderLine")
  self~createPushButton(IDC_ORDLINES_DELETE, 177, 105, 58, 14, "", "Delete OrderLine")

::class "OrderFormView_IDR_ORDFORM_MENU" subclass NetMenuBar public   -- the .rc's IDR_ORDFORM_MENU MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new()
  p1~insertItem(, IDM_ORDFORM_PLACE, "Place Order...")
  p1~insertItem(, IDM_ORDFORM_SAVE, "Save Order...")
  p1~insertItem(, IDM_ORDFORM_CANCEL, "Cancel Order")
  self~insertPopup(, , p1, "Actions")
  p2 = .NetPopupMenu~new()
  p2~insertItem(, IDM_ORDFORM_ABOUT, "About")
  self~insertPopup(, , p2, "Help")

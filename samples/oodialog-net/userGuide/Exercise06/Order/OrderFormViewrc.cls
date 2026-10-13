/* OrderFormView.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with OrderFormView.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "OrderFormView_IDD_ORDFORM_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 272, 278, "Order Form", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createDateTimePicker(IDC_ORDFORM_DATE, 185, 9, 70, 15, "RIGHT")
  self~createEdit(IDC_ORDFORM_ORDNO, 50, 9, 40, 14, "", "IDC_ORDFORM_ORDNO")
  self~createStatic(IDC_STATIC, 10, 14, 32, 8, "", "Order No.")
  self~createStatic(IDC_STATIC, 158, 12, 16, 8, "", "Date")
  self~createStatic(IDC_STATIC, 116, 194, 35, 8, "", "Total Cost:")
  self~createStatic(IDC_STATIC, 116, 208, 29, 8, "", "Discount")
  self~createPushButton(IDC_ORDFORM_PLACEORDER, 200, 244, 50, 14, "", "Place Order")
  self~createStatic(IDC_STATIC, 116, 222, 13, 8, "", "Tax")
  self~createStatic(IDC_STATIC, 164, 208, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_STATIC, 164, 222, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_STATIC, 215, 222, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_STATIC, 215, 194, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_STATIC, 215, 208, 40, 8, "RIGHT", "0.00")
  self~createTab(IDC_ORDFORM_TABS, 15, 44, 245, 135, "")
  self~createPushButton(IDC_CANCEL, 132, 244, 46, 14, "", "Cancel Order")

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

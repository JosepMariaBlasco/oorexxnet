/* MessageSender.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with MessageSender.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "MessageSender_DLG_MESSAGESENDER" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 262, 156, "Message Sender", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 8, 17, 24, 8, "", "Target:")
  self~createStatic(IDC_STATIC, 8, 38, 27, 8, "", "Method:")
  self~createStatic(IDC_STATIC, 9, 60, 18, 8, "", "Data:")
  self~createEdit(IDC_MS_DATA, 40, 55, 210, 35, "MULTILINE VSCROLL", "IDC_MS_DATA")
  self~createStatic(IDC_STATIC, 10, 101, 21, 8, "", "Reply:")
  self~createEdit(IDC_MS_REPLY, 40, 101, 210, 35, "MULTILINE VSCROLL HSCROLL", "IDC_MS_REPLY")
  self~createPushButton(IDC_MS_SEND, 211, 15, 40, 14, "DEFAULT", "Send")
  self~createPushButton(IDC_MS_CLEAR, 211, 35, 40, 14, "DISABLED", "Clear")
  self~createStatic(IDC_MS_ERRORMSG, 13, 142, 225, 10, "", "")
  self~createComboBox(IDC_MS_COMPONENT, 40, 15, 125, 15, "SORT", "IDC_MS_COMPONENT")
  self~createComboBox(IDC_MS_METHOD, 40, 35, 115, 30, "SORT", "IDC_MS_METHOD")
  self~createCheckBox(IDC_MS_STORETARGET, 172, 17, 33, 8, "", "Store", "IDC_MS_STORETARGET")
  self~createCheckBox(IDC_MS_STOREMETHOD, 163, 36, 33, 9, "", "Store", "IDC_MS_STOREMETHOD")

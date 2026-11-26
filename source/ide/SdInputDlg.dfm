object InputDlg: TInputDlg
  Left = 200
  Top = 120
  ActiveControl = edValue
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Input'
  ClientHeight = 118
  ClientWidth = 339
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poOwnerFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  OnCreate = FormCreate
  object lblPrompt: TLabel
    Left = 12
    Top = 12
    Width = 31
    Height = 15
    Caption = '&Value:'
    FocusControl = edValue
  end
  object edValue: TEdit
    Left = 12
    Top = 32
    Width = 315
    Height = 23
    TabOrder = 0
  end
  object reValue: TRichEdit
    Left = 12
    Top = 32
    Width = 315
    Height = 23
    PlainText = True
    TabOrder = 1
    Visible = False
    WantReturns = False
    WordWrap = False
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 67
    Width = 339
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 339
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 143
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 239
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end

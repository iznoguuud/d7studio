object EvalDlg: TEvalDlg
  Left = 200
  Top = 120
  ActiveControl = edExpr
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Evaluate/Modify'
  ClientHeight = 307
  ClientWidth = 409
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
  object lblExpr: TLabel
    Left = 12
    Top = 12
    Width = 58
    Height = 15
    Caption = '&Expression:'
    FocusControl = edExpr
  end
  object lblResult: TLabel
    Left = 12
    Top = 62
    Width = 35
    Height = 15
    Caption = '&Result:'
    FocusControl = mmResult
  end
  object lblNewValue: TLabel
    Left = 12
    Top = 202
    Width = 58
    Height = 15
    Caption = '&New value:'
    FocusControl = edNewValue
  end
  object edExpr: TEdit
    Left = 12
    Top = 31
    Width = 385
    Height = 23
    TabOrder = 0
  end
  object mmResult: TMemo
    Left = 12
    Top = 81
    Width = 385
    Height = 113
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object edNewValue: TEdit
    Left = 12
    Top = 221
    Width = 385
    Height = 23
    TabOrder = 2
  end
  object Actions: TActionList
    Left = 16
    Top = 252
    object aEvaluate: TAction
      Caption = 'E&valuate'
      Hint = 'Evaluate the expression in the stopped program'
      OnExecute = aEvaluateExecute
      OnUpdate = ExprUpdate
    end
    object aModify: TAction
      Caption = '&Modify'
      Hint = 'Assign the new value to the expression'
      OnExecute = aModifyExecute
      OnUpdate = ExprUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 256
    Width = 409
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 409
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnEvaluate: TButton
      Left = 117
      Top = 13
      Width = 88
      Height = 26
      Action = aEvaluate
      Default = True
      TabOrder = 0
    end
    object btnModify: TButton
      Left = 213
      Top = 13
      Width = 88
      Height = 26
      Action = aModify
      TabOrder = 1
    end
    object btnClose: TButton
      Left = 309
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'Close'
      ModalResult = 2
      TabOrder = 2
    end
  end
end

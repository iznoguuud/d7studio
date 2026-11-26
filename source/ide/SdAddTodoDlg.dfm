object AddTodoDlg: TAddTodoDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'Add To-Do Item'
  ClientHeight = 225
  ClientWidth = 461
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  DesignSize = (
    461
    225)
  object xLabel1: TLabel
    Left = 12
    Top = 12
    Width = 24
    Height = 15
    Caption = '&Text:'
    FocusControl = Memo
  end
  object xLabel2: TLabel
    Left = 12
    Top = 120
    Width = 41
    Height = 15
    Caption = '&Priority:'
    FocusControl = PriorityEdit
  end
  object xLabel3: TLabel
    Left = 74
    Top = 121
    Width = 38
    Height = 15
    Caption = '&Owner:'
    FocusControl = cbOwner
  end
  object xLabel4: TLabel
    Left = 267
    Top = 121
    Width = 51
    Height = 15
    Caption = '&Category:'
    FocusControl = cbCategory
  end
  object Memo: TMemo
    Left = 12
    Top = 30
    Width = 437
    Height = 84
    Anchors = [akLeft, akTop, akRight]
    ScrollBars = ssBoth
    TabOrder = 0
    WordWrap = False
  end
  object xUpDown1: TUpDown
    Left = 47
    Top = 138
    Width = 18
    Height = 23
    Associate = PriorityEdit
    Max = 5
    TabOrder = 1
  end
  object cbCategory: TComboBox
    Left = 267
    Top = 139
    Width = 182
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    ItemHeight = 0
    TabOrder = 2
  end
  object PriorityEdit: TEdit
    Left = 12
    Top = 138
    Width = 35
    Height = 23
    BiDiMode = bdLeftToRight
    ParentBiDiMode = False
    TabOrder = 3
    Text = '0'
  end
  object cbOwner: TComboBox
    Left = 74
    Top = 139
    Width = 181
    Height = 23
    ItemHeight = 0
    TabOrder = 4
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 174
    Width = 461
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 5
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 461
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 265
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKButtonClick
    end
    object CancelButton: TButton
      Left = 361
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
    object CheckedBox: TCheckBox
      Left = 12
      Top = 17
      Width = 120
      Height = 19
      Caption = '&Done'
      TabOrder = 2
    end
  end
end

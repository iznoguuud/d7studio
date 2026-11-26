object AddRepositoryDlg: TAddRepositoryDlg
  Left = 200
  Top = 120
  ActiveControl = edTitle
  BorderStyle = bsDialog
  Caption = 'Add To Repository'
  ClientHeight = 290
  ClientWidth = 531
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
  object xLabel1: TLabel
    Left = 162
    Top = 12
    Width = 26
    Height = 15
    Caption = '&Title:'
    FocusControl = edTitle
  end
  object xLabel3: TLabel
    Left = 210
    Top = 170
    Width = 226
    Height = 19
    AutoSize = False
    Caption = 'Select an icon to represent this object:'
  end
  object Image: TImage
    Left = 162
    Top = 177
    Width = 33
    Height = 32
  end
  object xLabel2: TLabel
    Left = 162
    Top = 59
    Width = 63
    Height = 15
    Caption = '&Description:'
    FocusControl = meDesc
  end
  object xLabel5: TLabel
    Left = 12
    Top = 12
    Width = 36
    Height = 15
    Caption = '&Forms:'
    FocusControl = FormList
  end
  object xLabel4: TLabel
    Left = 162
    Top = 108
    Width = 29
    Height = 15
    Caption = '&Page:'
    FocusControl = PageCombo
  end
  object xLabel6: TLabel
    Left = 357
    Top = 108
    Width = 40
    Height = 15
    Caption = '&Author:'
    FocusControl = edAuthor
  end
  object edTitle: TEdit
    Left = 162
    Top = 30
    Width = 357
    Height = 23
    MaxLength = 40
    TabOrder = 0
  end
  object meDesc: TEdit
    Left = 162
    Top = 80
    Width = 357
    Height = 23
    TabOrder = 1
  end
  object BrowseButton: TButton
    Left = 211
    Top = 196
    Width = 88
    Height = 26
    Action = aBrowse
    TabOrder = 2
  end
  object FormList: TListBox
    Left = 12
    Top = 30
    Width = 137
    Height = 197
    ItemHeight = 13
    TabOrder = 3
  end
  object PageCombo: TComboBox
    Left = 162
    Top = 129
    Width = 187
    Height = 23
    ItemHeight = 0
    TabOrder = 4
  end
  object edAuthor: TEdit
    Left = 357
    Top = 129
    Width = 162
    Height = 23
    TabOrder = 5
  end
  object Actions: TActionList
    Left = 12
    Top = 217
    object aBrowse: TAction
      Caption = '&Browse...'
      OnExecute = aBrowseExecute
    end
    object aOK: TAction
      Caption = 'OK'
      OnExecute = aOKExecute
      OnUpdate = aOKUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 239
    Width = 531
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 6
    DesignSize = (
      531
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 531
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 335
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Action = aOK
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object CancelButton: TButton
      Left = 431
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end

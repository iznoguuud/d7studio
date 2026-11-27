object ChangeParamsDlg: TChangeParamsDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Change Parameters'
  ClientHeight = 390
  ClientWidth = 560
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
  OnDestroy = FormDestroy
  object lblPName: TLabel
    Left = 12
    Top = 174
    Width = 35
    Height = 15
    Caption = '&Name:'
    FocusControl = edPName
  end
  object lblPType: TLabel
    Left = 160
    Top = 174
    Width = 28
    Height = 15
    Caption = '&Type:'
    FocusControl = edPType
  end
  object lblPKind: TLabel
    Left = 308
    Top = 174
    Width = 26
    Height = 15
    Caption = '&Kind:'
    FocusControl = cbPKind
  end
  object lblPDefault: TLabel
    Left = 12
    Top = 229
    Width = 75
    Height = 15
    Caption = '&Default value:'
    FocusControl = edPDefault
  end
  object lblPValue: TLabel
    Left = 160
    Top = 229
    Width = 112
    Height = 15
    Caption = '&Value at the calls:'
    FocusControl = edPValue
  end
  object lblHeading: TLabel
    Left = 12
    Top = 284
    Width = 50
    Height = 15
    Caption = 'Heading:'
    FocusControl = edHeading
  end
  object lvParams: TListView
    Left = 12
    Top = 12
    Width = 440
    Height = 150
    Columns = <
      item
        Caption = 'Name'
        Width = 110
      end
      item
        Caption = 'Type'
        Width = 110
      end
      item
        Caption = 'Kind'
        Width = 55
      end
      item
        Caption = 'Default'
        Width = 70
      end
      item
        Caption = 'At the calls'
        Width = 75
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnSelectItem = lvParamsSelectItem
  end
  object btnAdd: TButton
    Left = 460
    Top = 12
    Width = 88
    Height = 26
    Caption = '&Add'
    TabOrder = 1
    OnClick = btnAddClick
  end
  object btnRemove: TButton
    Left = 460
    Top = 46
    Width = 88
    Height = 26
    Caption = '&Remove'
    TabOrder = 2
    OnClick = btnRemoveClick
  end
  object btnUp: TButton
    Left = 460
    Top = 80
    Width = 88
    Height = 26
    Caption = 'Move &Up'
    TabOrder = 3
    OnClick = btnUpClick
  end
  object btnDown: TButton
    Left = 460
    Top = 114
    Width = 88
    Height = 26
    Caption = 'Move Do&wn'
    TabOrder = 4
    OnClick = btnDownClick
  end
  object edPName: TEdit
    Left = 12
    Top = 194
    Width = 140
    Height = 23
    TabOrder = 5
    OnChange = FieldChange
  end
  object edPType: TEdit
    Left = 160
    Top = 194
    Width = 140
    Height = 23
    TabOrder = 6
    OnChange = FieldChange
  end
  object cbPKind: TComboBox
    Left = 308
    Top = 194
    Width = 144
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 7
    OnChange = FieldChange
    Items.Strings = (
      '(value)'
      'const'
      'var'
      'out')
  end
  object edPDefault: TEdit
    Left = 12
    Top = 249
    Width = 140
    Height = 23
    TabOrder = 8
    OnChange = FieldChange
  end
  object edPValue: TEdit
    Left = 160
    Top = 249
    Width = 140
    Height = 23
    TabOrder = 9
    OnChange = FieldChange
  end
  object edHeading: TEdit
    Left = 12
    Top = 304
    Width = 535
    Height = 23
    ReadOnly = True
    TabOrder = 10
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 339
    Width = 560
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 11
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 560
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 364
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 460
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

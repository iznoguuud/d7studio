object CodeTemplatesDlg: TCodeTemplatesDlg
  Left = 200
  Top = 120
  ActiveControl = CodeList
  AutoScroll = False
  BorderIcons = [biSystemMenu]
  Caption = 'Code Templates'
  ClientHeight = 431
  ClientWidth = 484
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
    484
    431)
  object xLabel1: TLabel
    Left = 12
    Top = 15
    Width = 57
    Height = 15
    Caption = '&Templates:'
    FocusControl = CodeList
    Transparent = False
  end
  object CodeLabel: TLabel
    Left = 40
    Top = 162
    Width = 31
    Height = 15
    Caption = '&Code:'
    Transparent = False
  end
  object TemplateBevel: TBevel
    Left = 84
    Top = 162
    Width = 388
    Height = 171
    Anchors = [akLeft, akTop, akRight, akBottom]
    Visible = False
  end
  object CodeList: TListView
    Left = 84
    Top = 12
    Width = 388
    Height = 104
    Anchors = [akLeft, akTop, akRight]
    Columns = <
      item
        Caption = 'Name'
      end
      item
        Caption = 'Description'
      end>
    ColumnClick = False
    HideSelection = False
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnSelectItem = ListSelect
  end
  object AddTemplateBtn: TButton
    Left = 84
    Top = 122
    Width = 74
    Height = 26
    Action = aAdd
    TabOrder = 1
  end
  object EditTemplateBtn: TButton
    Left = 169
    Top = 122
    Width = 74
    Height = 26
    Action = aEdit
    TabOrder = 2
  end
  object DeleteTemplateBtn: TButton
    Left = 254
    Top = 122
    Width = 74
    Height = 26
    Action = aDelete
    TabOrder = 3
  end
  object btnImport: TButton
    Left = 84
    Top = 342
    Width = 110
    Height = 26
    Action = aImport
    Anchors = [akLeft, akBottom]
    TabOrder = 4
  end
  object btnExport: TButton
    Left = 205
    Top = 342
    Width = 110
    Height = 26
    Action = aExport
    Anchors = [akLeft, akBottom]
    TabOrder = 5
  end
  object Actions: TActionList
    Left = 12
    Top = 363
    object aAdd: TAction
      Caption = '&Add...'
      OnExecute = aAddExecute
    end
    object aEdit: TAction
      Caption = '&Edit...'
      OnExecute = aEditExecute
      OnUpdate = SelectedUpdate
    end
    object aDelete: TAction
      Caption = 'De&lete'
      OnExecute = aDeleteExecute
      OnUpdate = SelectedUpdate
    end
    object aImport: TAction
      Caption = '&Import...'
      OnExecute = aImportExecute
    end
    object aExport: TAction
      Caption = 'E&xport...'
      OnExecute = aExportExecute
      OnUpdate = aExportUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 380
    Width = 484
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 6
    DesignSize = (
      484
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 484
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOk: TButton
      Left = 288
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 384
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

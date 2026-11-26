object InstallCompDlg: TInstallCompDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Install Component'
  ClientHeight = 265
  ClientWidth = 600
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
  object PageControl: TPageControl
    Left = 12
    Top = 12
    Width = 576
    Height = 190
    ActivePage = tsExisting
    TabOrder = 0
    OnChange = PageControlChange
    object tsExisting: TTabSheet
      Caption = 'Into existing package'
      object lblUnitE: TLabel
        Left = 9
        Top = 14
        Width = 82
        Height = 15
        Caption = '&Unit file name:'
        FocusControl = edUnitE
      end
      object lblSearchE: TLabel
        Left = 9
        Top = 52
        Width = 65
        Height = 15
        Caption = '&Search path:'
        FocusControl = edSearchE
      end
      object lblPackageE: TLabel
        Left = 9
        Top = 91
        Width = 104
        Height = 15
        Caption = '&Package file name:'
        FocusControl = cbPackage
      end
      object lblDescE: TLabel
        Left = 9
        Top = 129
        Width = 115
        Height = 15
        Caption = 'Package &description:'
        FocusControl = edDescE
      end
      object edUnitE: TEdit
        Left = 137
        Top = 11
        Width = 327
        Height = 23
        TabOrder = 0
      end
      object btnBrowseUnitE: TButton
        Left = 471
        Top = 9
        Width = 88
        Height = 26
        Action = aBrowseUnit
        TabOrder = 1
      end
      object edSearchE: TEdit
        Left = 137
        Top = 49
        Width = 422
        Height = 23
        TabOrder = 2
      end
      object cbPackage: TComboBox
        Left = 137
        Top = 88
        Width = 327
        Height = 23
        ItemHeight = 15
        Sorted = True
        TabOrder = 3
        OnChange = cbPackageChange
      end
      object btnBrowsePackageE: TButton
        Left = 471
        Top = 86
        Width = 88
        Height = 26
        Action = aBrowsePackage
        TabOrder = 4
      end
      object edDescE: TEdit
        Left = 137
        Top = 126
        Width = 422
        Height = 23
        ReadOnly = True
        TabOrder = 5
      end
    end
    object tsNew: TTabSheet
      Caption = 'Into new package'
      ImageIndex = 1
      object lblUnitN: TLabel
        Left = 9
        Top = 14
        Width = 82
        Height = 15
        Caption = '&Unit file name:'
        FocusControl = edUnitN
      end
      object lblSearchN: TLabel
        Left = 9
        Top = 52
        Width = 65
        Height = 15
        Caption = '&Search path:'
        FocusControl = edSearchN
      end
      object lblPackageN: TLabel
        Left = 9
        Top = 91
        Width = 104
        Height = 15
        Caption = '&Package file name:'
        FocusControl = edPackageN
      end
      object lblDescN: TLabel
        Left = 9
        Top = 129
        Width = 115
        Height = 15
        Caption = 'Package &description:'
        FocusControl = edDescN
      end
      object edUnitN: TEdit
        Left = 137
        Top = 11
        Width = 327
        Height = 23
        TabOrder = 0
      end
      object btnBrowseUnitN: TButton
        Left = 471
        Top = 9
        Width = 88
        Height = 26
        Action = aBrowseUnit
        TabOrder = 1
      end
      object edSearchN: TEdit
        Left = 137
        Top = 49
        Width = 422
        Height = 23
        TabOrder = 2
      end
      object edPackageN: TEdit
        Left = 137
        Top = 88
        Width = 327
        Height = 23
        TabOrder = 3
      end
      object btnBrowsePackageN: TButton
        Left = 471
        Top = 86
        Width = 88
        Height = 26
        Action = aBrowsePackage
        TabOrder = 4
      end
      object edDescN: TEdit
        Left = 137
        Top = 126
        Width = 422
        Height = 23
        TabOrder = 5
      end
    end
  end
  object Actions: TActionList
    Left = 16
    Top = 236
    object aBrowseUnit: TAction
      Caption = '&Browse...'
      Hint = 'Choose the unit of the component'
      OnExecute = aBrowseUnitExecute
    end
    object aBrowsePackage: TAction
      Caption = 'B&rowse...'
      Hint = 'Choose the package'
      OnExecute = aBrowsePackageExecute
    end
    object aOK: TAction
      Caption = 'OK'
      Hint = 'Add the unit to the package, then build and install the package'
      OnExecute = aOKExecute
      OnUpdate = aOKUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 214
    Width = 600
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 600
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 404
      Top = 13
      Width = 88
      Height = 26
      Action = aOK
      Default = True
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 500
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

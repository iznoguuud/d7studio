object PackageAddDlg: TPackageAddDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Add'
  ClientHeight = 184
  ClientWidth = 555
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object PageControl: TPageControl
    Left = 12
    Top = 12
    Width = 531
    Height = 109
    ActivePage = tsAddUnit
    HotTrack = True
    MultiLine = True
    TabOrder = 0
    OnChange = PageChange
    object tsAddUnit: TTabSheet
      Caption = 'Add Unit'
      object auLabel1: TLabel
        Left = 9
        Top = 14
        Width = 77
        Height = 15
        Caption = '&Unit file name:'
        FocusControl = auEditFileName
      end
      object auLabel2: TLabel
        Left = 9
        Top = 48
        Width = 65
        Height = 15
        Caption = '&Search path:'
        FocusControl = auEditSearchPath
      end
      object auEditFileName: TEdit
        Left = 93
        Top = 11
        Width = 212
        Height = 23
        TabOrder = 0
      end
      object auEditSearchPath: TEdit
        Left = 93
        Top = 45
        Width = 307
        Height = 23
        TabOrder = 1
      end
      object auBrowseButton: TButton
        Left = 312
        Top = 9
        Width = 88
        Height = 26
        Action = aBrowseUnit
        TabOrder = 2
      end
    end
    object tsRequires: TTabSheet
      Caption = 'Requires'
      object rqLabel1: TLabel
        Left = 9
        Top = 13
        Width = 80
        Height = 15
        Caption = '&Package name:'
        FocusControl = rqEditFileName
      end
      object rqLabel2: TLabel
        Left = 9
        Top = 48
        Width = 65
        Height = 15
        Caption = '&Search path:'
        FocusControl = rqEditSearchPath
      end
      object rqEditFileName: TEdit
        Left = 102
        Top = 10
        Width = 203
        Height = 23
        TabOrder = 0
      end
      object rqBrowseButton: TButton
        Left = 312
        Top = 9
        Width = 88
        Height = 26
        Action = aBrowsePackage
        TabOrder = 1
      end
      object rqEditSearchPath: TEdit
        Left = 102
        Top = 45
        Width = 298
        Height = 23
        TabOrder = 2
      end
    end
  end
  object Actions: TActionList
    Left = 12
    Top = 150
    object aBrowseUnit: TAction
      Caption = '&Browse...'
      OnExecute = aBrowseUnitExecute
    end
    object aBrowsePackage: TAction
      Caption = '&Browse...'
      OnExecute = aBrowsePackageExecute
    end
    object aOK: TAction
      Caption = 'OK'
      OnExecute = aOKExecute
      OnUpdate = aOKUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 133
    Width = 555
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    DesignSize = (
      555
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 555
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 359
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Action = aOK
      Default = True
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 455
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

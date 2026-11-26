object AttachDlg: TAttachDlg
  Left = 200
  Top = 120
  HorzScrollBar.Visible = False
  VertScrollBar.Visible = False
  ActiveControl = ProcessList
  AutoScroll = False
  BorderIcons = [biSystemMenu]
  Caption = 'Attach to Process'
  ClientHeight = 397
  ClientWidth = 594
  Color = clWindow
  Constraints.MinHeight = 256
  Constraints.MinWidth = 512
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
    594
    397)
  object xLabel1: TLabel
    Left = 12
    Top = 12
    Width = 93
    Height = 15
    Caption = 'Remote &Machine:'
    Enabled = False
    FocusControl = MachineName
  end
  object xLabel2: TLabel
    Left = 12
    Top = 56
    Width = 102
    Height = 15
    Caption = '&Running Processes:'
    FocusControl = ProcessList
  end
  object MachineName: TEdit
    Left = 12
    Top = 30
    Width = 570
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    Enabled = False
    TabOrder = 0
  end
  object ProcessList: TListView
    Left = 12
    Top = 74
    Width = 570
    Height = 233
    Anchors = [akLeft, akTop, akRight, akBottom]
    Columns = <
      item
        Caption = 'Image Name'
        Width = 100
      end
      item
        Caption = 'PID'
        Width = 75
      end
      item
        AutoSize = True
        Caption = 'Path'
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnColumnClick = ProcessListColumnClick
    OnCompare = ProcessListCompare
    OnDblClick = ProcessListDblClick
  end
  object cbShowSystemProcs: TCheckBox
    Left = 12
    Top = 315
    Width = 187
    Height = 19
    Anchors = [akLeft, akBottom]
    Caption = '&Show System Processes'
    TabOrder = 2
    OnClick = cbShowSystemProcsClick
  end
  object Actions: TActionList
    Left = 12
    Top = 274
    object aRefresh: TAction
      Caption = 'Re&fresh'
      OnExecute = aRefreshExecute
    end
    object aAttach: TAction
      Caption = '&Attach'
      OnExecute = aAttachExecute
      OnUpdate = aAttachUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 346
    Width = 594
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    DesignSize = (
      594
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 594
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object RefreshButton: TButton
      Left = 12
      Top = 13
      Width = 88
      Height = 26
      Action = aRefresh
      TabOrder = 0
    end
    object AttachButton: TButton
      Left = 398
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Action = aAttach
      Default = True
      ModalResult = 1
      TabOrder = 1
    end
    object CancelButton: TButton
      Left = 494
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 2
    end
  end
end

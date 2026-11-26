object AiApproveDialog: TAiApproveDialog
  Left = 360
  Top = 200
  BorderIcons = [biSystemMenu]
  Caption = 'Allow this change?'
  ClientHeight = 503
  ClientWidth = 680
  Color = clWindow
  Constraints.MinHeight = 360
  Constraints.MinWidth = 520
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  object TitleLabel: TLabel
    Left = 12
    Top = 12
    Width = 656
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = 'Edit Unit1.pas, line 40'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 10040064
    Font.Height = -16
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object NotesLabel: TLabel
    Left = 12
    Top = 38
    Width = 656
    Height = 15
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = 'The assistant asks to use edit_file.'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object ReasonLabel: TLabel
    Left = 12
    Top = 399
    Width = 267
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'If you deny it, tell the assistant &why (optional):'
    FocusControl = ReasonEdit
  end
  object DiffList: TListBox
    Left = 12
    Top = 62
    Width = 656
    Height = 327
    Style = lbOwnerDrawFixed
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ItemHeight = 17
    ParentFont = False
    TabOrder = 0
    OnDrawItem = DiffListDrawItem
  end
  object ReasonEdit: TEdit
    Left = 12
    Top = 417
    Width = 656
    Height = 23
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 1
  end
  object Footer: TPanel
    Left = 0
    Top = 452
    Width = 680
    Height = 51
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    DesignSize = (
      680
      48)
    object FooterLine: TShape
      Left = 0
      Top = 0
      Width = 680
      Height = 1
      Align = alTop
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object AllowButton: TButton
      Left = 336
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akRight, akBottom]
      Caption = '&Allow'
      ModalResult = 6
      TabOrder = 0
    end
    object AllowAllButton: TButton
      Left = 432
      Top = 13
      Width = 140
      Height = 26
      Anchors = [akRight, akBottom]
      Caption = 'Allow all in this &chat'
      ModalResult = 8
      TabOrder = 1
    end
    object DenyButton: TButton
      Left = 580
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akRight, akBottom]
      Cancel = True
      Caption = '&Deny'
      ModalResult = 7
      TabOrder = 2
    end
  end
end

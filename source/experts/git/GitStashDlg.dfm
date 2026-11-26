object GitStashDialog: TGitStashDialog
  Left = 400
  Top = 260
  BorderStyle = bsDialog
  Caption = 'Stash Changes'
  ClientHeight = 127
  ClientWidth = 400
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  object MessageLabel: TLabel
    Left = 12
    Top = 15
    Width = 49
    Height = 15
    Caption = '&Message:'
    FocusControl = MessageEdit
  end
  object MessageEdit: TEdit
    Left = 108
    Top = 12
    Width = 280
    Height = 23
    TabOrder = 0
  end
  object UntrackedBox: TCheckBox
    Left = 108
    Top = 45
    Width = 280
    Height = 19
    Caption = '&Include the untracked files'
    TabOrder = 1
  end
  object Footer: TPanel
    Left = 0
    Top = 82
    Width = 400
    Height = 51
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    object FooterLine: TShape
      Left = 0
      Top = 0
      Width = 400
      Height = 1
      Align = alTop
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 204
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object CancelButton: TButton
      Left = 300
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

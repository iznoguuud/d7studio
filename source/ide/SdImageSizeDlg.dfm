object ImageSizeDlg: TImageSizeDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Resize'
  ClientHeight = 277
  ClientWidth = 308
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
  object lblWidth: TLabel
    Left = 12
    Top = 15
    Width = 38
    Height = 15
    Caption = '&Width:'
    FocusControl = edWidth
  end
  object edWidth: TEdit
    Left = 84
    Top = 12
    Width = 61
    Height = 23
    OnChange = edWidthChange
    TabOrder = 0
  end
  object udWidth: TUpDown
    Left = 145
    Top = 12
    Width = 16
    Height = 23
    Associate = edWidth
    Min = 1
    Max = 4096
    Position = 32
    TabOrder = 1
    Thousands = False
  end
  object lblHeight: TLabel
    Left = 12
    Top = 44
    Width = 42
    Height = 15
    Caption = '&Height:'
    FocusControl = edHeight
  end
  object edHeight: TEdit
    Left = 84
    Top = 41
    Width = 61
    Height = 23
    OnChange = edHeightChange
    TabOrder = 2
  end
  object udHeight: TUpDown
    Left = 145
    Top = 41
    Width = 16
    Height = 23
    Associate = edHeight
    Min = 1
    Max = 4096
    Position = 32
    TabOrder = 3
    Thousands = False
  end
  object cbKeep: TCheckBox
    Left = 12
    Top = 72
    Width = 284
    Height = 19
    Caption = '&Keep the proportions'
    Checked = True
    State = cbChecked
    TabOrder = 4
  end
  object gbMode: TGroupBox
    Left = 12
    Top = 100
    Width = 284
    Height = 114
    Caption = ' Resize by '
    TabOrder = 5
    object rbSmooth: TRadioButton
      Left = 9
      Top = 18
      Width = 260
      Height = 19
      Caption = 'Scale &smoothly'
      TabOrder = 0
    end
    object rbPixels: TRadioButton
      Left = 9
      Top = 41
      Width = 260
      Height = 19
      Caption = 'Scale the &pixels (each the nearest one)'
      TabOrder = 1
    end
    object rbCanvas: TRadioButton
      Left = 9
      Top = 64
      Width = 260
      Height = 19
      Caption = 'The &canvas: the image at the top left'
      TabOrder = 2
    end
    object rbCanvasCentre: TRadioButton
      Left = 9
      Top = 87
      Width = 260
      Height = 19
      Caption = 'The canvas: the image in the &middle'
      TabOrder = 3
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 226
    Width = 308
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 6
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 308
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 112
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 208
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

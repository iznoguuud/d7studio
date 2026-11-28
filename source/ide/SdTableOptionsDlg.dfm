object TableOptionsDlg: TTableOptionsDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Table Properties'
  ClientHeight = 473
  ClientWidth = 417
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 15
  object ColorDialog: TColorDialog
    Left = 280
    Top = 312
  end
  object PageControl: TPageControl
    Left = 12
    Top = 12
    Width = 393
    Height = 398
    ActivePage = tsTable
    TabOrder = 0
    object tsTable: TTabSheet
      Caption = 'Table'
      object xLabel6: TLabel
        Left = 66
        Top = 12
        Width = 45
        Height = 15
        Caption = '&Caption:'
        FocusControl = eTableCaption
      end
      object xLabel7: TLabel
        Left = 39
        Top = 42
        Width = 73
        Height = 15
        Caption = '&Border Width:'
        FocusControl = eTableBorder
      end
      object xLabel8: TLabel
        Left = 22
        Top = 72
        Width = 86
        Height = 15
        Caption = '&Width (Percent):'
        FocusControl = eTableWidth
      end
      object xLabel9: TLabel
        Left = 39
        Top = 102
        Width = 68
        Height = 15
        Caption = 'Cell &Spacing:'
        FocusControl = eCellSpacing
      end
      object xLabel10: TLabel
        Left = 39
        Top = 132
        Width = 70
        Height = 15
        Caption = 'Cell &Padding:'
        FocusControl = eCellPadding
      end
      object xLabel13: TLabel
        Left = 9
        Top = 162
        Width = 99
        Height = 15
        Caption = 'Background C&olor:'
        FocusControl = btnColor
      end
      object btnColor: TButton
        Left = 198
        Top = 157
        Width = 23
        Height = 26
        Caption = '...'
        TabOrder = 0
        OnClick = btnColorClick
      end
      object eTableCaption: TEdit
        Left = 118
        Top = 9
        Width = 258
        Height = 23
        TabOrder = 1
      end
      object eTableBorder: TEdit
        Left = 118
        Top = 39
        Width = 86
        Height = 23
        MaxLength = 2
        TabOrder = 2
        Text = '0'
      end
      object eTableWidth: TEdit
        Left = 118
        Top = 69
        Width = 86
        Height = 23
        TabOrder = 3
        Text = '0'
      end
      object eCellSpacing: TEdit
        Left = 118
        Top = 99
        Width = 86
        Height = 23
        TabOrder = 4
        Text = '0'
      end
      object eCellPadding: TEdit
        Left = 118
        Top = 129
        Width = 86
        Height = 23
        TabOrder = 5
        Text = '0'
      end
      object xUpDown4: TUpDown
        Left = 203
        Top = 39
        Width = 18
        Height = 23
        Associate = eTableBorder
        TabOrder = 6
      end
      object xUpDown5: TUpDown
        Left = 203
        Top = 69
        Width = 18
        Height = 23
        Associate = eTableWidth
        TabOrder = 7
      end
      object xUpDown6: TUpDown
        Left = 203
        Top = 99
        Width = 18
        Height = 23
        Associate = eCellSpacing
        TabOrder = 8
      end
      object xUpDown7: TUpDown
        Left = 203
        Top = 129
        Width = 18
        Height = 23
        Associate = eCellPadding
        TabOrder = 9
      end
      object rgTableAlignment: TRadioGroup
        Left = 118
        Top = 189
        Width = 151
        Height = 82
        Caption = 'Alignment'
        Items.Strings = (
          '&Left'
          '&Right'
          'Ce&nter')
        TabOrder = 10
      end
      object pBackColor: TPanel
        Left = 118
        Top = 158
        Width = 81
        Height = 23
        BevelOuter = bvLowered
        Color = clBlack
        TabOrder = 11
        ParentBackground = False
      end
    end
    object tsColumns: TTabSheet
      Caption = 'Columns'
      ImageIndex = 1
      object xLabel11: TLabel
        Left = 9
        Top = 9
        Width = 46
        Height = 15
        Caption = '&Column:'
        FocusControl = ColList
      end
      object ColList: TListBox
        Left = 9
        Top = 26
        Width = 151
        Height = 153
        ItemHeight = 13
        TabOrder = 0
        OnClick = ColListClick
      end
      object rgAlign: TRadioGroup
        Left = 9
        Top = 186
        Width = 151
        Height = 82
        Caption = 'Alignment'
        Items.Strings = (
          '&Left'
          '&Right'
          'Ce&nter ')
        TabOrder = 1
      end
      object rgVAlign: TRadioGroup
        Left = 9
        Top = 275
        Width = 151
        Height = 82
        Caption = 'Vertical Alignment'
        Items.Strings = (
          'To&p'
          'Mi&ddle'
          'Botto&m')
        TabOrder = 2
      end
      object xGroupBox2: TGroupBox
        Left = 173
        Top = 186
        Width = 203
        Height = 165
        Caption = 'Font'
        TabOrder = 3
        object xLabel4: TLabel
          Left = 9
          Top = 23
          Width = 23
          Height = 15
          Caption = '&Size:'
          FocusControl = eColFontSize
        end
        object xLabel5: TLabel
          Left = 9
          Top = 54
          Width = 27
          Height = 15
          Caption = '&Face:'
          FocusControl = eFontFace
        end
        object xLabel12: TLabel
          Left = 9
          Top = 85
          Width = 32
          Height = 15
          Caption = 'C&olor:'
          FocusControl = btnColColor
        end
        object btnColColor: TButton
          Left = 171
          Top = 80
          Width = 23
          Height = 26
          Caption = '...'
          TabOrder = 0
          OnClick = btnColColorClick
        end
        object eColFontSize: TEdit
          Left = 46
          Top = 20
          Width = 100
          Height = 23
          TabOrder = 1
          Text = '3'
        end
        object eFontFace: TEdit
          Left = 46
          Top = 51
          Width = 147
          Height = 23
          TabOrder = 2
        end
        object cbBold: TCheckBox
          Left = 51
          Top = 112
          Width = 58
          Height = 19
          Caption = '&Bold'
          TabOrder = 3
        end
        object cbItalic: TCheckBox
          Left = 51
          Top = 138
          Width = 60
          Height = 19
          Caption = '&Italic'
          TabOrder = 4
        end
        object xUpDown3: TUpDown
          Left = 146
          Top = 20
          Width = 18
          Height = 23
          Associate = eColFontSize
          Min = 1
          Max = 7
          Position = 3
          TabOrder = 5
        end
        object pFontColor: TPanel
          Left = 46
          Top = 82
          Width = 116
          Height = 21
          BevelOuter = bvLowered
          Color = clBlack
          TabOrder = 6
          ParentBackground = False
        end
      end
      object xGroupBox4: TGroupBox
        Left = 173
        Top = 22
        Width = 203
        Height = 145
        Caption = 'General'
        TabOrder = 4
        object xLabel1: TLabel
          Left = 9
          Top = 23
          Width = 26
          Height = 15
          Caption = '&Title:'
          FocusControl = eColTitle
        end
        object xLabel2: TLabel
          Left = 9
          Top = 85
          Width = 79
          Height = 15
          Caption = 'Hei&ght (Pixels):'
          FocusControl = eColHeight
        end
        object xLabel3: TLabel
          Left = 9
          Top = 54
          Width = 86
          Height = 15
          Caption = '&Width (Percent):'
          FocusControl = eColWidth
        end
        object eColHeight: TEdit
          Left = 105
          Top = 82
          Width = 42
          Height = 23
          TabOrder = 0
          Text = '0'
        end
        object eColWidth: TEdit
          Left = 105
          Top = 51
          Width = 42
          Height = 23
          TabOrder = 1
          Text = '0'
        end
        object eColTitle: TEdit
          Left = 42
          Top = 20
          Width = 152
          Height = 23
          TabOrder = 2
        end
        object udColWidth: TUpDown
          Left = 147
          Top = 51
          Width = 18
          Height = 23
          Associate = eColWidth
          TabOrder = 3
        end
        object xUpDown2: TUpDown
          Left = 147
          Top = 82
          Width = 18
          Height = 23
          Associate = eColHeight
          Max = 1000
          TabOrder = 4
        end
        object cbWrapText: TCheckBox
          Left = 9
          Top = 118
          Width = 93
          Height = 19
          Caption = 'Wrap Te&xt'
          TabOrder = 5
        end
        object cbVisible: TCheckBox
          Left = 105
          Top = 118
          Width = 61
          Height = 19
          Caption = '&Visible'
          TabOrder = 6
        end
      end
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 422
    Width = 417
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 417
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 221
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 317
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

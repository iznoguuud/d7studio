object CustomizeDlg: TCustomizeDlg
  Left = 200
  Top = 120
  AutoScroll = False
  BorderIcons = [biSystemMenu]
  Caption = 'Customize'
  ClientHeight = 370
  ClientWidth = 424
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
    424
    370)
  object PageControl1: TPageControl
    Left = 12
    Top = 12
    Width = 400
    Height = 295
    ActivePage = TabSheet2
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
    object TabSheet2: TTabSheet
      Caption = 'Commands'
      ImageIndex = 1
      DesignSize = (
        392
        246)
      object xLabel1: TLabel
        Left = 9
        Top = 9
        Width = 59
        Height = 15
        Caption = 'Cate&gories:'
        FocusControl = CategoryList
      end
      object xLabel2: TLabel
        Left = 168
        Top = 9
        Width = 65
        Height = 15
        Caption = 'Comman&ds:'
        FocusControl = CommandList
      end
      object xLabel3: TLabel
        Left = 9
        Top = 223
        Width = 373
        Height = 31
        Anchors = [akLeft, akBottom]
        AutoSize = False
        Caption = 
          'To add command buttons, drag and drop commands onto a toolbar. T' +
          'o remove command buttons, drag them off of a Toolbar.'
        WordWrap = True
      end
      object CategoryList: TListBox
        Left = 9
        Top = 27
        Width = 151
        Height = 187
        Anchors = [akLeft, akTop, akBottom]
        ItemHeight = 13
        TabOrder = 0
        OnClick = CategoryListClick
      end
      object CommandList: TListView
        Left = 168
        Top = 27
        Width = 215
        Height = 187
        Anchors = [akLeft, akTop, akRight, akBottom]
        Columns = <
          item
            AutoSize = True
          end>
        ColumnClick = False
        ReadOnly = True
        RowSelect = True
        ShowColumnHeaders = False
        TabOrder = 1
        ViewStyle = vsReport
      end
    end
    object TabSheet3: TTabSheet
      Caption = 'Options'
      ImageIndex = 2
      object xCheckBox1: TCheckBox
        Left = 9
        Top = 9
        Width = 170
        Height = 19
        Caption = 'Show &tooltips'
        TabOrder = 0
        Checked = True
        OnClick = OptionClick
      end
      object xCheckBox2: TCheckBox
        Left = 9
        Top = 36
        Width = 198
        Height = 19
        Caption = 'Show shortcut &keys on tooltips'
        TabOrder = 1
        OnClick = OptionClick
      end
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 319
    Width = 424
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    DesignSize = (
      424
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 424
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object CloseButton: TButton
      Left = 324
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Close'
      TabOrder = 0
      OnClick = CloseButtonClick
    end
  end
end

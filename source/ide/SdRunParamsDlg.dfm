object RunParamsDlg: TRunParamsDlg
  Left = 200
  Top = 120
  ActiveControl = HostAppInput
  BorderStyle = bsDialog
  Caption = 'Run Parameters'
  ClientHeight = 477
  ClientWidth = 539
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object PageControl1: TPageControl
    Left = 12
    Top = 12
    Width = 515
    Height = 402
    ActivePage = LocalPage
    TabOrder = 0
    object LocalPage: TTabSheet
      Caption = 'Local'
      object HostAppGroupBox: TGroupBox
        Left = 9
        Top = 9
        Width = 489
        Height = 54
        Caption = ' Host &Application '
        TabOrder = 0
        object HostAppInput: TComboBox
          Left = 9
          Top = 20
          Width = 377
          Height = 23
          ItemHeight = 15
          TabOrder = 0
        end
        object BrowseButton: TButton
          Left = 392
          Top = 19
          Width = 88
          Height = 26
          Action = aBrowseHost
          TabOrder = 1
        end
      end
      object ParametersGroupBox: TGroupBox
        Left = 9
        Top = 69
        Width = 489
        Height = 53
        Caption = ' &Parameters '
        TabOrder = 1
        object ParamInput: TComboBox
          Left = 9
          Top = 20
          Width = 471
          Height = 23
          ItemHeight = 15
          TabOrder = 0
        end
      end
      object LauncherGroupBox: TGroupBox
        Left = 9
        Top = 194
        Width = 489
        Height = 46
        TabOrder = 2
        object LauncherInput: TComboBox
          Left = 9
          Top = 13
          Width = 471
          Height = 23
          ItemHeight = 15
          TabOrder = 0
        end
      end
      object LauncherCheckBox: TCheckBox
        Left = 19
        Top = 185
        Width = 156
        Height = 19
        Caption = '&Use Launcher Application'
        Checked = True
        State = cbChecked
        TabOrder = 3
      end
      object CWDGroupBox: TGroupBox
        Left = 9
        Top = 128
        Width = 489
        Height = 53
        Caption = ' Working &Directory '
        TabOrder = 4
        object CWDInput: TComboBox
          Left = 9
          Top = 20
          Width = 443
          Height = 23
          ItemHeight = 15
          TabOrder = 0
        end
        object bCWD: TButton
          Left = 456
          Top = 20
          Width = 24
          Height = 23
          Action = aBrowseCWD
          TabOrder = 1
        end
      end
    end
    object RemotePage: TTabSheet
      Caption = 'Remote'
      object xGroupBox3: TGroupBox
        Left = 9
        Top = 9
        Width = 489
        Height = 84
        Caption = ' Remote '
        TabOrder = 0
        object xLabel1: TLabel
          Left = 9
          Top = 23
          Width = 71
          Height = 15
          Caption = '&Remote Path:'
          FocusControl = RemotePath
        end
        object xLabel2: TLabel
          Left = 9
          Top = 54
          Width = 72
          Height = 15
          Caption = 'Remote H&ost:'
          FocusControl = RemoteHost
        end
        object RemotePath: TComboBox
          Left = 93
          Top = 20
          Width = 387
          Height = 23
          ItemHeight = 15
          TabOrder = 0
        end
        object RemoteHost: TComboBox
          Left = 93
          Top = 51
          Width = 387
          Height = 23
          ItemHeight = 15
          TabOrder = 1
        end
      end
      object xGroupBox4: TGroupBox
        Left = 9
        Top = 99
        Width = 489
        Height = 53
        Caption = ' &Parameters '
        TabOrder = 1
        object RemoteParams: TComboBox
          Left = 9
          Top = 20
          Width = 471
          Height = 23
          ItemHeight = 15
          TabOrder = 0
        end
      end
      object RemoteDebug: TCheckBox
        Left = 9
        Top = 161
        Width = 442
        Height = 19
        Caption = '&Debug project on remote machine'
        TabOrder = 2
      end
      object RemoteLauncherGroupBox: TGroupBox
        Left = 9
        Top = 207
        Width = 489
        Height = 53
        Caption = ' Remote La&uncher Application '
        TabOrder = 3
        Visible = False
        object RemoteLauncherInput: TComboBox
          Left = 9
          Top = 20
          Width = 471
          Height = 23
          ItemHeight = 15
          TabOrder = 0
        end
      end
    end
    object EnvVarPage: TTabSheet
      Caption = 'Environment Block'
      ImageIndex = 2
      object EnvVarOptions: TPanel
        Left = 0
        Top = 0
        Width = 507
        Height = 339
        BevelOuter = bvNone
        ParentBackground = True
        TabOrder = 0
        object frGroupBox1: TGroupBox
          Left = 9
          Top = 9
          Width = 489
          Height = 158
          Caption = ' &System variables '
          TabOrder = 0
          object bAddOverride: TButton
            Left = 380
            Top = 123
            Width = 100
            Height = 26
            Action = aVarOverride
            TabOrder = 0
          end
          object frPanel1: TPanel
            Left = 9
            Top = 20
            Width = 471
            Height = 93
            BevelOuter = bvNone
            ParentBackground = False
            TabOrder = 1
            object lvSystemVars: TListView
              Left = 0
              Top = 0
              Width = 471
              Height = 93
              Align = alClient
              Columns = <
                item
                  Caption = 'Variable'
                  Width = 120
                end
                item
                  Caption = 'Value'
                  Width = 240
                end>
              ColumnClick = False
              HideSelection = False
              ReadOnly = True
              RowSelect = True
              SortType = stText
              TabOrder = 0
              ViewStyle = vsReport
            end
          end
        end
        object frGroupBox2: TGroupBox
          Left = 9
          Top = 167
          Width = 489
          Height = 158
          Caption = ' &User overrides '
          TabOrder = 1
          object bNew: TButton
            Left = 204
            Top = 123
            Width = 88
            Height = 26
            Action = aVarNew
            TabOrder = 0
          end
          object bEdit: TButton
            Left = 298
            Top = 123
            Width = 88
            Height = 26
            Action = aVarEdit
            TabOrder = 1
          end
          object bDelete: TButton
            Left = 392
            Top = 123
            Width = 88
            Height = 26
            Action = aVarDelete
            TabOrder = 2
          end
          object lvUserVars: TListView
            Left = 9
            Top = 20
            Width = 471
            Height = 93
            Columns = <
              item
                Caption = 'Variable'
                Width = 120
              end
              item
                Caption = 'Value'
                Width = 240
              end>
            ColumnClick = False
            HideSelection = False
            ReadOnly = True
            RowSelect = True
            SortType = stText
            TabOrder = 3
            ViewStyle = vsReport
            OnDblClick = lvUserVarsDblClick
          end
        end
      end
      object cbIncludeSystem: TCheckBox
        Left = 9
        Top = 342
        Width = 187
        Height = 19
        Caption = '&Include System Variables'
        TabOrder = 1
      end
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 426
    Width = 539
    Height = 51
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 1
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 539
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object LoadProcButton: TButton
      Left = 247
      Top = 13
      Width = 88
      Height = 26
      Action = aLoad
      TabOrder = 0
    end
    object OKButton: TButton
      Left = 343
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 1
    end
    object CancelButton: TButton
      Left = 439
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 2
    end
  end
  object Actions: TActionList
    Left = 12
    Top = 380
    object aBrowseHost: TAction
      Caption = '&Browse'
      OnExecute = aBrowseHostExecute
    end
    object aBrowseCWD: TAction
      Caption = '...'
      OnExecute = aBrowseCWDExecute
    end
    object aLoad: TAction
      Caption = '&Load'
      OnExecute = aLoadExecute
    end
    object aVarOverride: TAction
      Caption = 'Add &Override...'
    end
    object aVarNew: TAction
      Caption = '&New...'
    end
    object aVarEdit: TAction
      Caption = '&Edit...'
    end
    object aVarDelete: TAction
      Caption = '&Delete'
    end
  end
end

object AboutDlg: TAboutDlg
  Left = 200
  Top = 120
  ActiveControl = btnOK
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'About D7 Studio'
  ClientHeight = 470
  ClientWidth = 520
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
  object lblTitle: TLabel
    Left = 202
    Top = 12
    Width = 150
    Height = 48
    Caption = 'D7 Studio'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -36
    Font.Name = 'Segoe UI Semilight'
    Font.Style = []
    ParentFont = False
  end
  object lblEdition: TLabel
    Left = 202
    Top = 60
    Width = 85
    Height = 21
    Caption = 'for Delphi 7'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -16
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object lblVersion: TLabel
    Left = 202
    Top = 97
    Width = 83
    Height = 15
    Caption = 'Version 1.0.0.0'
  end
  object lblCopyright: TLabel
    Left = 202
    Top = 115
    Width = 163
    Height = 15
    Caption = 'Copyright (c) 2026 iznoguuud'
  end
  object lblLicense: TLabel
    Left = 202
    Top = 133
    Width = 172
    Height = 15
    Caption = 'Released under the MIT License'
  end
  object lblRepo: TLabel
    Left = 202
    Top = 151
    Width = 172
    Height = 15
    Cursor = crHandPoint
    Hint = 'https://github.com/iznoguuud/d7studio'
    Caption = 'github.com/iznoguuud/d7studio'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clHotLight
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    ParentShowHint = False
    ShowHint = True
    OnClick = lblRepoClick
    OnMouseEnter = lblRepoMouseEnter
    OnMouseLeave = lblRepoMouseLeave
  end
  object shpLine: TShape
    Left = 202
    Top = 245
    Width = 306
    Height = 1
    Anchors = [akLeft, akTop, akRight]
    Brush.Color = clBtnShadow
    Pen.Color = clBtnShadow
  end
  object lblWindows: TLabel
    Left = 202
    Top = 261
    Width = 223
    Height = 15
    Caption = 'Windows 11 25H2 (build 26200.1), x64'
  end
  object lblDelphiCaption: TLabel
    Left = 202
    Top = 279
    Width = 44
    Height = 15
    Caption = 'Delphi 7'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object lblDelphiDir: TLabel
    Left = 266
    Top = 279
    Width = 207
    Height = 15
    Caption = 'C:\Program Files\Borland\Delphi7'
  end
  object lblCodePageCaption: TLabel
    Left = 202
    Top = 297
    Width = 57
    Height = 15
    Caption = 'Code page'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object lblCodePage: TLabel
    Left = 266
    Top = 297
    Width = 223
    Height = 15
    Caption = 'UTF-8 (system code page: Windows-1252)'
  end
  object pnlPicture: TPanel
    Left = 12
    Top = 12
    Width = 174
    Height = 300
    BevelOuter = bvNone
    Color = clWindow
    ParentBackground = False
    TabOrder = 0
  end
  object mmLicense: TMemo
    Left = 12
    Top = 324
    Width = 496
    Height = 83
    Anchors = [akLeft, akTop, akRight]
    Lines.Strings = (
      'D7 Studio, an integrated development environment for Borland Del' +
        'phi 7, is released under the MIT License (LICENSE.txt). Parts ma' +
        'de by others keep their own licenses: Scintilla and Lexilla, its' +
        ' editing component (Copyright Neil Hodgson), under their own lic' +
        'ense; FastMM4, the memory manager of the modernized RTL (Copyrig' +
        'ht Pierre le Riche / Professional Software Development), under t' +
        'he Mozilla Public License 1.1 or the GNU Lesser General Public L' +
        'icense 2.1; its icons, made from JetBrains'#39' IntelliJ Platform ic' +
        'ons (Copyright JetBrains s.r.o. and contributors), under the Apa' +
        'che License, Version 2.0 (THIRD-PARTY-NOTICES.md); Microsoft'#39's W' +
        'indows Help program (WinHlp32), which Setup installs, under Micr' +
        'osoft'#39's terms. Delphi and Borland are trademarks of their owners' +
        ' (today Embarcadero Technologies, Inc.). D7 Studio is not affili' +
        'ated with, endorsed or sponsored by them, and contains none of B' +
        'orland'#39's files.')
    ParentColor = True
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
    WantReturns = False
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 419
    Width = 520
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    DesignSize = (
      520
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 520
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 420
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
  end
end

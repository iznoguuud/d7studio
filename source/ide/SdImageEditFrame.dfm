object ImageEditFrame: TImageEditFrame
  Left = 0
  Top = 0
  Width = 840
  Height = 580
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  ParentFont = False
  TabOrder = 0
  object TopBar: TToolBar
    Left = 0
    Top = 0
    Width = 840
    Height = 22
    AutoSize = True
    Caption = 'TopBar'
    EdgeBorders = []
    Flat = True
    ParentShowHint = False
    ShowHint = True
    TabOrder = 0
    Wrapable = False
    object tbUndo: TToolButton
      Left = 0
      Top = 0
      Action = EditUndoCommand
    end
    object tbRedo: TToolButton
      Left = 23
      Top = 0
      Action = EditRedoCommand
    end
    object tbSep1: TToolButton
      Left = 46
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbCut: TToolButton
      Left = 54
      Top = 0
      Action = EditCutCommand
    end
    object tbCopy: TToolButton
      Left = 77
      Top = 0
      Action = EditCopyCommand
    end
    object tbPaste: TToolButton
      Left = 100
      Top = 0
      Action = EditPasteCommand
    end
    object tbDelete: TToolButton
      Left = 123
      Top = 0
      Action = EditDeleteCommand
    end
    object tbSep2: TToolButton
      Left = 146
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbFlipHorz: TToolButton
      Left = 154
      Top = 0
      Action = aFlipHorz
    end
    object tbFlipVert: TToolButton
      Left = 177
      Top = 0
      Action = aFlipVert
    end
    object tbRotate: TToolButton
      Left = 200
      Top = 0
      Action = aRotate
    end
    object tbInvert: TToolButton
      Left = 223
      Top = 0
      Action = aInvert
    end
    object tbSep3: TToolButton
      Left = 246
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbResize: TToolButton
      Left = 254
      Top = 0
      Action = aResize
    end
    object tbDepth: TToolButton
      Left = 277
      Top = 0
      Action = aDepth
      DropdownMenu = DepthMenu
      Style = tbsDropDown
    end
    object tbImport: TToolButton
      Left = 313
      Top = 0
      Action = aImport
    end
    object tbSep4: TToolButton
      Left = 336
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbGrid: TToolButton
      Left = 344
      Top = 0
      Action = aGrid
      Style = tbsCheck
    end
    object tbPreview: TToolButton
      Left = 367
      Top = 0
      Action = aPreview
      Style = tbsCheck
    end
    object tbSep5: TToolButton
      Left = 390
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbNewImage: TToolButton
      Left = 398
      Top = 0
      Action = aNewImage
    end
    object tbDeleteImage: TToolButton
      Left = 421
      Top = 0
      Action = aDeleteImage
    end
  end
  object ToolPanel: TPanel
    Left = 0
    Top = 22
    Width = 56
    Height = 474
    Align = alLeft
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 1
    object Tools: TToolBar
      Left = 0
      Top = 0
      Width = 56
      Height = 176
      AutoSize = True
      ButtonWidth = 23
      Caption = 'Tools'
      EdgeBorders = []
      Flat = True
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      object tbSelect: TToolButton
        Left = 0
        Top = 0
        Action = aSelect
        Style = tbsCheck
      end
      object tbLasso: TToolButton
        Left = 23
        Top = 0
        Action = aLasso
        Style = tbsCheck
      end
      object tbZoomTool: TToolButton
        Left = 0
        Top = 22
        Action = aZoomTool
        Style = tbsCheck
      end
      object tbPicker: TToolButton
        Left = 23
        Top = 22
        Action = aPicker
        Style = tbsCheck
      end
      object tbEraser: TToolButton
        Left = 0
        Top = 44
        Action = aEraser
        Style = tbsCheck
      end
      object tbFill: TToolButton
        Left = 23
        Top = 44
        Action = aFill
        Style = tbsCheck
      end
      object tbPencil: TToolButton
        Left = 0
        Top = 66
        Action = aPencil
        Style = tbsCheck
      end
      object tbBrush: TToolButton
        Left = 23
        Top = 66
        Action = aBrush
        Style = tbsCheck
      end
      object tbAirbrush: TToolButton
        Left = 0
        Top = 88
        Action = aAirbrush
        Style = tbsCheck
      end
      object tbText: TToolButton
        Left = 23
        Top = 88
        Action = aText
        Style = tbsCheck
      end
      object tbLine: TToolButton
        Left = 0
        Top = 110
        Action = aLine
        Style = tbsCheck
      end
      object tbRect: TToolButton
        Left = 23
        Top = 110
        Action = aRect
        Style = tbsCheck
      end
      object tbRoundRect: TToolButton
        Left = 0
        Top = 132
        Action = aRoundRect
        Style = tbsCheck
      end
      object tbEllipse: TToolButton
        Left = 23
        Top = 132
        Action = aEllipse
        Style = tbsCheck
      end
      object tbHotspot: TToolButton
        Left = 0
        Top = 154
        Action = aHotspot
        Style = tbsCheck
      end
    end
  end
  object lbImages: TListBox
    Left = 56
    Top = 22
    Width = 132
    Height = 474
    Align = alLeft
    ItemHeight = 40
    Style = lbOwnerDrawFixed
    TabOrder = 2
    OnClick = lbImagesClick
    OnDrawItem = lbImagesDrawItem
  end
  object BottomPanel: TPanel
    Left = 0
    Top = 496
    Width = 840
    Height = 84
    Align = alBottom
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 3
    object StatusPanel: TPanel
      Left = 0
      Top = 62
      Width = 840
      Height = 22
      Align = alBottom
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 0
      DesignSize = (
        840
        22)
      object lblStatus: TLabel
        Left = 8
        Top = 3
        Width = 824
        Height = 15
        Anchors = [akLeft, akTop, akRight]
        AutoSize = False
        ShowAccelChar = False
      end
    end
  end
  object DepthMenu: TPopupMenu
    Left = 220
    Top = 60
    object miDepth1: TMenuItem
      Action = aDepth1
      RadioItem = True
    end
    object miDepth4: TMenuItem
      Action = aDepth4
      RadioItem = True
    end
    object miDepth8: TMenuItem
      Action = aDepth8
      RadioItem = True
    end
    object miDepth24: TMenuItem
      Action = aDepth24
      RadioItem = True
    end
    object miDepth32: TMenuItem
      Action = aDepth32
      RadioItem = True
    end
  end
  object Actions: TActionList
    OnExecute = ActionsExecute
    OnUpdate = ActionsUpdate
    Left = 260
    Top = 60
    object aSelect: TAction
      Tag = 0
      Caption = 'Select'
      Hint = 'Select an area (drag it to move it; Shift+Alt+S)'
      ImageIndex = 183
      ShortCut = 41043
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aLasso: TAction
      Tag = 1
      Caption = 'Lasso'
      Hint = 'Select a free area'
      ImageIndex = 184
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aZoomTool: TAction
      Tag = 2
      Caption = 'Zoom'
      Hint = 'Zoom in where clicked, out with the right button (Ctrl+M)'
      ImageIndex = 185
      ShortCut = 16461
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aPicker: TAction
      Tag = 3
      Caption = 'Pick Colour'
      Hint = 'Take a colour of the image'
      ImageIndex = 186
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aEraser: TAction
      Tag = 4
      Caption = 'Eraser'
      Hint = 'Erase to the screen; a bitmap to the secondary colour (Ctrl+Shift+I)'
      ImageIndex = 187
      ShortCut = 24649
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aFill: TAction
      Tag = 5
      Caption = 'Fill'
      Hint = 'Fill an area of one colour (Ctrl+F)'
      ImageIndex = 188
      ShortCut = 16454
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aPencil: TAction
      Tag = 6
      Caption = 'Pencil'
      Hint = 'Draw single pixels (Ctrl+I)'
      ImageIndex = 189
      ShortCut = 16457
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aBrush: TAction
      Tag = 7
      Caption = 'Brush'
      Hint = 'Draw with the width chosen (Ctrl+B)'
      ImageIndex = 190
      ShortCut = 16450
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aAirbrush: TAction
      Tag = 8
      Caption = 'Airbrush'
      Hint = 'Spray (Ctrl+A)'
      ImageIndex = 191
      ShortCut = 16449
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aText: TAction
      Tag = 9
      Caption = 'Text'
      Hint = 'Draw a text (Ctrl+T)'
      ImageIndex = 192
      ShortCut = 16468
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aLine: TAction
      Tag = 10
      Caption = 'Line'
      Hint = 'Draw a line; Shift: straight or diagonal (Ctrl+L)'
      ImageIndex = 193
      ShortCut = 16460
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aRect: TAction
      Tag = 11
      Caption = 'Rectangle'
      Hint = 'Draw a rectangle; Shift: a square (Alt+R)'
      ImageIndex = 194
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aRoundRect: TAction
      Tag = 12
      Caption = 'Rounded Rectangle'
      Hint = 'Draw a rectangle with round corners (Alt+W)'
      ImageIndex = 195
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aEllipse: TAction
      Tag = 13
      Caption = 'Ellipse'
      Hint = 'Draw an ellipse; Shift: a circle (Ctrl+P)'
      ImageIndex = 196
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aHotspot: TAction
      Tag = 14
      Caption = 'Hot Spot'
      Hint = 'Set the cursor''s hot spot'
      ImageIndex = 197
      OnExecute = ToolExecute
      OnUpdate = ToolUpdate
    end
    object aShape0: TAction
      Tag = 0
      Caption = 'Rectangle'
      ShortCut = 32850
      OnExecute = ShapeExecute
    end
    object aShape1: TAction
      Tag = 1
      Caption = 'Outlined Rectangle'
      ShortCut = 41042
      OnExecute = ShapeExecute
    end
    object aShape2: TAction
      Tag = 2
      Caption = 'Filled Rectangle'
      ShortCut = 57426
      OnExecute = ShapeExecute
    end
    object aShape3: TAction
      Tag = 3
      Caption = 'Rounded Rectangle'
      ShortCut = 32855
      OnExecute = ShapeExecute
    end
    object aShape4: TAction
      Tag = 4
      Caption = 'Outlined Rounded Rectangle'
      ShortCut = 41047
      OnExecute = ShapeExecute
    end
    object aShape5: TAction
      Tag = 5
      Caption = 'Filled Rounded Rectangle'
      ShortCut = 57431
      OnExecute = ShapeExecute
    end
    object aShape6: TAction
      Tag = 6
      Caption = 'Ellipse'
      ShortCut = 16464
      OnExecute = ShapeExecute
    end
    object aShape7: TAction
      Tag = 7
      Caption = 'Outlined Ellipse'
      ShortCut = 41040
      OnExecute = ShapeExecute
    end
    object aShape8: TAction
      Tag = 8
      Caption = 'Filled Ellipse'
      ShortCut = 57424
      OnExecute = ShapeExecute
    end
    object aLargerBrush: TAction
      Tag = 1
      Caption = 'Larger Brush'
      ShortCut = 16571
      OnExecute = WidthExecute
    end
    object aSmallerBrush: TAction
      Tag = -1
      Caption = 'Smaller Brush'
      ShortCut = 16573
      OnExecute = WidthExecute
    end
    object aSmallBrush: TAction
      Tag = 0
      Caption = 'Small Brush'
      ShortCut = 16574
      OnExecute = WidthExecute
    end
    object aNextColor: TAction
      Tag = 1
      Caption = 'Next Colour'
      SecondaryShortCuts.Strings = (
        'Ctrl+Right')
      ShortCut = 16605
      OnExecute = ColorStepExecute
    end
    object aPrevColor: TAction
      Tag = -1
      Caption = 'Previous Colour'
      SecondaryShortCuts.Strings = (
        'Ctrl+Left')
      ShortCut = 16603
      OnExecute = ColorStepExecute
    end
    object aNextRightColor: TAction
      Tag = 2
      Caption = 'Next Secondary Colour'
      SecondaryShortCuts.Strings = (
        'Shift+Ctrl+Right')
      ShortCut = 24797
      OnExecute = ColorStepExecute
    end
    object aPrevRightColor: TAction
      Tag = -2
      Caption = 'Previous Secondary Colour'
      SecondaryShortCuts.Strings = (
        'Shift+Ctrl+Left')
      ShortCut = 24795
      OnExecute = ColorStepExecute
    end
    object aDepth1: TAction
      Tag = 1
      Caption = 'Monochrome'
      OnExecute = DepthExecute
      OnUpdate = DepthUpdate
    end
    object aDepth4: TAction
      Tag = 4
      Caption = '16 Colours'
      OnExecute = DepthExecute
      OnUpdate = DepthUpdate
    end
    object aDepth8: TAction
      Tag = 8
      Caption = '256 Colours'
      OnExecute = DepthExecute
      OnUpdate = DepthUpdate
    end
    object aDepth24: TAction
      Tag = 24
      Caption = '24 Bits'
      OnExecute = DepthExecute
      OnUpdate = DepthUpdate
    end
    object aDepth32: TAction
      Tag = 32
      Caption = '32 Bits'
      OnExecute = DepthExecute
      OnUpdate = DepthUpdate
    end
    object EditUndoCommand: TAction
      Caption = '&Undo'
      Hint = 'Undo (Ctrl+Z)'
      ImageIndex = 7
      ShortCut = 16474
      OnExecute = CommandExecute
    end
    object EditRedoCommand: TAction
      Caption = '&Redo'
      Hint = 'Redo (Ctrl+Y)'
      ImageIndex = 8
      ShortCut = 16473
      OnExecute = CommandExecute
    end
    object EditCutCommand: TAction
      Caption = 'Cu&t'
      Hint = 'Cut the selection (Ctrl+X)'
      ImageIndex = 9
      ShortCut = 16472
      OnExecute = CommandExecute
    end
    object EditCopyCommand: TAction
      Caption = '&Copy'
      Hint = 'Copy the selection, else the image (Ctrl+C)'
      ImageIndex = 10
      ShortCut = 16451
      OnExecute = CommandExecute
    end
    object EditPasteCommand: TAction
      Caption = '&Paste'
      Hint = 'Paste a picture of the clipboard (Ctrl+V)'
      ImageIndex = 11
      ShortCut = 16470
      OnExecute = CommandExecute
    end
    object EditDeleteCommand: TAction
      Caption = '&Delete'
      Hint = 'Delete the selection (Del)'
      ImageIndex = 12
      ShortCut = 46
      OnExecute = CommandExecute
    end
    object EditSelectAllCommand: TAction
      Caption = 'Select &All'
      Hint = 'Select the whole image'
      OnExecute = CommandExecute
    end
    object aOpaque: TAction
      Caption = '&Opaque Selection'
      Hint = 'The selection opaque or transparent: its secondary colour shows what is under it (Ctrl+J)'
      ShortCut = 16458
      OnExecute = CommandExecute
    end
    object aFlipHorz: TAction
      Caption = 'Flip &Horizontally'
      Hint = 'Flip the selection, else the image, horizontally (Ctrl+H)'
      ImageIndex = 198
      ShortCut = 16456
      OnExecute = CommandExecute
    end
    object aFlipVert: TAction
      Caption = 'Flip &Vertically'
      Hint = 'Flip the selection, else the image, vertically (Shift+Alt+H)'
      ImageIndex = 199
      ShortCut = 41032
      OnExecute = CommandExecute
    end
    object aRotate: TAction
      Caption = 'R&otate'
      Hint = 'Turn the selection, else the image, a quarter turn clockwise (Ctrl+Shift+H)'
      ImageIndex = 200
      ShortCut = 24648
      OnExecute = CommandExecute
    end
    object aInvert: TAction
      Caption = '&Invert Colours'
      Hint = 'Invert the colours of the selection, else of the image'
      ImageIndex = 201
      OnExecute = CommandExecute
    end
    object aResize: TAction
      Caption = 'Re&size...'
      Hint = 'Resize the image: scaled, or its canvas'
      ImageIndex = 202
      OnExecute = CommandExecute
    end
    object aDepth: TAction
      Caption = '&Colours'
      Hint = 'The image''s colours: monochrome, 16, 256, 24 or 32 bits'
      ImageIndex = 203
      OnExecute = CommandExecute
    end
    object aImport: TAction
      Caption = '&Import...'
      Hint = 'A picture file as a selection (PNG, BMP, JPEG, GIF, ICO, TIFF)'
      ImageIndex = 1
      OnExecute = CommandExecute
    end
    object aZoomIn: TAction
      Caption = 'Zoom &In'
      Hint = 'Zoom in (Ctrl+Up)'
      ImageIndex = 168
      SecondaryShortCuts.Strings = (
        'Ctrl+Up')
      ShortCut = 24766
      OnExecute = CommandExecute
    end
    object aZoomOut: TAction
      Caption = 'Zoom O&ut'
      Hint = 'Zoom out (Ctrl+Down)'
      ImageIndex = 169
      SecondaryShortCuts.Strings = (
        'Ctrl+Down')
      ShortCut = 16572
      OnExecute = CommandExecute
    end
    object aMagnify: TAction
      Caption = '&Actual Size'
      Hint = '1:1 and back (Ctrl+Shift+M)'
      ShortCut = 24653
      OnExecute = CommandExecute
    end
    object aGrid: TAction
      Caption = '&Grid'
      Hint = 'The grid between the pixels (Ctrl+Alt+S)'
      ImageIndex = 204
      ShortCut = 49235
      OnExecute = CommandExecute
    end
    object aPreview: TAction
      Caption = '&Preview'
      Hint = 'The image at its actual size beside the view'
      ImageIndex = 205
      OnExecute = CommandExecute
    end
    object aNewImage: TAction
      Caption = '&New Image...'
      Hint = 'Images of other sizes or colours (Insert)'
      ImageIndex = 0
      ShortCut = 45
      OnExecute = CommandExecute
    end
    object aDeleteImage: TAction
      Caption = 'Delete Ima&ge'
      Hint = 'Delete the image'
      ImageIndex = 6
      OnExecute = CommandExecute
    end
  end
end

object MainForm: TMainForm
  Left = 257
  Top = 113
  BorderStyle = bsSingle
  Caption = 'Can Device Programmer'
  ClientHeight = 498
  ClientWidth = 727
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesigned
  OnClose = FormClose
  OnCreate = FormCreate
  OnKeyPress = FormKeyPress
  OnShow = FormShow
  DesignSize = (
    727
    498)
  PixelsPerInch = 96
  TextHeight = 13
  object GroupBox1: TGroupBox
    Left = 8
    Top = 8
    Width = 711
    Height = 482
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
    object Label3: TLabel
      Left = 624
      Top = 50
      Width = 26
      Height = 13
      Caption = 'Time:'
    end
    object TimeReceived: TLabel
      Left = 680
      Top = 50
      Width = 6
      Height = 13
      Caption = '0'
    end
    object OnBus: TLabel
      Left = 8
      Top = 48
      Width = 36
      Height = 13
      Caption = 'Off Bus'
    end
    object CanDevices: TComboBox
      Left = 3
      Top = 20
      Width = 145
      Height = 21
      Style = csDropDownList
      TabOrder = 0
      OnChange = CanDevicesChange
    end
    object Output: TListBox
      Left = 223
      Top = 20
      Width = 378
      Height = 452
      ItemHeight = 13
      TabOrder = 1
    end
    object goOnBus: TButton
      Left = 3
      Top = 67
      Width = 75
      Height = 25
      Caption = 'Go on bus'
      TabOrder = 2
      OnClick = goOnBusClick
    end
    object Clear: TButton
      Left = 620
      Top = 19
      Width = 75
      Height = 25
      Caption = 'Clear'
      TabOrder = 3
      OnClick = ClearClick
    end
    object SendConfig: TButton
      Left = 620
      Top = 378
      Width = 75
      Height = 25
      Caption = 'Send Config'
      TabOrder = 4
      OnClick = SendConfigClick
    end
    object GetConfig: TButton
      Left = 620
      Top = 409
      Width = 75
      Height = 25
      Caption = 'Get Config'
      TabOrder = 5
      OnClick = GetConfigClick
    end
    object testeepromwrite: TButton
      Left = 620
      Top = 440
      Width = 75
      Height = 25
      Caption = 'EEPROM Wri'
      TabOrder = 6
      OnClick = testeepromwriteClick
    end
    object Button1: TButton
      Left = 620
      Top = 98
      Width = 75
      Height = 25
      Caption = 'Conf IVT Cycl'
      TabOrder = 7
      OnClick = Button1Click
    end
    object Button2: TButton
      Left = 620
      Top = 129
      Width = 75
      Height = 25
      Caption = 'Conf IVT Trig'
      TabOrder = 8
      OnClick = Button2Click
    end
    object Button3: TButton
      Left = 620
      Top = 69
      Width = 75
      Height = 25
      Caption = 'Conf IVT Fact'
      TabOrder = 9
      OnClick = Button3Click
    end
  end
  object Timer1: TTimer
    OnTimer = Timer1Timer
    Left = 120
    Top = 104
  end
end

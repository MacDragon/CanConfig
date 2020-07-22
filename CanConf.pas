unit CanConf;

interface

{$Define HPF20}

uses
//  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
//  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, CanChanEx, Vcl.ExtCtrls,
//  Vcl.Mask;
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, CanChanEx, ExtCtrls,
  Mask, System.Diagnostics;

type
  TMainForm = class(TForm)
    goOnBus: TButton;
    Output: TListBox;
    GroupBox1: TGroupBox;
    CanDevices: TComboBox;
    Label3: TLabel;
    TimeReceived: TLabel;
    Clear: TButton;
    OnBus: TLabel;
    SendConfig: TButton;
    GetConfig: TButton;
    testeepromwrite: TButton;
    Button1: TButton;
    Button2: TButton;
    Timer1: TTimer;
    Button3: TButton;
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure goOnBusClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    procedure CanDevicesChange(Sender: TObject);
    procedure SendConfigClick(Sender: TObject);
    procedure GetConfigClick(Sender: TObject);
    procedure testeepromwriteClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
    StartTime: TDateTime;
    CanChannel1: TCanChannelEx;
    CANFail : Boolean;
    ACKReceived : Boolean;
    SendData : Boolean;
    ReceiveData : Boolean;

    MainStatus : Integer;

    ECUFound : Boolean;

    SendPos : Integer;
    SendTime : TStopwatch;
    SendType : byte;
    SendSize : integer;
    SendBuffer: array[0..4095] of byte;
    ReceiveSize : Integer;
    procedure SendNextData;
    procedure SendDataAck(code: byte);
    procedure ReceiveNextData(var data : array of byte );
    procedure CanChannel1CanRx(Sender: TObject);
    procedure sendIVT(msg0, msg1, msg2, msg3 : byte);

  public
    { Public declarations }
    function CanSend(id: Longint; var msg; dlc, flags: Cardinal): integer;
    procedure PopulateList;
  end;

var
  MainForm: TMainForm;

implementation

uses DateUtils, canlib, consts;

{$R *.dfm}

const
{$IfDef HPF19}
  PDMReceived = 0;
  BMSReceived = 1;
  InverterReceived	= 2;
  InverterLReceived	= 2;
  FLeftSpeedReceived	= 3;
  FRightSpeedReceived =	4;
  PedalADCReceived	= 5;
  IVTReceived = 6;
  InverterRReceived = 7;
{$EndIf}

{$IfDef HPF20}
  PDMReceived = 6;
  BMSReceived = 5;
  Inverter1Received	= 0;
  Inverter2Received	= 2;
  PedalADCReceived	= 4;
  IVTReceived = 8;
 // InverterRReceived = 7;
{$EndIf}

  BrakeFErrorBit = 0;
  BrakeRErrorBit = 1;
  Coolant1ErrorBit = 2;
  Coolant2ErrorBit = 3;
  SteeringAngleErrorBit	= 4;
  AccelLErrorBit = 5;
  AccelRErrorBit = 6;
  ADCholdingbit	= 7;

  InverterLErrorBit	= 9;
  InverterRErrorBit	= 10;

  BMSVoltageErrorBit = 11;

  var
    badvalue : byte;


function TMainForm.CanSend(id: Longint; var msg; dlc, flags: Cardinal): integer;
var exception : Boolean;
begin
  exception := false;
  with CanChannel1 do
  begin
    try
      Check(Write(id, msg, dlc, flags), 'Write failed');
    except
      if not CANFail then
        Output.Items.Add('Error Sending to CAN');
      exception := true;
      goOnBusClick(nil);
    end;
    if exception then CANFail := true else CANFail := false;
  end;
  result := 0;
end;


procedure TMainForm.PopulateList;
var
  i : Integer;
  p : AnsiString;
begin
  SetLength(p, 64);
  CanDevices.Items.clear;
  CanChannel1.Options := [ccNoVirtual];
  for i := 0 to CanChannel1.ChannelCount - 1 do
  begin
    if ansipos('Virtual', CanChannel1.ChannelNames[i]) = 0 then  // don't populate virtual channels.
      CanDevices.Items.Add(CanChannel1.ChannelNames[i]);
  end;
  if CanDevices.Items.Count > 0 then
    CanDevices.ItemIndex := 0;
end;


procedure TMainForm.SendConfigClick(Sender: TObject);
var
  openDialog : topendialog;    // Open dialog variable
  F: TFileStream;
begin

  if ( MainStatus = 1) and ( not SendData ) then
  begin

    // Create the open dialog object - assign to our open dialog variable
    openDialog := TOpenDialog.Create(self);

    // Set up the starting directory to be the current one
    openDialog.InitialDir := GetCurrentDir;

    // Only allow existing files to be selected
    openDialog.Options := [ofFileMustExist];

    // Allow only .dpr and .pas files to be selected
    openDialog.Filter :=
      'ECU EEPROM Datafile|*.dat';

    // Select pascal files as the starting filter type
    openDialog.FilterIndex := 1;

    // Display the open file dialog
    if openDialog.Execute
    then
    begin
      openDialog.FileName;

      F := TFileStream.Create(openDialog.FileName, fmOpenRead);
      try
        if F.Size = 4096 then
        begin
          F.Read(SendBuffer, 4096);
          SendType := 0;
          SendSize := 4096;
        end;

        if F.Size <= 1600 then
        begin
          F.Read(SendBuffer, F.Size);
          SendType := 1;
          SendSize := F.Size;
        end;
        SendConfig.Enabled := false;
        GetConfig.Enabled := false;
        Output.Items.Add('Sending EEPROM Data.');
        SendData := true;

        SendPos := -1;
        SendNextData;
      Except
        Output.Items.Add('Error reading data.');

      end;

      F.Free;

    end;
 //   else ShowMessage('Sending cancelled.');

    // Free up the dialog
    openDialog.Free;
  end;
end;


procedure TMainForm.SendDataAck(code: byte);
var
  msg: array[0..7] of byte;
begin
        msg[0] := 30; // send err
        msg[1] := code;
        CanSend($21,msg,3,0);
end;

procedure TMainForm.ReceiveNextData( var data: array of byte );
var
  receivepos : integer;
  msg: array[0..7] of byte;
  F: TFileStream;
  saveDialog : tsavedialog;    // Save dialog variable
begin

		 receivepos := data[1]*256+data[2];
			// check receive buffer address matches sending position
			if ( receivepos <> SendPos ) then
      begin
				// unexpected data sequence, reset receive status;

		//		resetReceive();
				Output.Items.add('Receive OutSeq.');
        SendDataAck(99);
			 //	CAN_SendStatus(ReceivingData,ReceiveErr,0);
			end else // position good, continue.
			begin

				if SendPos+data[3]<=4096 then
				begin

          move(data[4], SendBuffer[SendPos], data[3]);

					if (data[3] < 4) then // data received ok, but wasn't full block. end of data.
					begin
            Inc(Sendpos, data[3]);
            SendDataAck(1);
					end else
					begin
            Inc(Sendpos, 4);
            SendDataAck(1);
					end;

          if (data[3] = 0 ) then
          begin
						ReceiveData := false;
            GetConfig.Enabled := true;
            SendConfig.Enabled := true;
						Output.Items.Add('Receive Done.');


            // Create the save dialog object - assign to our save dialog variable
            saveDialog := TSaveDialog.Create(self);

            // Give the dialog a title
            saveDialog.Title := 'Save ECU Config data.';

            // Set up the starting directory to be the current one
            saveDialog.InitialDir := GetCurrentDir;

            // Allow only .txt and .doc file types to be saved
            saveDialog.Filter := 'ECU EEPROM Datafile|*.dat';

            saveDialog.FileName := 'ECUEEPROM.dat';

            // Set the default extension
            saveDialog.DefaultExt := 'dat';

            // Select text files as the starting filter type
            saveDialog.FilterIndex := 1;

            // Display the open file dialog
            if saveDialog.Execute
            then
            begin

              saveDialog.FileName;
              try
                F := TFileStream.Create(saveDialog.FileName, fmCreate);

                if F.Size = 0 then
                begin
                  F.Write(SendBuffer, SendPos);
                end;
                Output.Items.Add('File saved.');

              except
                Output.Items.Add('Error writing file');
              end;
              F.Free;
            end;
          //  else ShowMessage('Save file was cancelled');

            // Free up the dialog
            saveDialog.Free;


          end;

				end else
				begin
					// TODO tried to receive too much data! error.
		 //			resetReceive();
     //		lcd_send_stringpos(3,0,"Receive Error.    ");
		 //			CAN_SendStatus(ReceivingData, ReceiveErr,0);
          msg[0] := 30; // send err
          msg[1] := 99;
          CanSend($21,msg,3,0);
          Output.Items.add('Receive Err.');
				end
			end;
end;

procedure TMainForm.SendNextData;
var
  msg: array[0..7] of byte;
  I : integer;
  packetsize : byte;
begin
  with CanChannel1 do
    begin
      if Active then
      begin
        if SendData then  // if request to send data activated.
        begin
          if SendPos = -1 then
          begin
      //      for I := 0 to 4095 do SendBuffer[I] := I;
            msg[0] := 8;

            msg[1] := byte(SendSize shr 8);
            msg[2] := byte(SendSize);

            msg[3] := SendType;

            SendPos := 0;

            CanSend($21,msg,4,0);  // send start of transfer.
            SendTime := TStopwatch.StartNew;
          end else
          begin
          if ACKReceived then //and ( SendTime.ElapsedMilliseconds > 100 ) then
            begin
              ACKReceived := false;
              if sendpos < sendsize-1 then // not yet at end
              begin

        //        Output.Items.Add('Send:'+inttostr(sendpos));
                msg[0] := 9; // sending byte.

                packetsize := 4;


                msg[1] := byte(sendpos shr 8);
                msg[2] := byte(sendpos);


                if ( SendPos+packetsize > Sendsize ) then
                  packetsize := sendsize-sendpos;

                msg[3] := packetsize;

                msg[4] := SendBuffer[sendpos];
                msg[5] := SendBuffer[sendpos+1];
                msg[6] := SendBuffer[sendpos+2];
                msg[7] := SendBuffer[sendpos+3];
                sendpos := sendpos+4;

                CanSend($21,msg,8,0);

  //              Sleep(100);
              end else
              if sendpos >= sendsize-1 then
              begin
                sendpos := sendsize;
                msg[1] := byte(sendpos shr 8);
                msg[2] := byte(sendpos);

                for I := 3 to 7 do msg[I] := 0;

                CanSend($21,msg,8,0);
                SendData := false;
                SendConfig.Enabled := true;
                GetConfig.Enabled := true;
                Output.Items.Add('Send Done');

              end;

            end;
          end;

      end;
    end;

  end;
end;



procedure TMainForm.goOnBusClick(Sender: TObject);
var
  formattedDateTime : String;
begin
  with CanChannel1 do begin
    if not Active then begin
      Bitrate := canBITRATE_1M;
      Channel := CanDevices.ItemIndex;
      //  TCanChanOption = (ccNotExclusive, ccNoVirtual, ccAcceptLargeDLC);
      //  TCanChanOptions = set of TCanChanOption;
      Options := [ccNotExclusive];
      Open;
    //  SetHardwareFilters($20, canFILTER_SET_CODE_STD);
    //  SetHardwareFilters($FE, canFILTER_SET_MASK_STD);
      OnCanRx := CanChannel1CanRx;
      BusActive := true;
      CanDevices.Enabled := false;
      onBus.Caption := 'On bus';
      goOnBus.Caption := 'Go off bus';
      StartTime := Now;

      ECUFound := false;
      MainStatus := 0;
    end
    else
    begin

      BusActive := false;

      onBus.Caption := 'Off bus';
      goOnBus.Caption := 'Go on bus';
      CanDevices.Enabled := true;
      Close;
    end;

  //  if Active then Label1.Caption := 'Active' else Label1.Caption := 'Inactive';

  end;
end;

procedure TMainForm.CanDevicesChange(Sender: TObject);
begin
   CanChannel1.Channel := CanDevices.ItemIndex;
end;

procedure TMainForm.ClearClick(Sender: TObject);
begin
  Output.Clear;
end;


procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  with CanChannel1 do
  begin
  try
        BusActive := false;
        onBus.Caption := 'Off bus';
        goOnBus.Caption := 'Go on bus';
        CanDevices.Enabled := true;
  except

  end;
        Close;
  end;


end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  try
    CanChannel1 := TCanChannelEx.Create(Self);
  except
     ShowMessage('Error initialisiting, are KVASER drivers installed?');
     Application.Terminate();
  end;
  CanChannel1.Channel := 0;
  CANFail := false;
  SendData := false;
  ACKReceived := false;
  ECUFound := false;
  Output.clear;
end;

procedure TMainForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = chr(27) then Close; //  close window on hitting Esc
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  PopulateList;
end;



procedure TMainForm.GetConfigClick(Sender: TObject);
var
  msg: array[0..7] of byte;
begin

  with CanChannel1 do
  begin
    if Active then
    begin
      if ( MainStatus = 1) and ( not SendData ) then  // only send request if in startup state.
      begin

        msg[0] := 10;
        msg[1] := 1; // specify full EEPROM = 0

        GetConfig.Enabled := false;
        SendConfig.Enabled := false;
        Output.Items.Add('Getting EEPROM Data.');
        ReceiveData := true;
        SendPos := 0;
        CanSend($21,msg,8,0);
        SendTime := TStopwatch.StartNew;
      end;
    end;
  end;

end;


procedure TMainForm.testeepromwriteClick(Sender: TObject);
var
  msg: array[0..7] of byte;
begin
  msg[0] := 11;
  with CanChannel1 do
  begin
    if Active then
    begin
      if MainStatus = 1 then  // only send request if in startup state.
      begin
        CanSend($21,msg,3,0);
        Output.Items.Add('EEPROM Write Request');
      end;
    end;
  end;
end;


procedure TMainForm.Timer1Timer(Sender: TObject);
begin
  if SendData then  // ensure timeout runs
  begin
     if SendTime.ElapsedMilliseconds > 1000  then
      begin
        // timeout
        ReceiveData := false;
        SendPos := -1;
        SendConfig.Enabled := true;
        GetConfig.Enabled := true;
        Output.Items.Add('Send Timeout');
        SendData := false;
      end;
  end;

  if ReceiveData then  // ensure timeout runs
  begin
     if SendTime.ElapsedMilliseconds > 1000  then
      begin
        // timeout
        ReceiveData := false;
        SendPos := -1;
        SendConfig.Enabled := true;
        GetConfig.Enabled := true;
        Output.Items.Add('Receive Timeout');
      end;
  end;
end;

procedure TMainForm.sendIVT(msg0, msg1, msg2, msg3 : byte);
var
  msg: array[0..7] of byte;
begin
    msg[0] := msg0;
    msg[1] := msg1;
    msg[2] := msg2;
    msg[3] := msg3;
    MainForm.Output.Items.Add('IVTSend('+IntToStr(msg[0] )+','+IntToStr(msg[1] )+','+
                            IntToStr(msg[2] )+','+  IntToStr(msg[3] )+')');
    MainForm.CanSend($411, msg, 8, 0);
    Sleep(100);
end;

procedure TMainForm.Button1Click(Sender: TObject);
begin
  with CanChannel1 do begin
    if Active then begin
     // Bitrate := canBITRATE_500K;
      Bitrate := canBITRATE_1M;

      Channel := CanDevices.ItemIndex;

      Open;
      OnCanRx := CanChannel1CanRx;
      BusActive := true;
      CanDevices.Enabled := false;
      StartTime := Now;
      with CanChannel1 do begin
          sendIVT( $34, 0, 1, 0);     // stop operation.
       //   sendIVT( $3A ,2, 0, 0);     // set 1mbit canbus.

         // cyclic default settings..
          sendIVT( $20, 2, 0, 10);  // current 20ms
          sendIVT( $21, 2, 0, 10);  // voltages 60ms
          sendIVT( $22, 2, 0, 10);
          sendIVT( $23, 0, 0, 10);

          sendIVT( $24, 0, 0, 100);    // temp on. 100ms
          sendIVT( $25, 2, 0, 100);    // watts on. 100ms
          sendIVT( $26, 0, 0, 100);   // watt hours on.  100ms
          sendIVT( $27, 2, 0, 255);   // watt hours on.  100ms
          sendIVT( $32, 0, 0, 100);   // save settings.
          sendIVT( $34, 1, 1, 0);    // turn operation back on.

//          BusActive := false;
                output.Items.Add('IVT programmed');
      end
    end;
  end;
end;

procedure TMainForm.Button2Click(Sender: TObject);
begin
  with CanChannel1 do begin
    if Active then begin
   //   Bitrate := canBITRATE_500K;
      Bitrate := canBITRATE_1M;

      Channel := CanDevices.ItemIndex;

      Open;
      OnCanRx := CanChannel1CanRx;
      BusActive := true;
      StartTime := Now;
      with CanChannel1 do begin
          sendIVT( $34, 0, 1, 0);     // stop operation.
       //   sendIVT( $3A ,2, 0, 0);     // set 1mbit canbus., cycle connection after.
       // 1041, 52, 0, 1, 0 // stop operation
       // 1041, 58, 4, 0, 0     <- 500k , 2 for 1mbitm

       // reset everything message, 48, 0, 0, 0, 0, 19, 235

      // ivt serial no 5099 ( 0,0, 19, 235 )

      // alive message, 191, can id for messages ( hi, lo), serial  ( hh, hm, ml, ll )



              // cyclic 100ms settings.
          sendIVT( $20, 1, 0, 1);   // current
          sendIVT( $21, 1, 0, 1);   // v1
          sendIVT( $22, 1, 0, 1);   // v2
          sendIVT( $23, 1, 0, 1);   // v3
          sendIVT( $24, 1, 0, 1);   // temp

          sendIVT( $25, 1, 0, 1);   // watts on.
          sendIVT( $26, 1, 0, 1);   // As?
          sendIVT( $27, 1, 0, 1);   // watt hours on.

          sendIVT( $32, 1, 0, 1);   // save settings.
          sendIVT( $34, 1, 1, 0);

                                    // trigger $31, 7 = i,v1,v2
       //   BusActive := false;
                 output.Items.Add('IVT programmed');
      end
    end;
  end;
end;


procedure TMainForm.Button3Click(Sender: TObject);
begin
  with CanChannel1 do begin
    if not Active then begin
        Bitrate := canBITRATE_500K;

        Channel := CanDevices.ItemIndex;

        Options := [ccNotExclusive];

        Open;
        OnCanRx := CanChannel1CanRx;
        BusActive := true;
        CanDevices.Enabled := false;
        StartTime := Now;
        with CanChannel1 do begin
            sendIVT( $34, 0, 1, 0);     // stop operation.
            sendIVT( $3A ,2, 0, 0);     // set 1mbit canbus.

           // cyclic default settings..
            sendIVT( $20, 2, 0, 10);  // current 20ms
            sendIVT( $21, 2, 0, 10);  // voltages 60ms
            sendIVT( $22, 2, 0, 10);
            sendIVT( $23, 0, 0, 10);

            sendIVT( $24, 0, 0, 100);    // temp on. 100ms
            sendIVT( $25, 2, 0, 100);    // watts on. 100ms
            sendIVT( $26, 0, 0, 100);   // watt hours on.  100ms
            sendIVT( $27, 2, 0, 255);   // watt hours on.  100ms
            sendIVT( $32, 0, 0, 100);   // save settings.
            sendIVT( $34, 1, 1, 0);    // turn operation back on.

            BusActive := false;
            Close;
            Bitrate := canBITRATE_1M;
            output.Items.Add('IVT programmed');
        end;
        CanDevices.Enabled := true;
    end
    else
    begin
      output.Items.Add('Go offbus to factory program, different can rate.');
    end;
  end;
end;

procedure TMainForm.CanChannel1CanRx(Sender: TObject);
var
  dlc, flag, time: cardinal;
  msg, msgout: array[0..7] of byte;
  i : integer;
  status : cardinal;
  id: longint;
  formattedDateTime, str : string;
begin
//  Output.Items.BeginUpdate;
  with CanChannel1 do
  begin
    while Read(id, msg, dlc, flag, time) >= 0 do
    begin
      DateTimeToString(formattedDateTime, 'hh:mm:ss.zzzzzz', SysUtils.Now);
      if flag = $20 then
      begin
        Output.Items.Add('Error Frame');
        if Output.TopIndex > Output.Items.Count - 2 then
        Output.TopIndex := Output.Items.Count - 1;

      end
      else
      begin
        for i := 0 to 7 do
        msgout[i] := 0;

        case id of
          $511 : begin
                  { Output.Items.Add('IVTReceive('+ IntToStr(msg[0])+','+IntToStr(msg[1])+','+IntToStr(msg[2])
                      +','+IntToStr(msg[3])+','+ IntToStr(msg[4])+','+IntToStr(msg[5]) +
                      ','+ IntToStr(msg[6])+','+IntToStr(msg[7])
                      +') : ' + formattedDateTime);    }
                 end;
          $20 : begin
            if not ECUFound then
            begin
              ECUFound := true;
              Output.Items.Add('ECU Found');

              if MainStatus <> msg[1] then
              begin
                Output.Items.Add('StatusChange('+IntToStr(msg[1])+') '+formattedDateTime);
                Output.TopIndex := Output.Items.Count - 1;
                MainStatus := msg[1];
              end;
            end;

            if ( msg[0] = 30 ) then
            begin
                // message sending
                if msg[1] = 1 then
                begin
            //      Output.Items.Add('DataAck');
                  ACKReceived := true;
                  SendTime.Reset;
                  SendTime.Start;
                  SendNextData;
                end else if msg[1] = 99 then
                begin
                  Output.Items.Add('DataErr!');
                  ACKReceived := false;
                  SendData := false;
                  SendTime.Stop;
                  SendNextData;
                  SendConfig.Enabled := true;
                end;
            end
          end;

          $21 : begin
            if ReceiveData then
            begin
              if msg[0] = 8 then  // receive data.
              begin
                ReceiveSize := msg[1]*256+msg[2];
                SendPos := 0;
                SendDataAck(1);
                Output.Items.Add('StartReceive('+inttostr(Receivesize)+')');
                SendTime := TStopwatch.StartNew;
              end;

              if msg[0] = 9 then  // receive data.
              begin
     //            Output.Items.Add('RCV block');;
                 ReceiveNextData(msg);
                 SendTime.Reset;
                 SendTime.Start;
              end;
            end;

          end;

        end;
      end;
    end;
  end;

end;

end.

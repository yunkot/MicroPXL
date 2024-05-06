unit MainFm;
(*
 * This file is part of Micro Platform eXtended Library (MicroPXL).
 * Copyright (c) 2015 - 2024 Yuriy Kotsarenko. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License is
 * distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and limitations under the License.
 *)
interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, ExtCtrls, PXL.TypeDef, PXL.Types,
  PXL.Classes, PXL.NetComs;

type
  TMainForm = class(TForm)
    SendButton: TButton;
    DestHostEdit: TEdit;
    DestPortEdit: TEdit;
    HostLabel: TLabel;
    TextEdit: TEdit;
    PortLabel: TLabel;
    PortLabel1: TLabel;
    SendGroupBox: TGroupBox;
    IncomingGroupBox: TGroupBox;
    IncomingMemo: TMemo;
    StatusBar: TStatusBar;
    SysTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure SendButtonClick(Sender: TObject);
    procedure SysTimerTimer(Sender: TObject);
  private
    { private declarations }
    FNetCom: TNetCom;
    FInputStream: TMemoryStream;
    FOutputStream: TMemoryStream;

    procedure OnReceiveData(const ASender: TObject; const AHost: StdString; const APort: Integer;
      const AData: Pointer; const ASize: Integer);
  public
    { public declarations }
  end;

var
  MainForm: TMainForm;

implementation
{$R *.lfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FNetCom := TNetCom.Create;

  // The following streams will be used to send/receive network data.
  FInputStream := TMemoryStream.Create;
  FOutputStream := TMemoryStream.Create;

  // Specify the event that is going to handle data reception.
  FNetCom.OnReceive := OnReceiveData;

  // Specify the local port.
  FNetCom.LocalPort := 7500;

  if not FNetCom.Initialize then
  begin
    FNetCom.LocalPort := 0;

    if not FNetCom.Initialize then
    begin
      ShowMessage('FNetCom initialization failed');
      Exit;
    end;
  end;

  StatusBar.Panels[0].Text := 'Local IP: ' + FNetCom.LocalIP;
  StatusBar.Panels[1].Text := 'Local Port: ' + IntToStr(FNetCom.LocalPort);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FNetCom.Finalize;
  FOutputStream.Free;
  FInputStream.Free;
  FNetCom.Free;
end;

procedure TMainForm.SendButtonClick(Sender: TObject);
var
  LDestHost: StdString;
  LDestPort: Integer;
begin
  // Retreive the destination host and port.
  LDestHost := DestHostEdit.Text;
  LDestPort := StrToIntDef(DestPortEdit.Text, -1);

  // Start with a fresh data stream.
  FOutputStream.Clear;

  // Put the message text into the stream as UTF-8 StdString.
  FOutputStream.PutShortString(TextEdit.Text);

  // You can use other Put[whatever] methods from StreamUtils.pas to put other
  // kind of data into the stream, like integers, floats and so on.

  // Send the data from our stream.
  FNetCom.Send(LDestHost, LDestPort, FOutputStream.Memory, FOutputStream.Size);
end;

procedure TMainForm.OnReceiveData(const ASender: TObject; const AHost: StdString; const APort: Integer;
  const AData: Pointer; const ASize: Integer);
var
  LInpText: StdString;
begin
  // Put the incoming Adata into our input stream.
  FInputStream.Clear;
  FInputStream.WriteBuffer(AData^, ASize);

  // Start reading from the beginning.
  FInputStream.Seek(0, soFromBeginning);

  // Read the UTF-8 StdString from the stream.
  LInpText := FInputStream.GetShortString;

  // Show the resulting text in the memo.
  IncomingMemo.Lines.Add('Received "' + LInpText + '" from ' + AHost + ':' + IntToStr(APort));
end;

procedure TMainForm.SysTimerTimer(Sender: TObject);
begin
  FNetCom.Update;
end;

end.

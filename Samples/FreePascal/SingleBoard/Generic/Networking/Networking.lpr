program Networking;
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
{
  This example illustrates communication between applications on different devices through UDP protocol.

  The communication is compliant and should work along with desktop-grade "Networking" sample. That is, this and other
  sample can communicate to each other. This application can also communicate with itself running on a different
  device.

  Since in this application the terminal is used for reading and writing messages, it is not very comfortable to use,
  but it is meant to illustrate the usage of NetCom on singleboard devices, which is the same as on desktop.
}
uses
  Crt, Classes, SysUtils, PXL.TypeDef, PXL.Classes, PXL.Timing, PXL.NetComs;

type
  TApplication = class
  private const
    DefaultPort = 7500;
    KeySpace = #32;
    KeyEscape = #27;
  private
    FNetCom: TNetCom;

    procedure OnReceiveData(const ASender: TObject; const AHost: StdString; const APort: Integer;
      const AData: Pointer; const ASize: Integer);

    procedure SeparateHostAndPort(const AText: StdString; out AHost: StdString; out APort: Integer);
    procedure SendTextMessage(const ADestHost: StdString; const ADestPort: Integer;
      const AMsgText: StdString);

    function WaitForValidKey: StdChar;
    procedure AskForMessageToSend;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Execute;
  end;

constructor TApplication.Create;
begin
  inherited;

  FNetCom := TNetCom.Create;

  // Assign event, which will be invoked when some message arrives.
  FNetCom.OnReceive := OnReceiveData;

  // Try to initialize NetCom with default port.
  FNetCom.LocalPort := DefaultPort;

  if not FNetCom.Initialize then
  begin
    // Default port seems to be used, try any available port (it will be choosen automatically).
    FNetCom.LocalPort := 0;

    if not FNetCom.Initialize then
      raise Exception.Create('Could not initialize networking component.');
  end;

  WriteLn('Listening at port: ', FNetCom.LocalPort);
end;

destructor TApplication.Destroy;
begin
  FNetCom.Free;

  inherited;
end;

procedure TApplication.OnReceiveData(const ASender: TObject; const AHost: StdString; const APort: Integer;
  const AData: Pointer; const ASize: Integer);
var
  LStream: TMemoryStream;
  LInpText: StdString;
begin
  LStream := TMemoryStream.Create;
  try
    // Put the chunk of binary Adata into the Lstream.
    LStream.WriteBuffer(AData^, ASize);

    // Move current Lstream position back to the beginning.
    LStream.Position := 0;

    // Try to read a readable string from the Lstream.
    LInpText := LStream.GetShortString;

    // Additional Adata can be read here from the Lstream using reverse order in which it was embedded previously.
  finally
    LStream.Free;
  end;

  WriteLn('Received "', LInpText, '" from ', AHost, ':', IntToStr(APort) + '.');
end;

procedure TApplication.SeparateHostAndPort(const AText: StdString; out AHost: StdString; out APort: Integer);
var
  LColonPos: Integer;
begin
  LColonPos := Pos(':', AText);
  if LColonPos = 0 then
  begin
    AHost := AText;
    APort := DefaultPort;
  end
  else
  begin
    AHost := Trim(Copy(AText, 1, LColonPos - 1));
    APort := StrToIntDef(Trim(Copy(AText, LColonPos + 1, Length(AText) - LColonPos)), DefaultPort);
  end;
end;

procedure TApplication.SendTextMessage(const ADestHost: StdString; const ADestPort: Integer;
  const AMsgText: StdString);
var
  LStream: TMemoryStream;
begin
  LStream := TMemoryStream.Create;
  try
    // Put the message into the Lstream.
    LStream.PutShortString(AMsgText);

    // Additional data can be written and embedded here to the Lstream.

    // Send the Lstream as a chunk of binary data.
    FNetCom.Send(ADestHost, ADestPort, LStream.Memory, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function TApplication.WaitForValidKey: StdChar;
begin
  Result := #0;

  repeat
    if KeyPressed then
    begin
      Result := ReadKey;

      // Accept only SPACE or ESC.
      if (Result <> KeySpace) and (Result <> KeyEscape) then
        Result := #0;
    end;

    // This tells NetCom to check for any incoming messages and if such arrive, invoke OnDataReceive event.
    FNetCom.Update;

    Sleep(100); // wait for 100 ms
  until Result <> #0;
end;

procedure TApplication.AskForMessageToSend;
var
  LDestText, LDestHost: StdString;
  LDestPort: Integer;
begin
  WriteLn('Please type destination address and port separated by ":", something like: "192.168.0.2:7500".');
  Write('> ');

  ReadLn(LDestText);
  if Length(LDestText) <= 0 then
    Exit;

  SeparateHostAndPort(LDestText, LDestHost, LDestPort);
  WriteLn('Type message for host "', LDestHost, '" and port "', LDestPort, '":');
  Write('> ');

  ReadLn(LDestText);
  if Length(LDestText) <= 0 then
    Exit;

  SendTextMessage(LDestHost, LDestPort, LDestText);
  WriteLn('Message sent.');
end;

procedure TApplication.Execute;
var
  LKey: StdChar;
begin
  repeat
    WriteLn('Waiting for incoming messages, press ESC to exit or SPACE to send a message...');

    LKey := WaitForValidKey;

    if LKey = KeySpace then
      AskForMessageToSend;
  until LKey = KeyEscape;
end;

var
  Application: TApplication = nil;

begin
  Application := TApplication.Create;
  try
    Application.Execute;
  finally
    Application.Free;
  end;
end.

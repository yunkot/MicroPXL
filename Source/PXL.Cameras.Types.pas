unit PXL.Cameras.Types;
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

{$INCLUDE PXL.Config.inc}
{.$DEFINE CAMERA_DEBUG}

uses
  PXL.TypeDef, PXL.Boards.Types;

type
  TCustomCamera = class
  protected const
    ProtocolSendID = $56;
    ProtocolReceiveID = $76;
    ProtocolSerialNo = $00;
    ProtocolDataEmpty = $00;
    ProtocolStatusOK = $00;

    ProtocolCommandReset = $26;
    ProtocolCommandSetBaudRate = $24;
    ProtocolCommandSetImageSize = $54;
    ProtocolCommandBufferControl = $36;
    ProtocolCommandGetBufferSize = $34;
    ProtocolCommandGetBufferData = $32;

    DefaultReactTimeout = 50;

    DefaultTextCharacterLimit = 256;
    DefaultTextTimeout = 500;
  private
    FDataPort: TCustomPortUART;
  protected
  {$IFDEF CAMERA_DEBUG}
    procedure LogDumpBytes(const ABytes: PByte; const AByteCount: Integer);
  {$ENDIF}

    function ComputeBaudTimeout(const AByteCount: Integer): Integer; virtual;

    function SendCommand(const ACommand: Integer; const AData: array of Byte): Boolean; overload;
    function SendCommand(const ACommand: Integer): Boolean; overload;
    function ReceiveAck(const ACommand: Integer; const
      AReactTimeout: Integer = DefaultReactTimeout): Boolean;
    function ReceiveAckInt32(const ACommand: Integer; out AValue: Integer;
      const AReactTimeout: Integer = DefaultReactTimeout): Boolean;
    function ReceiveAckString(const ACommand: Integer; out AText: StdString;
      const AStringReactTimeout: Integer = DefaultReactTimeout;
      const AReactTimeout: Integer = DefaultReactTimeout): Boolean;

    function ReceiveText(const AMaxCharacters: Integer = DefaultTextCharacterLimit;
      const ATimeout: Integer = DefaultTextTimeout): StdString;

    function GetDefaultBaudRate: Integer; virtual;
  public
    constructor Create(const ADataPort: TCustomPortUART);

    function Reset: Boolean; virtual; abstract;
    function SetImageSize(const AWidth, AHeight: Integer): Boolean; virtual; abstract;

    function TakeSnapshot: Boolean; virtual; abstract;

    function GetPictureSize: Integer; virtual; abstract;
    function GetPicture(out ABuffer: Pointer; out ABufferSize: Integer): Boolean; virtual; abstract;

    property DataPort: TCustomPortUART read FDataPort;
    property DefaultBaudRate: Integer read GetDefaultBaudRate;
  end;

implementation

uses
{$IFDEF CAMERA_DEBUG}
  PXL.Logs, Math,
{$ENDIF}

  SysUtils;

constructor TCustomCamera.Create(const ADataPort: TCustomPortUART);
begin
  inherited Create;

  FDataPort := ADataPort;
end;

{$IFDEF CAMERA_DEBUG}
procedure TCustomCamera.LogDumpBytes(const ABytes: PByte; const AByteCount: Integer);
var
  LSrcByte: PByte;
  I: Integer;
begin
  LSrcByte := ABytes;
  for I := 0 to AByteCount - 1 do
  begin
    LogText('  [byte ' + IntToStr(I) + '] = ' + IntToHex(LSrcByte^, 2) + 'h');
    Inc(LSrcByte);
  end;
end;
{$ENDIF}

function TCustomCamera.ComputeBaudTimeout(const AByteCount: Integer): Integer;
const
  BitsPerByte = 12; // assume generous extra 4 bits wasted in case of losses or other delays
var
  LBytesPerMSec: Int64;
  LTimeNeeded: Integer;
begin
  LBytesPerMSec := Int64(1000) * Int64(FDataPort.BaudRate) div BitsPerByte;
  if LBytesPerMSec <= 0 then
    Exit(0);

  LTimeNeeded := (Int64(1000000) * Int64(AByteCount)) div LBytesPerMSec;
  Result := LTimeNeeded + (10 - (LTimeNeeded mod 10))
end;

function TCustomCamera.SendCommand(const ACommand: Integer; const AData: array of Byte): Boolean;
var
  LValues: array of Byte;
  LBytesWritten, I: Integer;
begin
  SetLength(LValues, 4 + Length(AData));

  LValues[0] := ProtocolSendID;
  LValues[1] := ProtocolSerialNo;
  LValues[2] := ACommand;
  LValues[3] := Length(AData);

  for I := 0 to Length(AData) - 1 do
    LValues[4 + I] := AData[I];

  LBytesWritten := FDataPort.WriteBuffer(@LValues[0], Length(LValues), ComputeBaudTimeout(Length(LValues)));
  Result := LBytesWritten = Length(LValues);

{$IFDEF CAMERA_DEBUG}
  if not Result then
  begin
    LogText(ClassName + '.SendCommand (extended) failed, sending ' + IntToStr(LBytesWritten) + ' out of ' +
      IntToStr(Length(LValues)) + ' bytes:');
    LogDumpBytes(@LValues[0], Length(LValues));
  end;
{$ENDIF}
end;

function TCustomCamera.SendCommand(const ACommand: Integer): Boolean;
var
  LValues: array[0..3] of Byte;
  LBytesWritten: Integer;
begin
  LValues[0] := ProtocolSendID;
  LValues[1] := ProtocolSerialNo;
  LValues[2] := ACommand;
  LValues[3] := ProtocolDataEmpty;

  LBytesWritten := FDataPort.WriteBuffer(@LValues[0], SizeOf(LValues), ComputeBaudTimeout(SizeOf(LValues)));
  Result := LBytesWritten = SizeOf(LValues);

{$IFDEF CAMERA_DEBUG}
  if not Result then
  begin
    LogText(ClassName + '.SendCommand failed, sending ' + IntToStr(LBytesWritten) + ' out of ' +
      IntToStr(Length(LValues)) + ' bytes:');
    LogDumpBytes(@LValues[0], SizeOf(LValues));
  end;
{$ENDIF}
end;

function TCustomCamera.ReceiveAck(const ACommand: Integer; const AReactTimeout: Integer): Boolean;
var
  LValues: array[0..4] of Byte;
  LBytesRead: Integer;
begin
  LBytesRead := FDataPort.ReadBuffer(@LValues[0], SizeOf(LValues), ComputeBaudTimeout(SizeOf(LValues)) +
    AReactTimeout);
  if LBytesRead <> SizeOf(LValues) then
  begin
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.ReceiveAck failed, reading ' + IntToStr(LBytesRead) + ' out of ' +
      IntToStr(SizeOf(LValues)) + ' bytes:');
    LogDumpBytes(@LValues[0], Min(LBytesRead, SizeOf(LValues)));
  {$ENDIF}
    Exit(False);
  end;

  if (LValues[0] <> ProtocolReceiveID) or (LValues[1] <> ProtocolSerialNo) or (LValues[2] <> ACommand) or
    (LValues[3] <> ProtocolStatusOK) or (LValues[4] <> ProtocolDataEmpty) then
  begin
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.ReceiveAck failed, due to unexpected response.');
    LogText('  Expected: ' + IntToHex(ProtocolReceiveID, 2) + 'h, ' + IntToHex(ProtocolSerialNo, 2) + 'h, ' +
      IntToHex(ACommand, 2) + 'h, ' + IntToHex(ProtocolStatusOK, 2) + 'h, ' + IntToHex(ProtocolDataEmpty, 2) + 'h.');
    LogDumpBytes(@LValues[0], SizeOf(LValues));
  {$ENDIF}
    Exit(False);
  end;

  Result := True;
end;

function TCustomCamera.ReceiveAckInt32(const ACommand: Integer; out AValue: Integer;
  const AReactTimeout: Integer): Boolean;
const
  ByteCount = 9;
var
  LValues: array[0..ByteCount - 1] of Byte;
  LBytesRead: Integer;
begin
  LBytesRead := FDataPort.ReadBuffer(@LValues[0], ByteCount, ComputeBaudTimeout(ByteCount) + AReactTimeout);
  if LBytesRead <> ByteCount then
  begin
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.ReceiveAckInt32 failed, reading ' + IntToStr(LBytesRead) + ' out of ' +
      IntToStr(ByteCount) + ' bytes:');
    LogDumpBytes(@LValues[0], Min(LBytesRead, ByteCount));
  {$ENDIF}
    Exit(False);
  end;

  if (LValues[0] <> ProtocolReceiveID) or (LValues[1] <> ProtocolSerialNo) or (LValues[2] <> ACommand) or
    (LValues[3] <> ProtocolStatusOK) or (LValues[4] <> 4) then
  begin
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.ReceiveAckInt32 failed, due to unexpected response.');
    LogText('  Expected: ' + IntToHex(ProtocolReceiveID, 2) + 'h, ' + IntToHex(ProtocolSerialNo, 2) + 'h, ' +
      IntToHex(ACommand, 2) + 'h, ' + IntToHex(ProtocolStatusOK, 2) + 'h, 04h.');
    LogDumpBytes(@LValues[0], SizeOf(LValues));
  {$ENDIF}
    Exit(False);
  end;

  AValue := Integer(Cardinal(LValues[5]) shl 24) or Integer(Cardinal(LValues[6]) shl 16) or
    Integer(Cardinal(LValues[7]) shl 8) or Integer(Cardinal(LValues[8]));

  Result := True;
end;

function TCustomCamera.ReceiveAckString(const ACommand: Integer; out AText: StdString;
  const AStringReactTimeout: Integer; const AReactTimeout: Integer): Boolean;
const
  ByteCount = 5;
var
  LValues: array[0..ByteCount - 1] of Byte;
  LBytesRead, LExpectedStringSize: Integer;
begin
  LBytesRead := FDataPort.ReadBuffer(@LValues[0], ByteCount, ComputeBaudTimeout(ByteCount) + AReactTimeout);
  if LBytesRead <> ByteCount then
  begin
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.ReceiveAckString failed, reading ' + IntToStr(LBytesRead) + ' out of ' +
      IntToStr(ByteCount) + ' bytes:');
    LogDumpBytes(@LValues[0], Min(LBytesRead, ByteCount));
  {$ENDIF}
    Exit(False);
  end;

  if (LValues[0] <> ProtocolReceiveID) or (LValues[1] <> ProtocolSerialNo) or (LValues[2] <> ACommand) or
    (LValues[3] <> ProtocolStatusOK) or (LValues[4] <= 0) then
  begin
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.ReceiveAckString failed, due to unexpected response.');
    LogText('  Expected: ' + IntToHex(ProtocolReceiveID, 2) + 'h, ' + IntToHex(ProtocolSerialNo, 2) + 'h, ' +
      IntToHex(ACommand, 2) + 'h, ' + IntToHex(ProtocolStatusOK, 2) + 'h, XXh.');
    LogDumpBytes(@LValues[0], SizeOf(LValues));
  {$ENDIF}
    Exit(False);
  end;

  LExpectedStringSize := LValues[4];

  Result := FDataPort.ReadString(AText, LExpectedStringSize, ComputeBaudTimeout(LExpectedStringSize) +
    AStringReactTimeout);
  if Length(AText) <> LExpectedStringSize then
  begin
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.ReceiveAckString: Expected ' + IntToStr(LExpectedStringSize) +
      ' string length, but got ' + IntToStr(Length(AText)) + ' bytes.');
    if Length(AText) > 0 then
      LogText('  Received string is: ' + AText);
  {$ENDIF}
    Result := False;
  end;
end;

function TCustomCamera.ReceiveText(const AMaxCharacters, ATimeout: Integer): StdString;
begin
  if not FDataPort.ReadString(Result, AMaxCharacters, ATimeout) then
  begin
  {$IFDEF CAMERA_DEBUG}
    if Length(Result) <= 0 then
      LogText(ClassName + '.ReceiveText: Failed reading text.');
  {$ENDIF}
    Exit('');
  end;

{$IFDEF CAMERA_DEBUG}
  if Length(Result) <= 0 then
    LogText(ClassName + '.ReceiveAckString: Expected text, but got nothing.');
{$ENDIF}
end;

function TCustomCamera.GetDefaultBaudRate: Integer;
begin
  Result := 38400;
end;

end.

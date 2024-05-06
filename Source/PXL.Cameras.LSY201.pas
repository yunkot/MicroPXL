unit PXL.Cameras.LSY201;
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
  PXL.TypeDef, PXL.Cameras.Types;

type
  TCamera = class(TCustomCamera)
  protected const
    ProtocolCommandSetIRCut = $AA;

    SnapshotReactTimeout = 4000;
  private
    FBootText: StdString;

    function BaudRateToCode(const AValue: Integer): Word;
    function ImageSizeToCode(const AWidth, AHeight: Integer): Byte;
  protected
    function GetDefaultBaudRate: Integer; override;
  public
    function Reset: Boolean; override;

    function SetImageSize(const AWidth, AHeight: Integer): Boolean; override;
    function TakeSnapshot: Boolean; override;

    function GetPictureSize: Integer; override;
    function GetPicture(out ABuffer: Pointer; out ABufferSize: Integer): Boolean; override;

    function SetBaudRate(const ABaudRate: Integer): Boolean;
    function SetIRCut(const ADayMode: Boolean): Boolean;

    property BootText: StdString read FBootText;
  end;

implementation

uses
{$IFDEF CAMERA_DEBUG}
  PXL.Logs,
{$ENDIF}

  SysUtils;

function TCamera.GetDefaultBaudRate: Integer;
begin
  Result := 115200;
end;

function TCamera.BaudRateToCode(const AValue: Integer): Word;
begin
  if AValue = 9600 then
    Result := $AEC8
  else if AValue = 19200 then
    Result := $56E4
  else if AValue = 38400 then
    Result := $2AF2
  else if AValue = 57600 then
    Result := $1C4C
  else if AValue = 115200 then
    Result := $0DA6
  else
    Result := $0000;
end;

function TCamera.ImageSizeToCode(const AWidth, AHeight: Integer): Byte;
begin
  if (AWidth = 160) and (AHeight = 120) then
    Result := $22
  else if (AWidth = 320) and (AHeight = 240) then
    Result := $11
  else if (AWidth = 640) and (AHeight = 480) then
    Result := $00
  else if (AWidth = 800) and (AHeight = 600) then
    Result := $1D
  else if (AWidth = 1024) and (AHeight = 768) then
    Result := $1C
  else if (AWidth = 1280) and (AHeight = 960) then
    Result := $1B
  else if (AWidth = 1600) and (AHeight = 1200) then
    Result := $21
  else
    Result := $FF;
end;

function TCamera.Reset: Boolean;
begin
  if not SendCommand(ProtocolCommandReset) then
    Exit(False);

  FBootText := ReceiveText;
  Result := Length(FBootText) > 0;
end;

function TCamera.SetImageSize(const AWidth, AHeight: Integer): Boolean;
var
  LCode: Byte;
begin
  LCode := ImageSizeToCode(AWidth, AHeight);
  if LCode = $FF then
  begin
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.SedImageSize: Unsupported image size.');
  {$ENDIF}
    Exit(False);
  end;

  if not SendCommand(ProtocolCommandSetImageSize, [LCode]) then
    Exit(False);

  Result := ReceiveAck(ProtocolCommandSetImageSize);
end;

function TCamera.TakeSnapshot: Boolean;
begin
  if not SendCommand(ProtocolCommandBufferControl, [$00]) then
    Exit(False);

  Result := ReceiveAck(ProtocolCommandBufferControl, SnapshotReactTimeout);
end;

function TCamera.GetPictureSize: Integer;
begin
  if not SendCommand(ProtocolCommandGetBufferSize, [$00]) then
    Exit(0);

  if not ReceiveAckInt32(ProtocolCommandGetBufferSize, Result) then
    Result := 0;
end;

function TCamera.GetPicture(out ABuffer: Pointer; out ABufferSize: Integer): Boolean;
const
  DataRetrieveDelay = 40; // ms
  DataReactTimeout = 500; // ms
var
  LBytesRead: Integer;
begin
  ABuffer := nil;

  ABufferSize := GetPictureSize;
  if ABufferSize <= 0 then
    Exit(False);

  if not SendCommand(ProtocolCommandGetBufferData, [$00, $0A, $00, $00, $00, $00,
    Cardinal(ABufferSize) shr 24, (Cardinal(ABufferSize) shr 16) and $FF,
    (Cardinal(ABufferSize) shr 8) and $FF, Cardinal(ABufferSize) and $FF, $02, $00]) then
    Exit(False);

  if not ReceiveAck(ProtocolCommandGetBufferData) then
    Exit(False);

  Sleep(DataRetrieveDelay);

  ABuffer := AllocMem(ABufferSize);

  LBytesRead := DataPort.ReadBuffer(ABuffer, ABufferSize, DataReactTimeout + ComputeBaudTimeout(ABufferSize));
  if LBytesRead <> ABufferSize then
  begin
    FreeMemAndNil(ABuffer);
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.GetPicture: Failed reading data, obtained ' + IntToStr(LBytesRead) + ' out of ' +
      IntToStr(ABufferSize) + ' bytes.');
  {$ENDIF}
    Exit(False);
  end;

  Result := ReceiveAck(ProtocolCommandGetBufferData);
end;

function TCamera.SetBaudRate(const ABaudRate: Integer): Boolean;
var
  LCode: Word;
begin
  LCode := BaudRateToCode(ABaudRate);
  if LCode = 0 then
  begin
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.SedBaudRate: Unsupported baud rate value.');
  {$ENDIF}
    Exit(False);
  end;

  if not SendCommand(ProtocolCommandSetBaudRate, [$01, LCode shr 8, LCode and $FF]) then
    Exit(False);

  Result := ReceiveAck(ProtocolCommandSetBaudRate);
end;

function TCamera.SetIRCut(const ADayMode: Boolean): Boolean;
var
  LCode: Byte;
//  LBytesWritten: Integer;
//  LValues: array[0..4] of Byte;
begin
  if ADayMode then
    LCode := $00
  else
    LCode := $01;

(*  LValues[0] := ProtocolSendID;
  LValues[1] := ProtocolSerialNo;
  LValues[2] := ProtocolCommandSetIRCut;
  LValues[4] := $00;

  if ADayMode then
    LValues[3] := $00
  else
    LValues[3] := $01;

  LBytesWritten := SerialPort.WriteBuffer(@LValues[0], SizeOf(LValues), ComputeBaudTimeout(SizeOf(LValues)));
  if LBytesWritten <> SizeOf(LValues) then
  begin
  {$IFDEF CAMERA_DEBUG}
    LogText(ClassName + '.SetIRCut failed, sending ' + IntToStr(LBytesWritten) + ' out of ' +
      IntToStr(SizeOf(LValues)) + ' bytes:');
    LogDumpBytes(@LValues[0], SizeOf(LValues));
  {$ENDIF}
    Exit(False);
  end;*)

  if not SendCommand(ProtocolCommandSetIRCut, [LCode]) then
    Exit(False);

  Result := ReceiveAck(ProtocolCommandSetIRCut);
end;

end.

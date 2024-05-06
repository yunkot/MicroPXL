unit PXL.Cameras.VC0706;
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
    ProtocolCommandGetVersion = $11;
  private
    FBootText: StdString;
    FVersionText: StdString;

    function ImageSizeToCode(const AWidth, AHeight: Integer): Byte;
  protected
    function GetDefaultBaudRate: Integer; override;

    function ChangeCaptureStatus(const AEnabled: Boolean): Boolean;
  public
    function Reset: Boolean; override;
    function GetVersion: Boolean;

    function SetImageSize(const AWidth, AHeight: Integer): Boolean; override;
    function TakeSnapshot: Boolean; override;

    function GetPictureSize: Integer; override;
    function GetPicture(out ABuffer: Pointer; out ABufferSize: Integer): Boolean; override;

    function ResumeCapture: Boolean;
    function StopCapture: Boolean;

    property BootText: StdString read FBootText;
    property VersionText: StdString read FVersionText;
  end;

implementation

uses
{$IFDEF CAMERA_DEBUG}
  PXL.Logs,
{$ENDIF}

  SysUtils;

function TCamera.GetDefaultBaudRate: Integer;
begin
  Result := 38400;
end;

function TCamera.ImageSizeToCode(const AWidth, AHeight: Integer): Byte;
begin
  if (AWidth = 160) and (AHeight = 120) then
    Result := $22
  else if (AWidth = 320) and (AHeight = 240) then
    Result := $11
  else if (AWidth = 640) and (AHeight = 480) then
    Result := $00
  else
    Result := $FF;
end;

function TCamera.Reset: Boolean;
begin
  if not SendCommand(ProtocolCommandReset) then
    Exit(False);

  if not ReceiveAck(ProtocolCommandReset) then
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

function TCamera.GetVersion: Boolean;
begin
  if not SendCommand(ProtocolCommandGetVersion) then
    Exit(False);

  Result := ReceiveAckString(ProtocolCommandGetVersion, FVersionText);
end;

function TCamera.ChangeCaptureStatus(const AEnabled: Boolean): Boolean;
var
  LControlFlag: Byte;
begin
  if AEnabled then
    LControlFlag := $02
  else
    LControlFlag := $00;

  if not SendCommand(ProtocolCommandBufferControl, [LControlFlag]) then
    Exit(False);

  Result := ReceiveAck(ProtocolCommandBufferControl);
end;

function TCamera.TakeSnapshot: Boolean;
begin
  Result := ChangeCaptureStatus(False);
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

  LBytesRead := DataPort.ReadBuffer(ABuffer, ABufferSize, DataReactTimeout +
    ComputeBaudTimeout(ABufferSize));
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

function TCamera.ResumeCapture: Boolean;
begin
  Result := ChangeCaptureStatus(True);
end;

function TCamera.StopCapture: Boolean;
begin
  Result := ChangeCaptureStatus(False);
end;

end.

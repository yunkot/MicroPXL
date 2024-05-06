unit PXL.Clocks.DS1307;
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

uses
  SysUtils, PXL.Boards.Types;

type
  // Abstract RTC (Real-Time Clock) manager.
  TCustomClockRTC = class
  protected
    // Returns current clock value.
    function GetValue: TDateTime; virtual; abstract;

    // Sets new clock value.
    procedure SetValue(const AValue: TDateTime); virtual; abstract;
  public
    // Current clock value.
    property Value: TDateTime read GetValue write SetValue;
  end;

  TClockRTC = class(TCustomClockRTC)
  public const
    DefaultAddress = $68;
  private
    FDataPort: TCustomPortI2C;
    FAddress: Integer;

    class function ValueToBCD(const AValue: Integer): Integer; static; inline;
    class function BCDToValue(const AValue: Integer): Integer; static; inline;

    function GetSquarePinMode: Integer;
    procedure SetSquarePinMode(const APinMode: Integer);
  protected
    function GetValue: TDateTime; override;
    procedure SetValue(const AValue: TDateTime); override;
  public
    constructor Create(const ADataPort: TCustomPortI2C; const AAddress: Integer = DefaultAddress);

    procedure ReadNVRAM(const ADataAddress: Integer; const ABuffer: Pointer; const ABufferSize: Integer);
    procedure WriteNVRAM(const ADataAddress: Integer; const ABuffer: Pointer; const ABufferSize: Integer);

    property DataPort: TCustomPortI2C read FDataPort;
    property Address: Integer read FAddress;
    property SquarePinMode: Integer read GetSquarePinMode write SetSquarePinMode;
  end;

  EClockGeneric = class(Exception);

  EClockDataRead = class(EClockGeneric);
  EClockDataWrite = class(EClockGeneric);

  EClockNoDataPort = class(EClockGeneric);
  EClockInvalidAddress = class(EClockGeneric);

  EClockNVRAMError = class(EClockGeneric);
  EClockNVRAMInvalidAddress = class(EClockNVRAMError);
  EClockNVRAMDataTooBig = class(EClockNVRAMError);
  EClockNVRAMDataInvalid = class(EClockNVRAMError);

resourcestring
  SClockDataRead = 'Unable to read <%d> bytes from RTC clock.';
  SClockDataWrite = 'Unable to write <%d> bytes to RTC clock.';
  SClockNoDataPort = 'A valid data port is required for RTC clock.';
  SClockInvalidAddress = 'The specified RTC clock address <%x> is invalid.';
  SClockNVRAMInvalidAddress = 'The specified RTC clock NVRAM address <%x> is invalid.';
  SClockNVRAMDataTooBig = 'RTC clock <%d> data bytes starting at <%x> address is too big to fit in NVRAM.';
  SClockNVRAMDataInvalid = 'The specified data buffer and/or size are invalid.';

implementation

uses
  DateUtils;

class function TClockRTC.ValueToBCD(const AValue: Integer): Integer;
begin
  Result := AValue + 6 * (AValue div 10);
end;

class function TClockRTC.BCDToValue(const AValue: Integer): Integer;
begin
  Result := AValue - 6 * (AValue shr 4);
end;

constructor TClockRTC.Create(const ADataPort: TCustomPortI2C; const AAddress: Integer);
begin
  inherited Create;

  FDataPort := ADataPort;
  if FDataPort = nil then
    raise EClockNoDataPort.Create(SClockNoDataPort);

  FAddress := AAddress;
  if (FAddress < 0) or (FAddress > $7F) then
    raise EClockInvalidAddress.Create(Format(SClockInvalidAddress, [FAddress]));
end;

function TClockRTC.GetValue: TDateTime;
var
  LValues: array[0..6] of Byte;
begin
  FDataPort.SetAddress(FAddress);
  FDataPort.WriteByte(0);

  if FDataPort.Read(@LValues[0], SizeOf(LValues)) <> SizeOf(LValues) then
    raise EClockDataRead.Create(Format(SClockDataRead, [SizeOf(LValues)]));

  Result := EncodeDateTime(BCDToValue(LValues[6]) + 2000, BCDToValue(LValues[5]), BCDToValue(LValues[4]),
    BCDToValue(LValues[2]), BCDToValue(LValues[1]), BCDToValue(LValues[0] and $7F), 0);
end;

procedure TClockRTC.SetValue(const AValue: TDateTime);
var
  LValues: array[0..9] of Byte;
  LYears, LMonths, LDays, LHours, LMinutes, LSeconds, LMilliseconds: Word;
begin
  DecodeDateTime(AValue, LYears, LMonths, LDays, LHours, LMinutes, LSeconds, LMilliseconds);

  LValues[0] := 0;
  LValues[1] := ValueToBCD(LSeconds);
  LValues[2] := ValueToBCD(LMinutes);
  LValues[3] := ValueToBCD(LHours);

  LValues[4] := 0;
  LValues[5] := ValueToBCD(LDays);
  LValues[6] := ValueToBCD(LMonths);
  LValues[7] := ValueToBCD(LYears - 2000);
  LValues[8] := 0;

  FDataPort.SetAddress(FAddress);

  if FDataPort.Write(@LValues[0], SizeOf(LValues)) <> SizeOf(LValues) then
    raise EClockDataWrite.Create(Format(SClockDataWrite, [SizeOf(LValues)]));
end;

function TClockRTC.GetSquarePinMode: Integer;
var
  Value: Byte;
begin
  FDataPort.SetAddress(FAddress);
  FDataPort.WriteByte($07);

  if not FDataPort.ReadByte(Value) then
    raise EClockDataRead.Create(Format(SClockDataRead, [SizeOf(Byte)]));

  Result := Value and $93;
end;

procedure TClockRTC.SetSquarePinMode(const APinMode: Integer);
var
  LValues: array[0..1] of Byte;
begin
  LValues[0] := $07;
  LValues[1] := APinMode;

  FDataPort.SetAddress(FAddress);

  if FDataPort.Write(@LValues[0], SizeOf(LValues)) <> SizeOf(LValues) then
    raise EClockDataWrite.Create(Format(SClockDataWrite, [SizeOf(LValues)]));
end;

procedure TClockRTC.ReadNVRAM(const ADataAddress: Integer; const ABuffer: Pointer;
  const ABufferSize: Integer);
begin
  if (ADataAddress < 0) or (ADataAddress >= 56) then
    raise EClockNVRAMInvalidAddress.Create(Format(SClockNVRAMInvalidAddress, [ADataAddress]));

  if ADataAddress + ABufferSize > 56 then
    raise EClockNVRAMDataTooBig.Create(Format(SClockNVRAMDataTooBig, [ABufferSize, ADataAddress]));

  if (ABuffer = nil) or (ABufferSize < 1) then
    raise EClockNVRAMDataInvalid.Create(SClockNVRAMDataInvalid);

  FDataPort.SetAddress(FAddress);
  FDataPort.WriteByte($08 + ADataAddress);

  if FDataPort.Read(ABuffer, ABufferSize) <> ABufferSize then
    raise EClockDataRead.Create(Format(SClockDataRead, [ABufferSize]));
end;

procedure TClockRTC.WriteNVRAM(const ADataAddress: Integer; const ABuffer: Pointer;
  const ABufferSize: Integer);
var
  LValues: array of Byte;
begin
  if (ADataAddress < 0) or (ADataAddress >= 56) then
    raise EClockNVRAMInvalidAddress.Create(Format(SClockNVRAMInvalidAddress, [ADataAddress]));

  if ADataAddress + ABufferSize > 56 then
    raise EClockNVRAMDataTooBig.Create(Format(SClockNVRAMDataTooBig, [ABufferSize, ADataAddress]));

  if (ABuffer = nil) or (ABufferSize < 1) then
    raise EClockNVRAMDataInvalid.Create(SClockNVRAMDataInvalid);

  SetLength(LValues, ABufferSize + 1);
  LValues[0] := $08 + ADataAddress;

  Move(ABuffer^, LValues[1], ABufferSize);

  FDataPort.SetAddress(FAddress);
  if FDataPort.Write(@LValues[0], ABufferSize + 1) <> ABufferSize + 1 then
    raise EClockDataWrite.Create(Format(SClockDataWrite, [ABufferSize + 1]));
end;

end.

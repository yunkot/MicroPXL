unit PXL.Sensors.L3GD20;
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
  Types, PXL.Types, PXL.Boards.Types, PXL.Sensors.Types;

type
  TSensorL3GD20 = class(TCustomSensor)
  public type
    TSensitivity = (Scale245, Scale500, Scale2000);
    TGyroscope = array[0..2] of Single;
    TGyroscopeRaw = array[0..2] of Integer;
  public const
    DefaultAddress = $6B;
  private
    FDataPort: TCustomPortI2C;
    FAddress: Integer;
    FSensitivity: TSensitivity;
    FGyroCoefficient: Single;

    procedure TestChipID;
    procedure Configure;

    function GetGyroscope: TGyroscope;
  public
    constructor Create(const ADataPort: TCustomPortI2C;  const AAddress: Integer = DefaultAddress;
      const ASensitivity: TSensitivity = TSensitivity.Scale245);

    function GetGyroscopeRaw: TGyroscopeRaw;
    function GetTemperatureRaw: Integer;

    property DataPort: TCustomPortI2C read FDataPort;
    property Address: Integer read FAddress;
    property Sensitivity: TSensitivity read FSensitivity;

    property Gyroscope: TGyroscope read GetGyroscope;
    property Temperature: Integer read GetTemperatureRaw;
  end;

implementation

uses
  SysUtils, Math;

constructor TSensorL3GD20.Create(const ADataPort: TCustomPortI2C; const AAddress: Integer;
  const ASensitivity: TSensitivity);
begin
  inherited Create;

  FDataPort := ADataPort;
  if FDataPort = nil then
    raise ESensorNoDataPort.Create(SSensorNoDataPort);

  FAddress := AAddress;
  if (FAddress < 0) or (FAddress > $7F) then
    raise ESensorInvalidAddress.Create(Format(SSensorInvalidAddress, [FAddress]));

  FSensitivity := ASensitivity;

  TestChipID;
  Configure;
end;

procedure TSensorL3GD20.TestChipID;
const
  ExpectedID1 = $D4;
  ExpectedID2 = $D7;
var
  ChipID: Byte;
begin
  FDataPort.SetAddress(FAddress);

  if not FDataPort.ReadByteData($0F, ChipID) then
    raise ESensorDataRead.Create(Format(SSensorDataRead, [SizeOf(ChipID)]));

  if not (ChipID in [ExpectedID1, ExpectedID2]) then
    raise ESensorInvalidChipID.Create(Format(SSensorInvalidChipID, [ExpectedID2, ChipID]));
end;

procedure TSensorL3GD20.Configure;
begin
  FDataPort.SetAddress(FAddress);

  if not FDataPort.WriteByteData($20, $0F) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [2]));

  if not FDataPort.WriteByteData($23, Ord(FSensitivity) shl 4) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [2]));

  case FSensitivity of
    TSensitivity.Scale500:
      FGyroCoefficient := 1.0 / 500.0;

    TSensitivity.Scale2000:
      FGyroCoefficient := 1.0 / 2000.0;
  else
    FGyroCoefficient := 1.0 / 250.0;
  end;
end;

function TSensorL3GD20.GetGyroscopeRaw: TGyroscopeRaw;
var
  LValues: array[0..5] of Byte;
begin
  FDataPort.SetAddress(FAddress);

  if not FDataPort.WriteByte($28 or $80) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [SizeOf(Byte)]));

  if FDataPort.Read(@LValues[0], SizeOf(LValues)) <> SizeOf(LValues) then
    raise ESensorDataRead.Create(Format(SSensorDataRead, [SizeOf(LValues)]));

  Result[0] := SmallInt(Word(LValues[0]) or (Word(LValues[1]) shl 8));
  Result[1] := SmallInt(Word(LValues[2]) or (Word(LValues[3]) shl 8));
  Result[2] := SmallInt(Word(LValues[4]) or (Word(LValues[5]) shl 8));
end;

function TSensorL3GD20.GetTemperatureRaw: Integer;
var
  LValue: Byte;
begin
  FDataPort.SetAddress(FAddress);

  if not FDataPort.ReadByteData($26, LValue) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [SizeOf(Byte)]));

  Result := LValue;
end;

function TSensorL3GD20.GetGyroscope: TGyroscope;
var
  LValueRaw: TGyroscopeRaw;
begin
  LValueRaw := GetGyroscopeRaw;

  Result[0] := DegToRad(LValueRaw[0] * FGyroCoefficient);
  Result[1] := DegToRad(LValueRaw[1] * FGyroCoefficient);
  Result[2] := DegToRad(LValueRaw[2] * FGyroCoefficient);
end;

end.

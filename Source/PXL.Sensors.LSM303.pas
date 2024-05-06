unit PXL.Sensors.LSM303;
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
  PXL.Types, PXL.Boards.Types, PXL.Sensors.Types;

type
  TSensorLSM303 = class(TCustomSensor)
  public type
    TVector3f = array[0..2] of Single;
    TVector3i = array[0..2] of Integer;
  public const
    DefaultAccelerometerAddress = $19;
    DefaultMagnetometerAddress = $1E;
  private
    FDataPort: TCustomPortI2C;
    FAccelerometerAddress: Integer;
    FMagnetometerAddress: Integer;

    function GetAccelerometer: TVector3f;
    function GetMagnetometer: TVector3f;
    function GetThermometer: Single;
  public
    constructor Create(const ADataPort: TCustomPortI2C;
      const AAccelerometerAddress: Integer = DefaultAccelerometerAddress;
      const AMagnetometerAddress: Integer = DefaultMagnetometerAddress);

    // Returns raw values of accelerometer registers.
    function GetAccelerometerRaw: TVector3i;

    // Returns raw values of magnetometer registers.
    function GetMagnetometerRaw: TVector3i;

    // Returns raw values of thermometer registers. If there is a communication error, -1 is returned. On
    // occasions there is an issue with thermometer on this chip, where it would fail each time when reading.
    // This seems to be determined on startup, so powering down and then powering up sensor breakout may fix
    // the problem. Therefore, if -1 is returned by this method, likely it will keep this way until next
    // power cycle of sensor breakout.
    function GetThermometerRaw: Integer;

    // Retrieves "compact" values of accelerometer, with spherical coordinates indicating direction (Latitude
    // and Longitude have range of [0..255]) and magnitude multiplied by 8192. Returns True if successful and
    // False if there were communication errors.
    function GetAccelerometerCompact(out ALatitude, ALongitude: Byte; out AMagnitude: Word): Boolean;

    // Retrieves "compact" values of magnetometer, with spherical coordinates indicating direction (Latitude
    // and Longitude have range of [0..255]) and magnitude multiplied by 8192. Returns True if successful and
    // False if there were communication errors.
    function GetMagnetometerCompact(out ALatitude, ALongitude: Byte; out AMagnitude: Word): Boolean;

    // Converts "compact" values obtained by either @link(GetAccelerometerCompact) or
    // @link(GetMagnetometerCompact) into the actual 3D vector.
    class function CompactToVector(const ALatitude, ALongitude: Byte; const AMagnitude: Word): TVector3f;

    property DataPort: TCustomPortI2C read FDataPort;
    property AccelerometerAddress: Integer read FAccelerometerAddress;
    property MagnetometerAddress: Integer read FMagnetometerAddress;

    // Current value of accelerometer in "g" units.
    property Accelerometer: TVector3f read GetAccelerometer;

    // Current value of magnetometer in "Gauss" units.
    property Magnetometer: TVector3f read GetMagnetometer;

    // Current value of thermometer in "Celsius" units. Note that this value is not calibrated and can only
    // be used to calculate changes in temperature. Also, on occasions (this is determined at startup) it may
    // not work at all, in which case a value of zero will be returned.
    property Thermometer: Single read GetThermometer;
  end;

implementation

uses
  SysUtils, Math;

const
  PiHalf = Pi * 0.5;
  PiTo256 = 256.0 / Pi;
  TwoPiTo256 = 256.0 / (2.0 * Pi);

constructor TSensorLSM303.Create(const ADataPort: TCustomPortI2C; const AAccelerometerAddress,
  AMagnetometerAddress: Integer);
begin
  inherited Create;

  FDataPort := ADataPort;
  if FDataPort = nil then
    raise ESensorNoDataPort.Create(SSensorNoDataPort);

  FAccelerometerAddress := AAccelerometerAddress;
  if (FAccelerometerAddress < 0) or (FAccelerometerAddress > $7F) then
    raise ESensorInvalidAddress.Create(Format(SSensorInvalidAddress, [FAccelerometerAddress]));

  FMagnetometerAddress := AMagnetometerAddress;
  if (FMagnetometerAddress < 0) or (FAccelerometerAddress > $7F) then
    raise ESensorInvalidAddress.Create(Format(SSensorInvalidAddress, [FMagnetometerAddress]));

  FDataPort.SetAddress(FAccelerometerAddress);
  if not FDataPort.WriteByteData($20, $27) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [2]));

  FDataPort.SetAddress(FMagnetometerAddress);
  if not FDataPort.WriteByteData($00, $90) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [2]));
  if not FDataPort.WriteByteData($02, $00) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [2]));
end;

function TSensorLSM303.GetAccelerometerRaw: TVector3i;
var
  Values: array[0..5] of Byte;
begin
  FDataPort.SetAddress(FAccelerometerAddress);

  if not FDataPort.WriteByte($28 or $80) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [1]));

  if FDataPort.Read(@Values[0], SizeOf(Values)) <> SizeOf(Values) then
    raise ESensorDataRead.Create(Format(SSensorDataRead, [SizeOf(Values)]));

  Result[0] := SmallInt(Word(Values[0]) or (Word(Values[1]) shl 8)) div 16;
  Result[1] := SmallInt(Word(Values[2]) or (Word(Values[3]) shl 8)) div 16;
  Result[2] := SmallInt(Word(Values[4]) or (Word(Values[5]) shl 8)) div 16;
end;

function TSensorLSM303.GetMagnetometerRaw: TVector3i;
var
  LValues: array[0..5] of Byte;
begin
  FDataPort.SetAddress(FMagnetometerAddress);

  if not FDataPort.WriteByte($03) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [1]));

  if FDataPort.Read(@LValues[0], SizeOf(LValues)) <> SizeOf(LValues) then
    raise ESensorDataRead.Create(Format(SSensorDataRead, [SizeOf(LValues)]));

  Result[0] := SmallInt(Word(LValues[1]) or (Word(LValues[0]) shl 8));
  Result[1] := SmallInt(Word(LValues[3]) or (Word(LValues[2]) shl 8));
  Result[2] := SmallInt(Word(LValues[5]) or (Word(LValues[4]) shl 8));
end;

function TSensorLSM303.GetThermometerRaw: Integer;
var
  LTempValue: Word;
begin
  FDataPort.SetAddress(FMagnetometerAddress);

  if not FDataPort.ReadWordData($31, LTempValue) then
    Exit(-1);

  Result := (LTempValue shr 8) or ((LTempValue and $FF) shl 8);
end;

function TSensorLSM303.GetAccelerometer: TVector3f;
var
  LRaw: TVector3i;
begin
  LRaw := GetAccelerometerRaw;
  Result[0] := LRaw[0] * 0.001;
  Result[1] := LRaw[1] * 0.001;
  Result[2] := LRaw[2] * 0.001;
end;

function TSensorLSM303.GetMagnetometer: TVector3f;
const
  NormalizeCoefXY = 1.0 / 950.0;
  NormalizeCoefZ = 1.0 / 1055.0;
var
  LRaw: TVector3i;
begin
  LRaw := GetMagnetometerRaw;
  Result[0] := LRaw[0] * NormalizeCoefXY;
  Result[1] := LRaw[1] * NormalizeCoefXY;
  Result[2] := LRaw[2] * NormalizeCoefZ;
end;

function TSensorLSM303.GetThermometer: Single;
var
  LRawValue: Integer;
begin
  LRawValue := GetThermometerRaw;
  if LRawValue > 0 then
    Result := LRawValue / 8.0
  else
    Result := 0.0;
end;

function TSensorLSM303.GetAccelerometerCompact(out ALatitude, ALongitude: Byte;
  out AMagnitude: Word): Boolean;
const
  MagToWord = 8192.0 * 0.001;
var
  LValueRaw: TVector3i;
  LLengthRaw: Single;
  LValueNorm: TVector3f;
begin
  try
    LValueRaw := GetAccelerometerRaw;
  except
    Exit(False);
  end;

  LLengthRaw := Sqrt(Sqr(LValueRaw[0]) + Sqr(LValueRaw[1]) + Sqr(LValueRaw[2]));
  LValueNorm[0] := LValueRaw[0] / LLengthRaw;
  LValueNorm[1] := LValueRaw[1] / LLengthRaw;
  LValueNorm[2] := LValueRaw[2] / LLengthRaw;

  ALatitude := Round((ArcSin(LValueNorm[2]) + PiHalf) * PiTo256) and $FF;
  ALongitude := Round((ArcTan2(LValueNorm[1], LValueNorm[0]) + Pi) * TwoPiTo256) and $FF;
  AMagnitude := Min(Round(LLengthRaw * MagToWord), 65535);

  Result := True;
end;

function TSensorLSM303.GetMagnetometerCompact(out ALatitude, ALongitude: Byte; out AMagnitude: Word): Boolean;
var
  LValueRaw, LValueNorm: TVector3f;
  LLengthRaw: Single;
begin
  try
    LValueRaw := GetMagnetometer;
  except
    Exit(False);
  end;

  LLengthRaw := Sqrt(Sqr(LValueRaw[0]) + Sqr(LValueRaw[1]) + Sqr(LValueRaw[2]));
  LValueNorm[0] := LValueRaw[0] / LLengthRaw;
  LValueNorm[1] := LValueRaw[1] / LLengthRaw;
  LValueNorm[2] := LValueRaw[2] / LLengthRaw;

  ALatitude := Round((ArcSin(LValueNorm[2]) + PiHalf) * PiTo256) and $FF;
  ALongitude := Round((ArcTan2(LValueNorm[1], LValueNorm[0]) + Pi) * TwoPiTo256) and $FF;
  AMagnitude := Min(Round(LLengthRaw * 8192.0), 65535);

  Result := True;
end;

class function TSensorLSM303.CompactToVector(const ALatitude, ALongitude: Byte; const AMagnitude: Word): TVector3f;
var
  LLatF, LLongF, LMagF: Single;
begin
  LLatF := ((ALatitude * Pi) / 256.0) - PiHalf;
  LLongF := ((ALongitude * 2.0 * Pi) / 256.0) - Pi;
  LMagF := AMagnitude / 8192.0;

  Result[0] := LMagF * Cos(LLatF) * Cos(LLongF);
  Result[1] := LMagF * Cos(LLatF) * Sin(LLongF);
  Result[2] := LMagF * Sin(LLatF);
end;

end.

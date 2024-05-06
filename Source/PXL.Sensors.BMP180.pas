unit PXL.Sensors.BMP180;
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
  SysUtils, PXL.Boards.Types, PXL.Sensors.Types;

type
  TSensorBMP180 = class(TCustomSensor)
  private type
    TCalibration = (AC1, AC2, AC3, AC4, AC5, AC6, B1, B2, MB, MC, MD);
    TCalibrationData = record
    case Integer of
      0: (Values: array[TCalibration] of Word);
      1: (AC1, AC2, AC3: SmallInt;
          AC4, AC5, AC6: Word;
          B1, B2, MB, MC, MD: SmallInt);
    end;
  public type
    TMode = (UltraLowPower, Standard, HighResolution, UltraHighResolution);
  public const
    DefaultAddress = $77;
  private
    FSystemCore: TCustomSystemCore;
    FDataPort: TCustomPortI2C;
    FAddress: Integer;
    FMode: TMode;
    FCalibrationData: TCalibrationData;

    function ReadWordValue(const ACommand: Byte): Word; inline;

    procedure TestChipID;
    procedure ReadCalibrationData;
    function ReadUncompensatedTemperature: Integer;
    function ReadUncompensatedPressure: Integer;

    function CalculateB5(const AUT: Integer): Integer;
    function GetTemperature: Single; inline;
    function GetPressure: Single; inline;
    function GetAltitude: Single;
  public
    constructor Create(const ASystemCore: TCustomSystemCore; const ADataPort: TCustomPortI2C;
      const AAddress: Integer = DefaultAddress; const AMode: TMode = TMode.HighResolution);

    function GetTemperatureRaw: Integer;
    function GetPressureRaw: Integer;

    property DataPort: TCustomPortI2C read FDataPort;
    property Address: Integer read FAddress;
    property Mode: TMode read FMode;

    // Current temperature in "Celcius" units.
    property Temperature: Single read GetTemperature;

    // Current atmospheric pressure in "kPa" units.
    property Pressure: Single read GetPressure;

    // Current calculated altitude in meters.
    property Altitude: Single read GetAltitude;
  end;

  ESensorCalibrationInvalid = class(ESensorGeneric);

resourcestring
  SSensorCalibrationInvalid = 'Sensor calibration data appears to be invalid.';

implementation

uses
  Math;

constructor TSensorBMP180.Create(const ASystemCore: TCustomSystemCore; const ADataPort: TCustomPortI2C;
  const AAddress: Integer; const AMode: TMode);
begin
  inherited Create;

  FSystemCore := ASystemCore;
  if FSystemCore = nil then
    raise ESensorNoSystemCore.Create(SSensorNoSystemCore);

  FDataPort := ADataPort;
  if FDataPort = nil then
    raise ESensorNoDataPort.Create(SSensorNoDataPort);

  FAddress := AAddress;
  if (FAddress < 0) or (FAddress > $7F) then
    raise ESensorInvalidAddress.Create(Format(SSensorInvalidAddress, [FAddress]));

  FMode := AMode;

  TestChipID;
  ReadCalibrationData;
end;

function TSensorBMP180.ReadWordValue(const ACommand: Byte): Word;
var
  LTempValue: Word;
begin
  if not FDataPort.ReadWordData(ACommand, LTempValue) then
    raise ESensorDataRead.Create(Format(SSensorDataRead, [SizeOf(Word)]));

  Result := (LTempValue shr 8) or ((LTempValue and $FF) shl 8);
end;

procedure TSensorBMP180.TestChipID;
const
  ExpectedID = $55;
var
  LChipID: Byte;
begin
  FDataPort.SetAddress(FAddress);

  if not FDataPort.ReadByteData($D0, LChipID) then
    raise ESensorDataRead.Create(Format(SSensorDataRead, [SizeOf(LChipID)]));

  if LChipID <> ExpectedID then
    raise ESensorInvalidChipID.Create(Format(SSensorInvalidChipID, [ExpectedID, LChipID]));
end;

procedure TSensorBMP180.ReadCalibrationData;
var
  I: TCalibration;
  LCommand: Byte;
begin
  FDataPort.SetAddress(FAddress);

  LCommand := $AA;

  for I := Low(TCalibration) to High(TCalibration) do
  begin
    FCalibrationData.Values[I] := ReadWordValue(LCommand);

    if (FCalibrationData.Values[I] = $0000) or (FCalibrationData.Values[I] = $FFFF) then
      raise ESensorCalibrationInvalid.Create(SSensorCalibrationInvalid);

    Inc(LCommand, 2);
  end;
end;

function TSensorBMP180.ReadUncompensatedTemperature: Integer;
begin
  FDataPort.SetAddress(FAddress);

  if not FDataPort.WriteByteData($F4, $2E) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [2]));

  FSystemCore.Delay(4500);

  Result := ReadWordValue($F6);
end;

function TSensorBMP180.ReadUncompensatedPressure: Integer;
var
  LTempValue1: Word;
  LTempValue2: Byte;
begin
  FDataPort.SetAddress(FAddress);

  if not FDataPort.WriteByteData($F4, $34 or (Ord(FMode) shl 6)) then
    raise ESensorDataWrite.Create(Format(SSensorDataWrite, [2]));

  case FMode of
    TMode.Standard:
      FSystemCore.Delay(7500);

    TMode.HighResolution:
      FSystemCore.Delay(13500);

    TMode.UltraHighResolution:
      FSystemCore.Delay(25500);
  else
    FSystemCore.Delay(4500);
  end;

  LTempValue1 := ReadWordValue($F6);

  if not FDataPort.ReadByteData($F8, LTempValue2) then
    raise ESensorDataRead.Create(Format(SSensorDataRead, [1]));

  Result := ((Cardinal(LTempValue1) shl 8) or LTempValue1) shr (8 - Ord(FMode));
end;

function TSensorBMP180.CalculateB5(const AUT: Integer): Integer;
var
  LX1, LX2: Integer;
begin
  LX1 := ((Int64(AUT) - FCalibrationData.AC6) * FCalibrationData.AC5) div 32768;
  LX2 := (Int64(FCalibrationData.MC) * 2048) div (Int64(LX1) + FCalibrationData.MD);
  Result := LX1 + LX2;
end;

function TSensorBMP180.GetTemperatureRaw: Integer;
var
  LUT, LB5: Integer;
begin
  LUT := ReadUncompensatedTemperature;
  LB5 := CalculateB5(LUT);
  Result := (LB5 + 8) div 16;
end;

function TSensorBMP180.GetTemperature: Single;
begin
  Result := GetTemperatureRaw * 0.1;
end;

function TSensorBMP180.GetPressureRaw: Integer;
var
  LUT, LUP, LB5, LB6, LX1, LX2, LX3, LB3, LP: Integer;
  LB4, LB7: Cardinal;
begin
  LUT := ReadUncompensatedTemperature;
  LUP := ReadUncompensatedPressure;
  LB5 := CalculateB5(LUT);
  LB6 := LB5 - 4000;
  LX1 := (Int64(FCalibrationData.B2) * (Sqr(Int64(LB6)) div 4096)) div 2048;
  LX2 := (Int64(FCalibrationData.AC2) * LB6) div 2048;
  LX3 := LX1 + LX2;
  LB3 := (((Int64(FCalibrationData.AC1) * 4 + LX3) shl Ord(FMode)) + 2) div 4;
  LX1 := (Int64(FCalibrationData.AC3) * LB6) div 8192;
  LX2 := (Int64(FCalibrationData.B1) * (Sqr(Int64(LB6)) div 4096)) div 65536;
  LX3 := ((Int64(LX1) + LX2) + 2) div 4;
  LB4 := (Int64(FCalibrationData.AC4) * (Int64(LX3) + 32768)) div 32768;
  LB7 := (Int64(LUP) - LB3) * (50000 shr Ord(FMode));

  if LB7 < $80000000 then
    LP := (Int64(LB7) * 2) div LB4
  else
    LP := (LB7 div LB4) * 2;

  LX1 := Sqr(Int64(LP) div 256);
  LX1 := (Int64(LX1) * 3038) div 65536;
  LX2 := (-7357 * Int64(LP)) div 65536;

  Result := LP + ((LX1 + LX2 + 3791) div 16);
end;

function TSensorBMP180.GetPressure: Single;
begin
  Result := GetPressureRaw * 0.001;
end;

function TSensorBMP180.GetAltitude: Single;
const
  PressureAtSeaLevel = 101.325;
begin
  Result := 44330.0 * (1.0 - Power(GetPressure / PressureAtSeaLevel, 0.190294957));
end;

end.

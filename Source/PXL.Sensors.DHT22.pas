unit PXL.Sensors.DHT22;
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

// Enable the following option to "restart" the sensor each time, which seems to be the only way to somewhat
// reliably read the sensor each time. Otherwise, the sensor would give data a couple of times and then
// continue to fail.
{$DEFINE DHT22_WORKAROUND}

uses
  SysUtils, PXL.Types, PXL.Boards.Types, PXL.Sensors.Types;

type
  TSensorDHT22 = class(TCustomSensor)
  private const
    WaitSignalTimeout = 250; // microseconds
  protected const
    SensorUpdateInterval = 2000; // milliseconds
    SensorStartupTime = 250; // milliseconds
    SensorWakeupTime = 20; // milliseconds
  private
    FSystemCore: TCustomSystemCore;
    FGPIO: TCustomGPIO;
    FPin: Integer;
    FLastTemperature: Integer;
    FLastHumidity: Integer;
    FLastReadTicks: UInt64;

    function WaitForLowSignal(out AWaitedTicks: UInt64): Boolean; overload; inline;
    function WaitForHighSignal(out AWaitedTicks: UInt64): Boolean; inline;

    function GetTemperature: Single;
    function GetHumidity: Single;
  public
    constructor Create(const ASystemCore: TCustomSystemCore; const AGPIO: TCustomGPIO; const APin: Integer);
    destructor Destroy; override;

    function ReadRawValues(out ATemperature, AHumidity: Integer): Boolean;

    // Retrieves "compact" values of temperature (multiplied by two, e.g. value of 90 means 45 C) and
    // relative humidity (0 = 0%, 255 = 100%), clamped to fit within their respective ranges. Returns True if
    // successful and False if there were communication errors.
    function ReadValuesCompact(out ATemperature: ShortInt; out AHumidity: Byte): Boolean;

    property SystemCore: TCustomSystemCore read FSystemCore;
    property GPIO: TCustomGPIO read FGPIO;
    property Pin: Integer read FPin;

    property Temperature: Single read GetTemperature;
    property Humidity: Single read GetHumidity;
  end;

  ESensorReadValues = class(ESensorGeneric);

resourcestring
  SSensorReadValues = 'Error trying to read values from the sensor.';

implementation

constructor TSensorDHT22.Create(const ASystemCore: TCustomSystemCore; const AGPIO: TCustomGPIO;
  const APin: Integer);
begin
  inherited Create;

  FSystemCore := ASystemCore;
  if FSystemCore = nil then
    raise ESensorNoSystemCore.Create(SSensorNoSystemCore);

  FGPIO := AGPIO;
  if FGPIO = nil then
    raise ESensorNoGPIO.Create(SSensorNoGPIO);

  FPin := APin;

{$IFNDEF DHT22_WORKAROUND}
  FGPIO.PinMode[FPin] := TPinMode.Output;
  FGPIO.PinValue[FPin] := TPinValue.High;
  FSystemCore.Delay(SensorStartupTime * 1000);
{$ENDIF}

  FLastTemperature := -1;
  FLastHumidity := -1;
end;

destructor TSensorDHT22.Destroy;
begin
  FGPIO.PinMode[FPin] := TPinMode.Input;

  inherited;
end;

function TSensorDHT22.WaitForLowSignal(out AWaitedTicks: UInt64): Boolean;
var
  LStartTime: UInt64;
begin
  LStartTime := FSystemCore.GetTickCount;

  while FGPIO.PinValue[FPin] = TPinValue.High do
  begin
    if FSystemCore.TicksInBetween(LStartTime, FSystemCore.GetTickCount) >= WaitSignalTimeout then
      Exit(False);
  end;

  AWaitedTicks := FSystemCore.TicksInBetween(LStartTime, FSystemCore.GetTickCount);
  Result := True;
end;

function TSensorDHT22.WaitForHighSignal(out AWaitedTicks: UInt64): Boolean;
var
  LStartTime: UInt64;
begin
  LStartTime := FSystemCore.GetTickCount;

  while FGPIO.PinValue[FPin] = TPinValue.Low do
  begin
    if FSystemCore.TicksInBetween(LStartTime, FSystemCore.GetTickCount) >= WaitSignalTimeout then
      Exit(False);
  end;

  AWaitedTicks := FSystemCore.TicksInBetween(LStartTime, FSystemCore.GetTickCount);
  Result := True;
end;

function TSensorDHT22.ReadRawValues(out ATemperature, AHumidity: Integer): Boolean;
const
  DataReceiveWaitTime = 40;
  MinTimeToConsiderOne = 40;
var
  LCycle, LMask, LIndex: Integer;
  LData: array[0..5] of Byte;
  LWaitedTicks: UInt64;
begin
  if (FLastTemperature <> -1) and (FLastHumidity <> -1) and (FSystemCore.TicksInBetween(FLastReadTicks,
    FSystemCore.GetTickCount) < SensorUpdateInterval * 1000) then
  begin
    ATemperature := FLastTemperature;
    AHumidity := FLastHumidity;
    Exit(True);
  end;

  FillChar(LData, SizeOf(LData), 0);

{$IFDEF DHT22_WORKAROUND}
  FGPIO.PinMode[FPin] := TPinMode.Output;
  FGPIO.PinValue[FPin] := TPinValue.High;
  FSystemCore.Delay(SensorStartupTime * 1000);
{$ENDIF}

  FGPIO.PinValue[FPin] := TPinValue.Low;
  FSystemCore.Delay(SensorWakeupTime * 1000);

  FGPIO.PinValue[FPin] := TPinValue.High;
  FSystemCore.Delay(DataReceiveWaitTime);
  FGPIO.PinMode[FPin] := TPinMode.Input;

  if not WaitForHighSignal(LWaitedTicks) then
    Exit(False);

  if not WaitForLowSignal(LWaitedTicks) then
    Exit(False);

  LMask := 128;
  LIndex := 0;

  for LCycle := 0 to 39 do
  begin
    if not WaitForHighSignal(LWaitedTicks) then
      Exit(False);

    if not WaitForLowSignal(LWaitedTicks) then
      Exit(False);

    if LWaitedTicks > MinTimeToConsiderOne then
      LData[LIndex] := LData[LIndex] or LMask;

    LMask := LMask shr 1;
    if LMask = 0 then
    begin
      LMask := 128;
      Inc(LIndex);
    end;
  end;

{$IFDEF DHT22_WORKAROUND}
  FGPIO.PinMode[FPin] := TPinMode.Input;
{$ELSE}
  FGPIO.PinMode[FPin] := TPinMode.Output;
  FGPIO.PinValue[FPin] := TPinValue.High;
{$ENDIF}

  if (LData[0] + LData[1] + LData[2] + LData[3]) and $FF <> LData[4] then
    Exit(False);

  ATemperature := (Word(LData[2] and $7F) shl 8) or Word(LData[3]);
  if LData[2] and $80 > 0 then
    ATemperature := -ATemperature;

  AHumidity := (Word(LData[0]) shl 8) or Word(LData[1]);

  FLastTemperature := ATemperature;
  FLastHumidity := AHumidity;
  FLastReadTicks := FSystemCore.GetTickCount;

  Result := True;
end;

function TSensorDHT22.GetTemperature: Single;
var
  LRawTemperature, LRawHumidity: Integer;
begin
  if not ReadRawValues(LRawTemperature, LRawHumidity) then
    raise ESensorReadValues.Create(SSensorReadValues);

  Result := LRawTemperature * 0.1;
end;

function TSensorDHT22.GetHumidity: Single;
var
  LRawTemperature, LRawHumidity: Integer;
begin
  if not ReadRawValues(LRawTemperature, LRawHumidity) then
    raise ESensorReadValues.Create(SSensorReadValues);

  Result := LRawHumidity * 0.1;
end;

function TSensorDHT22.ReadValuesCompact(out ATemperature: ShortInt; out AHumidity: Byte): Boolean;
var
  LRawTemperature, LRawHumidity: Integer;
begin
  if not ReadRawValues(LRawTemperature, LRawHumidity) then
    Exit(False);

  ATemperature := Saturate(LRawTemperature div 5, Low(ShortInt), High(ShortInt));
  AHumidity := Saturate((LRawHumidity * 255) div 10, Low(Byte), High(Byte));

  Result := True;
end;

end.

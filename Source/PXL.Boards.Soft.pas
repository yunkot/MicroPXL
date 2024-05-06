unit PXL.Boards.Soft;
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

{$INCLUDE PXL.MicroConfig.inc}

uses
  PXL.Boards.Types;

type
  TSoftSPI = class(TCustomPortSPI)
  private
    FSystemCore: TCustomSystemCore;
    FGPIO: TCustomGPIO;

    FPinSCLK: TPinIdentifier;
    FPinMOSI: TPinIdentifier;
    FPinMISO: TPinIdentifier;
    FPinCS: TPinIdentifier;

    FFrequency: Cardinal;
    FMode: TSPIMode;
    FDelayInterval: Cardinal;

    function GetInitialValueSCLK: Cardinal;
    function GetInitialValueCS: Cardinal;
    procedure SetChipSelect(const AChipSelect: Cardinal);
    procedure FlipClock(var AValueSCLK: Cardinal);
  protected
    function GetFrequency: Cardinal; override;
    procedure SetFrequency(const AFrequency: Cardinal); override;
    function GetBitsPerWord: TBitsPerWord; override;
    procedure SetBitsPerWord(const ABitsPerWord: TBitsPerWord); override;
    function GetMode: TSPIMode; override;
    procedure SetMode(const AMode: TSPIMode); override;
  public
    constructor Create(const ASystemCore: TCustomSystemCore; const AGPIO: TCustomGPIO; const APinSCLK,
      APinMOSI, APinMISO, APinCS: TPinIdentifier;
      const AChipSelectMode: TChipSelectMode = TChipSelectMode.ActiveLow);
    destructor Destroy; override;

    function Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;
    function Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;

    function Transfer(const AReadBuffer, AWriteBuffer: Pointer;
      const ABufferSize: Cardinal): Cardinal; override;

    property SystemCore: TCustomSystemCore read FSystemCore;
    property GPIO: TCustomGPIO read FGPIO;

    property PinSCLK: TPinIdentifier read FPinSCLK;
    property PinMOSI: TPinIdentifier read FPinMOSI;
    property PinMISO: TPinIdentifier read FPinMISO;
    property PinCS: TPinIdentifier read FPinCS;
  end;

  TSoftUART = class(TCustomPortUART)
  private const
    DefaultReadTimeout = 100; // ms
  private
    FGPIO: TCustomGPIO;

    FPinTX: TPinIdentifier;
    FPinRX: TPinIdentifier;

    FBaudRate: Cardinal;

    function CalculatePeriod(const AElapsedTime: TTickCounter): Cardinal;
    procedure WaitForPeriod(const AStartTime: TTickCounter; const APeriod: Cardinal);
  protected
    function GetBaudRate: Cardinal; override;
    procedure SetBaudRate(const ABaudRate: Cardinal); override;
    function GetBitsPerWord: TBitsPerWord; override;
    procedure SetBitsPerWord(const ABitsPerWord: TBitsPerWord); override;
    function GetParity: TParity; override;
    procedure SetParity(const AParity: TParity); override;
    function GetStopBits: TStopBits; override;
    procedure SetStopBits(const AStopBits: TStopBits); override;
  public
    constructor Create(const ASystemCore: TCustomSystemCore; const AGPIO: TCustomGPIO;
      const APinTX, APinRX: TPinIdentifier);
    destructor Destroy; override;

    function Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;
    function Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;

    function ReadBuffer(const ABuffer: Pointer; const ABufferSize, ATimeout: Cardinal): Cardinal; override;
    function WriteBuffer(const ABuffer: Pointer; const ABufferSize, ATimeout: Cardinal): Cardinal; override;

    procedure Flush; override;

    property PinTX: TPinIdentifier read FPinTX;
    property PinRX: TPinIdentifier read FPinRX;
  end;

implementation

uses
  PXL.TypeDef;

{$REGION 'TSoftSPI'}

constructor TSoftSPI.Create(const ASystemCore: TCustomSystemCore; const AGPIO: TCustomGPIO; const APinSCLK,
  APinMOSI, APinMISO, APinCS: TPinIdentifier; const AChipSelectMode: TChipSelectMode);
begin
  inherited Create(AChipSelectMode);

  FSystemCore := ASystemCore;
  FGPIO := AGPIO;

  FPinSCLK := APinSCLK;
  FPinMOSI := APinMOSI;
  FPinMISO := APinMISO;
  FPinCS := APinCS;

  FGPIO.PinMode[FPinSCLK] := TPinMode.Output;

  if FPinMOSI <> PinDisabled then
    FGPIO.PinMode[FPinMOSI] := TPinMode.Output;

  if FPinMISO <> PinDisabled then
    FGPIO.PinMode[FPinMISO] := TPinMode.Output;

  if FPinCS <> PinDisabled then
  begin
    FGPIO.PinMode[FPinCS] := TPinMode.Output;
    FGPIO.PinValue[FPinCS] := TPinValue.High;
  end;
end;

destructor TSoftSPI.Destroy;
begin
  if FPinCS <> PinDisabled then
    FGPIO.PinMode[FPinCS] := TPinMode.Input;

  if FPinMISO <> PinDisabled then
    FGPIO.PinMode[FPinMISO] := TPinMode.Input;

  if FPinMOSI <> PinDisabled then
    FGPIO.PinMode[FPinMOSI] := TPinMode.Input;

  FGPIO.PinMode[FPinSCLK] := TPinMode.Input;

  inherited;
end;

function TSoftSPI.GetFrequency: Cardinal;
begin
  Result := FFrequency;
end;

procedure TSoftSPI.SetFrequency(const AFrequency: Cardinal);
begin
  if (AFrequency <> 0) and (AFrequency <= 1000000) and (FSystemCore <> nil) then
  begin
    FFrequency := AFrequency;
    FDelayInterval := 1000000 div FFrequency;
  end
  else
  begin
    FFrequency := 0;
    FDelayInterval := 0;
  end;
end;

function TSoftSPI.GetBitsPerWord: TBitsPerWord;
begin
  Result := 8;
end;

procedure TSoftSPI.SetBitsPerWord(const ABitsPerWord: TBitsPerWord);
begin
end;

function TSoftSPI.GetMode: TSPIMode;
begin
  Result := FMode;
end;

procedure TSoftSPI.SetMode(const AMode: TSPIMode);
begin
  FMode := AMode;
end;

function TSoftSPI.GetInitialValueSCLK: Cardinal;
begin
  if FMode and 2 <> 0 then
    Result := 0
  else
    Result := 1;
end;

function TSoftSPI.GetInitialValueCS: Cardinal;
begin
  if FChipSelectMode = TChipSelectMode.ActiveHigh then
    Result := 1
  else
    Result := 0;
end;

procedure TSoftSPI.SetChipSelect(const AChipSelect: Cardinal);
begin
  if (FPinCS <> PinDisabled) and (FChipSelectMode <> TChipSelectMode.Disabled) then
    FGPIO.PinValue[FPinCS] := TPinValue(AChipSelect);
end;

procedure TSoftSPI.FlipClock(var AValueSCLK: Cardinal);
begin
  AValueSCLK := AValueSCLK xor 1;
  FGPIO.PinValue[FPinSCLK] := TPinValue(AValueSCLK);
end;

function TSoftSPI.Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LValueSCLK, LValueCS, LReadValue: Cardinal;
  LCycleStartTime: TTickCounter;
  I, LBitIndex: Integer;
begin
  if (ABuffer = nil) or (ABufferSize = 0) then
    Exit(0);

  LValueSCLK := GetInitialValueSCLK;
  LValueCS := GetInitialValueCS;

  FGPIO.PinValue[FPinSCLK] := TPinValue(LValueSCLK);
  SetChipSelect(LValueCS);
  try
    for I := 0 to ABufferSize - 1 do
    begin
      LReadValue := 0;

      for LBitIndex := 0 to 7 do
      begin
        if FDelayInterval <> 0 then
          LCycleStartTime := FSystemCore.GetTickCount;

        if FGPIO.PinValue[FPinMISO] = TPinValue.High then
          LReadValue := LReadValue or 1;

        LReadValue := LReadValue shl 1;

        FlipClock(LValueSCLK);

        if FDelayInterval <> 0 then
          while FSystemCore.TicksInBetween(LCycleStartTime, FSystemCore.GetTickCount) < FDelayInterval do ;

        FlipClock(LValueSCLK);
      end;

      PByte(PtrUInt(ABuffer) + Cardinal(I))^ := LReadValue;
    end;
  finally
    SetChipSelect(LValueCS xor 1);
  end;

  Result := ABufferSize;
end;

function TSoftSPI.Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LValueSCLK, LValueCS, LWriteValue: Cardinal;
  LCycleStartTime: TTickCounter;
  I, LBitIndex: Integer;
begin
  if (ABuffer = nil) or (ABufferSize = 0) then
    Exit(0);

  LValueSCLK := GetInitialValueSCLK;
  LValueCS := GetInitialValueCS;

  FGPIO.PinValue[FPinSCLK] := TPinValue(LValueSCLK);
  SetChipSelect(LValueCS);
  try
    for I := 0 to ABufferSize - 1 do
    begin
      LWriteValue := PByte(PtrUInt(ABuffer) + Cardinal(I))^;

      for LBitIndex := 0 to 7 do
      begin
        if FDelayInterval <> 0 then
          LCycleStartTime := FSystemCore.GetTickCount;

        if LWriteValue and $80 > 0 then
          FGPIO.PinValue[FPinMOSI] := TPinValue.High
        else
          FGPIO.PinValue[FPinMOSI] := TPinValue.Low;

        LWriteValue := LWriteValue shl 1;

        FlipClock(LValueSCLK);

        if FDelayInterval <> 0 then
          while FSystemCore.TicksInBetween(LCycleStartTime, FSystemCore.GetTickCount) < FDelayInterval do ;

        FlipClock(LValueSCLK);
      end;
    end;
  finally
    SetChipSelect(LValueCS xor 1);
  end;

  Result := ABufferSize;
end;

function TSoftSPI.Transfer(const AReadBuffer, AWriteBuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LValueSCLK, LValueCS, LWriteValue, LReadValue: Cardinal;
  LCycleStartTime: TTickCounter;
  I, LBitIndex: Integer;
begin
  if ((AReadBuffer = nil) and (AWriteBuffer = nil)) or (ABufferSize = 0) then
    Exit(0);

  LValueSCLK := GetInitialValueSCLK;
  LValueCS := GetInitialValueCS;

  FGPIO.PinValue[FPinSCLK] := TPinValue(LValueSCLK);
  SetChipSelect(LValueCS);
  try
    LWriteValue := 0;

    for I := 0 to ABufferSize - 1 do
    begin
      LReadValue := 0;

      if AWriteBuffer <> nil then
        LWriteValue := PByte(PtrUInt(AWriteBuffer) + Cardinal(I))^;

      for LBitIndex := 0 to 7 do
      begin
        if FDelayInterval <> 0 then
          LCycleStartTime := FSystemCore.GetTickCount;

        if FPinMOSI <> PinDisabled then
        begin
          if LWriteValue and $80 > 0 then
            FGPIO.PinValue[FPinMOSI] := TPinValue.High
          else
            FGPIO.PinValue[FPinMOSI] := TPinValue.Low;

          LWriteValue := LWriteValue shl 1;
        end;

        if FPinMISO <> PinDisabled then
        begin
          if FGPIO.PinValue[FPinMISO] = TPinValue.High then
            LReadValue := LReadValue or 1;

          LReadValue := LReadValue shl 1;
        end;

        FlipClock(LValueSCLK);

        if FDelayInterval <> 0 then
          while FSystemCore.TicksInBetween(LCycleStartTime, FSystemCore.GetTickCount) < FDelayInterval do ;

        FlipClock(LValueSCLK);
      end;

      if AReadBuffer <> nil then
        PByte(PtrUInt(AReadBuffer) + Cardinal(I))^ := LReadValue;
    end;
  finally
    SetChipSelect(LValueCS xor 1);
  end;

  Result := ABufferSize;
end;

{$ENDREGION}
{$REGION 'TSoftUART'}

constructor TSoftUART.Create(const ASystemCore: TCustomSystemCore; const AGPIO: TCustomGPIO; const APinTX,
  APinRX: TPinIdentifier);
begin
  inherited Create(ASystemCore);

  FGPIO := AGPIO;

  FPinTX := APinTX;
  FPinRX := APinRX;

  if FPinTX <> PinDisabled then
  begin
    FGPIO.PinMode[FPinTX] := TPinMode.Output;
    FGPIO.PinValue[FPinTX] := TPinValue.High;
  end;

  if FPinRX <> PinDisabled then
    FGPIO.PinMode[FPinRX] := TPinMode.Input;
end;

destructor TSoftUART.Destroy;
begin
  if FPinTX <> PinDisabled then
    FGPIO.PinMode[FPinTX] := TPinMode.Input;

  inherited;
end;

function TSoftUART.GetBaudRate: Cardinal;
begin
  Result := FBaudRate;
end;

procedure TSoftUART.SetBaudRate(const ABaudRate: Cardinal);
begin
  FBaudRate := ABaudRate;
end;

function TSoftUART.GetBitsPerWord: TBitsPerWord;
begin
  Result := 8;
end;

procedure TSoftUART.SetBitsPerWord(const ABitsPerWord: TBitsPerWord);
begin
end;

function TSoftUART.GetParity: TParity;
begin
  Result := TParity.None;
end;

procedure TSoftUART.SetParity(const AParity: TParity);
begin
end;

function TSoftUART.GetStopBits: TStopBits;
begin
  Result := TStopBits.One;
end;

procedure TSoftUART.SetStopBits(const AStopBits: TStopBits);
begin
end;

function TSoftUART.CalculatePeriod(const AElapsedTime: TTickCounter): Cardinal;
begin
  Result := (UInt64(FBaudRate) * AElapsedTime) div 1000000;
end;

procedure TSoftUART.WaitForPeriod(const AStartTime: TTickCounter; const APeriod: Cardinal);
var
  Current: Cardinal;
begin
  repeat
    Current := CalculatePeriod(FSystemCore.TicksInBetween(AStartTime, FSystemCore.GetTickCount));
  until Current >= APeriod;
end;

function TSoftUART.Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LStartTime: TTickCounter;
  LPeriod, LBitMask, LValue: Cardinal;
  I: Integer;
begin
  for I := 0 to ABufferSize - 1 do
  begin
    FGPIO.PinValue[FPinTX] := TPinValue.Low;

    // Start sending data a bit earlier to ensure that receiver will sample data correctly.
    FSystemCore.MicroDelay(TTickCounter(1000000 * 3) div (TTickCounter(FBaudRate) * 5));

    LPeriod := 0;
    LStartTime := FSystemCore.GetTickCount;

    LValue := PByte(PtrUInt(ABuffer) + Cardinal(I))^;
    LBitMask := 1;

    while LBitMask <> 256 do
    begin
      if LValue and LBitMask > 0 then
        FGPIO.PinValue[FPinTX] := TPinValue.High
      else
        FGPIO.PinValue[FPinTX] := TPinValue.Low;

      LBitMask := LBitMask shl 1;

      Inc(LPeriod);
      WaitForPeriod(LStartTime, LPeriod);
    end;

    FGPIO.PinValue[FPinTX] := TPinValue.High;

    Inc(LPeriod);
    WaitForPeriod(LStartTime, LPeriod);
  end;

  Result := ABufferSize;
end;

function TSoftUART.Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
begin
  Result := ReadBuffer(ABuffer, ABufferSize, DefaultReadTimeout);
end;

function TSoftUART.ReadBuffer(const ABuffer: Pointer; const ABufferSize, ATimeout: Cardinal): Cardinal;
var
  LStartTime, LTimeoutStart, LTimeoutMicroSec: TTickCounter;
  LPeriod, LBitMask, LValue, LBytesReceived: Cardinal;
begin
  LBytesReceived := 0;

  if ATimeout <> 0 then
    LTimeoutMicroSec := TTickCounter(ATimeout) * 1000
  else
    LTimeoutMicroSec := DefaultReadTimeout * 1000;

  LTimeoutStart := FSystemCore.GetTickCount;

  // Wait for RX line to settle on high LValue.
  repeat
    if FSystemCore.TicksInBetween(LTimeoutStart, FSystemCore.GetTickCount) > LTimeoutMicroSec then
      Exit(0);
  until FGPIO.PinValue[FPinRX] = TPinValue.High;

  while LBytesReceived < ABufferSize do
  begin
    // Wait until RX line goes low for the "Start" bit.
    repeat
      if FSystemCore.TicksInBetween(LTimeoutStart, FSystemCore.GetTickCount) > LTimeoutMicroSec then
        Exit(LBytesReceived);
    until FGPIO.PinValue[FPinRX] = TPinValue.Low;

    // Once start bit is received, wait for another 1/3rd of baud to sort of center next samples.
    FSystemCore.MicroDelay(TTickCounter(1000000) div (TTickCounter(FBaudRate) * TTickCounter(4)));

    // Start receiving next byte.
    LBitMask := 1;
    LValue := 0;

    LPeriod := 0;
    LStartTime := FSystemCore.GetTickCount;

    // Skip the remaining of "Start" bit.
    Inc(LPeriod);
    WaitForPeriod(LStartTime, LPeriod);

    while LBitMask <> 256 do
    begin
      if FGPIO.PinValue[FPinRX] = TPinValue.High then
        LValue := LValue or LBitMask;

      LBitMask := LBitMask shl 1;

      Inc(LPeriod);
      WaitForPeriod(LStartTime, LPeriod);
    end;

    PByte(PtrUInt(ABuffer) + Cardinal(LBytesReceived))^ := LValue;
    Inc(LBytesReceived);
  end;

  Result := LBytesReceived;
end;

function TSoftUART.WriteBuffer(const ABuffer: Pointer; const ABufferSize, ATimeout: Cardinal): Cardinal;
begin
  Result := Write(ABuffer, ABufferSize);
end;

procedure TSoftUART.Flush;
begin
end;

{$ENDREGION}

end.


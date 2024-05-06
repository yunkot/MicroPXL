unit PXL.Boards.SC16IS7x0;
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
  TUARTBridge = class(TCustomPortUART)
  public const
    DefaultAddress = $4D;
    DefaultBaudRate = 115200;
  private const
    CrystalFrequency = 14745600;
    DefaultPrescaler = 1;
  public type
    TGPIO = class(TCustomGPIO)
    strict private
      FParent: TUARTBridge;
      FPinModes: Cardinal;

      procedure SetPinModes(const AValue: Cardinal); inline;
      function GetPinValues: Cardinal; inline;
      procedure SetPinValues(const AValue: Cardinal); inline;
    protected
      function GetPinMode(const APin: TPinIdentifier): TPinMode; override;
      procedure SetPinMode(const APin: TPinIdentifier; const AMode: TPinMode); override;
      function GetPinValue(const APin: TPinIdentifier): TPinValue; override;
      procedure SetPinValue(const APin: TPinIdentifier; const AValue: TPinValue); override;
    public
      constructor Create(const AParent: TUARTBridge);

      property Parent: TUARTBridge read FParent;

      property PinModes: Cardinal read FPinModes write SetPinModes;
      property PinValues: Cardinal read GetPinValues write SetPinValues;
    end;
  strict private
    FDataPort: TCustomDataPort;
    FGPIO: TGPIO;
    FAddress: Integer;
    FBaudRate: Cardinal;
    FBitsPerWord: TBitsPerWord;
    FParity: TParity;
    FStopBits: TStopBits;

    procedure UpdateParameters;
    procedure SelfTest;
    function GetGPIO: TGPIO;
  protected
    procedure UpdateAddress; inline;
    procedure WriteReg(const RegAddr, Value: Byte); inline;
    function ReadReg(const RegAddr: Byte): Byte; inline;

    function GetBaudRate: Cardinal; override;
    procedure SetBaudRate(const ABaudRate: Cardinal); override;
    function GetBitsPerWord: TBitsPerWord; override;
    procedure SetBitsPerWord(const ABitsPerWord: TBitsPerWord); override;
    function GetParity: TParity; override;
    procedure SetParity(const AParity: TParity); override;
    function GetStopBits: TStopBits; override;
    procedure SetStopBits(const AStopBits: TStopBits); override;
  public
    constructor Create(const ADataPort: TCustomDataPort; const AAddress: Integer = DefaultAddress);
    destructor Destroy; override;

    function Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;
    function Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;
    procedure Flush; override;

    property DataPort: TCustomDataPort read FDataPort;
    property Address: Integer read FAddress;

    property BaudRate: Cardinal read FBaudRate write SetBaudRate;
    property BitsPerWord: TBitsPerWord read FBitsPerWord write SetBitsPerWord;
    property Parity: TParity read FParity write SetParity;
    property StopBits: TStopBits read FStopBits write SetStopBits;

    property GPIO: TGPIO read GetGPIO;
  end;

  EUARTBridgeGeneric = class(Exception);
  EUARTBridgeTransfer = class(EUARTBridgeGeneric);
  EUARTBridgeWrite = class(EUARTBridgeTransfer);
  EUARTBridgeExchange = class(EUARTBridgeTransfer);

  EUARTBridgeNoDataPort = class(EUARTBridgeGeneric);
  EUARTBridgeAddressInvalid = class(EUARTBridgeGeneric);
  EUARTBridgeBaudRateInvalid = class(EUARTBridgeGeneric);
  EUARTBridgeBitsPerWordInvalid = class(EUARTBridgeGeneric);
  EUARTBridgeSelfTestFailed = class(EUARTBridgeGeneric);

  EUARTBridgeGPIOGeneric = class(EUARTBridgeGeneric);
  EUARTBridgeGPIOPinInvalid = class(EUARTBridgeGeneric);

resourcestring
  SUARTBridgeWrite = 'Error writing <%d> byte(s) to Serial-UART Bridge.';
  SUARTBridgeExchange = 'Error exchanging <%d> byte(s) with Serial-UART Bridge.';
  SUARTBridgeNoDataPort = 'A valid data port is required for Serial-UART Bridge.';
  SUARTBridgeAddressInvalid = 'The specified Serial-UART Bridge address <%x> is invalid.';
  SUARTBridgeBaudRateInvalid = 'The specified Serial-UART Bridge baud rate <%d> is invalid.';
  SUARTBridgeBitsPerWordInvalid = 'The specified Serial-UART Bridge bits per word <%d> are invalid.';
  SUARTBridgeSelfTestFailed = 'Serial-UART Bridge self-test failed: expected <%x>, got <%x>.';
  SUARTBridgeGPIOPinInvalid = 'The specified Serial-UART Bridge I/O pin <%d> is invalid.';

implementation

const
  REG_THR = $00;
  REG_RHR = $00;
  REG_FCR = $02;
  REG_LCR = $03;
  REG_MCR = $04;
  REG_LSR = $05;
//  REG_MSR = $06;
  REG_SPR = $07;
  REG_TXLVL = $08;
  REG_RXLVL = $09;
  REG_IODIR = $0A;
  REG_IOSTATE = $0B;
  REG_IOCTRL = $0E;
  REG_DLL = $00;
  REG_DLM = $01;

{$REGION 'TUARTBridge.TGPIO'}

constructor TUARTBridge.TGPIO.Create(const AParent: TUARTBridge);
begin
  inherited Create;

  FParent := AParent;

  FParent.UpdateAddress;
  FPinModes := FParent.ReadReg(REG_IODIR);
end;

procedure TUARTBridge.TGPIO.SetPinModes(const AValue: Cardinal);
begin
  if FPinModes <> AValue then
  begin
    FPinModes := AValue and $FF;
    FParent.WriteReg(REG_IODIR, FPinModes);
  end;
end;

function TUARTBridge.TGPIO.GetPinValues: Cardinal;
begin
  Result := FParent.ReadReg(REG_IOSTATE);
end;

procedure TUARTBridge.TGPIO.SetPinValues(const AValue: Cardinal);
begin
  FParent.WriteReg(REG_IOSTATE, AValue and $FF);
end;

function TUARTBridge.TGPIO.GetPinMode(const APin: TPinIdentifier): TPinMode;
begin
  if (APin < 0) or (APin > 7) then
    raise EUARTBridgeGPIOPinInvalid.Create(Format(SUARTBridgeGPIOPinInvalid, [APin]));

  if FPinModes and (Cardinal(1) shl APin) > 0 then
    Result := TPinMode.Output
  else
    Result := TPinMode.Input;
end;

procedure TUARTBridge.TGPIO.SetPinMode(const APin: TPinIdentifier; const AMode: TPinMode);
begin
  if (APin < 0) or (APin > 7) then
    raise EUARTBridgeGPIOPinInvalid.Create(Format(SUARTBridgeGPIOPinInvalid, [APin]));

  if AMode = TPinMode.Output then
    SetPinModes(FPinModes or (Cardinal(1) shl APin))
  else
    SetPinModes(FPinModes and (not (Cardinal(1) shl APin)));
end;

function TUARTBridge.TGPIO.GetPinValue(const APin: TPinIdentifier): TPinValue;
var
  PinValues: Byte;
begin
  if (APin < 0) or (APin > 7) then
    raise EUARTBridgeGPIOPinInvalid.Create(Format(SUARTBridgeGPIOPinInvalid, [APin]));

  PinValues := GetPinValues;
  if PinValues and (Cardinal(1) shl APin) > 0 then
    Result := TPinValue.High
  else
    Result := TPinValue.Low;
end;

procedure TUARTBridge.TGPIO.SetPinValue(const APin: TPinIdentifier; const AValue: TPinValue);
begin
  if (APin < 0) or (APin > 7) then
    raise EUARTBridgeGPIOPinInvalid.Create(Format(SUARTBridgeGPIOPinInvalid, [APin]));

  PinValues := GetPinValues;

  if AValue = TPinValue.High then
    SetPinValues(PinValues or (Cardinal(1) shl APin))
  else
    SetPinValues(PinValues and (not (Cardinal(1) shl APin)));
end;

{$ENDREGION}
{$REGION 'TUARTBridge'}

constructor TUARTBridge.Create(const ADataPort: TCustomDataPort; const AAddress: Integer);
begin
  inherited Create(nil);

  FDataPort := ADataPort;
  if FDataPort = nil then
    raise EUARTBridgeNoDataPort.Create(SUARTBridgeNoDataPort);

  if FDataPort is TCustomPortI2C then
  begin
    FAddress := AAddress;
    if (FAddress < 0) or (FAddress > $7F) then
      raise EUARTBridgeAddressInvalid.Create(Format(SUARTBridgeAddressInvalid, [FAddress]));
  end
  else
    FAddress := -1;

  FBaudRate := DefaultBaudRate;
  FBitsPerWord := 8;

  UpdateParameters;
  SelfTest;
end;

destructor TUARTBridge.Destroy;
begin
  FGPIO.Free;

  inherited;
end;

procedure TUARTBridge.UpdateAddress;
begin
  if FAddress <> -1 then
    TCustomPortI2C(FDataPort).SetAddress(FAddress);
end;

procedure TUARTBridge.WriteReg(const RegAddr, Value: Byte);
var
  Values: array[0..1] of Byte;
begin
  Values[0] := RegAddr shl 3;
  Values[1] := Value;

  if FDataPort.Write(@Values[0], SizeOf(Values)) <> SizeOf(Values) then
    raise EUARTBridgeWrite.Create(Format(SUARTBridgeWrite, [SizeOf(Values)]));
end;

function TUARTBridge.ReadReg(const RegAddr: Byte): Byte;
var
  Values: array[0..1] of Byte;
begin
  if FAddress <> -1 then
  begin
    if not TCustomPortI2C(FDataPort).ReadByteData(RegAddr shl 3, Result) then
      raise EUARTBridgeExchange.Create(Format(SUARTBridgeExchange, [SizeOf(Byte)]));
  end
  else
  begin
    Values[0] := (RegAddr shl 3) or $80;
    Values[1] := 0;

    if TCustomPortSPI(FDataPort).Transfer(@Values[0], @Values[0], SizeOf(Values)) <> SizeOf(Values) then
      raise EUARTBridgeExchange.Create(Format(SUARTBridgeExchange, [SizeOf(Byte)]));

    Result := Values[1];
  end;
end;

procedure TUARTBridge.UpdateParameters;
var
  ControlValue, ControlDivisor: Cardinal;
begin
  UpdateAddress;

//  WriteReg(REG_IOCTRL, 1 shl 3);

  ControlValue := Cardinal(FBitsPerWord) - 5;

  if FStopBits > TStopBits.One then
    ControlValue := ControlValue or $04;

  if FParity > TParity.None then
    ControlValue := ControlValue or $08 or (Cardinal(FParity) shl 4);

  ControlDivisor := (CrystalFrequency div DefaultPrescaler) div (Cardinal(FBaudRate) * 16);
  if (ControlDivisor = 0) or (ControlDivisor > High(Word)) then
    raise EUARTBridgeBaudRateInvalid.Create(Format(SUARTBridgeBaudRateInvalid, [FBaudRate]));

  WriteLn('Using divisor: ', ControlDivisor);

  // Specify parameters and enable writing to DLx registers.
  WriteReg(REG_LCR, ControlValue or $80);
  WriteReg(REG_DLL, ControlDivisor and $FF);
  WriteReg(REG_DLM, ControlDivisor shr 8);

  // Disable writing to DLx registers but keep same parameters.
  WriteReg(REG_LCR, ControlValue);

  // Disable unnecessary features and enable normal operation.
  WriteReg(REG_MCR, $00);

  // Enable FIFO and reset buffers.
  WriteReg(REG_FCR, $07);
end;

procedure TUARTBridge.SelfTest;
const
  MagicNumber = $AA;
var
  Value: Byte;
begin
  UpdateAddress;

  WriteReg(REG_SPR, MagicNumber);

  Value := ReadReg(REG_SPR);
  if Value <> MagicNumber then
    raise EUARTBridgeSelfTestFailed.Create(Format(SUARTBridgeSelfTestFailed, [MagicNumber, Value]));
end;

function TUARTBridge.GetGPIO: TGPIO;
begin
  if FGPIO = nil then
    FGPIO := TGPIO.Create(Self);

  Result := FGPIO;
end;

function TUARTBridge.GetBaudRate: Cardinal;
begin
  Result := FBaudRate;
end;

procedure TUARTBridge.SetBaudRate(const ABaudRate: Cardinal);
begin
  if ABaudRate <= 0 then
    raise EUARTBridgeBaudRateInvalid.Create(Format(SUARTBridgeBaudRateInvalid, [ABaudRate]));

  if FBaudRate <> ABaudRate then
  begin
    FBaudRate := ABaudRate;
    UpdateParameters;
  end;
end;

function TUARTBridge.GetBitsPerWord: TBitsPerWord;
begin
  Result := FBitsPerWord;
end;

procedure TUARTBridge.SetBitsPerWord(const ABitsPerWord: TBitsPerWord);
begin
  if (ABitsPerWord < 5) or (ABitsPerWord > 8) then
    raise EUARTBridgeBitsPerWordInvalid.Create(Format(SUARTBridgeBitsPerWordInvalid, [FBitsPerWord]));

  if FBitsPerWord <> ABitsPerWord then
  begin
    FBitsPerWord := ABitsPerWord;
    UpdateParameters;
  end;
end;

function TUARTBridge.GetParity: TParity;
begin
  Result := FParity;
end;

procedure TUARTBridge.SetParity(const AParity: TParity);
begin
  if FParity <> AParity then
  begin
    FParity := AParity;
    UpdateParameters;
  end;
end;

function TUARTBridge.GetStopBits: TStopBits;
begin
  Result := FStopBits;
end;

procedure TUARTBridge.SetStopBits(const AStopBits: TStopBits);
begin
  if FStopBits <> AStopBits then
  begin
    FStopBits := AStopBits;
    UpdateParameters;
  end;
end;

function TUARTBridge.Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  I, LBytesAvailable, LRes: Integer;
begin
  UpdateAddress;

  LBytesAvailable := ReadReg(REG_RXLVL);

  Result := LBytesAvailable;
  if Result > ABufferSize then
    Result := ABufferSize;

  for I := 0 to Result - 1 do
    PByte(PtrUInt(ABuffer) + Cardinal(I))^ := ReadReg(REG_RHR);

  LRes := ReadReg(REG_LSR);
  if LRes and $80 > 0 then
  begin
    WriteLn('Read error: 0x', IntToHex(LRes, 2));
//    Result := 0;
  end;

{  WriteLn('RX bytes unread: ', ReadReg(REG_RXLVL));
  WriteLn('TX spaces left: ', ReadReg(REG_TXLVL));}
end;

function TUARTBridge.Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  I, LSpacesAvailable, LRes: Integer;
begin
  UpdateAddress;

  LSpacesAvailable := ReadReg(REG_TXLVL);

  Result := LSpacesAvailable;
  if Result > ABufferSize then
    Result := ABufferSize;

  for I := 0 to Result - 1 do
    WriteReg(REG_THR, PByte(PtrUInt(ABuffer) + Cardinal(I))^);

  LRes := ReadReg(REG_LSR);
  if LRes and $80 > 0 then
  begin
    WriteLn('Write error: 0x', IntToHex(LRes, 2));
//    Result := 0;
  end;

{  WriteLn('RX bytes unread: ', ReadReg(REG_RXLVL));
  WriteLn('TX spaces left: ', ReadReg(REG_TXLVL));}
end;

procedure TUARTBridge.Flush;
begin
  UpdateAddress;
  WriteReg(REG_FCR, $07);
end;

{$ENDREGION}

end.


unit PXL.Boards.RPi;
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
{
  Acknowledgments:

  For development of this support library, one of richest source of information was:
    "C library for Broadcom BCM 2835 as used in Raspberry Pi" written by Mike McCauley.
      http://www.airspayce.com/mikem/bcm2835/
  That library provided great deal of information and ideas on how to interact with BCM2835 registers,
  handling barriers, accessing SPI and I2C. Many thanks for that library author for such excellent work!

  An invaluable source of information was "BCM2835 ARM Peripherals" PDF file:
    http://www.raspberrypi.org/wp-content/uploads/2012/02/BCM2835-ARM-Peripherals.pdf
  This document provided important information about chip registers and the meaning of different
  bits / constants.

  Other sources of motivation were the following projects:

    "Hardware abstraction library for the Raspberry Pi" by Stefan Fischer.
    http://shop.basis.biz/shop/Raspberry-PI/piggy-back-board/

    "BCM2835 GPIO Registry Driver" by Gabor Szollosi.
    http://wiki.freepascal.org/Lazarus_on_Raspberry_Pi
}
interface

{$INCLUDE PXL.Config.inc}

// Enable this option to reset SPI and I2C pins back to "input" mode after using. By default and after reboot,
// these pins are usually set to Alt0 mode, so they are ready to use by Sysfs SPI/I2C. Therefore, resetting
// them to "input" would prevent native Linux SPI / I2C from working until next reboot, or until the function
// of these pins is adjusted.

{.$DEFINE DATAPORTS_PINS_RESET_AFTER_DONE}

uses
  SysUtils, PXL.TypeDef, PXL.Boards.Types, PXL.Sysfs.UART;

type
  TChipOffset = PtrUInt;

  TFastSystemCore = class(TCustomSystemCore)
  public const
    BaseClock = 250000000; // 250 mHz
    PageSize = 4096;
    ChipOffsetST = $3000;
  strict private const
    OffsetTimerLower = $0004; // System Timer Counter Lower 32 bits
    OffsetTimerUpper = $0008; // System Timer Counter Upper 32 bits
  strict private
    FChipOffsetBase: TChipOffset;
    FChipDataSize: Cardinal;

    FHandle: TUntypedHandle;
    FMemory: Pointer;

    function GetChipOffsetST: TChipOffset; inline;
    function UpdateIOValuesFromKernel: Boolean;
  protected
    function GetChipOffsetBase: TChipOffset; inline;
    function GetOffsetPointer(const AOffset: Cardinal): Pointer; inline;

    property Handle: TUntypedHandle read FHandle;
  public
    constructor Create;
    destructor Destroy; override;

    // Returns the current value of system timer as 64-bit unsigned integer, in microseconds.
    function GetTickCount: TTickCounter; override;

    // Waits for the specified amount of microseconds, calling NanoSleep if waiting time is long enough for
    // the most portion of wait time, while the remaining part doing a busy wait to provide greater accuracy.
    procedure MicroDelay(const AMicroseconds: TMicroseconds); override;
  end;

  TNumberingScheme = (Printed, BCM);

  TPinModeEx = (Input = $00, Output = $01, Alt5 = $02, Alt4 = $03, Alt0 = $04, Alt1 = $05, Alt2 = $06, Alt3 = $07);

  TFastGPIO = class(TCustomGPIO)
  strict private
    FSystemCore: TFastSystemCore;
    FMemory: Pointer;
    FNumberingScheme: TNumberingScheme;

    function GetChipOffsetGPIO: TChipOffset; inline;
    function GetPinModeEx(const APin: TPinIdentifier): TPinModeEx;
    procedure SetPinModeEx(const APin: TPinIdentifier; const AValue: TPinModeEx); inline;
  protected
    function GetOffsetPointer(const AOffset: Cardinal): Pointer; inline;
    function ProcessPinNumber(const APin: TPinIdentifier): TPinIdentifier;

    procedure SetPinModeBCM(const APinBCM: TPinIdentifier; const AMode: TPinModeEx);

    function GetPinMode(const APin: TPinIdentifier): TPinMode; override;
    procedure SetPinMode(const APin: TPinIdentifier; const AMode: TPinMode); override;

    function GetPinValue(const APin: TPinIdentifier): TPinValue; override;
    procedure SetPinValue(const APin: TPinIdentifier; const AValue: TPinValue); override;

    function GetPinDrive(const APin: TPinIdentifier): TPinDrive; override;
    procedure SetPinDrive(const APin: TPinIdentifier; const AValue: TPinDrive); override;

    property Memory: Pointer read FMemory;
  public
    constructor Create(const ASystemCore: TFastSystemCore;
      const ANumberingScheme: TNumberingScheme = TNumberingScheme.Printed);
    destructor Destroy; override;

    // Quickly changes specified pin value (assuming it is set for output). Note that the pin must be
    // specified using native BCM numbering scheme.
    procedure SetFastValue(const APinBCM: TPinIdentifier; const AValue: TPinValue);

    // Reference to @link(TFastSystemCore), which provides high performance timing and delay utilities.
    property SystemCore: TFastSystemCore read FSystemCore;

    // Defines what pin numbering scheme should be used for all functions that receive "Pin" as parameter.
    // Default is "Printed" scheme, which means pins are specified as they are numbered on PCB.
    // Alternatively, it can be changed to "BCM" numbering scheme, which use native GPIO numbers.
    property NumberingScheme: TNumberingScheme read FNumberingScheme write FNumberingScheme;

    // Provides control and feedback of currently selected mode for the given pin, including alternative
    // functions as supported by BCM2835 chip.
    property PinModeEx[const APin: TPinIdentifier]: TPinModeEx read GetPinModeEx write SetPinModeEx;
  end;

  TFastSPI = class(TCustomPortSPI)
  public const
    DefaultChipSelect = 0;
    DefaultFrequency = 8000000;
    DefaultMode = 0;
  strict private const
    OffsetControlStatus = $0000;
    OffsetDataBuffer = $0004;
    OffsetClockDivider = $0008;

    MaskControlStatusChipSelect = $00000003;
    MaskControlStatusClockPhase = $00000004;
    MaskControlStatusClockPolarity = $00000008;
    MaskControlStatusClearBuffer = $00000030;
    MaskControlStatusTransfer = $00000080;
    MaskControlStatusDone = $00010000;
    MaskControlStatusRXD = $00020000;
    MaskControlStatusTXD = $00040000;

    TransferBlockCounterStart = 1024; // # of ticks when to capture initial time
    TransferBlockCounterMax = 8192; // # of ticks after which to start comparing time
    TransferBlockTimeout = 1000000; // in microseconds
  private
    FFastGPIO: TFastGPIO;
    FMemory: Pointer;

    FFrequency: Cardinal;
    FMode: TSPIMode;
    FChipSelectIndex: Cardinal;

    function GetChipOffsetSPI: TChipOffset; inline;
    procedure UpdateChipSelectMode;
    procedure UpdateChipSelectIndex;
    procedure UpdateFrequency(const AFrequency: Cardinal);
    procedure UpdateMode;
    procedure SetChipSelectIndex(const AChipSelectIndex: Cardinal);
  protected
    function GetOffsetPointer(const AOffset: Cardinal): Pointer; inline;

    function GetFrequency: Cardinal; override;
    procedure SetFrequency(const AFrequency: Cardinal); override;
    function GetBitsPerWord: TBitsPerWord; override;
    procedure SetBitsPerWord(const ABitsPerWord: TBitsPerWord); override;
    function GetMode: TSPIMode; override;
    procedure SetMode(const AMode: TSPIMode); override;

    property FastGPIO: TFastGPIO read FFastGPIO;
    property Memory: Pointer read FMemory;
  public
    constructor Create(const AFastGPIO: TFastGPIO; const AChipSelectMode: TChipSelectMode = TChipSelectMode.ActiveLow);
    destructor Destroy; override;

    function Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;
    function Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;
    function Transfer(const AReadBuffer, AWriteBuffer: Pointer;
      const ABufferSize: Cardinal): Cardinal; override;

    // Controls the operating frequency of SPI bus in Hz, with supported values between ~3.8 kHz and 125 mHz.
    // Typically, default value for SPI is 8 mHz. }
    property Frequency: Cardinal read FFrequency write SetFrequency;

    // Defines clock polarity and phase for SPI operation.
    property Mode: TSPIMode read FMode write SetMode;

    // Defines what Chip Select line to enable during transfers. Supported values are 0 = CE0 and 1 = CE1.
    property ChipSelectIndex: Cardinal read FChipSelectIndex write SetChipSelectIndex;
  end;

  TFastI2C = class(TCustomPortI2C)
  strict private const
    OffsetControl = $0000;
    OffsetStatus = $0004;
    OffsetDataLength = $0008;
    OffsetSlaveAddress = $000C;
    OffsetDataBuffer = $0010;
    OffsetClockDivider = $0014;

    MaskControlRead = $00000001;
    MaskControlClearBuffers = $00000020;
    MaskControlStart = $00000080;
    MaskControlEnabled = $00008000;

    MaskStatusTransfer = $00000001;
    MaskStatusDone = $00000002;
    MaskStatusTXD = $00000010;
    MaskStatusRXD = $00000020;
    MaskStatusNoACK = $00000100;
    MaskStatusTimeout = $00000200;

    MaxInternalBufferSize = 16;

    TransferCounterStart = 1024; // # of ticks when to capture initial time
    TransferCounterMax = 8192; // # of ticks after which to start comparing time
    TransferTimeout = 1000000; // in microseconds
  strict private
    FFastGPIO: TFastGPIO;
    FMemory: Pointer;
    FFrequency: Cardinal;
    FTimePerByte: Cardinal;

    function GetChipOffsetI2C: TChipOffset; inline;
    procedure UpdateTimePerByte(const AClockDivider: Cardinal);
    procedure SetFrequency(const AFrequency: Cardinal);
    function ProcessBlockCounter(var ABlockCounter: Integer;
      var ABlockTimeoutStart: TTickCounter): Boolean; inline;
  protected
    function GetOffsetPointer(const AOffset: Cardinal): Pointer; inline;

    property FastGPIO: TFastGPIO read FFastGPIO;
    property Memory: Pointer read FMemory;
  public
    constructor Create(const AFastGPIO: TFastGPIO);
    destructor Destroy; override;

    procedure SetAddress(const AAddress: Cardinal); override;

    function Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;
    function Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;

    function ReadBlockData(const ACommand: Byte; const ABuffer: Pointer;
      const ABufferSize: Cardinal): Cardinal; override;
    function WriteBlockData(const ACommand: Byte; const ABuffer: Pointer;
      const ABufferSize: Cardinal): Cardinal; override;

    // Controls the operating frequency of I2C bus in Hz.
    property Frequency: Cardinal read FFrequency write SetFrequency;
  end;

  TDefaultUART = class(TSysfsUART)
  public const
    DefaultSystemPath = '/dev/ttyAMA0';
  private
    FFastGPIO: TFastGPIO;
  protected
    property FastGPIO: TFastGPIO read FFastGPIO;
  public
    constructor Create(const AFastGPIO: TFastGPIO; const ASystemPath: StdString = DefaultSystemPath);
    destructor Destroy; override;
  end;

  ERPiGeneric = class(Exception);
  ERPiOpenFile = class(ERPiGeneric);
  ERPiMemoryMap = class(ERPiGeneric);

  EGPIOGeneric = class(ERPiGeneric);
  EGPIOMemoryMap = class(EGPIOGeneric);
  EGPIOUnsupported = class(EGPIOGeneric);

  EGPIOInvalidPin = class(EGPIOGeneric);
  EGPIOInvalidBCMPin = class(EGPIOInvalidPin);
  EGPIOInvalidPrintedPin = class(EGPIOInvalidPin);
  EGPIOAlternateFunctionPin = class(EGPIOGeneric);

  ESPIGeneric = class(ERPiGeneric);
  ESPIMemoryMap = class(ESPIGeneric);
  ESPIUnsupportedGeneric = class(ESPIGeneric);
  ESPIUnsupportedBitsPerWord = class(ESPIUnsupportedGeneric);
  ESPIUnsupportedFrequency = class(ESPIUnsupportedGeneric);
  ESPIUnsupportedChipSelect = class(ESPIUnsupportedGeneric);

  EI2CGeneric = class(ERPiGeneric);
  EI2CUnsupportedGeneric = class(EI2CGeneric);
  EI2CUnsupportedFrequency = class(EI2CUnsupportedGeneric);

  ESystemCoreRefRequired = class(ERPiGeneric);
  EGPIORefRequired = class(ERPiGeneric);

resourcestring
  SCannotMapRegistersPortion = 'Cannot map <%s> portion of BCM2835 registers to memory.';
  SCannotOpenFileToMap = 'Cannot not open file <%s> for memory mapping.';
  SCouldNotInterpretIOKernelValues = 'Could not interpret I/O kernel values.';

  SGPIOSpecifiedBCMPinInvalid = 'The specified GPIO pin <%d> (BCM) is invalid.';
  SGPIOSpecifiedPrintedPinInvalid = 'The specified GPIO pin <%d> (Printed) is invalid.';
  SGPIOSpecifiedBCMPinAlternativeMode = 'The specified GPIO pin <%d> has non-basic alternative mode.';

  SGPIOUnsupported = 'The requested feature is unsupported.';

  SSPIUnsupportedBitsPerWord = 'Specified SPI number of bits per word <%d> is not supported.';
  SSPIUnsupportedFrequency = 'Specified SPI frequency <%d> is not supported.';
  SSPIUnsupportedChipSelect = 'Specified SPI chip select line <%d> is not supported.';

  SI2CUnsupportedFrequency = 'Specified I2C frequency <%d> is not supported.';

  SSystemCoreRefNotProvided = 'Reference to TFastSystemCore has not been provided.';
  SGPIORefNotProvided = 'Reference to TFastGPIO has not been provided.';

implementation

uses
  BaseUnix, Math, Classes;

{$REGION 'Global Types and Functions'}

const
  PinmapPrintedToBCM: array[1..40] of Integer = (
    { 01 } -1,  // 3.3V
    { 02 } -1,  // 5V
    { 03 }  2,  // SDA1 (Alt0)
    { 04 } -1,  // 5V
    { 05 }  3,  // SCL1 (Alt0)
    { 06 } -1,  // Ground
    { 07 }  4,  // GPCLK0
    { 08 } 14,  // TXD0 (Alt0)
    { 09 } -1,  // Ground
    { 10 } 15,  // RXD0 (Alt0)
    { 11 } 17,
    { 12 } 18,  // PCM_CLK / PWM0 (Alt0)
    { 13 } 27,  // PCM_DOUT
    { 14 } -1,  // Ground
    { 15 } 22,
    { 16 } 23,
    { 17 } -1,  // 3.3V
    { 18 } 24,
    { 19 } 10,  // SPI0_MOSI (Alt0)
    { 20 } -1,  // Ground
    { 21 }  9,  // SPI0_MISO (Alt0)
    { 22 } 25,
    { 23 } 11,  // SPI0_SCLK (Alt0)
    { 24 }  8,  // SPI0_CE0 (Alt0)
    { 25 } -1,  // Ground
    { 26 }  7,  // SPI0_CE1 (Alt0)

    { 27 } -1,  // EEPROM ID Data
    { 28 } -1,  // EEPROM ID Clock
    { 29 }  5,
    { 30 } -1,  // Ground
    { 31 }  6,
    { 32 } 12,  // PWM0 (Alt0)
    { 33 } 13,  // PWM1 (Alt0)
    { 34 } -1,  // Ground
    { 35 } 19,  // PCM Frame Sync (Alt0), SPI1_MISO (Alt4), PWM1 (Alt5)
    { 36 } 16,
    { 37 } 26,
    { 38 } 20,  // PCM Data In (Alt0), SPI1_MOSI (Alt4)
    { 39 } -1,  // Ground
    { 40 } 21   // PCM Data Out (Alt0), SPI_SCLK (Alt4)
  );

// The following "safe" commands do the actual reading and/or writing to make sure the data arrives in the
// appropriate order. Apparently, when switching access between different peripheral devices, next read or
// write operation may not arrive in the appropriate order so some values to be read may be lost, while
// others that are written may result in data corruption.

// Since FreePascal does not have any memory barrier build-ins, and under aarch64 does not compile "dmb"
// assembly instruction correctly, we compile these helper functions in C and then statically link them.

// Make sure to execute "WriteMemSafe.sh" script to compile these functions on your Raspberry PI.
// If you need to cross-compile, then take compiler commands from the script and adjust them accordingly.
// Either GCC or Clang would be able to compile them.

procedure WriteMemSafe(const AAddress: Pointer; const AValue: Cardinal); cdecl; external name 'writeMemSafe';
function ReadMemSafe(const AAddress: Pointer): Cardinal; cdecl; external name 'readMemSafe';

{$L WriteMemSafe.a}

procedure ChangeBitsSafe(const AAddress: Pointer; const AValue, AMask: Cardinal); inline;
begin
  WriteMemSafe(AAddress, (ReadMemSafe(AAddress) and (not AMask)) or (AValue and AMask));
end;

procedure WriteMemFast(const AAddress: Pointer; const AValue: Cardinal); inline;
begin
  PCardinal(AAddress)^ := AValue;
end;

function ReadMemFast(const AAddress: Pointer): Cardinal; inline;
begin
  Result := PCardinal(AAddress)^;
end;

function PortionMap(const ARegName: string; const AHandle: TUntypedHandle; const AOffset,
  ASize: Cardinal): Pointer;
begin
{$IFDEF cpuaarch64}
  Result := Fpmmap(nil, ASize, PROT_READ or PROT_WRITE, MAP_SHARED, AHandle, AOffset);
{$ELSE}
  // FreePascal RTL uses "mmap2" under "cpuarm" target.
  Result := Fpmmap(nil, ASize, PROT_READ or PROT_WRITE, MAP_SHARED, AHandle, AOffset div 4096);
{$ENDIF}
  if (Result = nil) or (Result = MAP_FAILED) then
    raise ERPiMemoryMap.Create(Format(SCannotMapRegistersPortion, [ARegName]));
end;

procedure PortionUnmap(var AMemAddr: Pointer; const ASize: Cardinal);
begin
  if AMemAddr <> nil then
  begin
    Fpmunmap(AMemAddr, ASize);
    AMemAddr := nil;
  end;
end;

{$ENDREGION}
{$REGION 'TFastSystemCore'}

constructor TFastSystemCore.Create;
const
  PathToDevMem = '/dev/mem';
begin
  inherited;

  // Assume I/O addresses for Raspberry PI 1.
  FChipOffsetBase := $20000000;
  FChipDataSize := $01000000;

  // Retrieve actual I/O addresses from the kernel.
  UpdateIOValuesFromKernel;

  FHandle := FpOpen(PathToDevMem, O_RDWR or O_SYNC);
  if FHandle < 0 then
  begin
    FHandle := 0;
    raise ERPiOpenFile.Create(Format(SCannotOpenFileToMap, [PathToDevMem]));
  end;

  FMemory := PortionMap('ST', FHandle, GetChipOffsetST, PageSize);
end;

destructor TFastSystemCore.Destroy;
begin
  PortionUnmap(FMemory, PageSize);

  if FHandle <> 0 then
  begin
    FpClose(FHandle);
    FHandle := 0;
  end;

  inherited;
end;

function TFastSystemCore.UpdateIOValuesFromKernel: Boolean;
const
  PathToDeviceTreeRanges = '/proc/device-tree/soc/ranges';
var
  LHandle: TUntypedHandle;
  LValues: array[0..3] of Cardinal;
  LByteCount: SizeInt;
begin
  LHandle := FpOpen(PathToDeviceTreeRanges, O_RDONLY);
  if LHandle < 0 then
    Exit(False);
  try
    LByteCount := FpRead(LHandle, LValues, SizeOf(LValues));
    if LByteCount < 12 then
      Exit(False);
  finally
    FpClose(LHandle);
  end;

  Result := True;
  FChipOffsetBase := BEtoN(LValues[1]);
  FChipDataSize := BEtoN(LValues[2]);

  if FChipOffsetBase = 0 then
  begin // Raspberry PI 4 ?
    if LByteCount >= 16 then
    begin
      FChipOffsetBase := BEtoN(LValues[2]);
      FChipDataSize := BEtoN(LValues[3]);
    end
    else
      raise ERPiOpenFile.Create(SCouldNotInterpretIOKernelValues);
  end;
end;

function TFastSystemCore.GetChipOffsetBase: TChipOffset;
begin
  Result := FChipOffsetBase;
end;

function TFastSystemCore.GetChipOffsetST: TChipOffset;
begin
  Result := GetChipOffsetBase + $3000;
end;

function TFastSystemCore.GetOffsetPointer(const AOffset: Cardinal): Pointer;
begin
  Result := Pointer(PtrUInt(FMemory) + AOffset);
end;

function TFastSystemCore.GetTickCount: TTickCounter;
var
  UpperBits, LowerBits: Cardinal;
begin
  UpperBits := ReadMemSafe(GetOffsetPointer(OffsetTimerUpper));
  LowerBits := ReadMemSafe(GetOffsetPointer(OffsetTimerLower));

  Result := ReadMemSafe(GetOffsetPointer(OffsetTimerUpper));

  if Result <> UpperBits then
    Result := (Result shl 32) or ReadMemSafe(GetOffsetPointer(OffsetTimerLower))
  else
    Result := (Result shl 32) or LowerBits;
end;

procedure TFastSystemCore.MicroDelay(const AMicroseconds: TMicroseconds);
var
  LStartTicks: TTickCounter;
  LNanoSpec: timespec;
begin
  LStartTicks := GetTickCount;

  if AMicroseconds > 300 then
  begin
  	LNanoSpec.tv_nsec := (AMicroseconds - 200) * 1000;
  	LNanoSpec.tv_sec := 0;

    FpNanoSleep(@LNanoSpec, nil);
  end;

  while TicksInBetween(LStartTicks, GetTickCount) < AMicroseconds do
    TThread.Yield;
end;

{$ENDREGION}
{$REGION 'TFastGPIO'}

constructor TFastGPIO.Create(const ASystemCore: TFastSystemCore; const ANumberingScheme: TNumberingScheme);
begin
  inherited Create;

  FSystemCore := ASystemCore;
  if FSystemCore = nil then
    raise ESystemCoreRefRequired.Create(SSystemCoreRefNotProvided);

  FNumberingScheme := ANumberingScheme;
  FMemory := PortionMap('GPIO', FSystemCore.Handle, GetChipOffsetGPIO, TFastSystemCore.PageSize);
end;

destructor TFastGPIO.Destroy;
begin
  PortionUnmap(FMemory, TFastSystemCore.PageSize);

  inherited;
end;

function TFastGPIO.GetChipOffsetGPIO: TChipOffset;
begin
  Result := FSystemCore.GetChipOffsetBase + $200000;
end;

function TFastGPIO.GetOffsetPointer(const AOffset: Cardinal): Pointer;
begin
  Result := Pointer(PtrUInt(FMemory) + AOffset);
end;

function TFastGPIO.ProcessPinNumber(const APin: TPinIdentifier): TPinIdentifier;
begin
  if FNumberingScheme = TNumberingScheme.Printed then
  begin
    if APin > High(PinmapPrintedToBCM) then
      raise EGPIOInvalidPin.CreateFmt(SGPIOSpecifiedBCMPinInvalid, [APin]);

    Result := PinmapPrintedToBCM[APin];
  end
  else
  begin
    if APin > 53 then
      raise EGPIOInvalidPin.CreateFmt(SGPIOSpecifiedPrintedPinInvalid, [APin]);

    Result := APin;
  end;
end;

procedure TFastGPIO.SetPinModeBCM(const APinBCM: TPinIdentifier; const AMode: TPinModeEx);
var
  LShift: Integer;
begin
  LShift := (Integer(APinBCM) mod 10) * 3;
  ChangeBitsSafe(GetOffsetPointer((Cardinal(APinBCM) div 10) * 4), Ord(AMode) shl LShift, $07 shl LShift);
end;

function TFastGPIO.GetPinMode(const APin: TPinIdentifier): TPinMode;
begin
  case GetPinModeEx(APin) of
    TPinModeEx.Input:
      Result := TPinMode.Input;
    TPinModeEx.Output:
      Result := TPinMode.Output;
  else
    raise EGPIOAlternateFunctionPin.CreateFmt(SGPIOSpecifiedBCMPinAlternativeMode, [APin]);
  end;
end;

procedure TFastGPIO.SetPinMode(const APin: TPinIdentifier; const AMode: TPinMode);
begin
  if AMode = TPinMode.Output then
    SetPinModeEx(APin, TPinModeEx.Output)
  else
    SetPinModeEx(APin, TPinModeEx.Input);
end;

function TFastGPIO.GetPinValue(const APin: TPinIdentifier): TPinValue;
var
  LPinBCM: TPinIdentifier;
begin
  LPinBCM := ProcessPinNumber(APin);

  if ReadMemSafe(GetOffsetPointer($34 + (Cardinal(LPinBCM) div 32) * 4)) and (1 shl (LPinBCM mod 32)) > 0 then
    Result := TPinValue.High
  else
    Result := TPinValue.Low;
end;

procedure TFastGPIO.SetPinValue(const APin: TPinIdentifier; const AValue: TPinValue);
var
  LPinBCM: TPinIdentifier;
  LDestPtr: Pointer;
begin
  LPinBCM := ProcessPinNumber(APin);

  if AValue = TPinValue.Low then
    LDestPtr := GetOffsetPointer($28 + (Cardinal(LPinBCM) div 32) * 4)
  else
    LDestPtr := GetOffsetPointer($1C + (Cardinal(LPinBCM) div 32) * 4);

  WriteMemSafe(LDestPtr, 1 shl (LPinBCM mod 32));
end;

function TFastGPIO.GetPinDrive(const APin: TPinIdentifier): TPinDrive;
begin
  Result := TPinDrive.None;
end;

procedure TFastGPIO.SetPinDrive(const APin: TPinIdentifier; const AValue: TPinDrive);
begin
end;

function TFastGPIO.GetPinModeEx(const APin: TPinIdentifier): TPinModeEx;
var
  LAddress: Pointer;
  LPinBCM: TPinIdentifier;
begin
  LPinBCM := ProcessPinNumber(APin);
  LAddress := GetOffsetPointer((Cardinal(LPinBCM) div 10) * 4);

  Result := TPinModeEx((ReadMemSafe(LAddress) shr ((LPinBCM mod 10) * 3)) and $07);
end;

procedure TFastGPIO.SetPinModeEx(const APin: TPinIdentifier; const AValue: TPinModeEx);
begin
  SetPinModeBCM(ProcessPinNumber(APin), AValue);
end;

procedure TFastGPIO.SetFastValue(const APinBCM: TPinIdentifier; const AValue: TPinValue);
var
  LDestValue: PLongWord;
begin
  if AValue = TPinValue.Low then
    LDestValue := GetOffsetPointer($0028 + (Cardinal(APinBCM) shr 5) shl 2)
  else
    LDestValue := GetOffsetPointer($001C + (Cardinal(APinBCM) shr 5) shl 2);

  LDestValue^ := 1 shl (APinBCM and $1F);
end;

{$ENDREGION}
{$REGION 'TFastSPI'}

constructor TFastSPI.Create(const AFastGPIO: TFastGPIO; const AChipSelectMode: TChipSelectMode);
var
  LDestPtr: Pointer;
begin
  inherited Create(AChipSelectMode);

  FFastGPIO := AFastGPIO;
  if FFastGPIO = nil then
    raise EGPIORefRequired.Create(ClassName + ExceptionClassNameSeparator + SGPIORefNotProvided);

  FMemory := PortionMap('SPI', FFastGPIO.SystemCore.Handle, GetChipOffsetSPI, TFastSystemCore.PageSize);

  FFastGPIO.SetPinModeBCM(7, TPinModeEx.Alt0);  // CE1
  FFastGPIO.SetPinModeBCM(8, TPinModeEx.Alt0);  // CE0
  FFastGPIO.SetPinModeBCM(9, TPinModeEx.Alt0);  // MISO
  FFastGPIO.SetPinModeBCM(10, TPinModeEx.Alt0); // MOSI
  FFastGPIO.SetPinModeBCM(11, TPinModeEx.Alt0); // SCLK

  LDestPtr := GetOffsetPointer(OffsetControlStatus);
  WriteMemSafe(LDestPtr, 0);
  WriteMemFast(LDestPtr, MaskControlStatusClearBuffer);

  UpdateFrequency(8000000);
  UpdateMode;
  UpdateChipSelectMode;
  UpdateChipSelectIndex;
end;

destructor TFastSPI.Destroy;
begin
{$IFDEF DATAPORTS_PINS_RESET_AFTER_DONE}
  FFastGPIO.SetPinModeBCM(11, TPinModeEx.Input);
  FFastGPIO.SetPinModeBCM(10, TPinModeEx.Input);
  FFastGPIO.SetPinModeBCM(9, TPinModeEx.Input);
  FFastGPIO.SetPinModeBCM(8, TPinModeEx.Input);
  FFastGPIO.SetPinModeBCM(7, TPinModeEx.Input);
{$ENDIF}

  PortionUnmap(FMemory, TFastSystemCore.PageSize);

  inherited;
end;

function TFastSPI.GetChipOffsetSPI: TChipOffset;
begin
  Result := FFastGPIO.SystemCore.GetChipOffsetBase + $204000;
end;

function TFastSPI.GetOffsetPointer(const AOffset: Cardinal): Pointer;
begin
  Result := Pointer(PtrUInt(FMemory) + AOffset);
end;

procedure TFastSPI.UpdateChipSelectMode;
var
  ActiveValue: Cardinal;
begin
  if FChipSelectMode <> TChipSelectMode.Disabled then
  begin
    if FChipSelectMode = TChipSelectMode.ActiveHigh then
      ActiveValue := 1
    else
      ActiveValue := 0;

    ChangeBitsSafe(GetOffsetPointer(OffsetControlStatus), Ord(ActiveValue) shl 21, 1 shl 21);
    ChangeBitsSafe(GetOffsetPointer(OffsetControlStatus), Ord(ActiveValue) shl 22, 1 shl 22);
  end
  else
    ChangeBitsSafe(GetOffsetPointer(OffsetControlStatus), 3, MaskControlStatusChipSelect)
end;

procedure TFastSPI.UpdateChipSelectIndex;
begin
  ChangeBitsSafe(GetOffsetPointer(OffsetControlStatus), FChipSelectIndex and $01, MaskControlStatusChipSelect);
end;

procedure TFastSPI.UpdateFrequency(const AFrequency: Cardinal);
var
  LRealDivider: Single;
  LActualDivider: Integer;
begin
  LRealDivider := TFastSystemCore.BaseClock / AFrequency;
  LActualDivider := Round(Power(2, Round(Log2(LRealDivider))));

  if (LActualDivider < 1) or (LActualDivider > 65536) then
    raise ESPIUnsupportedFrequency.Create(Format(SSPIUnsupportedFrequency, [AFrequency]));

  if LActualDivider = 65536 then
    LActualDivider := 0;

  WriteMemSafe(GetOffsetPointer(OffsetClockDivider), LActualDivider);
  FFrequency := AFrequency;
end;

procedure TFastSPI.UpdateMode;
begin
  ChangeBitsSafe(GetOffsetPointer(OffsetControlStatus), FMode shl 2, MaskControlStatusClockPolarity or
    MaskControlStatusClockPhase);
end;

procedure TFastSPI.SetChipSelectIndex(const AChipSelectIndex: Cardinal);
begin
  if AChipSelectIndex > 1 then
    raise ESPIUnsupportedChipSelect.CreateFmt(SSPIUnsupportedChipSelect, [AChipSelectIndex]);

  if FChipSelectIndex <> AChipSelectIndex then
  begin
    FChipSelectIndex := AChipSelectIndex;
    UpdateChipSelectIndex;
  end;
end;

function TFastSPI.GetFrequency: Cardinal;
begin
  Result := FFrequency;
end;

procedure TFastSPI.SetFrequency(const AFrequency: Cardinal);
begin
  if AFrequency = 0 then
    raise ESPIUnsupportedFrequency.CreateFmt(SSPIUnsupportedFrequency, [AFrequency]);

  if FFrequency <> AFrequency then
    UpdateFrequency(AFrequency);
end;

function TFastSPI.GetBitsPerWord: TBitsPerWord;
begin
  Result := 8;
end;

procedure TFastSPI.SetBitsPerWord(const ABitsPerWord: TBitsPerWord);
begin
  if ABitsPerWord <> 8 then
    raise ESPIUnsupportedBitsPerWord.CreateFmt(SSPIUnsupportedBitsPerWord, [ABitsPerWord]);
end;

function TFastSPI.GetMode: TSPIMode;
begin
  Result := FMode;
end;

procedure TFastSPI.SetMode(const AMode: TSPIMode);
begin
  if FMode <> AMode then
  begin
    FMode := AMode;
    UpdateMode;
  end;
end;

function TFastSPI.Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
begin
  Result := Transfer(ABuffer, nil, ABufferSize);
end;

function TFastSPI.Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
begin
  Result := Transfer(nil, ABuffer, ABufferSize);
end;

function TFastSPI.Transfer(const AReadBuffer, AWriteBuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LControlStatusPtr, LDataBufferPtr: Pointer;
  LBytesRead, LBytesWritten, LBlockCounter: Integer;
  LBlockTimeoutStart: UInt64;
begin
  LControlStatusPtr := GetOffsetPointer(OffsetControlStatus);
  LDataBufferPtr := GetOffsetPointer(OffsetDataBuffer);

  // Clear FIFO buffers.
  ChangeBitsSafe(LControlStatusPtr, MaskControlStatusClearBuffer, MaskControlStatusClearBuffer);

  // Begin transfer (TA = 1)
  ChangeBitsSafe(LControlStatusPtr, MaskControlStatusTransfer, MaskControlStatusTransfer);
  try
    LBytesRead := 0;
    LBytesWritten := 0;
    LBlockCounter := -1;

    while (LBytesRead < ABufferSize) or (LBytesWritten < ABufferSize) do
    begin
      // Send bytes.
      while (ReadMemSafe(LControlStatusPtr) and MaskControlStatusTXD <> 0) and
        (LBytesWritten < ABufferSize) do
      begin
        if AWriteBuffer <> nil then
          WriteMemFast(LDataBufferPtr, PByte(PtrUInt(AWriteBuffer) + Cardinal(LBytesWritten))^)
        else
          WriteMemFast(LDataBufferPtr, 0);

        Inc(LBytesWritten);
        LBlockCounter := -1;
      end;

      // Receive bytes.
      while (ReadMemSafe(LControlStatusPtr) and MaskControlStatusRXD <> 0) and (LBytesRead < ABufferSize) do
      begin
        if AReadBuffer <> nil then
          PByte(PtrUInt(AReadBuffer) + Cardinal(LBytesRead))^ := ReadMemFast(LDataBufferPtr)
        else
          ReadMemFast(LDataBufferPtr);

        Inc(LBytesRead);
        LBlockCounter := -1;
      end;

      // Apply a timeout to prevent hung up by adjusting ticks first and after certain fixed interval
      // calculating the actual waiting time.
      if LBlockCounter = -1 then
        LBlockCounter := 0
      else
      begin
        if LBlockCounter = TransferBlockCounterStart then
          LBlockTimeoutStart := FFastGPIO.SystemCore.GetTickCount;

        if LBlockCounter >= TransferBlockCounterMax then
        begin
          if FFastGPIO.SystemCore.TicksInBetween(LBlockTimeoutStart, FFastGPIO.SystemCore.GetTickCount) >
            TransferBlockTimeout then
            Exit(0);
        end
        else
          Inc(LBlockCounter);
      end
    end;

    // Wait for DONE flag to be set with a timeout to prevent hunging.
    LBlockTimeoutStart := FFastGPIO.SystemCore.GetTickCount;

    while ReadMemFast(LControlStatusPtr) and MaskControlStatusDone = 0 do
      if FFastGPIO.SystemCore.TicksInBetween(LBlockTimeoutStart, FFastGPIO.SystemCore.GetTickCount) >
        TransferBlockTimeout then
        Exit(0);
  finally
    // End transfer (TA = 0)
    ChangeBitsSafe(LControlStatusPtr, 0, MaskControlStatusTransfer);
  end;

  Result := ABufferSize;
end;

{$ENDREGION}
{$REGION 'TFastI2C'}

constructor TFastI2C.Create(const AFastGPIO: TFastGPIO);
begin
  inherited Create;

  FFastGPIO := AFastGPIO;
  if FFastGPIO = nil then
    raise EGPIORefRequired.Create(ClassName + ExceptionClassNameSeparator + SGPIORefNotProvided);

  FMemory := PortionMap('I2C', FFastGPIO.SystemCore.Handle, GetChipOffsetI2C, TFastSystemCore.PageSize);

  FFastGPIO.SetPinModeBCM(2, TPinModeEx.Alt0); // SDA
  FFastGPIO.SetPinModeBCM(3, TPinModeEx.Alt0); // SCL

  UpdateTimePerByte(ReadMemSafe(GetOffsetPointer(OffsetClockDivider)));
end;

destructor TFastI2C.Destroy;
begin
{$IFDEF DATAPORTS_PINS_RESET_AFTER_DONE}
  FFastGPIO.SetPinModeBCM(3, TPinModeEx.Input);
  FFastGPIO.SetPinModeBCM(2, TPinModeEx.Input);
{$ENDIF}

  PortionUnmap(FMemory, TFastSystemCore.PageSize);

  inherited;
end;

function TFastI2C.GetChipOffsetI2C: TChipOffset;
begin
  Result := FFastGPIO.SystemCore.GetChipOffsetBase + $804000;
end;

procedure TFastI2C.UpdateTimePerByte(const AClockDivider: Cardinal);
const
  BitsPerByte = 9;
begin
  FTimePerByte := (UInt64(AClockDivider) * BitsPerByte * 1000000) div TFastSystemCore.BaseClock;
end;

procedure TFastI2C.SetFrequency(const AFrequency: Cardinal);
var
  LClockDivider: Cardinal;
begin
  if AFrequency < 1 then
    raise EI2CUnsupportedFrequency.Create(Format(SI2CUnsupportedFrequency, [AFrequency]));

  if FFrequency <> AFrequency then
  begin
    LClockDivider := TFastSystemCore.BaseClock div Cardinal(AFrequency);

    if (LClockDivider < 1) or (LClockDivider > 65536) then
      raise EI2CUnsupportedFrequency.Create(Format(SI2CUnsupportedFrequency, [AFrequency]));

    if LClockDivider = 65536 then
      LClockDivider := 0;

    WriteMemSafe(GetOffsetPointer(OffsetClockDivider), LClockDivider);

    FFrequency := AFrequency;
    UpdateTimePerByte(LClockDivider);
  end;
end;

function TFastI2C.GetOffsetPointer(const AOffset: Cardinal): Pointer;
begin
  Result := Pointer(PtrUInt(FMemory) + AOffset);
end;

procedure TFastI2C.SetAddress(const AAddress: Cardinal);
begin
  WriteMemSafe(GetOffsetPointer(OffsetSlaveAddress), AAddress);
end;

function TFastI2C.ProcessBlockCounter(var ABlockCounter: Integer;
  var ABlockTimeoutStart: TTickCounter): Boolean;
begin
  if ABlockCounter = -1 then
    ABlockCounter := 0
  else
  begin
    if ABlockCounter = TransferCounterStart then
      ABlockTimeoutStart := FFastGPIO.SystemCore.GetTickCount;

    if ABlockCounter >= TransferCounterMax then
    begin
      if FFastGPIO.SystemCore.TicksInBetween(ABlockTimeoutStart,
        FFastGPIO.SystemCore.GetTickCount) > TransferTimeout then
        Exit(False);
    end
    else
      Inc(ABlockCounter);
  end;

  Result := True;
end;

function TFastI2C.Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LControlPtr, LStatusPtr, LDataBufferPtr: Pointer;
  LBlockTimeoutStart: TTickCounter;
  LBlockCounter: Integer;
  LBytesRead: Cardinal;
begin
  LControlPtr := GetOffsetPointer(OffsetControl);
  LStatusPtr := GetOffsetPointer(OffsetStatus);
  LDataBufferPtr := GetOffsetPointer(OffsetDataBuffer);

  // Clear FIFO and status flags.
  ChangeBitsSafe(LControlPtr, MaskControlClearBuffers, MaskControlClearBuffers);
  WriteMemFast(LStatusPtr, MaskStatusTimeout or MaskStatusNoACK or MaskStatusDone);

  // Specify data Abuffer size.
  WriteMemFast(GetOffsetPointer(OffsetDataLength), ABufferSize);

  // Begin reading operation and send "START" signal.
  WriteMemFast(LControlPtr, MaskControlEnabled or MaskControlStart or MaskControlRead);

  // Receive bytes.
  LBytesRead := 0;
  LBlockCounter := -1;

  while ReadMemFast(LStatusPtr) and MaskStatusDone = 0 do
  begin
    while (ReadMemFast(LStatusPtr) and MaskStatusRXD > 0) and (LBytesRead < ABufferSize) do
    begin
      PByte(PtrUInt(ABuffer) + Cardinal(LBytesRead))^ := ReadMemFast(LDataBufferPtr);
      Inc(LBytesRead);
      LBlockCounter := -1;
    end;

    if not ProcessBlockCounter(LBlockCounter, LBlockTimeoutStart) then
      Exit(0);
  end;

  // Retrieve any remaining bytes from FIFO Abuffer.
  while (ReadMemFast(LStatusPtr) and MaskStatusRXD > 0) and (LBytesRead < ABufferSize) do
  begin
    PByte(PtrUInt(ABuffer) + Cardinal(LBytesRead))^ := ReadMemFast(LDataBufferPtr);
    Inc(LBytesRead);
  end;

  Result := LBytesRead;

  // Check status flags for any issues during read.
  if ReadMemSafe(LStatusPtr) and (MaskStatusNoACK or MaskStatusTimeout) > 0 then
    Result := 0;
end;

function TFastI2C.Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LControlPtr, LStatusPtr, LDataBufferPtr: Pointer;
  LBlockTimeoutStart: TTickCounter;
  LBytesWritten: Cardinal;
  LBlockCounter: Integer;
begin
  LControlPtr := GetOffsetPointer(OffsetControl);
  LStatusPtr := GetOffsetPointer(OffsetStatus);
  LDataBufferPtr := GetOffsetPointer(OffsetDataBuffer);

  // Clear FIFO and status flags.
  ChangeBitsSafe(LControlPtr, MaskControlClearBuffers, MaskControlClearBuffers);
  WriteMemFast(LStatusPtr, MaskStatusTimeout or MaskStatusNoACK or MaskStatusDone);

  // Specify data Abuffer size.
  WriteMemFast(GetOffsetPointer(OffsetDataLength), ABufferSize);

  // Fill FIFO buffers as much as possible before starting transfer.
  LBytesWritten := 0;

  while (LBytesWritten < ABufferSize) and (LBytesWritten < MaxInternalBufferSize) do
  begin
    WriteMemFast(LDataBufferPtr, PByte(PtrUInt(ABuffer) + Cardinal(LBytesWritten))^);
    Inc(LBytesWritten);
  end;

  // Begin transfer and send "START" signal.
  WriteMemFast(LControlPtr, MaskControlEnabled or MaskControlStart);

  // Send bytes.
  LBlockCounter := -1;

  while ReadMemFast(LStatusPtr) and MaskStatusDone = 0 do
  begin
    while (ReadMemFast(LStatusPtr) and MaskStatusTXD > 0) and (LBytesWritten < ABufferSize) do
    begin
      WriteMemFast(LDataBufferPtr, PByte(PtrUInt(ABuffer) + Cardinal(LBytesWritten))^);
      Inc(LBytesWritten);
      LBlockCounter := -1;
    end;

    if not ProcessBlockCounter(LBlockCounter, LBlockTimeoutStart) then
      Exit(0);
  end;

  Result := LBytesWritten;

  // Check status flags for any issues during write.
  if ReadMemSafe(LStatusPtr) and (MaskStatusNoACK or MaskStatusTimeout) > 0 then
    Result := 0;
end;

function TFastI2C.ReadBlockData(const ACommand: Byte; const ABuffer: Pointer;
  const ABufferSize: Cardinal): Cardinal;
var
  LControlPtr, LStatusPtr, LDataBufferPtr: Pointer;
  LBlockTimeoutStart: TTickCounter;
  LBlockCounter: Integer;
  LBytesRead: Cardinal;
begin
  LControlPtr := GetOffsetPointer(OffsetControl);
  LStatusPtr := GetOffsetPointer(OffsetStatus);
  LDataBufferPtr := GetOffsetPointer(OffsetDataBuffer);

  // Clear FIFO and status flags.
  ChangeBitsSafe(LControlPtr, MaskControlClearBuffers, MaskControlClearBuffers);
  WriteMemFast(LStatusPtr, MaskStatusTimeout or MaskStatusNoACK or MaskStatusDone);

  // Specify data length and write Acommand to FIFO Abuffer.
  WriteMemFast(GetOffsetPointer(OffsetDataLength), 1);
  WriteMemFast(LDataBufferPtr, ACommand);

  // Begin transfer and send "START" signal.
  WriteMemFast(LControlPtr, MaskControlEnabled or MaskControlStart);

  // Wait until the transfer has started (with timeout).
  LBlockTimeoutStart := FFastGPIO.SystemCore.GetTickCount;

  while ReadMemFast(LStatusPtr) and (MaskStatusTransfer or MaskStatusDone) = 0 do
    if FFastGPIO.SystemCore.TicksInBetween(LBlockTimeoutStart,
      FFastGPIO.SystemCore.GetTickCount) > TransferTimeout then
      Exit(0);

  // Specify data length for reading and send "REPEATED START" signal.
  WriteMemFast(GetOffsetPointer(OffsetDataLength), ABufferSize);
  WriteMemFast(LControlPtr, MaskControlEnabled or MaskControlStart or MaskControlRead);

  // Wait until the Acommand is sent and one byte is received.
  FFastGPIO.SystemCore.MicroDelay(FTimePerByte * 2 * SizeOf(Byte));

  // Receive bytes.
  LBytesRead := 0;
  LBlockCounter := -1;

  while ReadMemFast(LStatusPtr) and MaskStatusDone = 0 do
  begin
    while (ReadMemFast(LStatusPtr) and MaskStatusRXD > 0) and (LBytesRead < ABufferSize) do
    begin
      PByte(PtrUInt(ABuffer) + Cardinal(LBytesRead))^ := ReadMemFast(LDataBufferPtr);
      Inc(LBytesRead);
      LBlockCounter := -1;
    end;

    if not ProcessBlockCounter(LBlockCounter, LBlockTimeoutStart) then
      Exit(0);
  end;

  // Retrieve any remaining bytes from FIFO Abuffer.
  while (ReadMemFast(LStatusPtr) and MaskStatusRXD > 0) and (LBytesRead < ABufferSize) do
  begin
    PByte(PtrUInt(ABuffer) + Cardinal(LBytesRead))^ := ReadMemFast(LDataBufferPtr);
    Inc(LBytesRead);
  end;

  Result := LBytesRead;

  // Check status flags for any issues during read.
  if ReadMemSafe(LStatusPtr) and (MaskStatusNoACK or MaskStatusTimeout) > 0 then
    Result := 0;
end;

function TFastI2C.WriteBlockData(const ACommand: Byte; const ABuffer: Pointer;
  const ABufferSize: Cardinal): Cardinal;
var
  LControlPtr, LStatusPtr, LDataBufferPtr: Pointer;
  LBlockTimeoutStart: TTickCounter;
  LBytesWritten: Cardinal;
  LBlockCounter: Integer;
begin
  LControlPtr := GetOffsetPointer(OffsetControl);
  LStatusPtr := GetOffsetPointer(OffsetStatus);
  LDataBufferPtr := GetOffsetPointer(OffsetDataBuffer);

  // Clear FIFO and status flags.
  ChangeBitsSafe(LControlPtr, MaskControlClearBuffers, MaskControlClearBuffers);
  WriteMemFast(LStatusPtr, MaskStatusTimeout or MaskStatusNoACK or MaskStatusDone);

  // Specify data Abuffer size.
  WriteMemFast(GetOffsetPointer(OffsetDataLength), ABufferSize + 1);

  // Fill FIFO buffers with the actual Acommand and as much data as possible before starting transfer.
  WriteMemFast(LDataBufferPtr, ACommand);
  LBytesWritten := 0;

  while (LBytesWritten < ABufferSize) and (LBytesWritten < MaxInternalBufferSize - 1) do
  begin
    WriteMemFast(LDataBufferPtr, PByte(PtrUInt(ABuffer) + Cardinal(LBytesWritten))^);
    Inc(LBytesWritten);
  end;

  // Begin transfer and send "START" signal.
  WriteMemFast(LControlPtr, MaskControlEnabled or MaskControlStart);

  // Send bytes.
  LBlockCounter := -1;

  while ReadMemFast(LStatusPtr) and MaskStatusDone = 0 do
  begin
    while (ReadMemFast(LStatusPtr) and MaskStatusTXD > 0) and (LBytesWritten < ABufferSize) do
    begin
      WriteMemFast(LDataBufferPtr, PByte(PtrUInt(ABuffer) + Cardinal(LBytesWritten))^);
      Inc(LBytesWritten);
      LBlockCounter := -1;
    end;

    if not ProcessBlockCounter(LBlockCounter, LBlockTimeoutStart) then
      Exit(0);
  end;

  Result := LBytesWritten;

  // Check status flags for any issues during write.
  if ReadMemSafe(LStatusPtr) and (MaskStatusNoACK or MaskStatusTimeout) > 0 then
    Result := 0;
end;

{$ENDREGION}
{$REGION 'TDefaultUART'}

constructor TDefaultUART.Create(const AFastGPIO: TFastGPIO; const ASystemPath: StdString);
var
  LSystemCore: TCustomSystemCore;
begin
  FFastGPIO := AFastGPIO;
  if (FFastGPIO <> nil) and (ASystemPath = DefaultSystemPath) then
  begin
    FFastGPIO.SetPinModeBCM(14, TPinModeEx.Alt0); // UART0_TXD
    FFastGPIO.SetPinModeBCM(15, TPinModeEx.Alt0); // UART0_RXD
  end;

  if FFastGPIO <> nil then
    LSystemCore := FFastGPIO.SystemCore
  else
    LSystemCore := nil;

  inherited Create(LSystemCore, ASystemPath);
end;

destructor TDefaultUART.Destroy;
begin
{$IFDEF DATAPORTS_PINS_RESET_AFTER_DONE}
  if (FFastGPIO <> nil) and (SystemPath = DefaultSystemPath) then
  begin
    FFastGPIO.SetPinModeBCM(15, TPinModeEx.Input);
    FFastGPIO.SetPinModeBCM(14, TPinModeEx.Input);
  end;
{$ENDIF}

  inherited;
end;

{$ENDREGION}

end.

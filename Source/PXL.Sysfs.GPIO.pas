unit PXL.Sysfs.GPIO;
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
  PXL.TypeDef, PXL.Sysfs.Types, PXL.Boards.Types;

type
  // Drive mode that is used in GPIO pins.
  TPinDriveEx = (
    // Strong low and high.
    Strong,

    // Resistive high, strong low.
    PullUp,

    // Resistive low, strong high.
    PullDown,

    // High Z state
    HighZ);

  TSysfsGPIO = class(TCustomGPIO)
  public const
    DefaultSystemPath = '/sys/class/gpio';
  protected const
    MaximumSupportedPins = 256;

    ExportedBitmask = $80;
    DirectionDefinedBitmask = $40;
    DirectionBitmask = $20;
    DriveBitmask = $18;
    ValueDefinedBitmask = $02;
    ValueBitmask = $01;
  private
    FSystemPath: StdString;
    FExportFileName: StdString;
    FUnexportFileName: StdString;
    FAccessFileName: StdString;

    FPins: packed array[0..MaximumSupportedPins - 1] of Byte;

    procedure SetPinBit(const APin: TPinIdentifier; const AMask: Cardinal); inline;
    procedure ClearPinBit(const APin: TPinIdentifier; const AMask: Cardinal); inline;
    function IsPinBitSet(const APin: TPinIdentifier; const AMask: Cardinal): Boolean; inline;

    function IsPinExported(const APin: TPinIdentifier): Boolean; inline;
    function HasPinDirection(const APin: TPinIdentifier): Boolean; inline;
    function HasPinValue(const APin: TPinIdentifier): Boolean; inline;

    procedure ExportPin(const APin: TPinIdentifier);
    procedure UnexportPin(const APin: TPinIdentifier);
    procedure UnexportAllPins;

    function GetPinDriveEx(const APin: TPinIdentifier): TPinDriveEx;
    procedure SetPinDriveEx(const APin: TPinIdentifier; const AValue: TPinDriveEx);
  protected
    function GetPinMode(const APin: TPinIdentifier): TPinMode; override;
    procedure SetPinMode(const APin: TPinIdentifier; const AMode: TPinMode); override;

    function GetPinValue(const APin: TPinIdentifier): TPinValue; override;
    procedure SetPinValue(const APin: TPinIdentifier; const AValue: TPinValue); override;

    function GetPinDrive(const APin: TPinIdentifier): TPinDrive; override;
    procedure SetPinDrive(const APin: TPinIdentifier; const AValue: TPinDrive); override;
  public
    constructor Create(const ASystemPath: StdString = DefaultSystemPath);
    destructor Destroy; override;

    function TrySetPinMode(const APin: TPinIdentifier; const AMode: TPinMode): Boolean;

    property PinDrive[const APin: TPinIdentifier]: TPinDriveEx read GetPinDriveEx write SetPinDriveEx;
  end;

  EGPIOGeneric = class(ESysfsGeneric);
  EGPIOInvalidPin = class(EGPIOGeneric);
  EGPIOUndefinedPin = class(EGPIOGeneric);
  EGPIOIncorrectPinDirection = class(EGPIOGeneric);

resourcestring
  SGPIOSpecifiedPinInvalid = 'The specified GPIO pin <%d> is invalid.';
  SGPIOSpecifiedPinUndefined = 'The specified GPIO pin <%d> is undefined.';
  SGPIOPinHasIncorrectDirection = 'The specified GPIO pin <%d> has incorrect direction.';

implementation

uses
  SysUtils;

constructor TSysfsGPIO.Create(const ASystemPath: StdString);
begin
  inherited Create;

  FSystemPath := ASystemPath;
  FExportFileName := FSystemPath + '/export';
  FUnexportFileName := FSystemPath + '/unexport';
  FAccessFileName := FSystemPath + '/gpio';
end;

destructor TSysfsGPIO.Destroy;
begin
  UnexportAllPins;

  inherited;
end;

procedure TSysfsGPIO.SetPinBit(const APin: TPinIdentifier; const AMask: Cardinal);
begin
  FPins[APin] := FPins[APin] or AMask;
end;

procedure TSysfsGPIO.ClearPinBit(const APin: TPinIdentifier; const AMask: Cardinal);
begin
  FPins[APin] := FPins[APin] and ($FF xor AMask);
end;

function TSysfsGPIO.IsPinBitSet(const APin: TPinIdentifier; const AMask: Cardinal): Boolean;
begin
  Result := FPins[APin] and AMask > 0;
end;

function TSysfsGPIO.IsPinExported(const APin: TPinIdentifier): Boolean;
begin
  Result := IsPinBitSet(APin, ExportedBitmask);
end;

function TSysfsGPIO.HasPinDirection(const APin: TPinIdentifier): Boolean;
begin
  Result := IsPinBitSet(APin, DirectionDefinedBitmask);
end;

function TSysfsGPIO.HasPinValue(const APin: TPinIdentifier): Boolean;
begin
  Result := IsPinBitSet(APin, ValueDefinedBitmask);
end;

procedure TSysfsGPIO.ExportPin(const APin: TPinIdentifier);
begin
  TryWriteTextToFile(FExportFileName, IntToStr(APin));
  SetPinBit(APin, ExportedBitmask);
end;

procedure TSysfsGPIO.UnexportPin(const APin: TPinIdentifier);
begin
  TryWriteTextToFile(FUnexportFileName, IntToStr(APin));
  ClearPinBit(APin, ExportedBitmask);
end;

procedure TSysfsGPIO.UnexportAllPins;
var
  I: Integer;
begin
  for I := Low(FPins) to High(FPins) do
    if IsPinExported(I) then
      UnexportPin(I);
end;

function TSysfsGPIO.GetPinMode(const APin: TPinIdentifier): TPinMode;
begin
  if APin > MaximumSupportedPins then
    raise EGPIOInvalidPin.Create(Format(SGPIOSpecifiedPinInvalid, [APin]));

  if (not IsPinExported(APin)) or (not HasPinDirection(APin)) then
    raise EGPIOUndefinedPin.Create(Format(SGPIOSpecifiedPinUndefined, [APin]));

  if IsPinBitSet(APin, DirectionBitmask) then
    Result := TPinMode.Output
  else
    Result := TPinMode.Input;
end;

procedure TSysfsGPIO.SetPinMode(const APin: TPinIdentifier; const AMode: TPinMode);
begin
  if APin > MaximumSupportedPins then
    raise EGPIOInvalidPin.Create(Format(SGPIOSpecifiedPinInvalid, [APin]));

  if not IsPinExported(APin) then
    ExportPin(APin);

  if AMode = TPinMode.Input then
  begin
    WriteTextToFile(FAccessFileName + IntToStr(APin) + '/direction', 'in');
    ClearPinBit(APin, DirectionBitmask);
  end
  else
  begin
    WriteTextToFile(FAccessFileName + IntToStr(APin) + '/direction', 'out');
    SetPinBit(APin, DirectionBitmask);
  end;

  SetPinBit(APin, DirectionDefinedBitmask);
end;

function TSysfsGPIO.TrySetPinMode(const APin: TPinIdentifier; const AMode: TPinMode): Boolean;
begin
  if APin > MaximumSupportedPins then
    Exit(False);

  if not IsPinExported(APin) then
    ExportPin(APin);

  if AMode = TPinMode.Input then
  begin
    Result := TryWriteTextToFile(FAccessFileName + IntToStr(APin) + '/direction', 'in');
    ClearPinBit(APin, DirectionBitmask);
  end
  else
  begin
    Result := TryWriteTextToFile(FAccessFileName + IntToStr(APin) + '/direction', 'out');
    SetPinBit(APin, DirectionBitmask);
  end;

  SetPinBit(APin, DirectionDefinedBitmask);
end;

function TSysfsGPIO.GetPinValue(const APin: TPinIdentifier): TPinValue;
begin
  if APin > MaximumSupportedPins then
    raise EGPIOInvalidPin.Create(Format(SGPIOSpecifiedPinInvalid, [APin]));

  if (not IsPinExported(APin)) or (not HasPinDirection(APin)) then
    raise EGPIOUndefinedPin.Create(Format(SGPIOSpecifiedPinUndefined, [APin]));

  if IsPinBitSet(APin, DirectionBitmask) and HasPinValue(APin) then
  begin // APin with direction set to OUTPUT and VALUE defined can be retrieved directly.
    if IsPinBitSet(APin, ValueBitmask) then
      Result := TPinValue.High
    else
      Result := TPinValue.Low;
  end
  else
  begin // APin needs to be read from GPIO.
    if ReadCharFromFile(FAccessFileName + IntToStr(APin) + '/value') = '1' then
      Result := TPinValue.High
    else
      Result := TPinValue.Low;
  end;
end;

procedure TSysfsGPIO.SetPinValue(const APin: TPinIdentifier; const AValue: TPinValue);
var
  LValue: TPinValue;
begin
  if APin > MaximumSupportedPins then
    raise EGPIOInvalidPin.Create(Format(SGPIOSpecifiedPinInvalid, [APin]));

  if (not IsPinExported(APin)) or (not HasPinDirection(APin)) then
    raise EGPIOUndefinedPin.Create(Format(SGPIOSpecifiedPinUndefined, [APin]));

  if not IsPinBitSet(APin, DirectionBitmask) then
    raise EGPIOIncorrectPinDirection.Create(Format(SGPIOPinHasIncorrectDirection, [APin]));

  if HasPinValue(APin) then
  begin
    if IsPinBitSet(APin, ValueBitmask) then
      LValue := TPinValue.High
    else
      LValue := TPinValue.Low;

    // Do not write Avalue to the Apin if it is already set.
    if LValue = AValue then
      Exit;
  end;

  if AValue = TPinValue.Low then
  begin
    WriteTextToFile(FAccessFileName + IntToStr(APin) + '/Avalue', '0');
    ClearPinBit(APin, ValueBitmask);
  end
  else
  begin
    WriteTextToFile(FAccessFileName + IntToStr(APin) + '/Avalue', '1');
    SetPinBit(APin, ValueBitmask);
  end;
end;

function TSysfsGPIO.GetPinDriveEx(const APin: TPinIdentifier): TPinDriveEx;
begin
  if APin > MaximumSupportedPins then
    raise EGPIOInvalidPin.Create(Format(SGPIOSpecifiedPinInvalid, [APin]));

  if (not IsPinExported(APin)) or (not HasPinDirection(APin)) then
    raise EGPIOUndefinedPin.Create(Format(SGPIOSpecifiedPinUndefined, [APin]));

  Result := TPinDriveEx((FPins[APin] and DriveBitmask) shr 3);
end;

procedure TSysfsGPIO.SetPinDriveEx(const APin: TPinIdentifier; const AValue: TPinDriveEx);
var
  LDriveText: StdString;
begin
  if APin > MaximumSupportedPins then
    raise EGPIOInvalidPin.Create(Format(SGPIOSpecifiedPinInvalid, [APin]));

  if (not IsPinExported(APin)) or (not HasPinDirection(APin)) then
    raise EGPIOUndefinedPin.Create(Format(SGPIOSpecifiedPinUndefined, [APin]));

  if IsPinBitSet(APin, DirectionBitmask) then
    raise EGPIOIncorrectPinDirection.Create(Format(SGPIOPinHasIncorrectDirection, [APin]));

  case AValue of
    TPinDriveEx.PullUp:
      LDriveText := 'pullup';

    TPinDriveEx.PullDown:
      LDriveText := 'pulldown';

    TPinDriveEx.HighZ:
      LDriveText := 'hiz';
  else
    LDriveText := 'strong';
  end;

  WriteTextToFile(FAccessFileName + IntToStr(APin) + '/drive', LDriveText);

  ClearPinBit(APin, DriveBitmask);
  SetPinBit(APin, (Ord(AValue) and $03) shl 3);
end;

function TSysfsGPIO.GetPinDrive(const APin: TPinIdentifier): TPinDrive;
begin
  Result := TPinDrive(GetPinDriveEx(APin));
end;

procedure TSysfsGPIO.SetPinDrive(const APin: TPinIdentifier; const AValue: TPinDrive);
begin
  SetPinDriveEx(APin, TPinDriveEx(AValue));
end;

end.


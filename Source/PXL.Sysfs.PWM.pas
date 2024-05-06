unit PXL.Sysfs.PWM;
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
  TSysfsPWM = class(TCustomPWM)
  private const
    MaximumSupportedChannels = 64;

    ExportedBitmask = $80;
    EnabledDefinedBitmask = $40;
    EnabledBitmask = $20;
    PeriodDefinedBitmask = $10;
    DutyCycleDefinedBitmask = $08;
  private
    FSystemPath: StdString;
    FExportFileName: StdString;
    FUnexportFileName: StdString;
    FAccessFileName: StdString;

    FChannels: array[0..MaximumSupportedChannels - 1] of Byte;
    FPeriods: array[0..MaximumSupportedChannels - 1] of Integer;
    FDutyCycles: array[0..MaximumSupportedChannels - 1] of Integer;

    procedure SetChannelBit(const AChannel: TPinChannel; const AMask: Cardinal); inline;
    procedure ClearChannelBit(const AChannel: TPinChannel; const AMask: Cardinal); inline;
    function IsChannelBitSet(const AChannel: TPinChannel; const AMask: Cardinal): Boolean; inline;
    function IsChannelExported(const AChannel: TPinChannel): Boolean; inline;
    function HasChannelAbility(const AChannel: TPinChannel): Boolean; inline;

    procedure ExportChannel(const AChannel: TPinChannel);
    procedure UnexportChannel(const AChannel: TPinChannel);
    procedure UnexportAllChannels;
  protected
    function GetEnabled(const AChannel: TPinChannel): Boolean; override;
    procedure SetEnabled(const AChannel: TPinChannel; const AValue: Boolean); override;
    function GetPeriod(const AChannel: TPinChannel): Cardinal; override;
    procedure SetPeriod(const AChannel: TPinChannel; const AValue: Cardinal); override;
    function GetDutyCycle(const AChannel: TPinChannel): Cardinal; override;
    procedure SetDutyCycle(const AChannel: TPinChannel; const AValue: Cardinal); override;
  public
    constructor Create(const ASystemPath: StdString);
    destructor Destroy; override;
  end;

  EPWMGeneric = class(ESysfsGeneric);
  EPWMInvalidChannel = class(EPWMGeneric);
  EPWMUndefinedChannel = class(EPWMGeneric);

resourcestring
  SPWMSpecifiedChannelInvalid = 'The specified PWM channel <%d> is invalid.';
  SPWMSpecifiedChannelUndefined = 'The specified PWM channel <%d> is undefined.';

implementation

uses
  SysUtils;

constructor TSysfsPWM.Create(const ASystemPath: StdString);
begin
  inherited Create;

  FSystemPath := ASystemPath;
  FExportFileName := FSystemPath + '/export';
  FUnexportFileName := FSystemPath + '/unexport';
  FAccessFileName := FSystemPath + '/pwm';
end;

destructor TSysfsPWM.Destroy;
begin
  UnexportAllChannels;

  inherited;
end;

procedure TSysfsPWM.SetChannelBit(const AChannel: TPinChannel; const AMask: Cardinal);
begin
  FChannels[AChannel] := FChannels[AChannel] or AMask;
end;

procedure TSysfsPWM.ClearChannelBit(const AChannel: TPinChannel; const AMask: Cardinal);
begin
  FChannels[AChannel] := FChannels[AChannel] and ($FF xor AMask);
end;

function TSysfsPWM.IsChannelBitSet(const AChannel: TPinChannel; const AMask: Cardinal): Boolean;
begin
  Result := FChannels[AChannel] and AMask > 0;
end;

function TSysfsPWM.IsChannelExported(const AChannel: TPinChannel): Boolean;
begin
  Result := IsChannelBitSet(AChannel, ExportedBitmask);
end;

function TSysfsPWM.HasChannelAbility(const AChannel: TPinChannel): Boolean;
begin
  Result := IsChannelBitSet(AChannel, EnabledDefinedBitmask);
end;

procedure TSysfsPWM.ExportChannel(const AChannel: TPinChannel);
begin
  TryWriteTextToFile(FExportFileName, IntToStr(AChannel));
  SetChannelBit(AChannel, ExportedBitmask);
end;

procedure TSysfsPWM.UnexportChannel(const AChannel: TPinChannel);
begin
  TryWriteTextToFile(FUnexportFileName, IntToStr(AChannel));
  ClearChannelBit(AChannel, ExportedBitmask);
end;

procedure TSysfsPWM.UnexportAllChannels;
var
  I: Integer;
begin
  for I := Low(FChannels) to High(FChannels) do
    if IsChannelExported(I) then
      UnexportChannel(I);
end;

function TSysfsPWM.GetEnabled(const AChannel: TPinChannel): Boolean;
begin
  if AChannel > MaximumSupportedChannels then
    raise EPWMInvalidChannel.Create(Format(SPWMSpecifiedChannelInvalid, [AChannel]));

  if (not IsChannelExported(AChannel)) or (not HasChannelAbility(AChannel)) then
    raise EPWMUndefinedChannel.Create(Format(SPWMSpecifiedChannelUndefined, [AChannel]));

  Result := IsChannelBitSet(AChannel, EnabledBitmask);
end;

procedure TSysfsPWM.SetEnabled(const AChannel: TPinChannel; const AValue: Boolean);
var
  LNeedModify: Boolean;
begin
  if AChannel > MaximumSupportedChannels then
    raise EPWMInvalidChannel.Create(Format(SPWMSpecifiedChannelInvalid, [AChannel]));

  if not IsChannelExported(AChannel) then
    ExportChannel(AChannel);

  if IsChannelBitSet(AChannel, EnabledDefinedBitmask) then
    if IsChannelBitSet(AChannel, EnabledBitmask) then
      LNeedModify := not AValue
    else
      LNeedModify := AValue
  else
    LNeedModify := True;

  if LNeedModify then
  begin
    if AValue then
    begin
      WriteTextToFile(FAccessFileName + IntToStr(AChannel) + '/enable', '1');
      SetChannelBit(AChannel, EnabledBitmask);
    end
    else
    begin
      WriteTextToFile(FAccessFileName + IntToStr(AChannel) + '/enable', '0');
      ClearChannelBit(AChannel, EnabledBitmask);
    end;

    SetChannelBit(AChannel, EnabledDefinedBitmask);
  end;
end;

function TSysfsPWM.GetPeriod(const AChannel: TPinChannel): Cardinal;
begin
  if AChannel > MaximumSupportedChannels then
    raise EPWMInvalidChannel.Create(Format(SPWMSpecifiedChannelInvalid, [AChannel]));

  if (not IsChannelExported(AChannel)) or (not HasChannelAbility(AChannel)) or
    (not IsChannelBitSet(AChannel, PeriodDefinedBitmask)) then
    raise EPWMUndefinedChannel.Create(Format(SPWMSpecifiedChannelUndefined, [AChannel]));

  Result := FPeriods[AChannel];
end;

procedure TSysfsPWM.SetPeriod(const AChannel: TPinChannel; const AValue: Cardinal);
begin
  if AChannel > MaximumSupportedChannels then
    raise EPWMInvalidChannel.Create(Format(SPWMSpecifiedChannelInvalid, [AChannel]));

  if (not IsChannelExported(AChannel)) or (not HasChannelAbility(AChannel)) then
    raise EPWMUndefinedChannel.Create(Format(SPWMSpecifiedChannelUndefined, [AChannel]));

  WriteTextToFile(FAccessFileName + IntToStr(AChannel) + '/period', IntToStr(AValue));
  FPeriods[AChannel] := AValue;

  SetChannelBit(AChannel, PeriodDefinedBitmask);
end;

function TSysfsPWM.GetDutyCycle(const AChannel: TPinChannel): Cardinal;
begin
  if AChannel > MaximumSupportedChannels then
    raise EPWMInvalidChannel.Create(Format(SPWMSpecifiedChannelInvalid, [AChannel]));

  if (not IsChannelExported(AChannel)) or (not HasChannelAbility(AChannel)) or
    (not IsChannelBitSet(AChannel, DutyCycleDefinedBitmask)) then
    raise EPWMUndefinedChannel.Create(Format(SPWMSpecifiedChannelUndefined, [AChannel]));

  Result := FDutyCycles[AChannel];
end;

procedure TSysfsPWM.SetDutyCycle(const AChannel: TPinChannel; const AValue: Cardinal);
begin
  if AChannel > MaximumSupportedChannels then
    raise EPWMInvalidChannel.Create(Format(SPWMSpecifiedChannelInvalid, [AChannel]));

  if (not IsChannelExported(AChannel)) or (not HasChannelAbility(AChannel)) then
    raise EPWMUndefinedChannel.Create(Format(SPWMSpecifiedChannelUndefined, [AChannel]));

  WriteTextToFile(FAccessFileName + IntToStr(AChannel) + '/duty_cycle', IntToStr(AValue));
  FDutyCycles[AChannel] := AValue;

  SetChannelBit(AChannel, DutyCycleDefinedBitmask);
end;

end.


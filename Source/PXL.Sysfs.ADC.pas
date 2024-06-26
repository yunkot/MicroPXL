unit PXL.Sysfs.ADC;
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
  TSysfsADC = class(TCustomADC)
  private const
    MaximumSupportedChannels = 64;
  private
    FSystemPath: StdString;
  protected
    function GetRawValue(const AChannel: TPinChannel): Cardinal; override;
  public
    constructor Create(const ASystemPath: StdString);
  end;

  EADCGeneric = class(ESysfsGeneric);
  EADCInvalidChannel = class(EADCGeneric);

resourcestring
  SADCSpecifiedChannelInvalid = 'The specified ADC channel <%d> is invalid.';

implementation

uses
  SysUtils;

constructor TSysfsADC.Create(const ASystemPath: StdString);
begin
  inherited Create;

  FSystemPath := ASystemPath;
end;

function TSysfsADC.GetRawValue(const AChannel: TPinChannel): Cardinal;
begin
  if AChannel > MaximumSupportedChannels then
    raise EADCInvalidChannel.Create(Format(SADCSpecifiedChannelInvalid, [AChannel]));

  Result := StrToInt(Trim(ReadTextFromFile(FSystemPath + '/in_voltage' + IntToStr(AChannel) + '_raw')));
end;

end.


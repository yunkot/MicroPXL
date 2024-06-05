unit PXL.DirectInput.Types;
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
{ < Utility functions to access shared DirectInput interface. }
interface

uses
  DirectInput, SysUtils;

type
  EDirectInput = class(Exception);

  TDirectInputTypes = record
  private class var
    FDirectInput: IDirectInput8;
    FDirectInputInstances: Integer;
  public
    // Initializes global DirectInput-related variables.
    class constructor Initialize;

    // Releases global DirectInput-related interfaces.
    class destructor Finalize;

    // Acquires access to a shared DirectInput interface.
    class procedure AcquireDirectInput; static;

    // Releases access to a shared DirectInput interface.
    class procedure ReleaseDirectInput; static;

  public class
    // Shared DirectInput interface.
    property DirectInput: IDirectInput8 read FDirectInput;
  end;

  // Generic DirectInput-based device.
  TDirectInputDevice = class abstract
  public
    // Initializes the component and prepares DirectInput interface. @link(WindowHandle) must be properly set
    // before for this call to succeed.
    procedure Initialize; virtual; abstract;

    // Finalizes the component releasing DirectInput interface.
    procedure Finalize; virtual; abstract;

    // Updates the state of the device. Returns @True if the state has actually been updated.
    function Update: Boolean; virtual; abstract;
  end;

resourcestring
  SCouldNotCreateDirectInput = 'Could not create DirectInput 8 interface';

implementation

uses
  Windows;

class constructor TDirectInputTypes.Initialize;
begin
  FDirectInput := nil;
  FDirectInputInstances := 0;
end;

class destructor TDirectInputTypes.Finalize;
begin
  FDirectInput := nil;
end;

class procedure TDirectInputTypes.AcquireDirectInput;
begin
  if FDirectInputInstances <= 0 then
  begin
    if not Succeeded(DirectInput8Create(HInstance, DIRECTINPUT_VERSION, IID_IDirectInput8, FDirectInput,
      nil)) then
      raise EDirectInput.Create(SCouldNotCreateDirectInput);
  end;

  Inc(FDirectInputInstances);
end;

class procedure TDirectInputTypes.ReleaseDirectInput;
begin
  Dec(FDirectInputInstances);

  if FDirectInputInstances <= 0 then
    FDirectInput := nil;
end;

end.

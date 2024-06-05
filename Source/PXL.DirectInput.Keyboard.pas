unit PXL.DirectInput.Keyboard;
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
{< Asynchronous keyboard input implementation using DirectInput 8. }
interface

uses
  DirectInput, SysUtils, PXL.DirectInput.Types;

type
  EDirectInputKeyboard = class(EDirectInput);

  // Keyboard input class that uses DirectInput 8 for retrieving the state of keyboard buttons asynchronously.
  TDirectInputKeyboard = class(TDirectInputDevice)
  private type
    { @exclude }
    TDIKeyBuf = array[0..255] of Byte;
  private
    FInputDevice: IDirectInputDevice8;
    FBackground: Boolean;
    FInitialized: Boolean;

    FWindowHandle: THandle;

    FBuffer: TDIKeyBuf;
    FBufferPrev: TDIKeyBuf;

    function GetKey(const AScanCode: Integer): Boolean;
    function GetKeyName(const AScanCode: Integer): string;
    function GetKeyPressed(const AScanCode: Integer): Boolean;
    function GetKeyReleased(const AScanCode: Integer): Boolean;

    function ConvertVirtualKey(const AVirtualCode: Cardinal): Integer;

    function GetVKey(const AVirtualCode: Cardinal): Boolean;
    function GetVKeyName(const AVirtualCode: Cardinal): string;
    function GetVKeyPressed(const AVirtualCode: Cardinal): Boolean;
    function GetVKeyReleased(const AVirtualCode: Cardinal): Boolean;
  public
    { @exclude } destructor Destroy; override;

    // Initializes the component and prepares DirectInput interface. @link(WindowHandle) must be properly set
    // before for this call to succeed.
    procedure Initialize; override;

    // Finalizes the component releasing DirectInput interface.
    procedure Finalize; override;

    // Updates the state of keyboard keys.
    function Update: Boolean; override;

    // DirectInput keyboard device.
    property InputDevice: IDirectInputDevice8 read FInputDevice;

    // Indicates whether DirectInput keyboard has been intiialized and is ready to be used.
    property Initialized: Boolean read FInitialized;

    // Determines whether the input should still be available when application is minimized or not focused.
    property Background: Boolean read FBackground write FBackground;

    // The handle of the application's main window. This should be properly set before initializing the
    // component as it will not work otherwise.
    property WindowHandle: THandle read FWindowHandle write FWindowHandle;

    // Returns the status of a single keyboard key. @code(AScanCode) is the internal key number as defined in
    // DirectInput. These constants are usually named as @code(DIK_[KeyName]). Search for Microsoft article
    // called "Keyboard Device Enumeration" for more information.
    property Key[const AScanCode: Integer]: Boolean read GetKey;

    // Returns the name of the given key as it is described by underlying OS.
    // @code(AScanCode) is the internal key number as with @link(Key) property.
    property KeyName[const AScanCode: Integer]: string read GetKeyName;

    // Indicates whether the key has been pressed after two consequent calls to @link(Update).
    // @code(AScanCode) is the internal key number as with @link(Key) property.
    property KeyPressed[const AScanCode: Integer]: Boolean read GetKeyPressed;

    // Indicates whether the key has been released after two consequent calls to @link(Update).
    // @code(AScanCode) is the internal key number as with @link(Key) property.
    property KeyReleased[const AScanCode: Integer]: Boolean read GetKeyReleased;

    // Returns the status of a single keyboard key. @code(VCode) is the virtual key code usually defined by
    // VK_[KeyName] constants.
    property VKey[const AVirtualCode: Cardinal]: Boolean read GetVKey;

    // Returns the name of the given key as it is described by underlying OS.
    // @code(VCode) is the virtual key code.
    property VKeyName[const AVirtualCode: Cardinal]: string read GetVKeyName;

    // Indicates whether the key has been pressed after two consequent calls to @link(Update). @code(VCode)
    // is the virtual key code.
    property VKeyPressed[const AVirtualCode: Cardinal]: Boolean read GetVKeyPressed;

    // Indicates whether the key has been released after two consequent calls to @link(Update).
    // @code(VCode) is the virtual key code.
    property VKeyReleased[const AVirtualCode: Cardinal]: Boolean read GetVKeyReleased;
  end;

resourcestring
  SWindowHandleRequiredForDIKeyboard = 'Window handle needs to be set for DirectInput keyboard interface';
  SCouldNotCreateDirectInputKeyboard = 'Could not create DirectInput keyboard interface';
  SCouldNotSetDIKeyboardDataFormat = 'Could not set DirectInput keyboard data format';
  SCouldNotSetDIKeyboardCooperativeLevel = 'Could not set DirectInput keyboard cooperative level';
  SCouldNotGetDIKeyboardState = 'Could not retrieve DirectInput keyboard state';
  SDIKeyboardNotInitialized = 'DirectInput keyboard is not initialized';

implementation

uses
  Windows;

destructor TDirectInputKeyboard.Destroy;
begin
  Finalize;
  inherited;
end;

procedure TDirectInputKeyboard.Initialize;
var
  LFlags: Cardinal;
begin
  if FInitialized then
    Exit; // Already initialized.

  if FWindowHandle = 0 then
    raise EDirectInputKeyboard.Create(SWindowHandleRequiredForDIKeyboard);

  TDirectInputTypes.AcquireDirectInput;
  try
    if not Succeeded(TDirectInputTypes.DirectInput.CreateDevice(GUID_SysKeyboard, FInputDevice, nil)) then
      raise EDirectInputKeyboard.Create(SCouldNotCreateDirectInputKeyboard);

    if not Succeeded(FInputDevice.SetDataFormat(c_dfDIKeyboard)) then
      raise EDirectInputKeyboard.Create(SCouldNotSetDIKeyboardDataFormat);

    LFlags := DISCL_NONEXCLUSIVE;

    if FBackground then
      LFlags := LFlags or DISCL_BACKGROUND
    else
      LFlags := LFlags or DISCL_FOREGROUND;

    if not Succeeded(FInputDevice.SetCooperativeLevel(FWindowHandle, LFlags)) then
      raise EDirectInputKeyboard.Create(SCouldNotSetDIKeyboardCooperativeLevel);
  except
    FInputDevice := nil;
    TDirectInputTypes.ReleaseDirectInput;
    raise;
  end;

  FillChar(FBuffer, SizeOf(TDIKeyBuf), 0);
  FillChar(FBufferPrev, SizeOf(TDIKeyBuf), 0);
  FInitialized := True;
end;

procedure TDirectInputKeyboard.Finalize;
begin
  if FInputDevice <> nil then
  begin
    FInputDevice.Unacquire;
    FInputDevice := nil;
  end;
  TDirectInputTypes.ReleaseDirectInput;
  FInitialized := False;
end;

function TDirectInputKeyboard.Update: Boolean;
var
  LRes: Integer;
begin
  if FInputDevice = nil then
    raise EDirectInputKeyboard.Create(SDIKeyboardNotInitialized);

  Move(FBuffer, FBufferPrev, SizeOf(TDIKeyBuf));

  LRes := FInputDevice.GetDeviceState(SizeOf(TDIKeyBuf), @FBuffer);
  if LRes <> DI_OK then
  begin
    if (LRes <> DIERR_INPUTLOST) and (LRes <> DIERR_NOTACQUIRED) then
      raise EDirectInputKeyboard.Create(SCouldNotGetDIKeyboardState);

    LRes := FInputDevice.Acquire;
    if LRes = DI_OK then
    begin
      LRes := FInputDevice.GetDeviceState(SizeOf(TDIKeyBuf), @FBuffer);
      if LRes <> DI_OK then
        raise EDirectInputKeyboard.Create(SCouldNotGetDIKeyboardState);
    end
    else
      Exit(False);
  end;
  Result := True;
end;

function TDirectInputKeyboard.GetKey(const AScanCode: Integer): Boolean;
begin
  Result := (FBuffer[AScanCode] and $80) = $80;
end;

function TDirectInputKeyboard.GetKeyName(const AScanCode: Integer): string;
var
  KeyName: array[0..255] of Char;
begin
  GetKeyNameText(AScanCode or $800000, @KeyName, 255);
  Result := string(KeyName);
end;

function TDirectInputKeyboard.GetKeyPressed(const AScanCode: Integer): Boolean;
begin
  Result := (FBufferPrev[AScanCode] and $80 <> $80) and (FBuffer[AScanCode] and $80 = $80);
end;

function TDirectInputKeyboard.GetKeyReleased(const AScanCode: Integer): Boolean;
begin
  Result := (FBufferPrev[AScanCode] and $80 = $80) and (FBuffer[AScanCode] and $80 <> $80);
end;

function TDirectInputKeyboard.ConvertVirtualKey(const AVirtualCode: Cardinal): Integer;
begin
  Result := MapVirtualKey(AVirtualCode, 0);
end;

function TDirectInputKeyboard.GetVKey(const AVirtualCode: Cardinal): Boolean;
begin
  Result := GetKey(ConvertVirtualKey(AVirtualCode));
end;

function TDirectInputKeyboard.GetVKeyName(const AVirtualCode: Cardinal): string;
begin
  Result := GetKeyName(ConvertVirtualKey(AVirtualCode));
end;

function TDirectInputKeyboard.GetVKeyPressed(const AVirtualCode: Cardinal): Boolean;
begin
  Result := GetKeyPressed(ConvertVirtualKey(AVirtualCode));
end;

function TDirectInputKeyboard.GetVKeyReleased(const AVirtualCode: Cardinal): Boolean;
begin
  Result := GetKeyReleased(ConvertVirtualKey(AVirtualCode));
end;

end.

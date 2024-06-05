unit PXL.DirectInput.Mouse;
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
{< Asynchronous mouse input implementation using DirectInput 8. }
interface

uses
  DirectInput, SysUtils, PXL.DirectInput.Types;

type
  EDirectInputMouse = class(EDirectInput);

  // Mouse input class that uses DirectInput 8 for retrieving the mouse state and its individual buttons.
  TDirectInputMouse = class(TDirectInputDevice)
  private
    FInitialized: Boolean;
    FExclusive: Boolean;
    FInputDevice: IDirectInputDevice8;
    FBackground: Boolean;
    FBufferSize: Integer;
    FDisplaceX: Integer;
    FDisplaceY: Integer;
    FMouseEvent: THandle;

    FWindowHandle: THandle;
    FButtonClick: array[0..7] of Integer;
    FButtonRelease: array[0..7] of Integer;
    FClearOnUpdate: Boolean;

    procedure ResetButtonStatus;
    function GetPressed(const AButton: Integer): Boolean;
    function GetReleased(const AButton: Integer): Boolean;
  public
    { @exclude } constructor Create;
    { @exclude } destructor Destroy; override;

    // Initializes the component and prepares DirectInput interface. @link(WindowHandle) must be properly set
    // before for this call to succeed.
    procedure Initialize; override;

    // Finalizes the component releasing DirectInput interface.
    procedure Finalize; override;

    // Updates the state of mouse buttons and calculates the displacement that occurred since the previous
    // call.
    function Update: Boolean; override;

    // DirectInput mouse device.
    property InputDevice: IDirectInputDevice8 read FInputDevice;

    // Indicates whether DirectInput mouse has been intiialized and is ready to be used.
    property Initialized: Boolean read FInitialized;

    // Determines whether the input should still be available when application is minimized or not focused.
    property Background: Boolean read FBackground write FBackground;

    // The handle of the application's main window. This should be properly set before initializing the
    // component as it will not work otherwise.
    property WindowHandle: THandle read FWindowHandle write FWindowHandle;

    // The size of mouse buffer that will store the events. It is recommended to leave this at its default
    // value unless @link(Update) is not called often enough; a larger buffer will accomodate more mouse
    // movement events.
    property BufferSize: Integer read FBufferSize write FBufferSize;

    // Determines whether the access to the mouse should be exclusive for this application.
    property Exclusive: Boolean read FExclusive write FExclusive;

    // Determines whether the status of mouse buttons should be cleared each time @link(Update) is called.
    property ClearOnUpdate: Boolean read FClearOnUpdate write FClearOnUpdate;

    // Horizontal mouse displacement computed since the previous call to @link(Update).
    property DisplaceX: Integer read FDisplaceX;

    // Vertical mouse displacement computed since the previous call to @link(Update).
    property DisplaceY: Integer read FDisplaceY;

    // Returns @True if the specified button has been pressed since the previous call to @link(Update).
    // If the button has not been pressed, the returned value is @False. The first button has index of zero.
    property Pressed[const AButton: Integer]: Boolean read GetPressed;

    // Returns @True if the specified button has been released since the previous call to @link(Update).
    // If the button has not been released, the returned value is @False. The first button has index of zero.
    property Released[const AButton: Integer]: Boolean read GetReleased;
  end;

resourcestring
  SWindowHandleRequiredForDIMouse = 'Window handle needs to be set for DirectInput mouse interface';
  SCouldNotCreateDirectInputMouse = 'Could not create DirectInput mouse interface';
  SCouldNotSetDIMouseDataFormat = 'Could not set DirectInput mouse data format';
  SCouldNotSetDIMouseCooperativeLevel = 'Could not set DirectInput mouse cooperative level';
  SCouldNotAllocateDIMouseEvent = 'Could not allocate DirectInput mouse event';
  SCouldNotSetDIMouseEventNotification = 'Could not assign DirectInput mouse event notification';
  SCouldNotSetDIMouseDeviceProperties = 'Could not set DirectInput mouse device properties';
  SDIMouseNotInitialized = 'DirectInput mouse is not initialized';
  SCouldNotGetDIMouseData = 'Could not retrieve DirectInput mouse data';

implementation

uses
  Windows;

constructor TDirectInputMouse.Create;
begin
  inherited;
  FBufferSize := 256;
  FExclusive := True;
end;

destructor TDirectInputMouse.Destroy;
begin
  Finalize;
  inherited;
end;

procedure TDirectInputMouse.ResetButtonStatus;
var
  I: Integer;
begin
  for I := 0 to 7 do
  begin
    FButtonClick[I] := 0;
    FButtonRelease[I] := 0;
  end;
end;

procedure TDirectInputMouse.Initialize;
var
  LFlags: Cardinal;
  LProp: TDIPropDWord;
begin
  if FInitialized then
    Exit; // Already initialized.

  if FWindowHandle = 0 then
    raise EDirectInputMouse.Create(SWindowHandleRequiredForDIMouse);

  TDirectInputTypes.AcquireDirectInput;
  try
    if not Succeeded(TDirectInputTypes.DirectInput.CreateDevice(GUID_SysMouse, FInputDevice, nil)) then
      raise EDirectInputMouse.Create(SCouldNotCreateDirectInputMouse);

    if not Succeeded(FInputDevice.SetDataFormat(c_dfDIMouse)) then
      raise EDirectInputMouse.Create(SCouldNotSetDIMouseDataFormat);

    LFlags := 0;

    if FBackground then
      LFlags := LFlags or DISCL_BACKGROUND
    else
      LFlags := LFlags or DISCL_FOREGROUND;

    if FExclusive then
      LFlags := LFlags or DISCL_EXCLUSIVE
    else
      LFlags := LFlags or DISCL_NONEXCLUSIVE;

    if not Succeeded(FInputDevice.SetCooperativeLevel(FWindowHandle, LFlags)) then
      raise EDirectInputMouse.Create(SCouldNotSetDIMouseCooperativeLevel);

    FMouseEvent := CreateEvent(nil, False, False, nil);
    if FMouseEvent = 0 then
      raise EDirectInputMouse.Create(SCouldNotAllocateDIMouseEvent);

    if not Succeeded(FInputDevice.SetEventNotification(FMouseEvent)) then
      raise EDirectInputMouse.Create(SCouldNotSetDIMouseEventNotification);

    FillChar(LProp, SizeOf(LProp), 0);
    with LProp do
    begin
      diph.dwSize := SizeOf(TDIPropDWord);
      diph.dwHeaderSize := SizeOf(TDIPropHeader);
      diph.dwObj := 0;
      diph.dwHow := DIPH_DEVICE;
      dwData := FBufferSize;
    end;

    if not Succeeded(FInputDevice.SetProperty(DIPROP_BUFFERSIZE, LProp.diph)) then
      raise EDirectInputMouse.Create(SCouldNotSetDIMouseDeviceProperties);
  except
    FInputDevice := nil;
    if FMouseEvent <> 0 then
    begin
      CloseHandle(FMouseEvent);
      FMouseEvent := 0;
    end;
    TDirectInputTypes.ReleaseDirectInput;
    raise;
  end;
  ResetButtonStatus;
  FInitialized := True;
end;

procedure TDirectInputMouse.Finalize;
begin
  if FInputDevice <> nil then
  begin
    FInputDevice.Unacquire;
    FInputDevice := nil;
  end;
  if FMouseEvent <> 0 then
  begin
    CloseHandle(FMouseEvent);
    FMouseEvent := 0;
  end;
  TDirectInputTypes.ReleaseDirectInput;
  FInitialized := False;
end;

function TDirectInputMouse.Update: Boolean;
var
  LRes: Integer;
  LObjData: TDIDeviceObjectData;
  LEventCount: Cardinal;
  LEventClick: Integer;
  LButtonIndex: Integer;
  LEventRelease: Integer;
begin
  if FInputDevice = nil then
    raise EDirectInputMouse.Create(SDIMouseNotInitialized);

  FDisplaceX := 0;
  FDisplaceY := 0;

  if FClearOnUpdate then
    ResetButtonStatus;

  repeat
    LEventCount := 1;

    LRes := FInputDevice.GetDeviceData(SizeOf(TDIDeviceObjectData), @LObjData, LEventCount, 0);
    if LRes <> DI_OK then
    begin
      if (LRes <> DIERR_INPUTLOST) and (LRes <> DIERR_NOTACQUIRED) then
        raise EDirectInputMouse.Create(SCouldNotGetDIMouseData);

      LRes := FInputDevice.Acquire;
      if LRes = DI_OK then
      begin
        LRes := FInputDevice.GetDeviceData(SizeOf(TDIDeviceObjectData), @LObjData, LEventCount, 0);
        if LRes <> DI_OK then
          raise EDirectInputMouse.Create(SCouldNotGetDIMouseData);
      end
      else
        Exit(False);
    end;

    if LEventCount < 1 then
      Break;

    case LObjData.dwOfs of
      DIMOFS_X:
        Inc(FDisplaceX, Integer(LObjData.dwData));

      DIMOFS_Y:
        Inc(FDisplaceY, Integer(LObjData.dwData));

      DIMOFS_BUTTON0 .. DIMOFS_BUTTON7:
        begin
          LEventClick := 0;
          LEventRelease := 1;

          if (LObjData.dwData and $80) = $80 then
          begin
            LEventClick := 1;
            LEventRelease := 0;
          end;

          LButtonIndex := LObjData.dwOfs - DIMOFS_BUTTON0;

          FButtonClick[LButtonIndex] := LEventClick;
          FButtonRelease[LButtonIndex] := LEventRelease;
        end;
    end;
  until (LEventCount < 1);
  Result := True;
end;

function TDirectInputMouse.GetPressed(const AButton: Integer): Boolean;
begin
  if (AButton >= 0) and (AButton < 8) then
    Result := FButtonClick[AButton] > 0
  else
    Result := False;
end;

function TDirectInputMouse.GetReleased(const AButton: Integer): Boolean;
begin
  if (AButton >= 0) and (AButton < 8) then
    Result := FButtonRelease[AButton] > 0
  else
    Result := False;
end;

end.

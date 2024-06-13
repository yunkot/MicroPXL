unit PXL.DirectInput.Joystick;
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
{< Joystick management implementation using DirectInput 8. }
interface

uses
  DirectInput, SysUtils, Messages, PXL.DirectInput.Types;

type
  EDirectInputJoystick = class(EDirectInput);

  // Joystick input class that uses DirectInput 8 for retrieving the state of the joystick, its axes buttons
  // and other parameters. This class is usually created inside @link(TDirectInputJoysticks) for every
  // joystick connected in the system.
  TDirectInputJoystick = class(TDirectInputDevice)
  private
    FInitialized: Boolean;
    FInputDevice: IDirectInputDevice8;
    FState: TDIJoyState2;
    FButtonCount: Integer;
    FAxisCount: Integer;
    FPOVCount: Integer;
    FDeviceCaps: TDIDevCaps;
    FBackground: Boolean;
  public
    { @exclude } destructor Destroy; override;

    // Initializes the component and prepares DirectInput interface.
    procedure Initialize(const AInstance: PDIDeviceInstance; const AWindowHandle: THandle); reintroduce;

    // Finalizes the component releasing DirectInput interface.
    procedure Finalize; override;

    // Updates the joystick state and refreshes values of @link(JoyState).
    function Update: Boolean; override;

    // DirectInput joystick device.
    property InputDevice: IDirectInputDevice8 read FInputDevice;

    // Indicates whether DirectInput joystick has been intiialized and is ready to be used.
    property Initialized: Boolean read FInitialized;

    // Provides access to the capabilities of the joystick device.
    property DeviceCaps: TDIDevCaps read FDeviceCaps;

    // The current state of joystick buttons, axes and sliders.
    property State: TDIJoyState2 read FState;

    // Indicates whether the joystick input is still available when the application is minimized or not
    // focused.
    property Background: Boolean read FBackground;

    // The number of buttons present in the joystick.
    property ButtonCount: Integer read FButtonCount;

    // The number of axes present in the joystick.
    property AxisCount: Integer read FAxisCount;

    // The number of point-of-views in the joystick.
    property POVCount: Integer read FPOVCount;
  end;

  // Collection of all available joystick interfaces.
  TDirectInputJoysticks = class(TDirectInputDevice)
  private
    FInitialized: Boolean;
    FWindowHandle: THandle;
    FBackground: Boolean;

    FJoysticks: TArray<TDirectInputJoystick>;
    FNotifyWindow: THandle;
    FDeviceNotify: Pointer;
    FDevicesChanged: Boolean;

    function GetCount: Integer; inline;
    function GetItem(const AIndex: Integer): TDirectInputJoystick; inline;
    procedure ReleaseJoysticks;
    procedure RecreateJoysticks;
    procedure DeviceNotify(var AMessage: TMessage);
  protected
    function AddJoystick: TDirectInputJoystick;
  public
    { @exclude } destructor Destroy; override;

    // Initializes the component and prepares DirectInput interface.
    procedure Initialize; override;

    // Finalizes the component releasing DirectInput interface.
    procedure Finalize; override;

    // Updates the status of all joysticks in the system.
    function Update: Boolean; override;

    // Indicates whether DirectInput joystick(s) have been intiialized and are ready to be used.
    property Initialized: Boolean read FInitialized;

    // The handle of the application's main window. This should be properly set before initializing the
    // component as it will not work otherwise.
    property WindowHandle: THandle read FWindowHandle write FWindowHandle;

    // Indicates whether the joystick input is still available when the application is minimized or not
    // focused.
    property Background: Boolean read FBackground write FBackground;

    // Number of joysticks connected in the system. If no joysticks are connected, this value will be zero.
    property Count: Integer read GetCount;

    // Provides access to individual joysticks connected in the system. @code(AIndex) can have values in
    // range of [0..Count - 1]. If the specified index is out of valid range, the returned value is @nil.
    property Items[const AIndex: Integer]: TDirectInputJoystick read GetItem; default;
  end;

resourcestring
  SWindowHandleRequiredForDIJoystick = 'Window handle needs to be set for DirectInput joystick interface';
  SCouldNotCreateDirectInputJoystick = 'Could not create DirectInput joystick interface';
  SCouldNotSetDIJoystickDataFormat = 'Could not set DirectInput joystick data format';
  SCouldNotSetDIJoystickCooperativeLevel = 'Could not set DirectInput joystick cooperative level';
  SCouldNotEnumerateDIJoystickAxes = 'Could not enumerate DirectInput joystick axes';
  SCouldNotRetrieveDIJoystickCapabilities = 'Could not retrieve DirectInput joystick capabilities';
  SFailedPollingDIJoystick = 'Failed polling DirectInput joystick device';
  SCouldNotReadDIJoystickState = 'Could not read DirectInput joystick state';
  SFailedEnumeratingDIJoysticks = 'Failed enumerating DirectInput joysticks';
  SCouldNotRegisterForDeviceNotification = 'Could not register to receive device notifications';

implementation

uses
  Windows, Classes;

type
  PUserReference = ^TUserReference;
  TUserReference = record
    Data: TObject;
    Success: Boolean;
  end;

  TDevBroadcastDeviceInterface = record
    dbcc_size: DWORD;
    dbcc_devicetype: DWORD;
    dbcc_reserved: DWORD;
    dbcc_classguid: TGUID;
    dbcc_name: PChar;
  end;

const
  DBT_DEVTYP_DEVICEINTERFACE = $00000005;
  DBT_DEVNODES_CHANGED = $0007;
  DBT_DEVICEARRIVAL = $8000;
  DBT_DEVICEREMOVECOMPLETE = $8004;
  DEVICE_NOTIFY_ALL_INTERFACE_CLASSES = $00000004;

function AxisEnumCallback(var AInstance: TDIDeviceObjectInstance; ARef: Pointer): Boolean; stdcall;
var
  LPropRange: TDIPropRange;
  LRes: Integer;
begin
  LPropRange.diph.dwSize := SizeOf(TDIPropRange);
  LPropRange.diph.dwHeaderSize := SizeOf(TDIPropHeader);
  LPropRange.diph.dwHow := DIPH_BYID;
  LPropRange.diph.dwObj := AInstance.dwType;

  LPropRange.lMin := Low(SmallInt); // [-32768..32767] range
  LPropRange.lMax := High(SmallInt);

  // DIPROP_RANGE actually reads the whole DIPROPRANGE structure, despite strange parameter passing below.
  LRes := TDirectInputJoystick(PUserReference(ARef).Data).InputDevice.SetProperty(DIPROP_RANGE,
    LPropRange.diph);

  if LRes <> DI_OK then
  begin
    Result := DIENUM_STOP;
    PUserReference(ARef).Success := False;
  end
  else
    Result := DIENUM_CONTINUE;
end;

function JoyEnumCallback(AInstance: PDIDeviceInstance; ARef: Pointer): Boolean; stdcall;
var
  LJoystick: TDirectInputJoystick;
begin
  LJoystick := TDirectInputJoysticks(PUserReference(ARef).Data).AddJoystick;

  try
    LJoystick.Initialize(AInstance, TDirectInputJoysticks(PUserReference(ARef).Data).WindowHandle);
    PUserReference(ARef).Success := True;
  except
    PUserReference(ARef).Success := False;
  end;

  if not PUserReference(ARef).Success then
    Result := DIENUM_STOP
  else
    Result := DIENUM_CONTINUE;
end;

destructor TDirectInputJoystick.Destroy;
begin
  Finalize;
  inherited;
end;

procedure TDirectInputJoystick.Initialize(const AInstance: PDIDeviceInstance; const AWindowHandle: THandle);
var
  LFlags: Cardinal;
  LRef: TUserReference;
begin
  if FInitialized then
    Exit; // Already initialized.

  if AWindowHandle = 0 then
    raise EDirectInputJoystick.Create(SWindowHandleRequiredForDIJoystick);

  if not Succeeded(TDirectInputTypes.DirectInput.CreateDevice(AInstance.guidInstance, FInputDevice,
    nil)) then
    raise EDirectInputJoystick.Create(SCouldNotCreateDirectInputJoystick);

  if not Succeeded(FInputDevice.SetDataFormat(c_dfDIJoystick2)) then
    raise EDirectInputJoystick.Create(SCouldNotSetDIJoystickDataFormat);

  LFlags := 0;

  if FBackground then
    LFlags := LFlags or DISCL_BACKGROUND or DISCL_NONEXCLUSIVE
  else
    LFlags := LFlags or DISCL_FOREGROUND or DISCL_EXCLUSIVE;

  if not Succeeded(FInputDevice.SetCooperativeLevel(AWindowHandle, LFlags)) then
    raise EDirectInputJoystick.Create(SCouldNotSetDIJoystickCooperativeLevel);

  LRef.Data := Self;
  LRef.Success := True;

  if (not Succeeded(FInputDevice.EnumObjects(@AxisEnumCallback, @LRef, DIDFT_AXIS))) or
    (not LRef.Success) then
    raise EDirectInputJoystick.Create(SCouldNotEnumerateDIJoystickAxes);

  FillChar(FDeviceCaps, SizeOf(TDIDevCaps), 0);
  FDeviceCaps.dwSize := SizeOf(TDIDevCaps);

  if not Succeeded(FInputDevice.GetCapabilities(FDeviceCaps)) then
    raise EDirectInputJoystick.Create(SCouldNotRetrieveDIJoystickCapabilities);

  FButtonCount := FDeviceCaps.dwButtons;
  FAxisCount := FDeviceCaps.dwAxes;
  FPOVCount := FDeviceCaps.dwPOVs;

  FInitialized := True;
end;

procedure TDirectInputJoystick.Finalize;
begin
  if FInputDevice <> nil then
  begin
    FInputDevice.Unacquire;
    FInputDevice := nil;
  end;
  FInitialized := False;
end;

function TDirectInputJoystick.Update: Boolean;
var
  LRes: Integer;
begin
  LRes := FInputDevice.Poll;

  if (LRes <> DI_OK) and (LRes <> DI_NOEFFECT) then
  begin
    if (LRes <> DIERR_INPUTLOST) and (LRes <> DIERR_NOTACQUIRED) then
      raise EDirectInputJoystick.Create(SFailedPollingDIJoystick);

    if not Succeeded(FInputDevice.Acquire) then
      Exit(False);

    LRes := FInputDevice.Poll;
    if (LRes <> DI_OK) and (LRes <> DI_NOEFFECT) then
      raise EDirectInputJoystick.Create(SFailedPollingDIJoystick);
  end;

  LRes := FInputDevice.GetDeviceState(SizeOf(TDIJoyState2), @FState);
  if LRes <> DI_OK then
  begin
    if (LRes <> DIERR_INPUTLOST) and (LRes <> DIERR_NOTACQUIRED) then
      raise EDirectInputJoystick.Create(SCouldNotReadDIJoystickState);

    if not Succeeded(FInputDevice.Acquire) then
      Exit(False);

    if not Succeeded(FInputDevice.GetDeviceState(SizeOf(TDIJoyState2), @FState)) then
      raise EDirectInputJoystick.Create(SCouldNotReadDIJoystickState);
  end;

  Result := True;
end;

destructor TDirectInputJoysticks.Destroy;
begin
  Finalize;
  inherited;
end;

function TDirectInputJoysticks.GetCount: Integer;
begin
  Result := Length(FJoysticks);
end;

function TDirectInputJoysticks.GetItem(const AIndex: Integer): TDirectInputJoystick;
begin
  if (AIndex >= 0) and (AIndex < Length(FJoysticks)) then
    Result := FJoysticks[AIndex]
  else
    Result := nil;
end;

procedure TDirectInputJoysticks.ReleaseJoysticks;
var
  I: Integer;
begin
  for I := Length(FJoysticks) - 1 downto 0 do
    FJoysticks[I].Free;

  SetLength(FJoysticks, 0);
end;

procedure TDirectInputJoysticks.RecreateJoysticks;
var
  LRef: TUserReference;
begin
  try
    LRef.Data := Self;
    LRef.Success := True;

    if (not Succeeded(TDirectInputTypes.DirectInput.EnumDevices(DI8DEVCLASS_GAMECTRL, @JoyEnumCallback,
      @LRef, DIEDFL_ATTACHEDONLY))) or (not LRef.Success) then
      raise EDirectInputJoystick.Create(SFailedEnumeratingDIJoysticks);
  except
    ReleaseJoysticks;
    raise;
  end;
end;

procedure TDirectInputJoysticks.DeviceNotify(var AMessage: TMessage);
begin
  if (AMessage.WParam = DBT_DEVNODES_CHANGED) or (AMessage.WParam = DBT_DEVICEARRIVAL) or
    (AMessage.WParam = DBT_DEVICEREMOVECOMPLETE) then
    FDevicesChanged := True;
end;

function TDirectInputJoysticks.AddJoystick: TDirectInputJoystick;
var
  LIndex: Integer;
begin
  LIndex := Length(FJoysticks);
  SetLength(FJoysticks, Length(FJoysticks) + 1);

  FJoysticks[LIndex] := TDirectInputJoystick.Create;
  FJoysticks[LIndex].FBackground := FBackground;
  Result := FJoysticks[LIndex];
end;

procedure TDirectInputJoysticks.Initialize;
var
  LFilter: TDevBroadcastDeviceInterface;
begin
  if FInitialized then
    Exit; // Already initialized.

  if FWindowHandle = 0 then
    raise EDirectInputJoystick.Create(SWindowHandleRequiredForDIJoystick);

  FNotifyWindow := AllocateHWND(DeviceNotify);

  FillChar(LFilter, SizeOf(TDevBroadcastDeviceInterface), 0);
  LFilter.dbcc_size := SizeOf(TDevBroadcastDeviceInterface);
  LFilter.dbcc_devicetype := DBT_DEVTYP_DEVICEINTERFACE;

  FDeviceNotify := RegisterDeviceNotification(FNotifyWindow, @LFilter,
    DEVICE_NOTIFY_WINDOW_HANDLE or DEVICE_NOTIFY_ALL_INTERFACE_CLASSES);

  if FDeviceNotify = nil then
  begin
    DeallocateHWnd(FNotifyWindow);
    raise EDirectInputJoystick.Create(SCouldNotRegisterForDeviceNotification);
  end;

  TDirectInputTypes.AcquireDirectInput;
  try
    RecreateJoysticks;
  except
    if FDeviceNotify <> nil then
    begin
      UnregisterDeviceNotification(FDeviceNotify);
      FDeviceNotify := nil;
    end;
    TDirectInputTypes.ReleaseDirectInput;
    raise;
  end;

  FInitialized := True;
end;

procedure TDirectInputJoysticks.Finalize;
begin
  ReleaseJoysticks;

  if FDeviceNotify <> nil then
  begin
    UnregisterDeviceNotification(FDeviceNotify);
    FDeviceNotify := nil;
  end;
  if FNotifyWindow <> 0 then
  begin
    DeallocateHWnd(FNotifyWindow);
    FNotifyWindow := 0;
  end;
  FInitialized := False;
end;

function TDirectInputJoysticks.Update: Boolean;
var
  LJoystick: TDirectInputJoystick;
begin
  Result := True;

  if FDevicesChanged then
  begin
    FDevicesChanged := False;
    ReleaseJoysticks;
    RecreateJoysticks;
  end;

  for LJoystick in FJoysticks do
    Result := LJoystick.Update and Result;
end;

end.

unit PXL.Timing;
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
{< High accuracy timing and sleep routines that can be used across different platforms. }
interface

{$INCLUDE PXL.Config.inc}

type
// A special-purpose timer implementation that can provide fixed frame-based processing independently of
// rendering frame rate. This class provides @italic(OnProcess) event, which occurs exactly @italic(Speed)
// times per second, and @italic(Latency) property, which can be used from within @italic(OnTimer) event as
// a scaling coefficient for moving things. In order to function properly, @italic(NotifyTick) method
// should be called as fast as possible (for example, before rendering each frame), whereas
// @italic(Process) event should be called right before flipping rendering buffers, to take advantage of
// parallel processing between CPU and GPU. @italic(FrameRate) will indicate how many frames per second
// @italic(NotifyTick) is called. See accompanying examples on how this component can be used.
  TMultimediaTimer = class
  public type
    // Event handler description that is used for timer events.
    TTimerEvent = procedure(const ASender: TObject) of object;
  private const
    OverrunDeltaLimit = 8.0;
  private
    FMaxFPS: Integer;
    FSpeed: Double;
    FEnabled: Boolean;
    FOnTimer: TTimerEvent;

    FFrameRate: Integer;

    FOnProcess: TTimerEvent;
    FProcessed: Boolean;

    FPrevValue: Double;
    FLatency: Double;
    FDelta: Double;
    FMinLatency: Double;
    FSpeedLatency: Double;
    FDeltaCounter: Double;

    FSampleLatency: Double;
    FSampleIndex: Integer;
    FSingleCallOnly: Boolean;

    function RetrieveLatency: Double;
    procedure SetSpeed(const AValue: Double);
    procedure SetMaxFPS(const AValue: Integer);
  public
    { @exclude } constructor Create;

    // This method should only be called from within OnTimer event to do constant object movement and
    // animation control. Each time this method is called, OnProcess event may (or may not) occur depending
    // on the current rendering frame rate (see FrameRate) and the desired processing speed (see Speed).
    // The only thing that is assured is that OnProcess event will occur exactly Speed times per second no
    // matter how fast OnTimer occurs (that is, the value of FrameRate).
    procedure Process;

    // Resets internal structures of the timer and starts over the timing calculations. This can be useful
    // when a very time-consuming task was executed inside OnTimer event that only occurs once. Normally, it
    // would stall the timer making it think that the processing takes too long or the rendering is too slow;
    // calling this method will tell the timer that it should ignore the situation and prevent the stall.
    procedure Reset;

    // This method should be called as fast as possible from within the main application for the timer to
    // work. It can be either called when idle event occurs or from within system timer event.
    procedure NotifyTick(AAllowSleep: Boolean = True);

    // Movement differential between the current frame rate and the requested Speed. Object movement and
    // animation control can be made inside OnTimer event if all displacements are multiplied by this
    // coefficient. For instance, if frame rate is 30 FPS and speed is set to 60, this coefficient will equal
    // to 2.0, so objects moving at 30 FPS will have double displacement to match 60 FPS speed; on the other
    // hand, if frame rate is 120 FPS with speed set to 60, this coefficient will equal to 0.5, to move
    // objects two times slower. An easier and more straight-forward approach can be used with OnProcess
    // event, where using this coefficient is not necessary.
    property Delta: Double read FDelta;

    // The time (in milliseconds) calculated between previous frame and the current one. This can be a direct
    // indicator of rendering performance as it indicates how much time it took to render (and possibly
    // process) the frame.
    property Latency: Double read FLatency;

    // The current frame rate in frames per second. This value is calculated approximately two times per
    // second and can only be used for informative purposes (e.g. displaying frame rate in the application).
    // For precise real-time indications it is recommended to use Latency property instead.
    property FrameRate: Integer read FFrameRate;

    // The speed of constant processing and animation control in frames per second. This affects both Delta
    // property and occurrence of OnProcess event.
    property Speed: Double read FSpeed write SetSpeed;

    // The maximum allowed frame rate at which OnTimer should be executed. This value is an approximate and
    // the resulting frame rate may be quite different (the resolution can be as low as 10 ms). It should be
    // used with reasonable values to prevent the application from using 100% of CPU and GPU with
    // unnecessarily high frame rates such as 1000 FPS. A reasonable and default value for this property
    // is 200.
    property MaxFPS: Integer read FMaxFPS write SetMaxFPS;

    // Determines whether the timer is enabled or not. The internal processing may still be occurring
    // independently of this value, but it controls whether OnTimer event occurs or not.
    property Enabled: Boolean read FEnabled write FEnabled;

    // If this property is set to True, it will prevent the timer from trying to fix situations where the
    // rendering speed is slower than the processing speed (that is, FrameRate is lower than Speed).
    // Therefore, faster rendering produces constant speed, while slower rendering slows the processing down.
    // This is particularly useful for dedicated servers that do no rendering but only processing; in this
    // case, the processing cannot be technically any faster than it already is.
    property SingleCallOnly: Boolean read FSingleCallOnly write FSingleCallOnly;

    // This event occurs when Enabled is set to @True and as fast as possible (only limited approximately by
    // MaxFPS). In this event, all rendering should be made. Inside this event, at some location it is
    // recommended to call Process method, which will invoke OnProcess event for constant object movement and
    // animation control. The idea is to render graphics as fast as possible while moving objects and
    // controlling animation at constant speed. Note that for this event to occur, it is necessary to call
    // NotifyIdle at some point in the application for this timer to do the required calculations.
    property OnTimer: TTimerEvent read FOnTimer write FOnTimer;

    // This event occurs when calling Process method inside OnTimer event. In this event all constant object
    // movement and animation control should be made. This event can occur more than once for each call to
    // Process or may not occur, depending on the current FrameRate and Speed. For instance, when frame rate
    // is 120 FPS and speed set to 60, this event will occur for each second call to Process; on the other
    // hand, if frame rate is 30 FPS with speed set to 60, this event will occur twice for each call to
    // Process to maintain constant processing. An alternative to this is doing processing inside OnTimer
    // event using Delta as coefficient for object movement. If the processing takes too much time inside
    // this event so that the target speed cannot be achieved, the timer may stall (that is, reduce number of
    // occurrences of this event until the balance is restored).
    property OnProcess: TTimerEvent read FOnProcess write FOnProcess;
  end;

type
  // Value type for @link(GetSystemTimerValue), defined in microseconds.
  TSystemTimerValue = UInt64;

// Returns number of microseconds between two values returned by @link(GetSystemTimerValue).
// This method takes into account potential value wrapping.
function TimerValueInBetween(const AValue1, AValue2: TSystemTimerValue): TSystemTimerValue;

// Returns number of milliseconds between two values returned by @link(GetSystemTickCount).
// This method takes into account potential value wrapping.
function TickCountInBetween(const AValue1, AValue2: Cardinal): Cardinal;

// Returns current timer counter represented as 64-bit unsigned integer. The resulting value is specified in
// microseconds. The value should only be used for calculating differences because it can wrap (from very
// high positive value back to zero) after prolonged time intervals. The wrapping usually occurs upon
// reaching High(UInt64) but depending on each individual platform, it can also occur earlier.
function GetSystemTimerValue: TSystemTimerValue;

// Returns current timer counter represented as 32-bit unsigned integer. The resulting value is specified in
// milliseconds. The value should only be used for calculating differences because it can wrap (from very
// high positive value back to zero) after prolonged time intervals. The wrapping usually occurs upon
// reaching High(Cardinal) but depending on each individual platform, it can also occur earlier.
function GetSystemTickCount: Cardinal;

// Returns the current timer counter represented as 64-bit floating-point number. The resulting value is
// specified in milliseconds and fractions of thereof. The value should only be used for calculating
// differences because it can wrap (from very high positive value back to zero or even some negative value)
// after prolonged time intervals.
function GetSystemTimeValue: Double;

// Causes the calling thread to sleep for a given number of microseconds. The sleep can actually be
// interrupted under certain conditions (such as when a message is sent to the caller's thread).
procedure MicroSleep(const AMicroseconds: UInt64);

implementation

uses
{$IFDEF MSWINDOWS}
  {$DEFINE NATIVE_TIMING_SUPPORT}
  Windows, MMSystem,
{$ENDIF}

{$IF DEFINED(FPC) AND DEFINED(UNIX)}
  {$DEFINE NATIVE_TIMING_SUPPORT}
  Unix, BaseUnix,
{$ELSE}
  {$IFDEF POSIX}
    {$DEFINE NATIVE_TIMING_SUPPORT}
    Posix.SysTime, Posix.Time,
  {$ENDIF}
{$ENDIF}

  SysUtils;

{$REGION 'Helper Functions'}

function TimerValueInBetween(const AValue1, AValue2: TSystemTimerValue): TSystemTimerValue;
begin
  Result := AValue2 - AValue1;
  if High(TSystemTimerValue) - Result < Result then
    Result := High(TSystemTimerValue) - Result;
end;

function TickCountInBetween(const AValue1, AValue2: Cardinal): Cardinal;
begin
  Result := AValue2 - AValue1;
  if High(Cardinal) - Result < Result then
    Result := High(Cardinal) - Result;
end;

{$IFDEF MSWINDOWS}
var
  PerformanceFrequency: Int64 = 0;
  PerformanceRequested: Boolean = False;
{$ENDIF}

{$IFDEF MSWINDOWS}
procedure InitPerformanceCounter; inline;
begin
  if not PerformanceRequested then
  begin
    if not QueryPerformanceFrequency(PerformanceFrequency) then
      PerformanceFrequency := 0;

    PerformanceRequested := True;
  end;
end;
{$ENDIF}

function GetSystemTimerValue: TSystemTimerValue;
var
{$IFDEF MSWINDOWS}
  LPerformanceCounter: Int64;
{$ENDIF}

{$IF (DEFINED(FPC) AND DEFINED(UNIX)) OR DEFINED(POSIX)}
  LValue: TimeVal;
{$ENDIF}

{$IFNDEF NATIVE_TIMING_SUPPORT}
  LCurTime: TDateTime;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  InitPerformanceCounter;

  if PerformanceFrequency <> 0 then
  begin
    QueryPerformanceCounter(LPerformanceCounter);
    Result := (UInt64(LPerformanceCounter) * 1000000) div UInt64(PerformanceFrequency);
  end
  else
    Result := UInt64(timeGetTime) * 1000;
{$ENDIF}

{$IF DEFINED(FPC) AND DEFINED(UNIX)}
  fpgettimeofday(@LValue, nil);
  Result := (UInt64(LValue.tv_sec) * 1000000) + UInt64(LValue.tv_usec);
{$ELSE}
  {$IFDEF POSIX}
  GetTimeOfDay(LValue, nil);
  Result := (UInt64(LValue.tv_sec) * 1000000) + UInt64(LValue.tv_usec);
  {$ENDIF}
{$ENDIF}

{$IFNDEF NATIVE_TIMING_SUPPORT}
  LCurTime := Now;

  {$IFDEF FPC}
  Result := Round(LCurTime * Double(8.64E10));
  {$ELSE}
  Result := Round(LCurTime * 8.64E10);
  {$ENDIF}
{$ENDIF}
end;

function GetSystemTickCount: Cardinal;
var
{$IFDEF MSWINDOWS}
  LPerformanceCounter: Int64;
{$ENDIF}

{$IF (DEFINED(FPC) AND DEFINED(UNIX)) OR DEFINED(POSIX)}
  LValue: TimeVal;
{$ENDIF}

{$IFNDEF NATIVE_TIMING_SUPPORT}
  LCurTime: TDateTime;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  InitPerformanceCounter;

  if PerformanceFrequency <> 0 then
  begin
    QueryPerformanceCounter(LPerformanceCounter);
    Result := (LPerformanceCounter * 1000) div PerformanceFrequency;
  end
  else
    Result := timeGetTime;
{$ENDIF}

{$IF DEFINED(FPC) AND DEFINED(UNIX)}
  fpgettimeofday(@LValue, nil);
  Result := (Int64(LValue.tv_sec) * 1000) + (LValue.tv_usec div 1000);
{$ELSE}
  {$IFDEF POSIX}
  GetTimeOfDay(LValue, nil);
  Result := (Int64(LValue.tv_sec) * 1000) + (LValue.tv_usec div 1000);
  {$ENDIF}
{$ENDIF}

{$IFNDEF NATIVE_TIMING_SUPPORT}
  LCurTime := Now;

  {$IFDEF FPC}
  Result := Round(LCurTime * Double(8.64E7));
  {$ELSE}
  Result := Round(LCurTime * 8.64E7);
  {$ENDIF}
{$ENDIF}
end;

function GetSystemTimeValue: Double;
var
{$IFDEF MSWINDOWS}
  LPerformanceCounter: Int64;
{$ENDIF}

{$IF (DEFINED(FPC) AND DEFINED(UNIX)) OR DEFINED(POSIX)}
  LValue: TimeVal;
{$ENDIF}

{$IFNDEF NATIVE_TIMING_SUPPORT}
  LCurTime: TDateTime;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  InitPerformanceCounter;

  if PerformanceFrequency <> 0 then
  begin
    QueryPerformanceCounter(LPerformanceCounter);

  {$IFDEF FPC}
    Result := (LPerformanceCounter * Double(1000.0)) / PerformanceFrequency;
  {$ELSE}
    Result := (LPerformanceCounter * 1000.0) / PerformanceFrequency;
  {$ENDIF}
  end
  else
    Result := timeGetTime;
{$ENDIF}

{$IF DEFINED(FPC) AND DEFINED(UNIX)}
  fpgettimeofday(@LValue, nil);
  Result := (LValue.tv_sec * Double(1000.0)) + (LValue.tv_usec / Double(1000.0));
{$ELSE}
  {$IFDEF POSIX}
  GetTimeOfDay(LValue, nil);
  Result := (LValue.tv_sec * 1000.0) + (LValue.tv_usec / 1000.0);
  {$ENDIF}
{$ENDIF}

{$IFNDEF NATIVE_TIMING_SUPPORT}
  LCurTime := Now;
  Result := LCurTime * 8.64E7;
{$ENDIF}
end;

{$IF DEFINED(POSIX) OR DEFINED(UNIX)}
procedure MicroSleep(const AMicroSeconds: UInt64);
var
  LDelay: TimeSpec;
begin
  LDelay.tv_sec := AMicroseconds div 1000000;
  LDelay.tv_nsec := (AMicroseconds mod 1000000) * 1000;

{$IFDEF POSIX}
  NanoSleep(LDelay, nil);
{$ELSE}
  fpnanosleep(@LDelay, nil);
{$ENDIF}
end;
{$ELSE}
procedure MicroSleep(const AMicroSeconds: UInt64);
begin
  Sleep(AMicroSeconds div 1000);
end;
{$ENDIF}

{$ENDREGION}
{$REGION 'TMultimediaTimer'}

constructor TMultimediaTimer.Create;
begin
  inherited;

  Speed := 60.0;
  MaxFPS := 100;
  FEnabled := True;

  FPrevValue := GetSystemTimeValue;
end;

procedure TMultimediaTimer.SetSpeed(const AValue: Double);
begin
  FSpeed := AValue;
  if FSpeed < 1.0 then
    FSpeed := 1.0;

  FSpeedLatency := 1000.0 / FSpeed;
end;

procedure TMultimediaTimer.SetMaxFPS(const AValue: Integer);
begin
  FMaxFPS := AValue;
  if FMaxFPS < 1 then
    FMaxFPS := 1;

  FMinLatency := 1000.0 / FMaxFPS;
end;

function TMultimediaTimer.RetrieveLatency: Double;
var
  LCurValue: Double;
begin
  LCurValue := GetSystemTimeValue;

  Result := Abs(LCurValue - FPrevValue);
  FPrevValue := LCurValue;
end;

procedure TMultimediaTimer.NotifyTick(AAllowSleep: Boolean);
var
  LWaitTime: Integer;
  LSampleMax: Integer;
begin
  // (1) Retrieve current latency.
  FLatency := RetrieveLatency;

  // (2) If Timer is disabled, wait a little to avoid using 100% of CPU.
  if not FEnabled then
  begin
    if AAllowSleep then
      Sleep(5);

    Exit;
  end;

  // (3) Adjust to maximum FPS, if necessary.
  if (FLatency < FMinLatency) and AAllowSleep then
  begin
    LWaitTime := Round(FMinLatency - FLatency);
    if LWaitTime > 0 then
      Sleep(LWaitTime);
  end
  else
    LWaitTime := 0;

  // (4) The running speed ratio.
  FDelta := FLatency / FSpeedLatency;
  // -> provide Delta limit to prevent auto-loop lockup.
  if FDelta > OverrunDeltaLimit then
    FDelta := OverrunDeltaLimit;

  // (5) Calculate Frame Rate every second.
  FSampleLatency := FSampleLatency + FLatency + LWaitTime;
  if FLatency <= 0 then
    LSampleMax := 4
  else
    LSampleMax := Round(1000.0 / FLatency);

  Inc(FSampleIndex);
  if FSampleIndex >= LSampleMax then
  begin
    if FSampleLatency > 0 then
      FFrameRate := Round((FSampleIndex * 1000.0) / FSampleLatency)
    else
      FFrameRate := 0;

    FSampleLatency := 0.0;
    FSampleIndex := 0;
  end;

  // (6) Increase processing queque, if processing was made last time.
  if FProcessed then
  begin
    FDeltaCounter := FDeltaCounter + FDelta;

    if FDeltaCounter > 2.0 then
      FDeltaCounter := 2.0;

    FProcessed := False;
  end;

  // (7) Call Timer event.
  if Assigned(FOnTimer) then
    FOnTimer(Self);
end;

procedure TMultimediaTimer.Process;
var
  I, LIterations: Integer;
begin
  FProcessed := True;

  LIterations := Trunc(FDeltaCounter);
  if LIterations < 1 then
    Exit;

  if FSingleCallOnly then
  begin
    LIterations := 1;
    FDeltaCounter := 0.0;
  end;

  if Assigned(FOnProcess) then
    for I := 1 to LIterations do
      FOnProcess(Self);

  FDeltaCounter := Frac(FDeltaCounter);
end;

procedure TMultimediaTimer.Reset;
begin
  FDeltaCounter := 0.0;
  FDelta := 0.0;

  RetrieveLatency;
end;

{$ENDREGION}

end.

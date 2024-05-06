unit PXL.Windows.UART;
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
  SysUtils, PXL.TypeDef, PXL.Boards.Types;

type
  TWinUART = class(TCustomPortUART)
  public const
    MaxSupportedBaudRate = 115200;
  private
    FSystemPath: StdString;
    FHandle: TUntypedHandle;

    FBaudRate: Cardinal;
    FBitsPerWord: TBitsPerWord;
    FParity: TParity;
    FStopBits: TStopBits;

    procedure UpdateCommState;
  protected
    function GetBaudRate: Cardinal; override;
    procedure SetBaudRate(const ABaudRate: Cardinal); override;
    function GetBitsPerWord: TBitsPerWord; override;
    procedure SetBitsPerWord(const ABitsPerWord: TBitsPerWord); override;
    function GetParity: TParity; override;
    procedure SetParity(const AParity: TParity); override;
    function GetStopBits: TStopBits; override;
    procedure SetStopBits(const AStopBits: TStopBits); override;
  public
    constructor Create(const ASystemPath: StdString); // e.g. "\\.\COM1"
    destructor Destroy; override;

    function Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;
    function Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;
    procedure Flush; override;

    property SystemPath: StdString read FSystemPath;
    property Handle: TUntypedHandle read FHandle;

    property BaudRate: Cardinal read FBaudRate write SetBaudRate;
    property BitsPerWord: TBitsPerWord read FBitsPerWord write SetBitsPerWord;
    property Parity: TParity read FParity write SetParity;
    property StopBits: TStopBits read FStopBits write SetStopBits;
  end;

  EWinUARTGeneric = class(Exception);

  EWinUARTInvalidParams = class(EWinUARTGeneric);
  EWinUARTOpen = class(EWinUARTGeneric);
  EWinUARTFlush = class(EWinUARTGeneric);

  EWinUARTCommState = class(EWinUARTGeneric);
  EWinUARTSetCommState = class(EWinUARTCommState);
  EWinUARTSetCommTimeouts = class(EWinUARTCommState);

resourcestring
  SCannotOpenFileForUART = 'Cannot open UART file <%s> for reading and writing.';
  SCannotSetCommState = 'Cannot set COMM state for UART (%s).';
  SCannotSetCommTimeouts = 'Cannot set COMM timeouts for UART (%s).';
  SInvalidParameters = 'The specified parameters are invalid.';
  SCannotFlushUARTBuffers = 'Cannot flush UART buffers.';

implementation

uses
  Windows;

const
  DCB_BINARY = $1;
  DCB_PARITY = $2;

constructor TWinUART.Create(const ASystemPath: StdString);
begin
  inherited Create(nil);

  FSystemPath := ASystemPath;

  FHandle := CreateFile(PStdChar(FSystemPath), GENERIC_WRITE or GENERIC_READ, 0, nil, OPEN_EXISTING, 0, 0);
  if FHandle = TUntypedHandle(INVALID_HANDLE_VALUE) then
    raise EWinUARTOpen.CreateFmt(SCannotOpenFileForUART, [FSystemPath]);

  FBaudRate := MaxSupportedBaudRate;
  FBitsPerWord := 8;

  UpdateCommState;
end;

destructor TWinUART.Destroy;
begin
  if FHandle <> TUntypedHandle(INVALID_HANDLE_VALUE) then
  begin
    CloseHandle(FHandle);
    FHandle := TUntypedHandle(INVALID_HANDLE_VALUE);
  end;

  inherited;
end;

procedure TWinUART.UpdateCommState;
var
  DCB: TDCB;
  Timeouts: TCommTimeouts;
begin
  FillChar(DCB, SizeOf(TDCB), 0);

  DCB.DCBlength := SizeOf(TDCB);
  DCB.BaudRate := FBaudRate;
  DCB.flags := DCB_BINARY;
  DCB.ByteSize := FBitsPerWord;
  DCB.XonChar := #17;
  DCB.XoffChar := #19;

  if FParity <> TParity.None then
  begin
    DCB.Flags := DCB.Flags or DCB_PARITY;
    DCB.Parity := Ord(FParity);
  end;

  case FStopBits of
    TStopBits.One:
      DCB.StopBits := ONESTOPBIT;

    TStopBits.OneDotFive:
      DCB.StopBits := ONE5STOPBITS;

    TStopBits.Two:
      DCB.StopBits := TWOSTOPBITS;
  end;

  if not SetCommState(FHandle, DCB) then
    raise EWinUARTSetCommState.CreateFmt(SCannotSetCommState, [FSystemPath]);

  FillChar(Timeouts, SizeOf(TCommTimeouts), 0);
  Timeouts.ReadIntervalTimeout := High(LongWord);

  if not SetCommTimeouts(FHandle, Timeouts) then
    raise EWinUARTSetCommTimeouts.CreateFmt(SCannotSetCommTimeouts, [FSystemPath]);
end;

function TWinUART.GetBaudRate: Cardinal;
begin
  Result := FBaudRate;
end;

procedure TWinUART.SetBaudRate(const ABaudRate: Cardinal);
begin
  if FBaudRate <> ABaudRate then
  begin
    FBaudRate := ABaudRate;
    UpdateCommState;
  end;
end;

function TWinUART.GetBitsPerWord: TBitsPerWord;
begin
  Result := FBitsPerWord;
end;

procedure TWinUART.SetBitsPerWord(const ABitsPerWord: TBitsPerWord);
begin
  if FBitsPerWord <> ABitsPerWord then
  begin
    FBitsPerWord := ABitsPerWord;
    UpdateCommState;
  end;
end;

function TWinUART.GetParity: TParity;
begin
  Result := FParity;
end;

procedure TWinUART.SetParity(const AParity: TParity);
begin
  if FParity <> AParity then
  begin
    FParity := AParity;
    UpdateCommState;
  end;
end;

function TWinUART.GetStopBits: TStopBits;
begin
  Result := FStopBits;
end;

procedure TWinUART.SetStopBits(const AStopBits: TStopBits);
begin
  if FStopBits <> AStopBits then
  begin
    FStopBits := AStopBits;
    UpdateCommState;
  end;
end;

function TWinUART.Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LBytesRead: Cardinal;
begin
  if (ABuffer = nil) or (ABufferSize <= 0) then
    raise EWinUARTInvalidParams.Create(SInvalidParameters);

  if not ReadFile(FHandle, ABuffer^, ABufferSize, LBytesRead, nil) then
    Exit(0);

  Result := LBytesRead;
end;

function TWinUART.Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  BytesWritten: Cardinal;
begin
  if (ABuffer = nil) or (ABufferSize <= 0) then
    raise EWinUARTInvalidParams.Create(SInvalidParameters);

  if not WriteFile(FHandle, ABuffer^, ABufferSize, BytesWritten, nil) then
    Exit(0);

  Result := BytesWritten;
end;

procedure TWinUART.Flush;
begin
  if not FlushFileBuffers(FHandle) then
    raise EWinUARTFlush.Create(SCannotFlushUARTBuffers);
end;

end.

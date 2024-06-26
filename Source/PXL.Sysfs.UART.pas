unit PXL.Sysfs.UART;
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
  PXL.TypeDef, PXL.Boards.Types, PXL.Sysfs.Types;

type
  TSysfsUART = class(TCustomPortUART)
  private
    FSystemPath: StdString;
    FHandle: TUntypedHandle;

    FBaudRate: Cardinal;
    FBitsPerWord: TBitsPerWord;
    FParity: TParity;
    FStopBits: TStopBits;

    function GetBaudRateCode: Integer;
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
    constructor Create(const ASystemCore: TCustomSystemCore; const ASystemPath: StdString);
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

  ESysfsUARTOpen = class(ESysfsFileOpen);
  ESysfsUARTFlush = class(ESysfsGeneric);

  ESysfsUARTAttributes = class(ESysfsGeneric);
  ESysfsUARTGetAttributes = class(ESysfsUARTAttributes);
  ESysfsUARTSetAttributes = class(ESysfsUARTAttributes);

resourcestring
  SCannotOpenFileForUART = 'Cannot open UART file <%s> for reading and writing.';
  SCannotFlushUARTBuffers = 'Cannot flush UART buffers.';
  SCannotGetUARTAttributes = 'Cannot get current UART attributes.';
  SCannotSetUARTAttributes = 'Cannot set updated UART attributes.';

implementation

uses
  SysUtils, TermIO, BaseUnix;

constructor TSysfsUART.Create(const ASystemCore: TCustomSystemCore; const ASystemPath: StdString);
begin
  inherited Create(ASystemCore);

  FSystemPath := ASystemPath;

  FHandle := fpopen(FSystemPath, O_RDWR or O_NOCTTY or O_NDELAY);
  if FHandle < 0 then
  begin
    FHandle := 0;
    raise ESysfsUARTOpen.Create(Format(SCannotOpenFileForUART, [FSystemPath]));
  end;

  FBaudRate := DefaultUARTBaudRate;
  FBitsPerWord := 8;

  UpdateCommState;
end;

destructor TSysfsUART.Destroy;
begin
  if FHandle <> 0 then
  begin
    fpclose(FHandle);
    FHandle := 0;
  end;

  inherited;
end;

function TSysfsUART.GetBaudRateCode: Integer;
begin
  case FBaudRate of
    0: Result := B0;
    50: Result := B50;
    75: Result := B75;
    110: Result := B110;
    134: Result := B134;
    150: Result := B150;
    200: Result := B200;
    300: Result := B300;
    600: Result := B600;
    1200: Result := B1200;
    1800: Result := B1800;
    2400: Result := B2400;
    4800: Result := B4800;
    9600: Result := B9600;
    19200: Result := B19200;
    38400: Result := B38400;
    57600: Result := B57600;
  else
    Result := B115200;
  end;
end;

procedure TSysfsUART.UpdateCommState;
var
  LOptions: TermIOS;
begin
  if tcgetattr(FHandle, LOptions) < 0 then
    raise ESysfsUARTGetAttributes.Create(SCannotGetUARTAttributes);

  LOptions.c_cflag := CLOCAL or CREAD or GetBaudRateCode;
  LOptions.c_iflag := IGNPAR;
  LOptions.c_oflag := 0;
  LOptions.c_lflag := 0;

  case FBitsPerWord of
    5: LOptions.c_cflag := LOptions.c_cflag or CS5;
    6: LOptions.c_cflag := LOptions.c_cflag or CS6;
    7: LOptions.c_cflag := LOptions.c_cflag or CS7;
  else
    LOptions.c_cflag := LOptions.c_cflag or CS8;
  end;

  if FParity <> TParity.None then
  begin
    LOptions.c_cflag := LOptions.c_cflag or PARENB;
    if FParity = TParity.Odd then
      LOptions.c_cflag := LOptions.c_cflag or PARODD;
  end;

  if tcflush(FHandle, TCIOFLUSH) < 0 then
    raise ESysfsUARTFlush.Create(SCannotFlushUARTBuffers);

  if tcsetattr(FHandle, TCSANOW, LOptions) < 0 then
    raise ESysfsUARTSetAttributes.Create(SCannotSetUARTAttributes);
end;

function TSysfsUART.GetBaudRate: Cardinal;
begin
  Result := FBaudRate;
end;

procedure TSysfsUART.SetBaudRate(const ABaudRate: Cardinal);
begin
  if FBaudRate <> ABaudRate then
  begin
    FBaudRate := ABaudRate;
    UpdateCommState;
  end;
end;

function TSysfsUART.GetBitsPerWord: TBitsPerWord;
begin
  Result := FBitsPerWord;
end;

procedure TSysfsUART.SetBitsPerWord(const ABitsPerWord: TBitsPerWord);
begin
  if FBitsPerWord <> ABitsPerWord then
  begin
    FBitsPerWord := ABitsPerWord;
    UpdateCommState;
  end;
end;

function TSysfsUART.GetParity: TParity;
begin
  Result := FParity;
end;

procedure TSysfsUART.SetParity(const AParity: TParity);
begin
  if FParity <> AParity then
  begin
    FParity := AParity;
    UpdateCommState;
  end;
end;

function TSysfsUART.GetStopBits: TStopBits;
begin
  Result := FStopBits;
end;

procedure TSysfsUART.SetStopBits(const AStopBits: TStopBits);
begin
  if FStopBits <> AStopBits then
  begin
    FStopBits := AStopBits;
    UpdateCommState;
  end;
end;

function TSysfsUART.Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LBytesRead: Integer;
begin
  if (ABuffer = nil) or (ABufferSize <= 0) then
    raise ESysfsInvalidParams.Create(SInvalidParameters);

  LBytesRead := fpRead(FHandle, ABuffer^, ABufferSize);
  if LBytesRead < 0 then
    Exit(0);

  Result := Cardinal(LBytesRead);
end;

function TSysfsUART.Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LBytesWritten: Integer;
begin
  if (ABuffer = nil) or (ABufferSize <= 0) then
    raise ESysfsInvalidParams.Create(SInvalidParameters);

  LBytesWritten := fpWrite(FHandle, ABuffer^, ABufferSize);
  if LBytesWritten < 0 then
    Exit(0);

  Result := Cardinal(LBytesWritten);
end;

procedure TSysfsUART.Flush;
begin
  if tcflush(FHandle, TCIOFLUSH) < 0 then
    raise ESysfsUARTFlush.Create(SCannotFlushUARTBuffers);
end;

end.

unit PXL.Logs;
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
{< Helper functions for debugging purposes. }
interface

{$INCLUDE PXL.Config.inc}

{$IF DEFINED(MSWINDOWS) AND NOT DEFINED(PXL_CONSOLE)}
  {$DEFINE PXL_LOG_TO_FILE}
{$ENDIF}

uses
  PXL.TypeDef;

type
  // Type of log information to be displayed.
  TLogType = (
    // Information is treated depending on default settings for each of platforms.
    Default,

    // Information is treated as a hint.
    Hint,

    // Information is treated as a warning with minimal severity.
    Warning,

    // Information is treated as a severe error.
    Error);

// Sends information text to logging console (the location and context of which depends on platform).
procedure LogText(const AText: StdString; const ALogType: TLogType = TLogType.Default;
  const ATag: StdString = '');

implementation

uses
  SysUtils;

{$IFDEF PXL_LOG_TO_FILE}
var
  LogFile: TextFile;

  ExecFile: StdString = '-';
  ExecDate: StdString = '--';
  ExecPath: StdString = '';

  LogFileName: StdString = 'file-xxxx-xx-xx-xx.log';
  LogFileHour: Integer = -1;
  LogFileDay : Integer = -1;

function IntToStr2(const AValue: Integer): StdString;
begin
  Result := IntToStr(AValue);
  if Length(Result) < 2 then
    Result := '0' + Result;
end;

function GetLogFileName: StdString;
var
  LTimestamp: TDateTime;
  LYear, LMonth, LDay, LHour, LMin, LSec, LMSec: Word;
begin
  LTimestamp := Now;

  DecodeDate(LTimestamp, LYear, LMonth, LDay);
  DecodeTime(LTimestamp, LHour, LMin, LSec, LMSec);

  Result := ExecPath + ExecFile + '-' + IntToStr(LYear) + '-' + IntToStr2(LMonth) + '-' + IntToStr2(LDay) +
    '-' + IntToStr2(LHour) + '.log';
end;

function StartupFile(const AFileName: StdString): Boolean;
begin
  AssignFile(LogFile, AFileName);

  ReWrite(LogFile);
  if IOResult <> 0 then
  begin
    CloseFile(LogFile);
    Exit(False);
  end;

  WriteLn(LogFile, 'Executed name: ' + ExecPath + ExecFile);
  WriteLn(LogFile, 'Executed date: ' + ExecDate);
  WriteLn(LogFile, '-------------------- ENTRY -----------------------');

  Result := IOResult = 0;
  CloseFile(LogFile);
end;

function ValidateLogFileName: Boolean;
var
  LTimestamp: TDateTime;
  LDay, LHour, LMin, LSec, LMSec: Word;
begin
  LTimestamp := Now;

  DecodeTime(LTimestamp, LHour, LMin, LSec, LMSec);
  LDay := Trunc(LTimestamp);

  if (LogFileHour = -1) or (LogFileHour <> LHour) or (LogFileDay = -1) or (LogFileDay <> LDay) then
  begin
    LogFileHour := LHour;
    LogFileDay := LDay;
    LogFileName := GetLogFileName;

    if not FileExists(LogFileName) then
      Result := StartupFile(LogFileName)
    else
      Result := True;
  end
  else
    Result:= True;
end;
{$ENDIF}

procedure LogText(const AText: StdString; const ALogType: TLogType; const ATag: StdString);
{$IFDEF PXL_LOG_TO_FILE}
var
  LHour, LMin, LSec, LMSec: Word;
{$ENDIF}
begin
{$IFDEF PXL_LOG_TO_FILE}
  if not ValidateLogFileName then
    Exit;

  AssignFile(LogFile, LogFileName);
  Append(LogFile);
  if IOResult <> 0 then
  begin
    CloseFile(LogFile);
    Exit;
  end;

  DecodeTime(Time, LHour, LMin, LSec, LMSec);
  WriteLn(LogFile, '[' + IntToStr2(LMin) + '] ' + AText);

  CloseFile(LogFile);
{$ENDIF}
{$IFDEF PXL_CONSOLE}
  WriteLn(AText);
{$ENDIF}
end;

initialization
{$IFDEF PXL_LOG_TO_FILE}
  ExecFile := ExtractFileName(ParamStr(0));
  ExecPath := ExtractFilePath(ParamStr(0));
  ExecDate := DateTimeToStr(Now);
{$ENDIF}

end.


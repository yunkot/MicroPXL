unit PXL.Sysfs.Types;
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
  SysUtils, PXL.TypeDef;

type
  ESysfsGeneric = class(Exception);

  ESysfsFileOpen = class(ESysfsGeneric);
  ESysfsFileOpenWrite = class(ESysfsFileOpen);
  ESysfsFileOpenRead = class(ESysfsFileOpen);
  ESysfsFileOpenReadWrite = class(ESysfsFileOpen);

  ESysfsFileAccess = class(ESysfsGeneric);
  ESysfsFileWrite = class(ESysfsFileAccess);
  ESysfsFileRead = class(ESysfsFileAccess);
  ESysfsFileMemoryMap = class(ESysfsFileAccess);

  ESysfsInvalidParams = class(ESysfsGeneric);

procedure WriteTextToFile(const AFileName, AText: StdString);
function TryWriteTextToFile(const AFileName, AText: StdString): Boolean;

function ReadCharFromFile(const AFileName: StdString): StdChar;
function TryReadCharFromFile(const AFileName: StdString; out AValue: StdChar): Boolean;

function ReadTextFromFile(const AFileName: StdString): StdString;
function TryReadTextFromFile(const AFileName: StdString; out AValue: StdString): Boolean;

resourcestring
  SCannotOpenFileForWriting = 'Cannot open file <%s> for writing.';
  SCannotOpenFileForReading = 'Cannot open file <%s> for reading.';
  SCannotOpenFileForReadingWriting = 'Cannot open file <%s> for reading and writing.';
  SCannotWriteTextToFile = 'Cannot write text <%s> to file <%s>.';
  SCannotReadTextFromFile = 'Cannot read text from file <%s>.';
  SCannotMemoryMapFile = 'Cannot map file <%s> to memory.';
  SInvalidParameters = 'The specified parameters are invalid.';

implementation

uses
  BaseUnix;

const
  PercentualLengthDiv = 4;
  StringBufferSize = 8;

procedure WriteTextToFile(const AFileName, AText: StdString);
var
  LHandle: TUntypedHandle;
begin
  LHandle := fpopen(AFileName, O_WRONLY);
  if LHandle < 0 then
    raise ESysfsFileOpenWrite.Create(Format(SCannotOpenFileForWriting, [AFileName]));
  try
    if fpwrite(LHandle, AText[1], Length(AText)) <> Length(AText) then
      raise ESysfsFileWrite.Create(Format(SCannotWriteTextToFile, [AText, AFileName]));
  finally
    fpclose(LHandle);
  end;
end;

function TryWriteTextToFile(const AFileName, AText: StdString): Boolean;
var
  LHandle: TUntypedHandle;
begin
  LHandle := fpopen(AFileName, O_WRONLY);
  if LHandle < 0 then
    Exit(False);
  try
    Result := fpwrite(LHandle, AText[1], Length(AText)) = Length(AText);
  finally
    fpclose(LHandle);
  end;
end;

function ReadCharFromFile(const AFileName: StdString): StdChar;
var
  LHandle: TUntypedHandle;
begin
  LHandle := fpopen(AFileName, O_RDONLY);
  if LHandle < 0 then
    raise ESysfsFileOpenRead.Create(Format(SCannotOpenFileForReading, [AFileName]));
  try
  {$IF SIZEOF(STDCHAR) > 1}
    Result := #0;
  {$ENDIF}
    if fpread(LHandle, Result, 1) <> 1 then
      raise ESysfsFileRead.Create(Format(SCannotReadTextFromFile, [AFileName]));
  finally
    fpclose(LHandle);
  end;
end;

function TryReadCharFromFile(const AFileName: StdString; out AValue: StdChar): Boolean;
var
  LHandle: TUntypedHandle;
begin
  LHandle := fpopen(AFileName, O_RDONLY);
  if LHandle < 0 then
    Exit(False);
  try
  {$IF SIZEOF(STDCHAR) > 1}
    AValue := #0;
  {$ENDIF}
    Result := fpread(LHandle, AValue, 1) = 1;
  finally
    fpclose(LHandle);
  end;
end;

function ReadTextFromFile(const AFileName: StdString): StdString;
var
  LHandle: TUntypedHandle;
  LBuffer: array[0..StringBufferSize - 1] of Byte;
  I, LBytesRead, LTextLength, LNewTextLength: Integer;
begin
  LTextLength := 0;

  LHandle := fpopen(AFileName, O_RDONLY);
  if LHandle < 0 then
    raise ESysfsFileOpenRead.Create(Format(SCannotOpenFileForReading, [AFileName]));
  try
    SetLength(Result, StringBufferSize);

    repeat
      LBytesRead := fpread(LHandle, LBuffer[0], StringBufferSize);
      if (LBytesRead < 0) or ((LBytesRead = 0) and (LTextLength <= 0)) then
        raise ESysfsFileRead.Create(Format(SCannotReadTextFromFile, [AFileName]));

      if Length(Result) < LTextLength + LBytesRead then
      begin
        LNewTextLength := Length(Result) + StringBufferSize + (Length(Result) div PercentualLengthDiv);
        SetLength(Result, LNewTextLength);
      end;

      for I := 0 to LBytesRead - 1 do
        Result[1 + LTextLength + I] := Chr(LBuffer[I]);

      Inc(LTextLength, LBytesRead);
    until LBytesRead <= 0;
  finally
    fpclose(LHandle);
  end;

  SetLength(Result, LTextLength);
end;

function TryReadTextFromFile(const AFileName: StdString; out AValue: StdString): Boolean;
var
  LHandle: TUntypedHandle;
  LBuffer: array[0..StringBufferSize - 1] of Byte;
  I, LBytesRead, LTextLength, LNewTextLength: Integer;
begin
  LTextLength := 0;

  LHandle := fpopen(AFileName, O_RDONLY);
  if LHandle < 0 then
  begin
    SetLength(AValue, 0);
    Exit(False);
  end;

  try
    SetLength(AValue, StringBufferSize);

    repeat
      LBytesRead := fpread(LHandle, LBuffer[0], StringBufferSize);
      if (LBytesRead < 0) or ((LBytesRead = 0) and (LTextLength <= 0)) then
      begin
        SetLength(AValue, 0);
        Exit(False);
      end;

      if Length(AValue) < LTextLength + LBytesRead then
      begin
        LNewTextLength := Length(AValue) + StringBufferSize + (Length(AValue) div PercentualLengthDiv);
        SetLength(AValue, LNewTextLength);
      end;

      for I := 0 to LBytesRead - 1 do
        AValue[1 + LTextLength + I] := Chr(LBuffer[I]);

      Inc(LTextLength, LBytesRead);
    until LBytesRead <= 0;
  finally
    fpclose(LHandle);
  end;

  SetLength(AValue, LTextLength);
  Result := True;
end;

end.

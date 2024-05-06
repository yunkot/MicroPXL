unit PXL.Classes;
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
{< Extensions and utility classes that extend functionality of streams. }
interface

{$INCLUDE PXL.Config.inc}

uses
  Types, Classes, PXL.TypeDef, PXL.Types;

type
  // Extensions to TStream class for reading and writing different values depending on platform.
  // Although TStream in recent versions of FPC and Delphi introduced similar functions, this extension class
  // provides a more comprehensive and unified set of functions that work across all platforms.
  TStreamHelper = class helper for TStream
  public type
    // Value stored as unsigned 8-bit integer, but represented as unsigned 32-bit or 64-bit value depending
    // on platform.
    TStreamByte = SizeUInt;

    // Value stored as unsigned 16-bit integer, but represented as unsigned 32-bit or 64-bit value depending
    // on platform.
    TStreamWord = SizeUInt;

    // Value stored as unsigned 32-bit integer, but represented as unsigned 32-bit or 64-bit value depending
    // on platform.
    TStreamLongWord = {$IF SIZEOF(SizeUInt) >= 4} SizeUInt {$ELSE} LongWord {$ENDIF};

    // Value stored and represented as unsigned 64-bit integer.
    TStreamUInt64 = UInt64;

    // Value stored as 8-bit signed integer, but represented as signed 32-bit or 64-bit value depending on
    // platform.
    TStreamShortInt = SizeInt;

    // Value stored as 16-bit signed integer, but represented as signed 32-bit or 64-bit value depending on
    // platform.
    TStreamSmallInt = SizeInt;

    // Value stored as 32-bit signed integer, but represented as signed 32-bit or 64-bit value depending on
    // platform.
    TStreamLongInt = {$IF SIZEOF(SizeInt) >= 4} SizeInt {$ELSE} LongInt {$ENDIF};

    // Value stored and represented as signed 64-bit integer.
    TStreamInt64 = Int64;

    // Value stored and represented as 32-bit (single-precision) floating-point.
    TStreamSingle = Single;

    // Value stored and represented as 64-bit (double-precision) floating-point.
    TStreamDouble = Double;

    // Value stored as 8-bit unsigned integer, but represented as Boolean.
    TStreamByteBool = Boolean;

    // Value stored as unsigned 8-bit integer, but represented as signed 32-bit or 64-bit index depending on
    // platform.
    TStreamByteIndex = SizeInt;

    // Value stored as unsigned 16-bit integer, but represented as signed 32-bit or 64-bit index depending on
    // platform.
    TStreamWordIndex = {$IF SIZEOF(SizeInt) >= 4} SizeInt {$ELSE} LongInt {$ENDIF};
  public
    // Saves 8-bit unsigned integer to the stream. If the value is outside of [0..255] range, it will be
    // clamped.
    procedure PutByte(const AValue: TStreamByte); inline;

    // Loads 8-bit unsigned integer from the stream.
    function GetByte: TStreamByte; inline;

    // Saves 16-bit unsigned integer to the stream. If the AValue is outside of [0..65535] range, it will be
    // clamped.
    procedure PutWord(const AValue: TStreamWord); inline;

    // Loads 16-bit unsigned integer AValue from the stream.
    function GetWord: TStreamWord; inline;

    // Saves 32-bit unsigned integer to the stream.
    procedure PutLongWord(const AValue: TStreamLongWord); inline;

    // Loads 32-bit unsigned integer from the stream.
    function GetLongWord: TStreamLongWord; inline;

    // Saves 64-bit unsigned integer to the stream.
    procedure PutUInt64(const AValue: TStreamUInt64); inline;

    // Loads 64-bit unsigned integer from the stream.
    function GetUInt64: TStreamUInt64; inline;

    // Saves 8-bit signed integer to the stream. If the AValue is outside of [-128..127] range, it will be
    // clamped.
    procedure PutShortInt(const AValue: TStreamShortInt); inline;

    // Loads 8-bit signed integer from the stream.
    function GetShortInt: TStreamShortInt; inline;

    // Saves 16-bit signed integer to the stream. If the AValue is outside of [-32768..32767] range, it will
    // be clamped.
    procedure PutSmallInt(const AValue: TStreamSmallInt); inline;

    // Loads 16-bit signed integer from the stream.
    function GetSmallInt: TStreamSmallInt; inline;

    // Saves 32-bit signed integer to the stream.
    procedure PutLongInt(const AValue: TStreamLongInt); inline;

    // Loads 32-bit signed integer from the stream.
    function GetLongInt: TStreamLongInt; inline;

    // Saves 64-bit signed integer to the stream.
    procedure PutInt64(const AValue: TStreamInt64); inline;

    // Loads 64-bit signed integer from the stream.
    function GetInt64: TStreamInt64; inline;

    // Saves 32-bit floating-point AValue (single-precision) to the stream.
    procedure PutSingle(const AValue: TStreamSingle); inline;

    // Loads 32-bit floating-point AValue (single-precision) from the stream.
    function GetSingle: TStreamSingle; inline;

    // Saves 64-bit floating-point AValue (double-precision) to the stream.
    procedure PutDouble(const AValue: TStreamDouble); inline;

    // Loads 64-bit floating-point AValue (double-precision) from the stream.
    function GetDouble: TStreamDouble; inline;

    // Saves @bold(Boolean) AValue to the stream as 8-bit unsigned integer. A value of @False is saved
    // as 255, while @True is saved as 0.
    procedure PutByteBool(const AValue: TStreamByteBool); inline;

    // Loads @bold(Boolean) AValue from the stream previously saved by @link(PutByteBool). The resulting
    // value is treated as 8-bit unsigned integer with values of [0..127] considered as @True and values of
    // [128..255] considered as @False.
    function GetByteBool: TStreamByteBool; inline;

    // Saves 8-bit unsigned index to the stream. A value of -1 (and other negative values) is stored as 255.
    // Positive numbers that are outside of [0..254] range will be clamped.
    procedure PutByteIndex(const AValue: TStreamByteIndex); inline;

    // Loads 8-bit unsigned index from the stream. The range of returned values is [0..254], the value of 255
    // is returned as -1.
    function GetByteIndex: TStreamByteIndex; inline;

    // Saves 16-bit unsigned index to the stream. A value of -1 (and other negative values) is stored as
    // 65535. Positive numbers that are outside of [0..65534] range will be clamped. }
    procedure PutWordIndex(const AValue: TStreamWordIndex); inline;

    // Loads 16-bit unsigned index from the stream. The range of returned values is [0..65534], the value of
    // 65535 is returned as -1.
    function GetWordIndex: TStreamWordIndex; inline;

    // Saves 2D integer point to the stream. Each coordinate is saved as 32-bit signed integer.
    procedure PutLongPoint2i(const AValue: TPoint);

    // Loads 2D integer point from the stream. Each coordinate is loaded as 32-bit signed integer.
    function GetLongPoint2i: TPoint;

    // Saves Unicode string to the stream in UTF-8 encoding. The resulting UTF-8 string is limited to
    // a maximum of 255 characters; therefore, for certain charsets the actual string is limited to either
    // 127 or even 85 characters in worst case. If AMaxCount is not zero, the input string will be limited to
    // the given number of characters.
    procedure PutShortString(const AText: UniString; const AMaxCount: Integer = 0);

    // Loads Unicode string from the stream in UTF-8 encoding previously saved by @link(PutShortString).
    function GetShortString: UniString;

    // Saves Unicode string to the stream in UTF-8 encoding. The resulting UTF-8 string is limited to
    // a maximum of 65535 characters; therefore, for certain charsets the actual string is limited to either
    // 32767 or even 21845 characters in worst case. If AMaxCount is not zero, the input string will be
    // limited to the given number of characters.
    procedure PutMediumString(const AText: UniString; const AMaxCount: Integer = 0);

    // Loads Unicode string from the stream in UTF-8 encoding previously saved by @link(PutMediumString).
    function GetMediumString: UniString;

    // Stores Unicode string to the stream in UTF-8 encoding.
    procedure PutLongString(const AText: UniString);

    // Loads Unicode string from the stream in UTF-8 encoding previously saved by @link(PutLongString).
    function GetLongString: UniString;
  end;

// A quick method for replacing "\" with "/" and vice-versa depending on platform. This calls makes sure that
// the provided path uses correct path delimiter.
function CrossFixFileName(const AFileName: StdString): StdString;

implementation

uses
{$IFDEF DELPHI_NEXTGEN}
  SysUtils,
{$ENDIF}

  RTLConsts, PXL.Consts;

{$REGION 'Globals'}
{$IFDEF DELPHI_NEXTGEN}

const
  DefaultCodePage = 65001; // UTF-8

function StringToBytes(const AText: string): TBytes;
var
  LByteCount: Integer;
begin
  if AText.IsEmpty then
    Exit(nil);

  LByteCount := LocaleCharsFromUnicode(DefaultCodePage, 0, Pointer(AText), Length(AText), nil, 0, nil, nil);

  SetLength(Result, LByteCount);
  LocaleCharsFromUnicode(DefaultCodePage, 0, Pointer(AText), Length(AText), Pointer(Result), LByteCount, nil, nil);
end;

function BytesToString(const ABytes: TBytes): string;
var
  LTextLength: Integer;
begin
  if Length(ABytes) < 1 then
    Exit(string.Empty);

  LTextLength := UnicodeFromLocaleChars(DefaultCodePage, 0, Pointer(ABytes), Length(ABytes), nil, 0);
  if LTextLength < 1 then
    Exit(string.Empty);

  SetLength(Result, LTextLength);
  UnicodeFromLocaleChars(DefaultCodePage, 0, Pointer(ABytes), Length(ABytes), Pointer(Result), LTextLength);
end;

{$ENDIF}

function CrossFixFileName(const AFileName: StdString): StdString;
const
{$IFDEF MSWINDOWS}
  PrevChar = '/';
  NewChar = '\';
{$ELSE}
  PrevChar = '\';
  NewChar = '/';
{$ENDIF}
var
  I: Integer;
begin
  Result := AFileName;
  UniqueString(Result);

  for I := 1 to Length(Result) do
    if Result[I] = PrevChar then
      Result[I] := NewChar;
end;

{$ENDREGION}
{$REGION 'TStreamHelper'}

procedure TStreamHelper.PutByte(const AValue: TStreamByte);
var
  LByteValue: Byte;
begin
  if AValue <= High(Byte) then
    LByteValue := AValue
  else
    LByteValue := High(Byte);

  WriteBuffer(LByteValue, SizeOf(Byte));
end;

function TStreamHelper.GetByte: TStreamByte;
var
  LByteValue: Byte;
begin
  ReadBuffer(LByteValue, SizeOf(Byte));
  Result := LByteValue;
end;

procedure TStreamHelper.PutWord(const AValue: TStreamWord);
{$IF SIZEOF(TStream.TStreamWord) > 2}
var
  LWordValue: Word;
{$ENDIF}
begin
{$IF SIZEOF(TStream.TStreamWord) > 2}
  if AValue <= High(Word) then
    LWordValue := AValue
  else
    LWordValue := High(Word);

  WriteBuffer(LWordValue, SizeOf(Word));
{$ELSE}
  WriteBuffer(AValue, SizeOf(Word));
{$ENDIF}
end;

function TStreamHelper.GetWord: TStreamWord;
{$IF SIZEOF(TStream.TStreamWord) > 2}
var
  LWordValue: Word;
{$ENDIF}
begin
{$IF SIZEOF(TStream.TStreamWord) > 2}
  ReadBuffer(LWordValue, SizeOf(Word));
  Result := LWordValue;
{$ELSE}
  ReadBuffer(Result, SizeOf(Word));
{$ENDIF}
end;

procedure TStreamHelper.PutLongWord(const AValue: TStreamLongWord);
{$IF SIZEOF(TStream.TStreamLongWord) > 4}
var
  LLongWordValue: LongWord;
{$ENDIF}
begin
{$IF SIZEOF(TStream.TStreamLongWord) > 4}
  if AValue <= High(LongWord) then
    LLongWordValue := AValue
  else
    LLongWordValue := High(LongWord);

  WriteBuffer(LLongWordValue, SizeOf(LongWord));
{$ELSE}
  WriteBuffer(AValue, SizeOf(LongWord));
{$ENDIF}
end;

function TStreamHelper.GetLongWord: TStreamLongWord;
{$IF SIZEOF(TStream.TStreamLongWord) > 4}
var
  LLongWordValue: LongWord;
{$ENDIF}
begin
{$IF SIZEOF(TStream.TStreamLongWord) > 4}
  ReadBuffer(LLongWordValue, SizeOf(LongWord));
  Result := LLongWordValue;
{$ELSE}
  ReadBuffer(Result, SizeOf(LongWord));
{$ENDIF}
end;

procedure TStreamHelper.PutUInt64(const AValue: TStreamUInt64);
begin
  WriteBuffer(AValue, SizeOf(UInt64));
end;

function TStreamHelper.GetUInt64: TStreamUInt64;
begin
  ReadBuffer(Result, SizeOf(UInt64));
end;

procedure TStreamHelper.PutShortInt(const AValue: TStreamShortInt);
var
  LShortValue: ShortInt;
begin
  if AValue < Low(ShortInt) then
    LShortValue := Low(ShortInt)
  else if AValue > High(ShortInt) then
    LShortValue := High(ShortInt)
  else
    LShortValue := AValue;

  WriteBuffer(LShortValue, SizeOf(ShortInt));
end;

function TStreamHelper.GetShortInt: TStreamShortInt;
var
  LShortValue: ShortInt;
begin
  ReadBuffer(LShortValue, SizeOf(ShortInt));
  Result := LShortValue;
end;

procedure TStreamHelper.PutSmallInt(const AValue: TStreamSmallInt);
{$IF SIZEOF(TStream.TStreamSmallInt) > 2}
var
  LSmallValue: SmallInt;
{$ENDIF}
begin
{$IF SIZEOF(TStream.TStreamSmallInt) > 2}
  if AValue < Low(SmallInt) then
    LSmallValue := Low(SmallInt)
  else if AValue > High(SmallInt) then
    LSmallValue := High(SmallInt)
  else
    LSmallValue := AValue;

  WriteBuffer(LSmallValue, SizeOf(SmallInt));
{$ELSE}
  WriteBuffer(AValue, SizeOf(SmallInt));
{$ENDIF}
end;

function TStreamHelper.GetSmallInt: TStreamSmallInt;
{$IF SIZEOF(TStream.TStreamSmallInt) > 2}
var
  LSmallValue: SmallInt;
{$ENDIF}
begin
{$IF SIZEOF(TStream.TStreamSmallInt) > 2}
  ReadBuffer(LSmallValue, SizeOf(SmallInt));
  Result := LSmallValue;
{$ELSE}
  ReadBuffer(Result, SizeOf(SmallInt));
{$ENDIF}
end;

procedure TStreamHelper.PutLongInt(const AValue: TStreamLongInt);
{$IF SIZEOF(TStream.TStreamLongInt) > 4}
var
  LLongValue: LongInt;
{$ENDIF}
begin
{$IF SIZEOF(TStream.TStreamLongInt) > 4}
  if AValue < Low(LongInt) then
    LLongValue := Low(LongInt)
  else if AValue > High(LongInt) then
    LLongValue := High(LongInt)
  else
    LLongValue := AValue;

  WriteBuffer(LLongValue, SizeOf(LongInt));
{$ELSE}
  WriteBuffer(AValue, SizeOf(LongInt));
{$ENDIF}
end;

function TStreamHelper.GetLongInt: TStreamLongInt;
{$IF SIZEOF(TStream.TStreamLongInt) > 4}
var
  LLongValue: LongInt;
{$ENDIF}
begin
{$IF SIZEOF(TStream.TStreamLongInt) > 4}
  ReadBuffer(LLongValue, SizeOf(LongInt));
  Result := LLongValue;
{$ELSE}
  ReadBuffer(Result, SizeOf(LongInt));
{$ENDIF}
end;

procedure TStreamHelper.PutInt64(const AValue: TStreamInt64);
begin
  WriteBuffer(AValue, SizeOf(Int64));
end;

function TStreamHelper.GetInt64: TStreamInt64;
begin
  ReadBuffer(Result, SizeOf(Int64));
end;

procedure TStreamHelper.PutSingle(const AValue: TStreamSingle);
begin
  WriteBuffer(AValue, SizeOf(Single));
end;

function TStreamHelper.GetSingle: TStreamSingle;
begin
  ReadBuffer(Result, SizeOf(Single));
end;

procedure TStreamHelper.PutDouble(const AValue: TStreamDouble);
begin
  WriteBuffer(AValue, SizeOf(Double));
end;

function TStreamHelper.GetDouble: TStreamDouble;
begin
  ReadBuffer(Result, SizeOf(Double));
end;

procedure TStreamHelper.PutByteBool(const AValue: TStreamByteBool);
var
  LByteValue: Byte;
begin
  LByteValue := 255;

  if AValue then
    LByteValue := 0;

  WriteBuffer(LByteValue, SizeOf(Byte));
end;

function TStreamHelper.GetByteBool: TStreamByteBool;
var
  LByteValue: Byte;
begin
  ReadBuffer(LByteValue, SizeOf(Byte));
  Result := LByteValue < 128;
end;

procedure TStreamHelper.PutByteIndex(const AValue: TStreamByteIndex);
var
  LByteValue: Byte;
begin
  if AValue < 0 then
    LByteValue := 255
  else if AValue > 254 then
    LByteValue := 254
  else
    LByteValue := AValue;

  WriteBuffer(LByteValue, SizeOf(Byte));
end;

function TStreamHelper.GetByteIndex: TStreamByteIndex;
var
  LByteValue: Byte;
begin
  Result := -1;

  if (Read(LByteValue, SizeOf(Byte)) = SizeOf(Byte)) and (LByteValue <> 255) then
    Result := LByteValue;
end;

procedure TStreamHelper.PutWordIndex(const AValue: TStreamWordIndex);
var
  LWordValue: Word;
begin
  if AValue < 0 then
    LWordValue := 65535
  else if AValue > 65534 then
    LWordValue := 65534
  else
    LWordValue := AValue;

  Write(LWordValue, SizeOf(Word));
end;

function TStreamHelper.GetWordIndex: TStreamWordIndex;
var
  LWordValue: Word;
begin
  Result := -1;

  if (Read(LWordValue, SizeOf(Word)) = SizeOf(Word)) and (LWordValue <> 65535) then
    Result := LWordValue;
end;

procedure TStreamHelper.PutLongPoint2i(const AValue: TPoint);
begin
  PutLongInt(AValue.X);
  PutLongInt(AValue.Y);
end;

function TStreamHelper.GetLongPoint2i: TPoint;
begin
  Result.X := GetLongInt;
  Result.Y := GetLongInt;
end;

{$IFDEF DELPHI_NEXTGEN}

procedure TStreamHelper.PutShortString(const AText: UniString; const AMaxCount: Integer);
var
  LCount: Integer;
  LBytes: TBytes;
begin
  LBytes := StringToBytes(AText);
  LCount := Length(LBytes);

  if LCount > 255 then
    LCount := 255;

  if (AMaxCount > 0) and (AMaxCount < LCount) then
    LCount := AMaxCount;

  PutByte(LCount);

  Write(Pointer(LBytes)^, LCount);
end;

function TStreamHelper.GetShortString: UniString;
var
  LCount: Integer;
  LBytes: TBytes;
begin
  LCount := GetByte;
  SetLength(LBytes, LCount);

  if Read(Pointer(LBytes)^, LCount) = LCount then
    Result := BytesToString(LBytes)
  else
    Result := string.Empty;
end;

procedure TStreamHelper.PutMediumString(const AText: UniString; const AMaxCount: Integer);
var
  LCount: Integer;
  LBytes: TBytes;
begin
  LBytes := StringToBytes(AText);
  LCount := Length(LBytes);

  if LCount > 65535 then
    LCount := 65535;

  if (AMaxCount > 0) and (AMaxCount < LCount) then
    LCount := AMaxCount;

  PutWord(LCount);

  Write(Pointer(LBytes)^, LCount);
end;

function TStreamHelper.GetMediumString: UniString;
var
  LCount: Integer;
  LBytes: TBytes;
begin
  LCount := GetWord;
  SetLength(LBytes, LCount);

  if Read(Pointer(LBytes)^, LCount) = LCount then
    Result := BytesToString(LBytes)
  else
    Result := string.Empty;
end;

procedure TStreamHelper.PutLongString(const AText: UniString);
var
  LCount: Integer;
  LBytes: TBytes;
begin
  LBytes := StringToBytes(AText);
  LCount := Length(LBytes);

  PutLongInt(LCount);
  Write(Pointer(LBytes)^, LCount);
end;

function TStreamHelper.GetLongString: UniString;
var
  LCount: Integer;
  LBytes: TBytes;
begin
  LCount := GetLongInt;
  SetLength(LBytes, LCount);

  if Read(Pointer(LBytes)^, LCount) = LCount then
    Result := BytesToString(LBytes)
  else
    Result := string.Empty;
end;

{$ELSE}

procedure TStreamHelper.PutShortString(const AText: UniString; const AMaxCount: Integer);
var
  LCount: Integer;
  LShortText: AnsiString;
begin
  LShortText := UTF8Encode(AText);
  LCount := Length(LShortText);

  if LCount > 255 then
    LCount := 255;

  if (AMaxCount > 0) and (AMaxCount < LCount) then
    LCount := AMaxCount;

  PutByte(LCount);

  Write(Pointer(LShortText)^, LCount);
end;

function TStreamHelper.GetShortString: UniString;
var
  LCount: Integer;
  LShortText: AnsiString;
begin
  LCount := GetByte;
  SetLength(LShortText, LCount);

  if Read(Pointer(LShortText)^, LCount) <> LCount then
    Exit('');

{$IFDEF FPC}
  Result := UTF8Decode(LShortText);
{$ELSE}
  Result := UTF8ToWideString(LShortText);
{$IFEND}
end;

procedure TStreamHelper.PutMediumString(const AText: UniString; const AMaxCount: Integer);
var
  LCount: Integer;
  LMediumText: AnsiString;
begin
  LMediumText := UTF8Encode(AText);

  LCount := Length(LMediumText);
  if LCount > 65535 then
    LCount := 65535;

  if (AMaxCount > 0) and (AMaxCount < LCount) then
    LCount := AMaxCount;

  PutWord(LCount);

  Write(Pointer(LMediumText)^, LCount);
end;

function TStreamHelper.GetMediumString: UniString;
var
  LCount: Integer;
  LMediumText: AnsiString;
begin
  LCount := GetWord;
  SetLength(LMediumText, LCount);

  if Read(Pointer(LMediumText)^, LCount) <> LCount then
    Exit('');

{$IFDEF FPC}
  Result := UTF8Decode(LMediumText);
{$ELSE}
  Result := UTF8ToWideString(LMediumText);
{$IFEND}
end;

procedure TStreamHelper.PutLongString(const AText: UniString);
var
  LCount: Integer;
  LLongText: AnsiString;
begin
  LLongText := UTF8Encode(AText);

  LCount := Length(LLongText);
  PutLongInt(LCount);

  Write(Pointer(LLongText)^, LCount);
end;

function TStreamHelper.GetLongString: UniString;
var
  LCount: Integer;
  LLongText: AnsiString;
begin
  LCount := GetLongInt;
  SetLength(LLongText, LCount);

  if Read(Pointer(LLongText)^, LCount) <> LCount then
    Exit('');

{$IFDEF FPC}
  Result := UTF8Decode(LLongText);
{$ELSE}
  Result := UTF8ToWideString(LLongText);
{$IFEND}
end;

{$ENDIF}
{$ENDREGION}

end.

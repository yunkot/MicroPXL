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

{$IFDEF INTERFACE}
type
  TCharSet = set of StdChar;

procedure FreeAndNil(var AObject);
function Min(const AValue1, AValue2: LongInt): LongInt; overload; inline;
function Min(const AValue1, AValue2: Int64): Int64; overload; inline;
function Min(const AValue1, AValue2: Single): Single; overload; inline;
function Min(const AValue1, AValue2: Double): Double; overload; inline;
function Max(const AValue1, AValue2: LongInt): LongInt; overload; inline;
function Max(const AValue1, AValue2: Int64): Int64; overload; inline;
function Max(const AValue1, AValue2: Single): Single; overload; inline;
function Max(const AValue1, AValue2: Double): Double; overload; inline;
function Hypot(const AValue1, AValue2: Extended): Extended; overload;
function ArcTan2(const AY, AX: Extended): Extended;
function ArcSin(const AValue: Extended): Extended;
function ArcCos(const AValue: Extended): Extended;
procedure SinCos(const AAngle: Single; out ASinValue, ACosValue: Single); overload;
procedure SinCos(const AAngle: Double; out ASinValue, ACosValue: Double); overload;
function Cot(const AValue: Extended): Extended;
function IntToStr(const AValue: LongInt): StdString;
function IntToHex(AValue, ADigits: Integer): StdString;
function PosEx(const AChar: StdChar; const AText: StdString; const AStartPos: Integer): Integer;
function StrToIntDef(const AText: StdString; const ADefaultValue: LongInt): LongInt;

function StrPCopy(const ADest: PStdChar; const ASource: StdString;
  const AMaxLength: Integer = 0): PStdChar; overload;
{$IF SIZEOF(StdChar) <> SIZEOF(UniChar)}
function StrPCopy(const ADest: PUniChar; const ASource: UniString;
  const AMaxLength: Integer = 0): PUniChar; overload;
{$ENDIF}

function CompareText(const AText1, AText2: StdString): Integer; overload;
{$IF SIZEOF(StdChar) <> SIZEOF(UniChar)}
function CompareText(const AText1, AText2: UniString): Integer; overload;
{$ENDIF}

function SameText(const AText1, AText2: StdString): Boolean; overload; inline;
{$IF SIZEOF(StdChar) <> SIZEOF(UniChar)}
function SameText(const AText1, AText2: UniString): Boolean; overload; inline;
{$ENDIF}

{$IF SIZEOF(StdChar) = 1}
function CharInSet(const AChar: StdChar; const ACharSet: TCharSet): Boolean; overload;
{$ENDIF}
function CharInSet(const AChar: UniChar; const ACharSet: TCharSet): Boolean; overload;

function ExtractFileExt(const AFileName: StdString): StdString; overload;
{$IF SIZEOF(StdChar) <> SIZEOF(UniChar)}
function ExtractFileExt(const AFileName: UniString): UniString; overload;
{$ENDIF}

function CompareMem(const AData1, AData2: Pointer; ADataLength: Integer): Boolean;

{$ENDIF}

{$IFDEF IMPLEMENTATION}
procedure FreeAndNil(var AObject);
var
  LTemp: TObject;
begin
  LTemp := TObject(AObject);
  Pointer(AObject) := nil;
  LTemp.Free;
end;

function Min(const AValue1, AValue2: LongInt): LongInt;
begin
  if AValue1 <= AValue2 then
    Result := AValue1
  else
    Result := AValue2;
end;

function Min(const AValue1, AValue2: Int64): Int64;
begin
  if AValue1 <= AValue2 then
    Result := AValue1
  else
    Result := AValue2;
end;

function Min(const AValue1, AValue2: Single): Single;
begin
  if AValue1 <= AValue2 then
    Result := AValue1
  else
    Result := AValue2;
end;

function Min(const AValue1, AValue2: Double): Double;
begin
  if AValue1 <= AValue2 then
    Result := AValue1
  else
    Result := AValue2;
end;

function Max(const AValue1, AValue2: LongInt): LongInt;
begin
  if AValue1 >= AValue2 then
    Result := AValue1
  else
    Result := AValue2;
end;

function Max(const AValue1, AValue2: Int64): Int64;
begin
  if AValue1 >= AValue2 then
    Result := AValue1
  else
    Result := AValue2;
end;

function Max(const AValue1, AValue2: Single): Single;
begin
  if AValue1 >= AValue2 then
    Result := AValue1
  else
    Result := AValue2;
end;

function Max(const AValue1, AValue2: Double): Double;
begin
  if AValue1 >= AValue2 then
    Result := AValue1
  else
    Result := AValue2;
end;

function Hypot(const AValue1, AValue2: Extended): Extended;
begin
  Result := Sqrt(AValue1 * AValue1 + AValue2 * AValue2);
end;

function ArcTan2(const AY, AX: Extended): Extended;
begin
  if AX = 0.0 then
  begin
    if AY > 0.0 then
      Result := Pi * 0.5
    else if AY < 0.0 then
      Result := -Pi * 0.5
    else
      Result := 0.0;
  end
  else
    Result := ArcTan(AY / AX);

  if AX < 0.0 then
    Result := Result + Pi;

  if Result > Pi then
    Result := Result - Pi * 2.0;
end;

function ArcSin(const AValue: Extended): Extended;
begin
  Result := ArcTan2(AValue, Sqrt((1.0 - AValue) * (1.0 + AValue)));
end;

function ArcCos(const AValue: Extended): Extended;
begin
  if Abs(AValue) >= 1.0 then
    if AValue < 0.0 then
      Result := Pi
    else
      Result := 0.0
  else
    Result := ArcTan2(Sqrt((1.0 - AValue) * (1.0 + AValue)), AValue);
end;

procedure SinCos(const AAngle: Single; out ASinValue, ACosValue: Single);
begin
  ASinValue := Sin(AAngle);
  ACosValue := Cos(AAngle);
end;

procedure SinCos(const AAngle: Double; out ASinValue, ACosValue: Double);
begin
  ASinValue := Sin(AAngle);
  ACosValue := Cos(AAngle);
end;

function Cot(const AValue: Extended): Extended;
begin
  Result := Cos(AValue) / Sin(AValue);
end;

function IntToStr(const AValue: LongInt): StdString;
var
  LTempValue, LDigits, I: Integer;
begin
  LDigits := 0;
  LTempValue := AValue;

  while LTempValue > 0 do
  begin
    LTempValue := LTempValue div 10;
    Inc(LDigits);
  end;

  SetLength(Result, LDigits);
  LTempValue := AValue;

  for I := 0 to LDigits - 1 do
  begin
    Result[LDigits - I] := Chr(Ord('0') + (LTempValue mod 10));
    LTempValue := LTempValue div 10;
  end;
end;

function IntToHex(AValue, ADigits: Integer): StdString;
const
  HexDigits: array[0..15] of StdChar = '0123456789ABCDEF';
var
  I: Integer;
begin
  if ADigits <= 0 then
    ADigits := 1;

  SetLength(Result, ADigits);
  for I := 0 to ADigits - 1 do
  begin
    Result[ADigits - I] := HexDigits[AValue and $0F];
    AValue := AValue shr 4;
  end;

  while AValue <> 0 do
  begin
    Result := HexDigits[AValue and $0F] + Result;
    AValue := AValue shr 4;
  end;
end;

function PosEx(const AChar: StdChar; const AText: StdString; const AStartPos: Integer): Integer;
var
  LCurPos: Integer;
begin
  LCurPos := AStartPos;

  while LCurPos <= Length(AText) do
  begin
    if AText[LCurPos] = AChar then
      Exit(LCurPos);

    Inc(LCurPos);
  end;

  Exit(-1);
end;

function StrToIntDef(const AText: StdString; const ADefaultValue: LongInt): LongInt;
var
  LConvRes: Integer;
begin
  Val(AText, Result, LConvRes);
  if LConvRes <> 0 then
    Result := ADefaultValue;
end;

function StrPCopy(const ADest: PStdChar; const ASource: StdString; const AMaxLength: Integer = 0): PStdChar;
var
  LCopyChars: Integer;
begin
  Result := ADest;
  if Result <> nil then
  begin
    LCopyChars := Length(ASource);
    if (AMaxLength > 0) and (LCopyChars > AMaxLength) then
      LCopyChars := AMaxLength;

    Move(ASource[1], ADest^, SizeOf(StdChar) * LCopyChars);
    PStdChar(PtrUInt(ADest) + Cardinal(LCopyChars) * SizeOf(StdChar))^ := #0;
  end;
end;

{$IF SIZEOF(StdChar) <> SIZEOF(UniChar)}
function StrPCopy(const ADest: PUniChar; const ASource: UniString; const AMaxLength: Integer = 0): PUniChar;
var
  LCopyChars: Integer;
begin
  Result := ADest;
  if Result <> nil then
  begin
    LCopyChars := Length(ASource);
    if (AMaxLength > 0) and (LCopyChars > AMaxLength) then
      LCopyChars := AMaxLength;

    Move(ASource[1], ADest^, SizeOf(UniChar) * LCopyChars);
    PUniChar(PtrUInt(ADest) + Cardinal(LCopyChars) * SizeOf(UniChar))^ := #0;
  end;
end;
{$ENDIF}

function CompareText(const AText1, AText2: StdString): Integer;
var
  LIndex, LCommonLength, LLength1, LLength2: Integer;
  LValue1, LValue2: Byte;
  LChar1, LChar2: PStdChar;
begin
  LLength1 := Length(AText1);
  LLength2 := Length(AText2);

  LCommonLength := Min(LLength1, LLength2);

  LValue1 := 0;
  LValue2 := 0;
  LIndex := 0;

  if LCommonLength > 0 then
  begin
    LChar1 := @AText1[1];
    LChar2 := @AText2[1];

    while LIndex < LCommonLength do
    begin
      LValue1 := Ord(LChar1^);
      LValue2 := Ord(LChar2^);

      if LValue1 <> LValue2 then
      begin
        if LValue1 in [97..122] then
          Dec(LValue1, 32);

        if LValue2 in [97..122] then
          Dec(LValue2, 32);

        if LValue1 <> LValue2 then
          Break;
      end;

      Inc(LChar1);
      Inc(LChar2);
      Inc(LIndex);
    end;
  end;

  if LIndex < LCommonLength then
    Result := LValue1 - LValue2
  else
    Result := LLength1 - LLength2;
end;

{$IF SIZEOF(StdChar) <> SIZEOF(UniChar)}
function CompareText(const AText1, AText2: UniString): Integer;
var
  LIndex, LCommonLength, LLength1, LLength2: Integer;
  LValue1, LValue2: Byte;
  LChar1, LChar2: PUniChar;
begin
  LLength1 := Length(AText1);
  LLength2 := Length(AText2);

  LCommonLength := Min(LLength1, LLength2);

  LValue1 := 0;
  LValue2 := 0;
  LIndex := 0;

  if LCommonLength > 0 then
  begin
    LChar1 := @AText1[1];
    LChar2 := @AText2[1];

    while LIndex < LCommonLength do
    begin
      LValue1 := Ord(LChar1^);
      LValue2 := Ord(LChar2^);

      if LValue1 <> LValue2 then
      begin
        if LValue1 in [97..122] then
          Dec(LValue1, 32);

        if LValue2 in [97..122] then
          Dec(LValue2, 32);

        if LValue1 <> LValue2 then
          Break;
      end;

      Inc(LChar1);
      Inc(LChar2);
      Inc(LIndex);
    end;
  end;

  if LIndex < LCommonLength then
    Result := LValue1 - LValue2
  else
    Result := LLength1 - LLength2;
end;
{$ENDIF}

function SameText(const AText1, AText2: StdString): Boolean;
begin
  Result := CompareText(AText1, AText2) = 0;
end;

{$IF SIZEOF(StdChar) <> SIZEOF(UniChar)}
function SameText(const AText1, AText2: UniString): Boolean;
begin
  Result := CompareText(AText1, AText2) = 0;
end;
{$ENDIF}

{$IF SIZEOF(StdChar) = 1}
function CharInSet(const AChar: StdChar; const ACharSet: TCharSet): Boolean; overload;
begin
  Result := AChar in ACharSet;
end;
{$ENDIF}

function CharInSet(const AChar: UniChar; const ACharSet: TCharSet): Boolean; overload;
begin
  Result := (Ord(AChar) <= 255) and (StdChar(AChar) in ACharSet);
end;

function ExtractFileExt(const AFileName: StdString): StdString;
const
  PathChars = ['/', '\'];
  StopChars = PathChars + [':', '.'];
var
  LCharPos: Integer;
begin
  Result := '';
  LCharPos := Length(AFileName);

  while (LCharPos > 0) and (not CharInSet(AFileName[LCharPos], StopChars)) do
    Dec(LCharPos);

  if (LCharPos > 1) and (AFileName[LCharPos] = '.') and (not CharInSet(AFileName[LCharPos - 1],
    PathChars)) then
    Result := Copy(AFileName, LCharPos, Length(AFileName));
end;

{$IF SIZEOF(StdChar) <> SIZEOF(UniChar)}
function ExtractFileExt(const AFileName: UniString): UniString;
const
  PathChars = ['/', '\'];
  StopChars = PathChars + [':', '.'];
var
  LCharPos: Integer;
begin
  Result := '';
  LCharPos := Length(AFileName);

  while (LCharPos > 0) and (not CharInSet(AFileName[LCharPos], StopChars)) do
    Dec(LCharPos);

  if (LCharPos > 1) and (AFileName[LCharPos] = '.') and (not CharInSet(AFileName[LCharPos - 1],
    PathChars)) then
    Result := Copy(AFileName, LCharPos, Length(AFileName));
end;
{$ENDIF}

function CompareMem(const AData1, AData2: Pointer; ADataLength: Integer): Boolean;
var
  I: Integer;
  LValue1, LValue2: PByte;
begin
  if ADataLength > 0 then
  begin
    LValue1 := AData1;
    LValue2 := AData2;

    for I := 0 to ADataLength - 1 do
    begin
      if LValue1^ <> LValue2^ then
        Exit(False);

      Inc(LValue1);
      Inc(LValue2);
    end;
  end;

  Result := True;
end;

{$ENDIF}

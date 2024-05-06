unit PXL.TypeDef;
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
{< General integer, floating-point and string types optimized for each platform that are used throughout the entire
  framework. }
interface

{$INCLUDE PXL.Config.inc}

type
{$IFNDEF FPC}
  {$IFDEF DELPHI_PRE_XE2}
    PtrInt = Integer;
    PtrUInt = Cardinal;
  {$ELSE}
    // Pointer type represented as a signed integer.
    PtrInt = NativeInt;

    // Pointer type represented as an unsigned integer.
    PtrUInt = NativeUInt;
  {$ENDIF}
{$ENDIF}

{$IFNDEF FPC}
  // Pointer to @link(SizeInt).
  PSizeInt = ^SizeInt;

  // Signed integer data type having the same size as pointer on the given platform.
  SizeInt = PtrInt;

  // Pointer to @link(SizeUInt).
  PSizeUInt = ^SizeUInt;

  // Unsigned integer data type having the same size as pointer on the given platform.
  SizeUInt = PtrUInt;
{$ENDIF}

  // Pointer to @link(SizeFloat).
  PSizeFloat = ^SizeFloat;

  // Floating-point data type that has the same size as @italic(Pointer) depending on each platform.
  // That is, on 32-bit platforms this is equivalent of @italic(Single), whereas on 64-bit platforms
  // this is equivalent of @italic(Double).
  SizeFloat = {$IFDEF CPUX64} Double {$ELSE} Single {$ENDIF};

  // Pointer to @link(UniString). It is not recommended to use pointer to strings, so this is mostly for
  // internal use only.
  PUniString = ^UniString;

  // General-purpose string type that is best optimized for Unicode usage. Typically, each character uses
  // UTF-16 encoding, but it may vary depending on platform.
  UniString = {$IFDEF DELPHI_LEGACY} WideString {$ELSE} {$IFDEF MSDOS} UTF8String {$ELSE} UnicodeString {$ENDIF} {$ENDIF};

  // Pointer to @link(StdString). It is not recommended to use pointer to strings, so this is mostly for
  // internal use only.
  PStdString = ^StdString;

  // General-purpose string type that is best optimized for standard usage such as file names, paths,
  // XML tags and attributes and so on. It may also contain Unicode-encoded text, either UTF-8 or UTF-16
  // depending on platform and compiler.
  StdString =
  {$IFDEF FPC}
    {$IFDEF MSDOS}
      ShortString
    {$ELSE}
      {$IFDEF EMBEDDED}
        RawByteString
      {$ELSE}
        UTF8String
      {$ENDIF}
    {$ENDIF}
  {$ELSE}
    string
  {$ENDIF};

  // Pointer to @link(StdChar).
  PStdChar = {$IFDEF DELPHI} PChar {$ELSE} ^StdChar {$ENDIF};

  // General-purpose character type optimized for standard usage and base element of @link(StdString).
  StdChar =
  {$IFDEF FPC}
    AnsiChar
  {$ELSE}
    {$IFDEF DELPHI_LEGACY}
      AnsiChar
    {$ELSE}
      Char
    {$ENDIF}
  {$ENDIF};

  // Pointer to @link(UniChar).
  PUniChar =
  {$IFDEF FPC}
    ^UniChar
  {$ELSE}
    {$IFDEF DELPHI_LEGACY}
      PWideChar
    {$ELSE}
      PChar
    {$ENDIF}
  {$ENDIF};

  // General-purpose character type optimized for Unicode usage and is base element of @link(UniString).
  UniChar =
  {$IFDEF FPC}
    {$IFDEF MSDOS} AnsiChar {$ELSE} WideChar {$ENDIF}
  {$ELSE}
    {$IFDEF DELPHI_LEGACY}
      WideChar
    {$ELSE}
      Char
    {$ENDIF}
  {$ENDIF};

  // Pointer to @link(TUntypedHandle).
  PUntypedHandle = ^TUntypedHandle;

  // Data type meant for storing cross-platform handles. This is a signed integer with the same size as
  // pointer on the given platform.
  TUntypedHandle = PtrInt;

const
  // A special value that determines precision limit when comparing vectors and coordinates.
  VectorEpsilon: Single {$IFNDEF PASDOC} = 0.00001{$ENDIF};

// Checks whether the Value is @nil and if not, calls FreeMem on that value and then assigns @nil to it.
procedure FreeMemAndNil(var AValue);

{$IFNDEF EMBEDDED}
// Saves the current FPU state to stack and increments internal stack pointer. The stack has length of 16.
// If the stack becomes full, this function does nothing.
procedure PushFPUState;
{$ENDIF}

{$IFNDEF EMBEDDED}
// Similarly to @link(PushFPUState), this saves the current FPU state to stack and increments internal stack
// pointer. Afterwards, this function disables all FPU exceptions. This is typically used with Direct3D
// rendering methods that require FPU exceptions to be disabled.
procedure PushClearFPUState;
{$ENDIF}

{$IFNDEF EMBEDDED}
// Recovers FPU state from the stack previously saved by @link(PushFPUState) or @link(PushClearFPUState) and
// decrements internal stack pointer. If there are no items on the stack, this function does nothing.
procedure PopFPUState;
{$ENDIF}

implementation

{$IFNDEF EMBEDDED}
uses
  Math;
{$ENDIF}

{$IFNDEF EMBEDDED}
const
  FPUStateStackLength = 16;
{$ENDIF}

{$IF NOT DEFINED(EMBEDDED) AND NOT DEFINED(DELPHI_XE2_UP)}
type
  TArithmeticExceptionMask = TFPUExceptionMask;

const
  exAllArithmeticExceptions = [exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision];
{$ENDIF}

{$IFNDEF EMBEDDED}
var
  FPUStateStack: array[0..FPUStateStackLength - 1] of TArithmeticExceptionMask;
  FPUStackAt: Integer = 0;
{$ENDIF}

procedure FreeMemAndNil(var AValue);
var
  LTempValue: Pointer;
begin
  if Pointer(AValue) <> nil then
  begin
    LTempValue := Pointer(AValue);
    Pointer(AValue) := nil;
    FreeMem(LTempValue);
  end;
end;

{$IFNDEF EMBEDDED}
procedure PushFPUState;
begin
  if FPUStackAt >= FPUStateStackLength then
    Exit;

  FPUStateStack[FPUStackAt] := GetExceptionMask;
  Inc(FPUStackAt);
end;
{$ENDIF}

{$IFNDEF EMBEDDED}
procedure PushClearFPUState;
begin
  PushFPUState;
  SetExceptionMask(exAllArithmeticExceptions);
end;
{$ENDIF}

{$IFNDEF EMBEDDED}
procedure PopFPUState;
begin
  if FPUStackAt <= 0 then
    Exit;

  Dec(FPUStackAt);

  SetExceptionMask(FPUStateStack[FPUStackAt]);
  FPUStateStack[FPUStackAt] := [];
end;
{$ENDIF}

end.

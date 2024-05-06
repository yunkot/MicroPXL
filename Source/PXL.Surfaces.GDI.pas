unit PXL.Surfaces.GDI;
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
  Windows, PXL.TypeDef, PXL.Types, PXL.Surfaces;

type
{$IFDEF FPC}{$PACKRECORDS C}{$ENDIF}
  TGDIBitmapInfo = record
    bmiHeader: BITMAPINFOHEADER;
    bmiColors: array[0..3] of DWORD;
  end;
{$IFDEF FPC}{$PACKRECORDS DEFAULT}{$ENDIF}

  TGDIPixelSurface = class(TPixelSurface)
  private
    FBitmapInfo: TGDIBitmapInfo;
    FBitmap: HBITMAP;
    FHandle: HDC;

    function CreateHandle: Boolean;
    procedure DestroyHandle;

    function CalculatePitch(const AWidth, ABitCount, AAlignment: Integer): Integer;

    function CreateBitmap(const AWidth, AHeight: Integer): Boolean;
    procedure DestroyBitmap;
  protected
    procedure ResetAllocation; override;
    function Reallocate(const AWidth, AHeight: Integer): Boolean; override;
  public
    procedure BitBlt(const ADestHandle: HDC; const ADestAt, ASize: TPoint;
      const ASrcAt: TPoint); overload;
    procedure BitBlt(const ADestSurface: TGDIPixelSurface; const ADestAt, ASize: TPoint;
      const ASrcAt: TPoint); overload; inline;

    property BitmapInfo: TGDIBitmapInfo read FBitmapInfo;
    property Bitmap: HBITMAP read FBitmap;
    property Handle: HDC read FHandle;
  end;

implementation

function TGDIPixelSurface.CreateHandle: Boolean;
begin
  if FHandle = 0 then
  begin
    FHandle := CreateCompatibleDC(0);
    if FHandle <> 0 then
      SetMapMode(FHandle, MM_TEXT);
  end;

  Result := FHandle <> 0;
end;

procedure TGDIPixelSurface.DestroyHandle;
begin
  if FHandle <> 0 then
  begin
    DeleteDC(FHandle);
    FHandle := 0;
  end;
end;

function TGDIPixelSurface.CalculatePitch(const AWidth, ABitCount, AAlignment: Integer): Integer;
begin
  Result := (((AWidth * ABitCount) + (AAlignment - 1)) and (not (AAlignment - 1))) div 8;
end;

function TGDIPixelSurface.CreateBitmap(const AWidth, AHeight: Integer): Boolean;
begin
  if FBitmap <> 0 then
    DeleteObject(FBitmap);

  FillChar(FBitmapInfo, SizeOf(TGDIBitmapInfo), 0);

  FBitmapInfo.bmiHeader.biSize := SizeOf(BITMAPINFOHEADER);
  FBitmapInfo.bmiHeader.biWidth := AWidth;
  FBitmapInfo.bmiHeader.biHeight := -AHeight;
  FBitmapInfo.bmiHeader.biPlanes := 1;
  FBitmapInfo.bmiHeader.biBitCount := 32;

  FBitmapInfo.bmiHeader.biCompression := BI_BITFIELDS;
  FBitmapInfo.bmiColors[0] := $000000FF;
  FBitmapInfo.bmiColors[1] := $0000FF00;
  FBitmapInfo.bmiColors[2] := $00FF0000;

  FBitmap := CreateDIBSection(FHandle, PBitmapInfo(@FBitmapInfo)^, DIB_RGB_COLORS, FBits, 0, 0);
  if FBitmap = 0 then
    Exit(False);

  FWidth := AWidth;
  FHeight := AHeight;
  FPitch := CalculatePitch(FWidth, 32, 32);
  FBufferSize := Cardinal(FHeight) * FPitch;

  SelectObject(FHandle, FBitmap);
  Result := True;
end;

procedure TGDIPixelSurface.DestroyBitmap;
begin
  if FBitmap <> 0 then
  begin
    DeleteObject(FBitmap);
    FBitmap := 0;
  end;
end;

procedure TGDIPixelSurface.ResetAllocation;
begin
  DestroyBitmap;
  DestroyHandle;

  FBits := nil;
  FPitch := 0;
  FWidth := 0;
  FHeight := 0;
  FBufferSize := 0;
end;

function TGDIPixelSurface.Reallocate(const AWidth, AHeight: Integer): Boolean;
begin
  if not CreateHandle then
    Exit(False);

  Result := CreateBitmap(AWidth, AHeight);
end;

procedure TGDIPixelSurface.BitBlt(const ADestHandle: HDC; const ADestAt, ASize, ASrcAt: TPoint);
begin
  if (ADestHandle <> 0) and (FHandle <> 0) then
    Windows.BitBlt(ADestHandle, ADestAt.X, ADestAt.Y, ASize.X, ASize.Y, FHandle, ASrcAt.X, ASrcAt.Y,
      SRCCOPY);
end;

procedure TGDIPixelSurface.BitBlt(const ADestSurface: TGDIPixelSurface; const ADestAt, ASize,
  ASrcAt: TPoint);
begin
  BitBlt(ADestSurface.Handle, ADestAt, ASize, ASrcAt);
end;

end.

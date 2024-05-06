unit PXL.Surfaces.LCL;
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
  Graphics, PXL.Types, PXL.Surfaces;

function LoadSurfaceFromBitmap(const ASurface: TPixelSurface; const ABitmap: TBitmap): Boolean;
function SaveSurfaceToBitmap(const ASurface: TPixelSurface; const ABitmap: TBitmap): Boolean;
function DrawSurfaceToCanvas(const ASurface: TPixelSurface; const ACanvas: TCanvas;
  const AX, AY: Integer): Boolean;

implementation

uses
  GraphType, FPImage, IntfGraphics;

function LoadSurfaceFromBitmap(const ASurface: TPixelSurface; const ABitmap: TBitmap): Boolean;
var
  LImage: TLazIntfImage;
  LSourcePixel: TFPColor;
  LDestPixel: PIntColor;
  I, J: Integer;
begin
  if (ABitmap = nil) or (ABitmap.Width < 1) or (ABitmap.Height < 1) then
    Exit(False);

  try
    LImage := ABitmap.CreateIntfImage;
    if (LImage = nil) or (LImage.Width < 1) or (LImage.Height < 1) then
      Exit(False);
    try
      ASurface.SetSize(LImage.Width, LImage.Height);

      for J := 0 to ASurface.Height - 1 do
      begin
        LDestPixel := ASurface.Scanline[J];

        for I := 0 to ASurface.Width - 1 do
        begin
          LSourcePixel := LImage.Colors[I, J];
          LDestPixel^ := TIntColor(LSourcePixel.red shr 8) or (TIntColor(LSourcePixel.green shr 8) shl 8) or
            (TIntColor(LSourcePixel.blue shr 8) shl 16) or (TIntColor(LSourcePixel.alpha shr 8) shl 24);

          Inc(LDestPixel);
        end;
      end;
    finally
      LImage.Free;
    end;
  except
    Exit(False);
  end;

  Result := True;
end;

function SaveSurfaceToBitmap(const ASurface: TPixelSurface; const ABitmap: TBitmap): Boolean;
var
  LImage: TLazIntfImage;
  LRawImage: TRawImage;
  LSourcePixel: PIntColor;
  LDestPixel: TFPColor;
  I, J: Integer;
begin
  if ASurface.Empty or (ABitmap = nil) then
    Exit(False);

  try
    LImage := TLazIntfImage.Create(0, 0);
    try
      LRawImage.Init;
      LRawImage.Description := GetDescriptionFromDevice(0, ASurface.Width, ASurface.Height);

      LRawImage.CreateData(False);
      LImage.SetRawImage(LRawImage);

      for J := 0 to ASurface.Height - 1 do
      begin
        LSourcePixel := ASurface.Scanline[J];

        for I := 0 to ASurface.Width - 1 do
        begin
          LDestPixel.red := (Integer(LSourcePixel^ and $FF) * $FFFF) div 255;
          LDestPixel.green := (Integer((LSourcePixel^ shr 8) and $FF) * $FFFF) div 255;
          LDestPixel.blue := (Integer((LSourcePixel^ shr 16) and $FF) * $FFFF) div 255;
          LDestPixel.alpha := (Integer((LSourcePixel^ shr 24) and $FF) * $FFFF) div 255;

          LImage.Colors[I, J] := LDestPixel;
          Inc(LSourcePixel);
        end;
      end;

      ABitmap.LoadFromIntfImage(LImage);
    finally
      LImage.Free;
    end;
  except
    Exit(False);
  end;

  Result := True;
end;

function DrawSurfaceToCanvas(const ASurface: TPixelSurface; const ACanvas: TCanvas;
  const AX, AY: Integer): Boolean;
var
  LBitmap: TBitmap;
begin
  if (ASurface = nil) or (ACanvas = nil) then
    Exit(False);

  ASurface.ResetAlpha({$IFDEF MSWINDOWS}False{$ELSE}True{$ENDIF});

  LBitmap := TBitmap.Create;
  try
    if not SaveSurfaceToBitmap(ASurface, LBitmap) then
      Exit(False);

    ACanvas.Draw(AX, AY, LBitmap);
  finally
    LBitmap.Free;
  end;
end;

end.

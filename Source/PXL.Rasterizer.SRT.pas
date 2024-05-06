unit PXL.Rasterizer.SRT;
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
{
  This triangle rasterization code is based on C/C++ affine texture mapping code, that was originally
  published long time ago in "fatmap2.zip" package by Mats Byggmastar, 1997.

  Initial Pascal translation and adaptation was made by Yuriy Kotsarenko in November 2007.

  The code has been rewritten to use vertex indices and avoid pointer math as much as possible, in addition
  to interpolating colors in August, 2015 by Yuriy Kotsarenko. "Inner loop" code is made with preference on
  stability rather the performance, guarding against possible access violations and overflows.
}
interface

{$INCLUDE PXL.Config.inc}

uses
  Types, PXL.TypeDef, PXL.Types, PXL.Surfaces;

// Renders colored and/or textured triangle on destination surface.
// Note that the vertices should be specified in anti-clockwise order.
procedure DrawTriangle(const ASurface: TConceptualPixelSurface; const ATexture: TPixelSurface; const APos1,
  APos2, APos3: TPointF; ATexPos1, ATexPos2, ATexPos3: TPointF; const AColor1, AColor2, AColor3: TIntColor;
  const AClipRect: TRect; const ABlendAdd: Boolean);

implementation

type
  TRasterInt = Integer;

  TRasterPoint = record
    X, Y: TRasterInt;
  end;

  TRasterColor = record
    R, G, B, A: TRasterInt;
  end;

  TRightSection = record
    VertexIndex: TRasterInt;
    X: TRasterInt;       // right edge X position
    Delta: TRasterInt;   // right edge X velocity (dx/dy)
    Height: TRasterInt;  // right section vertical height
  end;

  TLeftSection = record
    VertexIndex: TRasterInt;
    X: TRasterInt;       // left edge X position
    Delta: TRasterInt;   // left edge X velocity (dx/dy)
    Height: TRasterInt;  // left section vertical height
    TexCoord: TRasterPoint;
    TexCoordDelta: TRasterPoint; // du/dy, dv/dy
    Color: TRasterColor;
    ColorDelta: TRasterColor;
  end;

  TVertexPoint = record
    Position: TRasterPoint;
    TexCoord: TRasterPoint;
    Color: TRasterColor;
  end;

  TRasterSettings = record
    Textured: Boolean;
    Colored: Boolean;
    BlendAdd: Boolean;
    ClipRect: TRect;
  end;

  TVertices = array[0..2] of TVertexPoint;

function FixedCeil16(const AValue: TRasterInt): TRasterInt; inline;
begin
  Result := (AValue + 65535) div 65536;
end;

function FixedMultiply14(const AValue1, AValue2: TRasterInt): TRasterInt; inline;
begin
  Result := (Int64(AValue1) * AValue2) div 16384;
end;

function FixedMultiply16(const AValue1, AValue2: TRasterInt): TRasterInt; inline;
begin
  Result := (Int64(AValue1) * AValue2) div 65536;
end;

function FixedDivide16(const AValue1, AValue2: TRasterInt): TRasterInt; inline;
begin
  Result := (Int64(AValue1) * 65536) div AValue2;
end;

function FloatToFixed(const AValue: Single): TRasterInt; inline; overload;
begin
  Result := Round(AValue * 65536.0);
end;

function FloatToFixed(const APoint: TPointF): TRasterPoint; inline; overload;
begin
  Result.X := FloatToFixed(APoint.X);
  Result.Y := FloatToFixed(APoint.Y);
end;

function FloatToFixed(const AColor: TIntColor): TRasterColor; inline; overload;
begin
  Result.R := TRasterInt(AColor and $FF) * 65536;
  Result.G := TRasterInt((AColor shr 8) and $FF) * 65536;
  Result.B := TRasterInt((AColor shr 16) and $FF) * 65536;
  Result.A := TRasterInt((AColor shr 24) and $FF) * 65536;
end;

function FloatToFixedHalfShift(const APoint: TPointF): TRasterPoint; inline;
begin
  Result.X := FloatToFixed(APoint.X - 0.5);
  Result.Y := FloatToFixed(APoint.Y - 0.5);
end;

procedure RenderScanlineTexturedColored(const ASurface: TConceptualPixelSurface;
  const ATexture: TPixelSurface; const ALineWidth: TRasterInt; const ADestPos, ATexCoord,
  ATexCoordDelta: TRasterPoint; const AColor, AColorDelta: TRasterColor; const AClipRect: TRect;
  const ABlendAdd: Boolean);
var
  LSourceColor, LModulateColor: TIntColor;
  LCurPos: TRasterPoint;
  LCurColor: TRasterColor;
  I, LDestX, LAlpha: Integer;
begin
  LCurPos := ATexCoord;
  LCurColor := AColor;

  for I := 0 to ALineWidth - 1 do
  begin
    LDestX := ADestPos.X + I;

    if (LDestX >= AClipRect.Left) and (LDestX < AClipRect.Right) then
    begin
      LModulateColor := IntColorRGB(
        Saturate(LCurColor.R div 65536, 0, 255),
        Saturate(LCurColor.G div 65536, 0, 255),
        Saturate(LCurColor.B div 65536, 0, 255),
        Saturate(LCurColor.A div 65536, 0, 255));

      LSourceColor := MultiplyPixels(ATexture.Pixels[LCurPos.X div 65536, LCurPos.Y div 65536],
        LModulateColor);
      LAlpha := GetIntColorAlpha(LSourceColor);

      if LAlpha > 0 then
        if LAlpha < 255 then
          if not ABlendAdd then
            ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := BlendPixels(
              ASurface.PixelsUnsafe[LDestX, ADestPos.Y], LSourceColor, LAlpha)
          else
            ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := AddPixels(ASurface.PixelsUnsafe[LDestX, ADestPos.Y],
              PremultiplyAlpha(LSourceColor))
        else if not ABlendAdd then
          ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := LSourceColor
        else
          ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := AddPixels(ASurface.PixelsUnsafe[LDestX, ADestPos.Y],
            LSourceColor);
    end;

    Inc(LCurPos.X, ATexCoordDelta.X);
    Inc(LCurPos.Y, ATexCoordDelta.Y);

    Inc(LCurColor.R, AColorDelta.R);
    Inc(LCurColor.G, AColorDelta.G);
    Inc(LCurColor.B, AColorDelta.B);
    Inc(LCurColor.A, AColorDelta.A);
  end;
end;

procedure RenderScanlineTextured(const ASurface: TConceptualPixelSurface; const ATexture: TPixelSurface;
  const ALineWidth: TRasterInt; const ADestPos, ATexCoord, ATexCoordDelta: TRasterPoint;
  const AClipRect: TRect; const ABlendAdd: Boolean);
var
  LSourceColor: TIntColor;
  LCurPos: TRasterPoint;
  I, LDestX, LAlpha: Integer;
begin
  LCurPos := ATexCoord;

  for I := 0 to ALineWidth - 1 do
  begin
    LDestX := ADestPos.X + I;

    if (LDestX >= AClipRect.Left) and (LDestX < AClipRect.Right) then
    begin
      LSourceColor := ATexture.Pixels[LCurPos.X div 65536, LCurPos.Y div 65536];
      LAlpha := GetIntColorAlpha(LSourceColor);

      if LAlpha > 0 then
        if LAlpha < 255 then
          if not ABlendAdd then
            ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := BlendPixels(
              ASurface.PixelsUnsafe[LDestX, ADestPos.Y], LSourceColor, LAlpha)
          else
            ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := AddPixels(
              ASurface.PixelsUnsafe[LDestX, ADestPos.Y], PremultiplyAlpha(LSourceColor))
        else if not ABlendAdd then
          ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := LSourceColor
        else
          ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := AddPixels(ASurface.PixelsUnsafe[LDestX, ADestPos.Y],
            LSourceColor);
    end;

    Inc(LCurPos.X, ATexCoordDelta.X);
    Inc(LCurPos.Y, ATexCoordDelta.Y);
  end;
end;

procedure RenderScanlineColored(const ASurface: TConceptualPixelSurface; const ALineWidth: TRasterInt;
  const ADestPos: TRasterPoint; const AColor, AColorDelta: TRasterColor; const AClipRect: TRect;
  const ABlendAdd: Boolean);
var
  LSourceColor: TIntColor;
  LCurColor: TRasterColor;
  I, LDestX, LAlpha: Integer;
begin
  LCurColor := AColor;

  for I := 0 to ALineWidth - 1 do
  begin
    LDestX := ADestPos.X + I;

    if (LDestX >= AClipRect.Left) and (LDestX < AClipRect.Right) then
    begin
      LSourceColor := IntColorRGB(
        Saturate(LCurColor.R div 65536, 0, 255),
        Saturate(LCurColor.G div 65536, 0, 255),
        Saturate(LCurColor.B div 65536, 0, 255),
        Saturate(LCurColor.A div 65536, 0, 255));

      LAlpha := GetIntColorAlpha(LSourceColor);

      if LAlpha > 0 then
        if LAlpha < 255 then
          if not ABlendAdd then
            ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := BlendPixels(
              ASurface.PixelsUnsafe[LDestX, ADestPos.Y], LSourceColor, LAlpha)
          else
            ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := AddPixels(
              ASurface.PixelsUnsafe[LDestX, ADestPos.Y], PremultiplyAlpha(LSourceColor))
        else if not ABlendAdd then
          ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := LSourceColor
        else
          ASurface.PixelsUnsafe[LDestX, ADestPos.Y] := AddPixels(ASurface.PixelsUnsafe[LDestX, ADestPos.Y],
            LSourceColor);
    end;

    Inc(LCurColor.R, AColorDelta.R);
    Inc(LCurColor.G, AColorDelta.G);
    Inc(LCurColor.B, AColorDelta.B);
    Inc(LCurColor.A, AColorDelta.A);
  end;
end;

procedure UpdateRightSection(const AVertices: TVertices; var ASection: TRightSection);
var
  LPrevIndex, LFixedHeight, LFixedInvHeight, LPrestep: TRasterInt;
begin
  // Walk backwards trough the vertex array
  LPrevIndex := ASection.VertexIndex;

  if ASection.VertexIndex > 0 then
    ASection.VertexIndex := ASection.VertexIndex - 1
  else
    ASection.VertexIndex := 2;

  // Calculate number of scanlines in this Asection
  ASection.Height := FixedCeil16(AVertices[ASection.VertexIndex].Position.Y) -
    FixedCeil16(AVertices[LPrevIndex].Position.Y);

  if ASection.Height > 0 then
  begin
    // Guard against possible div overflows
    LFixedHeight := AVertices[ASection.VertexIndex].Position.Y - AVertices[LPrevIndex].Position.Y;

    if ASection.Height > 1 then
      // OK, no worries, we have a Asection that is at least one pixel high. Calculate slope as usual.
      ASection.Delta := FixedDivide16(AVertices[ASection.VertexIndex].Position.X -
        AVertices[LPrevIndex].Position.X, LFixedHeight)
    else
    begin
      // FixedHeight is less or equal to one pixel.
      // Calculate slope = width * 1/LFixedheight using 18:14 bit precision to avoid overflows.
      LFixedInvHeight := ($10000 shl 14) div LFixedHeight;

      ASection.Delta := FixedMultiply14(AVertices[ASection.VertexIndex].Position.X -
        AVertices[LPrevIndex].Position.X, LFixedInvHeight);
    end;

    // Prestep initial values
    LPrestep := (FixedCeil16(AVertices[LPrevIndex].Position.Y) shl 16) - AVertices[LPrevIndex].Position.Y;
    ASection.X := AVertices[LPrevIndex].Position.X + FixedMultiply16(LPrestep, ASection.Delta);
  end;
end;

procedure UpdateLeftSection(const AVertices: TVertices; var ASection: TLeftSection;
  const ASettings: TRasterSettings);
var
  LPrevIndex, LFixedHeight, LFixedInvHeight, LPrestep: TRasterInt;
begin
  // Walk forward trough the vertex array
  LPrevIndex := ASection.VertexIndex;

  if ASection.VertexIndex < 2 then
    ASection.VertexIndex := ASection.VertexIndex + 1
  else
    ASection.VertexIndex := 0;

  // Calculate number of scanlines in this Asection
  ASection.Height := FixedCeil16(AVertices[ASection.VertexIndex].Position.Y) -
    FixedCeil16(AVertices[LPrevIndex].Position.Y);

  if ASection.Height > 0 then
  begin
    // Guard against possible div overflows
    LFixedHeight := AVertices[ASection.VertexIndex].Position.Y - AVertices[LPrevIndex].Position.Y;

    if ASection.Height > 1 then
    begin
      // OK, no worries, we have a section that is at least one pixel high. Calculate slope as usual.
      ASection.Delta := FixedDivide16(AVertices[ASection.VertexIndex].Position.X -
        AVertices[LPrevIndex].Position.X, LFixedHeight);

      if ASettings.Textured then
      begin
        ASection.TexCoordDelta.X := FixedDivide16(AVertices[ASection.VertexIndex].TexCoord.X -
          AVertices[LPrevIndex].TexCoord.X, LFixedHeight);

        ASection.TexCoordDelta.Y := FixedDivide16(AVertices[ASection.VertexIndex].TexCoord.Y -
          AVertices[LPrevIndex].TexCoord.Y, LFixedHeight);
      end;

      if ASettings.Colored then
      begin
        ASection.ColorDelta.R := FixedDivide16(AVertices[ASection.VertexIndex].Color.R -
          AVertices[LPrevIndex].Color.R, LFixedHeight);

        ASection.ColorDelta.G := FixedDivide16(AVertices[ASection.VertexIndex].Color.G -
          AVertices[LPrevIndex].Color.G, LFixedHeight);

        ASection.ColorDelta.B := FixedDivide16(AVertices[ASection.VertexIndex].Color.B -
          AVertices[LPrevIndex].Color.B, LFixedHeight);

        ASection.ColorDelta.A := FixedDivide16(AVertices[ASection.VertexIndex].Color.A -
          AVertices[LPrevIndex].Color.A, LFixedHeight);
      end;
    end
    else
    begin
      // FixedHeight is less or equal to one pixel.
      // Calculate slope = width * 1/FixedHeight using 18:14 bit precision to avoid overflows.
      LFixedInvHeight := ($10000 shl 14) div LFixedHeight;

      ASection.Delta := FixedMultiply14(AVertices[ASection.VertexIndex].Position.X -
        AVertices[LPrevIndex].Position.X, LFixedInvHeight);

      if ASettings.Textured then
      begin
        ASection.TexCoordDelta.X := FixedMultiply14(AVertices[ASection.VertexIndex].TexCoord.X -
          AVertices[LPrevIndex].TexCoord.X, LFixedInvHeight);

        ASection.TexCoordDelta.Y := FixedMultiply14(AVertices[ASection.VertexIndex].TexCoord.Y -
          AVertices[LPrevIndex].TexCoord.Y, LFixedInvHeight);
      end;

      if ASettings.Colored then
      begin
        ASection.ColorDelta.R := FixedMultiply14(AVertices[ASection.VertexIndex].Color.R -
          AVertices[LPrevIndex].Color.R, LFixedInvHeight);

        ASection.ColorDelta.G := FixedMultiply14(AVertices[ASection.VertexIndex].Color.G -
          AVertices[LPrevIndex].Color.G, LFixedInvHeight);

        ASection.ColorDelta.B := FixedMultiply14(AVertices[ASection.VertexIndex].Color.B -
          AVertices[LPrevIndex].Color.B, LFixedInvHeight);

        ASection.ColorDelta.A := FixedMultiply14(AVertices[ASection.VertexIndex].Color.A -
          AVertices[LPrevIndex].Color.A, LFixedInvHeight);
      end;
    end;

    // LPrestep initial values
    LPrestep := (FixedCeil16(AVertices[LPrevIndex].Position.Y) shl 16) - AVertices[LPrevIndex].Position.Y;
    ASection.X := AVertices[LPrevIndex].Position.X + FixedMultiply16(LPrestep, ASection.Delta);

    if ASettings.Textured then
    begin
      ASection.TexCoord.X := AVertices[LPrevIndex].TexCoord.X + FixedMultiply16(LPrestep,
        ASection.TexCoordDelta.X);
      ASection.TexCoord.Y := AVertices[LPrevIndex].TexCoord.Y + FixedMultiply16(LPrestep,
        ASection.TexCoordDelta.Y);
    end;

    if ASettings.Colored then
    begin
      ASection.Color.R := AVertices[LPrevIndex].Color.R + FixedMultiply16(LPrestep, ASection.ColorDelta.R);
      ASection.Color.G := AVertices[LPrevIndex].Color.G + FixedMultiply16(LPrestep, ASection.ColorDelta.G);
      ASection.Color.B := AVertices[LPrevIndex].Color.B + FixedMultiply16(LPrestep, ASection.ColorDelta.B);
      ASection.Color.A := AVertices[LPrevIndex].Color.A + FixedMultiply16(LPrestep, ASection.ColorDelta.A);
    end;
  end;
end;

procedure ComputePolyMargins(const AVertices: TVertices; out APolyTop, APolyBottom, AMinIndex,
  AMaxIndex: TRasterInt);
var
  I: TRasterInt;
begin
  APolyTop := AVertices[0].Position.Y;
  APolyBottom := AVertices[0].Position.Y;
  AMinIndex := 0;
  AMaxIndex := 0;

  for I := 1 to 2 do
  begin
    if AVertices[I].Position.Y < APolyTop then
    begin
      APolyTop := AVertices[I].Position.Y;
      AMinIndex := I;
    end;

    if AVertices[I].Position.Y > APolyBottom then
    begin
      APolyBottom := AVertices[I].Position.Y;
      AMaxIndex := I;
    end;
  end;
end;

procedure RasterizeTriangle(const Surface: TConceptualPixelSurface; const Texture: TPixelSurface;
  const Vertices: TVertices; const TexCoordDelta: TRasterPoint; const ColorDelta: TRasterColor;
  const Settings: TRasterSettings);
var
  PolyTop, PolyBottom, MinIndex, MaxIndex, LineWidth, Prestep: TRasterInt;
  DestPos, TexCoord: TRasterPoint;
  Color: TRasterColor;
  RightSection: TRightSection;
  LeftSection: TLeftSection;
begin
  ComputePolyMargins(Vertices, PolyTop, PolyBottom, MinIndex, MaxIndex);

  RightSection.VertexIndex := MinIndex;
  LeftSection.VertexIndex := MinIndex;

  // Search for the first usable right section
  repeat
    if RightSection.VertexIndex = MaxIndex then
      Exit;
    UpdateRightSection(Vertices, RightSection);
  until RightSection.Height > 0;

  // Search for the first usable left section
  repeat
    if LeftSection.VertexIndex = MaxIndex then
      Exit;
    UpdateLeftSection(Vertices, LeftSection, Settings);
  until LeftSection.Height > 0;

  DestPos.Y := FixedCeil16(PolyTop);

  while True do
  begin
    DestPos.X := FixedCeil16(LeftSection.X);
    LineWidth := FixedCeil16(RightSection.X) - DestPos.X;

    if (LineWidth > 0) and (DestPos.Y >= Settings.ClipRect.Top) and (DestPos.Y < Settings.ClipRect.Bottom) then
    begin
      // Prestep initial texture u,v
      Prestep := DestPos.X * 65536 - LeftSection.X;

      if Settings.Colored then
      begin
        Color.R := LeftSection.Color.R + FixedMultiply16(Prestep, ColorDelta.R);
        Color.G := LeftSection.Color.G + FixedMultiply16(Prestep, ColorDelta.G);
        Color.B := LeftSection.Color.B + FixedMultiply16(Prestep, ColorDelta.B);
        Color.A := LeftSection.Color.A + FixedMultiply16(Prestep, ColorDelta.A);
      end;

      if Settings.Textured then
      begin
        TexCoord.X := LeftSection.TexCoord.X + FixedMultiply16(Prestep, TexCoordDelta.X);
        TexCoord.Y := LeftSection.TexCoord.Y + FixedMultiply16(Prestep, TexCoordDelta.Y);

        if Settings.Colored then
          RenderScanlineTexturedColored(Surface, Texture, LineWidth, DestPos, TexCoord, TexCoordDelta, Color,
            ColorDelta, Settings.ClipRect, Settings.BlendAdd)
        else
          RenderScanlineTextured(Surface, Texture, LineWidth, DestPos, TexCoord, TexCoordDelta, Settings.ClipRect,
            Settings.BlendAdd);
      end
      else
        RenderScanlineColored(Surface, LineWidth, DestPos, Color, ColorDelta, Settings.ClipRect, Settings.BlendAdd);
    end;

    Inc(DestPos.Y);

    // Scan the right side
    Dec(RightSection.Height);
    if RightSection.Height <= 0 then // End of this section?
    begin
      repeat
        if RightSection.VertexIndex = MaxIndex then
          Exit;
        UpdateRightSection(Vertices, RightSection);
      until RightSection.Height > 0;
    end
    else
      Inc(RightSection.X, RightSection.Delta);

    // Scan the left side
    Dec(LeftSection.Height);
    if LeftSection.Height <= 0 then // End of this section?
    begin
      repeat
        if LeftSection.VertexIndex = MaxIndex then
          Exit;
        UpdateLeftSection(Vertices, LeftSection, Settings);
      until LeftSection.Height > 0;
    end
    else
    begin
      Inc(LeftSection.X, LeftSection.Delta);

      if Settings.Textured then
      begin
        Inc(LeftSection.TexCoord.X, LeftSection.TexCoordDelta.X);
        Inc(LeftSection.TexCoord.Y, LeftSection.TexCoordDelta.Y);
      end;

      if Settings.Colored then
      begin
        Inc(LeftSection.Color.R, LeftSection.ColorDelta.R);
        Inc(LeftSection.Color.G, LeftSection.ColorDelta.G);
        Inc(LeftSection.Color.B, LeftSection.ColorDelta.B);
        Inc(LeftSection.Color.A, LeftSection.ColorDelta.A);
      end;
    end;
  end;
end;

procedure DrawTriangle(const ASurface: TConceptualPixelSurface; const ATexture: TPixelSurface; const APos1,
  APos2, APos3: TPointF; ATexPos1, ATexPos2, ATexPos3: TPointF; const AColor1, AColor2, AColor3: TIntColor;
  const AClipRect: TRect; const ABlendAdd: Boolean);

  function CalculateDelta(const AValue1, AValue2, AValue3, APos1, APos2, APos3, AInvDenom: Single): Integer;
  begin
    Result := Round(((AValue1 - AValue3) * (APos2 - APos3) - (AValue2 - AValue3) * (APos1 - APos3)) *
      AInvDenom);
  end;

var
  LDenom, LInvDenom: Single;
  LTexCoordDelta: TRasterPoint;
  LColorDelta: TRasterColor;
  LVertices: TVertices;
  LSettings: TRasterSettings;
begin
  if ATexture <> nil then
  begin
    ATexPos1 := MultiplyPointF(ATexPos1, PointF(ATexture.Width, ATexture.Height));
    ATexPos2 := MultiplyPointF(ATexPos2, PointF(ATexture.Width, ATexture.Height));
    ATexPos3 := MultiplyPointF(ATexPos3, PointF(ATexture.Width, ATexture.Height));
  end;

  LDenom := (APos1.X - APos3.X) * (APos2.Y - APos3.Y) - (APos2.X - APos3.X) * (APos1.Y - APos3.Y);
  if Abs(LDenom) <= VectorEpsilon then
    Exit;

  LSettings.ClipRect := AClipRect;
  LSettings.Textured := ATexture <> nil;
  LSettings.BlendAdd := ABlendAdd;

  if (AColor1 = AColor2) and (AColor2 = AColor3) and (AColor1 = IntColorWhite) and (ATexture <> nil) then
    LSettings.Colored := False
  else
    LSettings.Colored := True;

  LVertices[0].Position := FloatToFixedHalfShift(APos1);
  LVertices[1].Position := FloatToFixedHalfShift(APos2);
  LVertices[2].Position := FloatToFixedHalfShift(APos3);

  LInvDenom := 1.0 / LDenom * 65536.0;

  if LSettings.Textured then
  begin
    LVertices[0].TexCoord := FloatToFixed(ATexPos1);
    LVertices[1].TexCoord := FloatToFixed(ATexPos2);
    LVertices[2].TexCoord := FloatToFixed(ATexPos3);

    // Calculate du/dx, dv/dy.
    LTexCoordDelta.X := CalculateDelta(ATexPos1.X, ATexPos2.X, ATexPos3.X, APos1.Y, APos2.Y, APos3.Y,
      LInvDenom);
    LTexCoordDelta.Y := CalculateDelta(ATexPos1.Y, ATexPos2.Y, ATexPos3.Y, APos1.Y, APos2.Y, APos3.Y,
      LInvDenom);
  end;

  if LSettings.Colored then
  begin
    LVertices[0].Color := FloatToFixed(AColor1);
    LVertices[1].Color := FloatToFixed(AColor2);
    LVertices[2].Color := FloatToFixed(AColor3);

    LColorDelta.R := CalculateDelta(AColor1 and $FF, AColor2 and $FF, AColor3 and $FF,
      APos1.Y, APos2.Y, APos3.Y, LInvDenom);

    LColorDelta.G := CalculateDelta((AColor1 shr 8) and $FF, (AColor2 shr 8) and $FF, (AColor3 shr 8) and $FF,
      APos1.Y, APos2.Y, APos3.Y, LInvDenom);

    LColorDelta.B := CalculateDelta((AColor1 shr 16) and $FF, (AColor2 shr 16) and $FF,
      (AColor3 shr 16) and $FF, APos1.Y, APos2.Y, APos3.Y, LInvDenom);

    LColorDelta.A := CalculateDelta((AColor1 shr 24) and $FF, (AColor2 shr 24) and $FF,
      (AColor3 shr 24) and $FF, APos1.Y, APos2.Y, APos3.Y, LInvDenom);
  end;

  RasterizeTriangle(ASurface, ATexture, LVertices, LTexCoordDelta, LColorDelta, LSettings);
end;

end.

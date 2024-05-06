unit PXL.Canvas;
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
{< Canvas specification that can draw variety of shapes including lines, triangles, hexagons and images with
   different blending effects, colors and transparency. }
interface

{$INCLUDE PXL.Config.inc}

uses
  Types, PXL.TypeDef, PXL.Types, PXL.Surfaces;

type
  // Software-based canvas implementation that provides functions for rendering different lines, filled
  // shapes and images.
  TCanvas = class
  private
    FSurface: TConceptualPixelSurface;
    FClipRect: TRect;

    procedure SetSurface(const ASurface: TConceptualPixelSurface);
    procedure WuLineHorizontal(AX1, AY1, AX2, AY2: Single; const AColor1, AColor2: TIntColor);
    procedure WuLineVertical(AX1, AY1, AX2, AY2: Single; const AColor1, AColor2: TIntColor);
  public
    // Creates new instance of canvas bound to the specific device.
    constructor Create;

    // Draws a single pixel on the destination surface with the specified position and color (alpha-blended).
    // This method is considered basic functionality and should always be implemented by derived classes.
    procedure PutPixel(const APoint: TPointF; const AColor: TIntColor); overload;

    // Draws a single pixel on the destination surface with the specified coordinates and color
    // (alpha-blended).
    procedure PutPixel(const AX, AY: Single; const AColor: TIntColor); overload;

    // Draws line between two specified positions and filled with color gradient.
    // This method is considered basic functionality and should always be implemented by derived classes.
    procedure Line(const ASrcPoint, ADestPoint: TPointF; const AColor1, AColor2: TIntColor); overload;

    // Draws line between two specified positions and filled with single color.
    procedure Line(const ASrcPoint, ADestPoint: TPointF; const AColor: TIntColor); overload;

    // Draws line between specified coordinate pairs and filled with color gradient.
    procedure Line(const AX1, AY1, AX2, AY2: Single; const AColor1, AColor2: TIntColor); overload;

    // Draws line between specified coordinate pairs and filled with single color.
    procedure Line(const AX1, AY1, AX2, AY2: Single; const AColor: TIntColor); overload;

    // Draws series of lines between specified AVertices using solid color.
    procedure LineArray(const APoints: PPointF; const AElementCount: Integer; const AColor: TIntColor);

    // Draws antialiased "wu-line" using @link(PutPixel) primitive between specified positions filled with
    // single color.
    procedure WuLine(const APoint1, APoint2: TPointF; const AColor1, AColor2: TIntColor);

    // Draws ellipse with given origin, radiuses and color. This function uses @link(Line) primitive.
    // @code(ASteps) parameter indicates number of divisions in the ellipse. @code(AUseWuLines) indicates
    // whether to use @link(WuLine) primitive instead.
    procedure Ellipse(const AOrigin, ARadius: TPointF; const ASteps: Integer; const AColor: TIntColor;
      const AUseWuLines: Boolean = False);

    // Draws circle with given origin, radius and color. This function uses @link(Line) primitive.
    // @code(ASteps) parameter indicates number of divisions in the ellipse. @code(AUseWuLines) determines
    // whether to use @link(WuLine) primitive instead.
    procedure Circle(const AOrigin: TPointF; const ARadius: Single; const ASteps: Integer;
      const AColor: TIntColor; const AUseWuLines: Boolean = False);

    // Draws lines between the specified vertices (making it a wireframe quadrilateral) and vertex AColors.
    // Note that this may not necessarily respect last pixel rendering rule). This method uses @link(Line)
    // primitive. @code(AUseWuLines) determines whether to use @link(WuLine) primitive instead.
    procedure WireQuad(const APoints: TQuad; const AColors: TColorRect; const AUseWuLines: Boolean = False);

    // Draws one or more triangles filled with color gradient, specified by vertex, color and index buffers.
    // This method is considered basic functionality and should always be implemented by derived classes.
    procedure DrawIndexedTriangles(const AVertices: PPointF; const AColors: PIntColor;
      const AIndices: PLongInt; const AVertexCount, ATriangleCount: Integer; const AAdditive: Boolean = False);

    // Draws triangle filled with color gradient specified by given positions and colors.
    procedure FillTri(const APoint1, APoint2, APoint3: TPointF; const AColor1, AColor2, AColor3: TIntColor;
      const AAdditive: Boolean = False);

    // Draws quadrilateral with color gradient specified by given vertices and colors.
    procedure FillQuad(const APoints: TQuad; const AColors: TColorRect;
      const AAdditive: Boolean = False);

    // Draws rectangle with color gradient specified by given margins and colors.
    procedure FillRect(const ARect: TRectF; const AColors: TColorRect;
      const AAdditive: Boolean = False); overload;

    // Draws rectangle filled with single color and specified by given margins.
    procedure FillRect(const ARect: TRectF; const AColor: TIntColor;
      const AAdditive: Boolean = False); overload;

    // Draws rectangle filled with single clor and specified by given coordinates.
    procedure FillRect(const ALeft, ATop, AWidth, AHeight: Single; const AColor: TIntColor;
      const AAdditive: Boolean = False); overload;

    // Draws rectangle with line width of one pixel specified by given vertices and colors. Although this may
    // receive coordinates for shapes other than rectangle (for example, quadrilateral), the result may be
    // unpredictable. This method unlike other line drawing methods uses filled shapes and assumes that four
    // vertices are aligned to form rectangle. The produced result respects last pixel rule and can be used
    // for drawing UI elements (whereas methods like @link(WireQuad) may produce incorrectly sized rectangles
    // depending on implementation).
    procedure FrameRect(const APoints: TQuad; const AColors: TColorRect;
      const AAdditive: Boolean = False); overload;

    // Draws rectangle with line width of one pixel specified by given margins and colors. This works in
    // similar fashion as other overloaded @italic(FrameRect) method by drawing filled shapes instead of
    // lines, and is meant for rendering UI elements.
    procedure FrameRect(const ARect: TRectF; const AColors: TColorRect;
      const AAdditive: Boolean = False); overload;

    // Draws horizontal line with specified coordinates and color gradient. This method uses filled shapes
    // instead of actual lines to produce accurate results and is meant for rendering UI elements.
    procedure HorizLine(const ALeft, ATop, AWidth: Single; const AColor1, AColor2: TIntColor;
      const AAdditive: Boolean = False); overload;

    // Draws horizontal line with specified coordinates and single color. This method uses filled shapes
    // instead of actual lines to produce accurate results and is meant for rendering UI elements.
    procedure HorizLine(const ALeft, ATop, AWidth: Single; const AColor: TIntColor;
      const AAdditive: Boolean = False); overload;

    // Draws vertical line with specified coordinates and color gradient. This method uses filled shapes
    // instead of actual lines to produce accurate results and is meant for rendering UI elements.
    procedure VertLine(const ALeft, ATop, AHeight: Single; const AColor1, AColor2: TIntColor;
      const AAdditive: Boolean = False); overload;

    // Draws vertical line with specified coordinates and single color. This method uses filled shapes
    // instead of actual lines to produce accurate results and is meant for rendering UI elements.
    procedure VertLine(const ALeft, ATop, AHeight: Single; const AColor: TIntColor;
      const AAdditive: Boolean = False); overload;

    // Draws filled arc at the given position and radius. The arc begins at @code(AInitAngle) and ends at
    // @code(AEndAngle) (in radians), subdivided into a number of triangles specified in @code(ASteps).
    // The arc's shape is filled with four color gradient.
    procedure FillArc(const AOrigin, ARadius: TPointF; const AInitAngle, AEndAngle: Single;
      const ASteps: Integer; const AColors: TColorRect; const AAdditive: Boolean = False); overload;

    // Draws filled arc at the given coordinates and radius. The arc begins at @code(AInitAngle) and ends at
    // @code(AEndAngle) (in radians), subdivided into a number of triangles specified in @code(ASteps).
    // The arc's shape is filled with four color gradient.
    procedure FillArc(const AX, AY, ARadius, AInitAngle, AEndAngle: Single; const ASteps: Integer;
      const AColors: TColorRect; const AAdditive: Boolean = False); overload;

    // Draws filled ellipse at the given position and radius. The ellipse is subdivided into a number of
    // triangles specified in @code(ASteps). The shape of ellipse is filled with four color gradient.
    procedure FillEllipse(const AOrigin, ARadius: TPointF; ASteps: Integer; const AColors: TColorRect;
      const AAdditive: Boolean = False);

    // Draws filled circle at the given position and radius. The circle is subdivided into a number of
    // triangles specified in @code(ASteps). The shape of circle is filled with four color gradient.
    procedure FillCircle(AX, AY, ARadius: Single; ASteps: Integer; const AColors: TColorRect;
      const AAdditive: Boolean = False);

    // Draws filled ribbon at the given position between inner and outer radiuses. The ribbon begins at
    // @code(AInitAngle) and ends at @code(AEndAngle) (in radians), subdivided into a number of triangles
    // specified in @code(ASteps). The ribbon's shape is filled with four color gradient.
    procedure FillRibbon(const AOrigin, AInsideRadius, AOutsideRadius: TPointF; const AInitAngle,
      AEndAngle: Single; const ASteps: Integer; const AColors: TColorRect;
      const AAdditive: Boolean = False); overload;

    // Draws filled ribbon at the given position between inner and outer radiuses. The ribbon begins at
    // @code(AInitAngle) and ends at @code(AEndAngle) (in radians), subdivided into a number of triangles
    // specified in @code(ASteps). The ribbon's shape is filled with continuous gradient set by three pairs
    // of inner and outer colors.
    procedure FillRibbon(const AOrigin, AInsideRadius, AOutsideRadius: TPointF; const AInitAngle,
      AEndAngle: Single; const ASteps: Integer; const AInsideColor1, AInsideColor2, AInsideColor3,
      AOutsideColor1, AOutsideColor2, AOutsideColor3: TIntColor; const AAdditive: Boolean = False); overload;

    // Draws a filled rectangle at the given position and size with a hole (in form of ellipse) inside at
    // the given center and radius. The quality of the hole is defined by the value of @code(ASteps) in number
    // of subdivisions. This entire shape is filled with gradient starting from outer color at the edges of
    // rectangle and inner color ending at the edge of hole. This shape can be particularly useful for
    // highlighting items on the screen by darkening the entire area except the one inside the hole.
    procedure QuadHole(const AAreaTopLeft, AAreaSize, AHoleOrigin, AHoleRadius: TPointF;
      const AOutsideColor, AInsideColor: TIntColor; const ASteps: Integer; const AAdditive: Boolean = False);

    // Draws one or more triangles filled with texture and color gradient, specified by vertex, texture
    // coordinates, color and index buffers.This method is considered basic functionality and should always
    // be implemented by derived classes.
    procedure DrawTexturedTriangles(const ASurface: TPixelSurface; const AVertices, ATexCoords: PPointF;
      const AColors: PIntColor; const AIndices: PLongInt; const AVertexCount, ATriangleCount: Integer;
      const AAdditive: Boolean = False);

    // Draws textured rectangle at given vertices and multiplied by the specified four color gradient.
    // All pixels of the rendered texture are multiplied by the gradient color before applying
    // alpha-blending. If the texture has no alpha-channel present, alpha value of the gradient will be used
    // instead.
    procedure TexQuad(const ASurface: TPixelSurface; const AVertices, ATexCoords: TQuad;
      const AColors: TColorRect; const AAdditive: Boolean = False);

    // Draws textured rectangle at given vertices and multiplied by the specified four color gradient.
    // All pixels of the rendered texture are multiplied by the gradient color before applying
    // alpha-blending. If the texture has no alpha-channel present, alpha value of the gradient will be used
    // instead.
    procedure TexQuadPx(const ASurface: TPixelSurface; const AVertices, ATexCoords: TQuad;
      const AColors: TColorRect; const AAdditive: Boolean = False);

    // The clipping rectangle in which the rendering will be made. This can be useful for restricting the
    // rendering to a certain portion of surface.
    property ClipRect: TRect read FClipRect write FClipRect;

    // Surface, where rendering is to be performed to.
    property Surface: TConceptualPixelSurface read FSurface write SetSurface;
  end;

implementation

uses
  Math, PXL.Rasterizer.SRT;

{$REGION 'Global Functions'}

procedure SwapFloat(var AValue1, AValue2: Single);
var
  LTemp: Single;
begin
  LTemp := AValue1;
  AValue1 := AValue2;
  AValue2 := LTemp;
end;

{$ENDREGION}
{$REGION 'TCanvas'}

constructor TCanvas.Create;
begin
  inherited;
  FClipRect := Bounds(0, 0, 65535, 65535);
end;

procedure TCanvas.SetSurface(const ASurface: TConceptualPixelSurface);
begin
  if FSurface <> ASurface then
  begin
    FSurface := ASurface;

    if FSurface is TPixelSurface then
    begin
      FClipRect.Width := Min(FClipRect.Width, TPixelSurface(FSurface).Width);
      FClipRect.Height := Min(FClipRect.Height, TPixelSurface(FSurface).Height);
    end
    else if ASurface = nil then
      FClipRect := Bounds(0, 0, 65535, 65535);
  end;
end;

procedure TCanvas.PutPixel(const APoint: TPointF; const AColor: TIntColor);
var
  LIntPoint: TPoint;
begin
  if FSurface <> nil then
  begin
    LIntPoint := APoint.Round;
    if FClipRect.Contains(LIntPoint) then
      FSurface.DrawPixelUnsafe(LIntPoint, AColor);
  end;
end;

procedure TCanvas.PutPixel(const AX, AY: Single; const AColor: TIntColor);
begin
  PutPixel(PointF(AX, AY), AColor);
end;

procedure TCanvas.Line(const ASrcPoint, ADestPoint: TPointF; const AColor1, AColor2: TIntColor);
var
  LSrcPt, LDestPt, LDelta, LDrawPos: TPoint;
  LFixedPos, LFixedDelta, LInitialPos, I, LAlphaPos, LAlphaDelta: Integer;
begin
  LSrcPt := ASrcPoint.Round;
  LDestPt := ADestPoint.Round;
  LDelta.X := Abs(LDestPt.X - LSrcPt.X);
  LDelta.Y := Abs(LDestPt.Y - LSrcPt.Y);

  if (LDelta.X < 1) and (LDelta.Y < 1) then
  begin
    if FClipRect.Contains((MultiplyPointF((ASrcPoint + ADestPoint), 0.5)).Round) then
      FSurface.DrawPixelUnsafe(LSrcPt, AveragePixels(AColor1, AColor2));

    Exit;
  end;

  if LDelta.Y > LDelta.X then
  begin
    LInitialPos := LSrcPt.Y;
    LFixedDelta := Round((ADestPoint.X - ASrcPoint.X) * 65536.0) div LDelta.Y;
    LAlphaDelta := $FFFF div LDelta.Y;

    if LDestPt.Y < LInitialPos then
    begin
      LInitialPos := LDestPt.Y;

      LFixedPos :=  Round(ADestPoint.X * 65536.0);
      LFixedDelta := -LFixedDelta;

      LAlphaPos := $FFFF;
      LAlphaDelta := -LAlphaDelta;
    end
    else
    begin
      LFixedPos := Round(ASrcPoint.X * 65536.0);
      LAlphaPos := 0;
    end;

    for I := 0 to LDelta.Y - 1 do
    begin
      LDrawPos := Point(LFixedPos div 65536, LInitialPos + I);

      if FClipRect.Contains(LDrawPos) then
        FSurface.DrawPixelUnsafe(LDrawPos, BlendPixels(AColor1, AColor2, LAlphaPos div 256));

      Inc(LFixedPos, LFixedDelta);
      Inc(LAlphaPos, LAlphaDelta);
    end;
  end
  else
  begin
    LInitialPos := LSrcPt.X;
    LFixedDelta := Round((ADestPoint.Y - ASrcPoint.Y) * 65536.0) div LDelta.X;
    LAlphaDelta := $FFFF div LDelta.X;

    if LDestPt.X < LInitialPos then
    begin
      LInitialPos := LDestPt.X;

      LFixedPos :=  Round(ADestPoint.Y * 65536.0);
      LFixedDelta := -LFixedDelta;

      LAlphaPos := $FFFF;
      LAlphaDelta := -LAlphaDelta;
    end
    else
    begin
      LFixedPos := Round(ASrcPoint.Y * 65536.0);
      LAlphaPos := 0;
    end;

    for I := 0 to LDelta.X - 1 do
    begin
      LDrawPos := Point(LInitialPos + I, LFixedPos div 65536);

      if FClipRect.Contains(LDrawPos) then
        FSurface.DrawPixelUnsafe(LDrawPos, BlendPixels(AColor1, AColor2, LAlphaPos div 256));

      Inc(LFixedPos, LFixedDelta);
      Inc(LAlphaPos, LAlphaDelta);
    end;
  end;
end;

procedure TCanvas.Line(const ASrcPoint, ADestPoint: TPointF; const AColor: TIntColor);
begin
  Line(ASrcPoint, ADestPoint, AColor, AColor);
end;

procedure TCanvas.Line(const AX1, AY1, AX2, AY2: Single; const AColor1, AColor2: TIntColor);
begin
  Line(PointF(AX1, AY1), PointF(AX2, AY2), AColor1, AColor2);
end;

procedure TCanvas.Line(const AX1, AY1, AX2, AY2: Single; const AColor: TIntColor);
begin
  Line(PointF(AX1, AY1), PointF(AX2, AY2), AColor, AColor);
end;

procedure TCanvas.LineArray(const APoints: PPointF; const AElementCount: Integer;
  const AColor: TIntColor);
var
  I: Integer;
  LCurrentPoint, LNextPoint: PPointF;
begin
  LCurrentPoint := APoints;

  for I := 0 to AElementCount - 2 do
  begin
    LNextPoint := LCurrentPoint;
    Inc(LNextPoint);

    Line(LCurrentPoint^, LNextPoint^, AColor, AColor);
    LCurrentPoint := LNextPoint;
  end;
end;

procedure TCanvas.WuLineHorizontal(AX1, AY1, AX2, AY2: Single; const AColor1, AColor2: TIntColor);
var
  LTempColor: TIntColor;
  LDeltaX, LDeltaY, LGradient, LFinalY: Single;
  LEndX, LX, LIntX1, LIntX2, LIntY1, LIntY2: Integer;
  LEndY, LGapX, LLAlpha1, LAlpha2, LAlpha, LAlphaInc: Single;
begin
  LDeltaX := AX2 - AX1;
  LDeltaY := AY2 - AY1;

  if AX1 > AX2 then
  begin
    SwapFloat(AX1, AX2);
    SwapFloat(AY1, AY2);

    LDeltaX := AX2 - AX1;
    LDeltaY := AY2 - AY1;
  end;

  LGradient := LDeltaY / LDeltaX;

  // End APoint 1
  LEndX := Trunc(AX1 + 0.5);
  LEndY := AY1 + LGradient * (LEndX - AX1);

  LGapX := 1 - Frac(AX1 + 0.5);

  LIntX1 := LEndX;
  LIntY1 := Trunc(LEndY);

  LLAlpha1 := (1 - Frac(LEndY)) * LGapX;
  LAlpha2 := Frac(LEndY) * LGapX;

  PutPixel(PointF(LIntX1, LIntY1), IntColor(AColor1, LLAlpha1));
  PutPixel(PointF(LIntX1, LIntY1 + 1), IntColor(AColor1, LAlpha2));

  LFinalY := LEndY + LGradient;

  // End APoint 2
  LEndX := Trunc(AX2 + 0.5);
  LEndY := AY2 + LGradient * (LEndX - AX2);

  LGapX := 1 - Frac(AX2 + 0.5);

  LIntX2 := LEndX;
  LIntY2 := Trunc(LEndY);

  LLAlpha1 := (1 - Frac(LEndY)) * LGapX;
  LAlpha2 := Frac(LEndY) * LGapX;

  PutPixel(PointF(LIntX2, LIntY2), IntColor(AColor2, LLAlpha1));
  PutPixel(PointF(LIntX2, LIntY2 + 1), IntColor(AColor2, LAlpha2));

  LAlpha := 0;
  LAlphaInc := 1 / LDeltaX;

  // Main Loop
  for LX := LIntX1 + 1 to LIntX2 - 1 do
  begin
    LLAlpha1 := 1 - Frac(LFinalY);
    LAlpha2 := Frac(LFinalY);

    LTempColor := LerpPixels(AColor1, AColor2, LAlpha);

    PutPixel(PointF(LX, Int(LFinalY)), IntColor(LTempColor, LLAlpha1));
    PutPixel(PointF(LX, Int(LFinalY) + 1), IntColor(LTempColor, LAlpha2));

    LFinalY := LFinalY + LGradient;
    LAlpha := LAlpha + LAlphaInc;
  end;
end;

procedure TCanvas.WuLineVertical(AX1, AY1, AX2, AY2: Single; const AColor1, AColor2: TIntColor);
var
  LTempColor: TIntColor;
  LDeltaX, LDeltaY, LGradient, FinalX: Single;
  LEndY, Y, LIntX1, LIntX2, LIntY1, LIntY2: Integer;
  LEndX, yGap, LLAlpha1, LAlpha2, LAlpha, LAlphaInc: Single;
begin
  LDeltaX := AX2 - AX1;
  LDeltaY := AY2 - AY1;

  if AY1 > AY2 then
  begin
    SwapFloat(AX1, AX2);
    SwapFloat(AY1, AY2);

    LDeltaX := AX2 - AX1;
    LDeltaY := AY2 - AY1;
  end;

  LGradient := LDeltaX / LDeltaY;

  // End APoint 1
  LEndY := Trunc(AY1 + 0.5);
  LEndX := AX1 + LGradient * (LEndY - AY1);

  yGap := 1 - Frac(AY1 + 0.5);

  LIntX1 := Trunc(LEndX);
  LIntY1 := LEndY;

  LLAlpha1 := (1 - Frac(LEndX)) * yGap;
  LAlpha2 := Frac(LEndX) * yGap;

  PutPixel(PointF(LIntX1, LIntY1), IntColor(AColor1, LLAlpha1));
  PutPixel(PointF(LIntX1 + 1, LIntY1), IntColor(AColor1, LAlpha2));

  FinalX := LEndX + LGradient;

  // End APoint 2
  LEndY := Trunc(AY2 + 0.5);
  LEndX := AX2 + LGradient * (LEndY - AY2);

  yGap := 1 - Frac(AY2 + 0.5);

  LIntX2 := Trunc(LEndX);
  LIntY2 := LEndY;

  LLAlpha1 := (1 - Frac(LEndX)) * yGap;
  LAlpha2 := Frac(LEndX) * yGap;

  PutPixel(PointF(LIntX2, LIntY2), IntColor(AColor2, LLAlpha1));
  PutPixel(PointF(LIntX2 + 1, LIntY2), IntColor(AColor2, LAlpha2));

  LAlpha := 0;
  LAlphaInc := 1 / LDeltaY;

  // Main Loop
  for Y := LIntY1 + 1 to LIntY2 - 1 do
  begin
    LLAlpha1 := 1 - Frac(FinalX);
    LAlpha2 := Frac(FinalX);

    LTempColor := LerpPixels(AColor1, AColor2, LAlpha);

    PutPixel(PointF(Int(FinalX), Y), IntColor(LTempColor, LLAlpha1));
    PutPixel(PointF(Int(FinalX) + 1, Y), IntColor(LTempColor, LAlpha2));

    FinalX := FinalX + LGradient;
    LAlpha := LAlpha + LAlphaInc;
  end;
end;

procedure TCanvas.WuLine(const APoint1, APoint2: TPointF; const AColor1, AColor2: TIntColor);
begin
  if (Abs(APoint2.X - APoint1.X) > Abs(APoint2.Y - APoint1.Y)) then
    WuLineHorizontal(APoint1.X, APoint1.Y, APoint2.X, APoint2.Y, AColor1, AColor2)
  else
    WuLineVertical(APoint1.X, APoint1.Y, APoint2.X, APoint2.Y, AColor1, AColor2);
end;

procedure TCanvas.Ellipse(const AOrigin, ARadius: TPointF; const ASteps: Integer;
  const AColor: TIntColor; const AUseWuLines: Boolean);
var
  I: Integer;
  LVertex, LPreVertex: TPointF;
  LAlpha, LSinAlpha, LCosAlpha: Single;
begin
  LVertex := PointF(0.0, 0.0);

  for I := 0 to ASteps do
  begin
    LAlpha := I * (Pi * 2) / ASteps;

    LPreVertex := LVertex;

    SinCos(LAlpha, LSinAlpha, LCosAlpha);
    LVertex.X := Int(AOrigin.X + LCosAlpha * ARadius.X);
    LVertex.Y := Int(AOrigin.Y - LSinAlpha * ARadius.Y);

    if I > 0 then
    begin
      if AUseWuLines then
        WuLine(LPreVertex, LVertex, AColor, AColor)
      else
        Line(LPreVertex, LVertex, AColor, AColor);
    end;
  end;
end;

procedure TCanvas.Circle(const AOrigin: TPointF; const ARadius: Single; const ASteps: Integer;
  const AColor: TIntColor; const AUseWuLines: Boolean);
begin
  Ellipse(AOrigin, PointF(ARadius, ARadius), ASteps, AColor, AUseWuLines);
end;

procedure TCanvas.WireQuad(const APoints: TQuad; const AColors: TColorRect; const AUseWuLines: Boolean);
begin
  if AUseWuLines then
  begin
    WuLine(APoints.TopLeft, APoints.TopRight, AColors.TopLeft, AColors.TopRight);
    WuLine(APoints.TopRight, APoints.BottomRight, AColors.TopRight, AColors.BottomRight);
    WuLine(APoints.BottomRight, APoints.BottomLeft, AColors.BottomRight, AColors.BottomLeft);
    WuLine(APoints.BottomLeft, APoints.TopLeft, AColors.BottomLeft, AColors.TopLeft);
  end
  else
  begin
    Line(APoints.TopLeft, APoints.TopRight, AColors.TopLeft, AColors.TopRight);
    Line(APoints.TopRight, APoints.BottomRight, AColors.TopRight, AColors.BottomRight);
    Line(APoints.BottomRight, APoints.BottomLeft, AColors.BottomRight, AColors.BottomLeft);
    Line(APoints.BottomLeft, APoints.TopLeft, AColors.BottomLeft, AColors.TopLeft);
  end;
end;

procedure TCanvas.DrawIndexedTriangles(const AVertices: PPointF; const AColors: PIntColor;
  const AIndices: PLongInt; const AVertexCount, ATriangleCount: Integer; const AAdditive: Boolean);
var
  I: Integer;
  LIndex1, LIndex2, LIndex3: PLongInt;
  LVertex1, LVertex2, LVertex3: PPointF;
  LColor1, LColor2, LColor3: PIntColor;
  LDet: Single;
begin
  if (ATriangleCount < 1) or (AVertexCount < 3) or (FSurface = nil) then
    Exit;

  LIndex1 := AIndices;
  LIndex2 := Pointer(PtrInt(AIndices) + SizeOf(LongInt));
  LIndex3 := Pointer(PtrInt(AIndices) + 2 * SizeOf(LongInt));

  for I := 0 to ATriangleCount - 1 do
  begin
    LVertex1 := Pointer(PtrInt(AVertices) + LIndex1^ * SizeOf(TPointF));
    LVertex2 := Pointer(PtrInt(AVertices) + LIndex2^ * SizeOf(TPointF));
    LVertex3 := Pointer(PtrInt(AVertices) + LIndex3^ * SizeOf(TPointF));

    LColor1 := Pointer(PtrInt(AColors) + LIndex1^ * SizeOf(TIntColor));
    LColor2 := Pointer(PtrInt(AColors) + LIndex2^ * SizeOf(TIntColor));
    LColor3 := Pointer(PtrInt(AColors) + LIndex3^ * SizeOf(TIntColor));

    LDet := (LVertex1.X - LVertex3.X) * (LVertex2.Y - LVertex3.Y) - (LVertex2.X - LVertex3.X) * (LVertex1.Y - LVertex3.Y);
    if LDet > 0 then
      DrawTriangle(FSurface, nil, LVertex3^, LVertex2^, LVertex1^, PointF(0.0, 0.0), PointF(0.0, 0.0), PointF(0.0, 0.0), LColor3^, LColor2^,
        LColor1^, FClipRect, AAdditive)
    else
      DrawTriangle(FSurface, nil, LVertex1^, LVertex2^, LVertex3^, PointF(0.0, 0.0), PointF(0.0, 0.0), PointF(0.0, 0.0), LColor1^, LColor2^,
        LColor3^, FClipRect, AAdditive);

    LIndex1 := Pointer(PtrInt(LIndex1) + 3 * SizeOf(LongInt));
    LIndex2 := Pointer(PtrInt(LIndex2) + 3 * SizeOf(LongInt));
    LIndex3 := Pointer(PtrInt(LIndex3) + 3 * SizeOf(LongInt));
  end;
end;

procedure TCanvas.FillTri(const APoint1, APoint2, APoint3: TPointF; const AColor1, AColor2,
  AColor3: TIntColor; const AAdditive: Boolean);
const
  Indices: packed array[0..2] of LongInt = (0, 1, 2);
var
  LVertices: packed array[0..2] of TPointF;
  LColors: packed array[0..2] of TIntColor;
begin
  LVertices[0] := APoint1;
  LVertices[1] := APoint2;
  LVertices[2] := APoint3;

  LColors[0] := AColor1;
  LColors[1] := AColor2;
  LColors[2] := AColor3;

  DrawIndexedTriangles(@LVertices[0], @LColors[0], @Indices[0], 3, 1, AAdditive);
end;

procedure TCanvas.FillQuad(const APoints: TQuad; const AColors: TColorRect; const AAdditive: Boolean);
const
  Indices: packed array[0..5] of LongInt = (0, 1, 2, 2, 3, 0);
var
  LVertices: packed array[0..3] of TPointF;
  LVertexColors: packed array[0..3] of TIntColor;
begin
  LVertices[0] := APoints.TopLeft;
  LVertices[1] := APoints.TopRight;
  LVertices[2] := APoints.BottomRight;
  LVertices[3] := APoints.BottomLeft;

  LVertexColors[0] := AColors.TopLeft;
  LVertexColors[1] := AColors.TopRight;
  LVertexColors[2] := AColors.BottomRight;
  LVertexColors[3] := AColors.BottomLeft;

  DrawIndexedTriangles(@LVertices[0], @LVertexColors[0], @Indices[0], 4, 2, AAdditive);
end;

procedure TCanvas.FillRect(const ARect: TRectF; const AColors: TColorRect;
  const AAdditive: Boolean);
begin
  FillQuad(Quad(ARect), AColors, AAdditive);
end;

procedure TCanvas.FillRect(const ARect: TRectF; const AColor: TIntColor; const AAdditive: Boolean);
begin
  FillRect(ARect, ColorRect(AColor), AAdditive);
end;

procedure TCanvas.FillRect(const ALeft, ATop, AWidth, AHeight: Single; const AColor: TIntColor;
  const AAdditive: Boolean = False);
begin
  FillRect(BoundsF(ALeft, ATop, AWidth, AHeight), AColor, AAdditive);
end;

procedure TCanvas.FrameRect(const APoints: TQuad; const AColors: TColorRect;
  const AAdditive: Boolean);
const
  Indices: array [0..23] of LongInt = (0, 1, 4, 4, 1, 5, 1, 2, 5, 5, 2, 6, 2, 3, 6, 6, 3, 7, 3, 0, 7, 7, 0, 4);
var
  LVertices: array[0..7] of TPointF;
  LVertexColors: array[0..7] of TIntColor;
begin
  LVertices[0] := APoints.TopLeft;
  LVertices[1] := APoints.TopRight;
  LVertices[2] := APoints.BottomRight;
  LVertices[3] := APoints.BottomLeft;
  LVertices[4] := PointF(APoints.Values[0].X + 1.0, APoints.Values[0].Y + 1.0);
  LVertices[5] := PointF(APoints.Values[1].X - 1.0, APoints.Values[1].Y + 1.0);
  LVertices[6] := PointF(APoints.Values[2].X - 1.0, APoints.Values[2].Y - 1.0);
  LVertices[7] := PointF(APoints.Values[3].X + 1.0, APoints.Values[3].Y - 1.0);

  LVertexColors[0] := AColors.TopLeft;
  LVertexColors[1] := AColors.TopRight;
  LVertexColors[2] := AColors.BottomRight;
  LVertexColors[3] := AColors.BottomLeft;
  LVertexColors[4] := AColors.TopLeft;
  LVertexColors[5] := AColors.TopRight;
  LVertexColors[6] := AColors.BottomRight;
  LVertexColors[7] := AColors.BottomLeft;

  DrawIndexedTriangles(@LVertices[0], @LVertexColors[0], @Indices[0], 8, 8);
end;

procedure TCanvas.FrameRect(const ARect: TRectF; const AColors: TColorRect;
  const AAdditive: Boolean);
begin
  FrameRect(Quad(ARect), AColors, AAdditive);
end;

procedure TCanvas.HorizLine(const ALeft, ATop, AWidth: Single; const AColor1, AColor2: TIntColor;
  const AAdditive: Boolean);
begin
  FillQuad(Quad(ALeft, ATop, AWidth, 1.0), ColorRect(AColor1, AColor2, AColor2, AColor1), AAdditive);
end;

procedure TCanvas.HorizLine(const ALeft, ATop, AWidth: Single; const AColor: TIntColor;
  const AAdditive: Boolean);
begin
  HorizLine(ALeft, ATop, AWidth, AColor, AColor, AAdditive);
end;

procedure TCanvas.VertLine(const ALeft, ATop, AHeight: Single; const AColor1, AColor2: TIntColor;
  const AAdditive: Boolean);
begin
  FillQuad(Quad(ALeft, ATop, 1, AHeight), ColorRect(AColor1, AColor1, AColor2, AColor2), AAdditive);
end;

procedure TCanvas.VertLine(const ALeft, ATop, AHeight: Single; const AColor: TIntColor;
  const AAdditive: Boolean);
begin
  VertLine(ALeft, ATop, AHeight, AColor, AColor, AAdditive);
end;

procedure TCanvas.FillArc(const AOrigin, ARadius: TPointF; const AInitAngle, AEndAngle: Single;
  const ASteps: Integer; const AColors: TColorRect; const AAdditive: Boolean);
var
  LVertices: packed array of TPointF;
  LVertexColors: packed array of TIntColor;
  LIndices: packed array of LongInt;
  LMarginTopLeft, LMarginBottomRight: TPointF;
  I, LCurVertexCount, LAlphaX, LAlphaY: Integer;
  LAlpha, LSinAlpha, LCosAlpha: Single;
begin
  if ASteps < 1 then
    Exit;

  LMarginTopLeft := AOrigin - ARadius;
  LMarginBottomRight := AOrigin + ARadius;

  SetLength(LVertices, ASteps + 2);
  SetLength(LVertexColors, Length(LVertices));
  SetLength(LIndices, ASteps * 3);

  LCurVertexCount := 0;

  LVertices[LCurVertexCount] := AOrigin;
  LVertexColors[LCurVertexCount] := AveragePixels(AveragePixels(AColors.TopLeft, AColors.TopRight),
    AveragePixels(AColors.BottomRight, AColors.BottomLeft));
  Inc(LCurVertexCount);

  for I := 0 to ASteps - 1 do
  begin
    LAlpha := (I * (AEndAngle - AInitAngle) / ASteps) + AInitAngle;

    SinCos(LAlpha, LSinAlpha, LCosAlpha);
    LVertices[LCurVertexCount].X := AOrigin.X + LCosAlpha * ARadius.X;
    LVertices[LCurVertexCount].Y := AOrigin.Y - LSinAlpha * ARadius.Y;

    LAlphaX := Round((LVertices[LCurVertexCount].X - LMarginTopLeft.X) * 255.0 / (LMarginBottomRight.X -
      LMarginTopLeft.X));
    LAlphaY := Round((LVertices[LCurVertexCount].Y - LMarginTopLeft.Y) * 255.0 / (LMarginBottomRight.Y -
      LMarginTopLeft.Y));

    LVertexColors[LCurVertexCount] := BlendFourPixels(AColors.TopLeft, AColors.TopRight, AColors.BottomRight,
      AColors.BottomLeft, LAlphaX, LAlphaY);

    LIndices[(I * 3) + 0] := 0;
    LIndices[(I * 3) + 1] := LCurVertexCount;
    LIndices[(I * 3) + 2] := LCurVertexCount + 1;

    Inc(LCurVertexCount);
  end;

  SinCos(AEndAngle, LSinAlpha, LCosAlpha);
  LVertices[LCurVertexCount].X := AOrigin.X + LCosAlpha * ARadius.X;
  LVertices[LCurVertexCount].Y := AOrigin.Y - LSinAlpha * ARadius.Y;

  LAlphaX := Round((LVertices[LCurVertexCount].X - LMarginTopLeft.X) * 255.0 / (LMarginBottomRight.X -
    LMarginTopLeft.X));
  LAlphaY := Round((LVertices[LCurVertexCount].Y - LMarginTopLeft.Y) * 255.0 / (LMarginBottomRight.Y -
    LMarginTopLeft.Y));

  LVertexColors[LCurVertexCount] := BlendFourPixels(AColors.TopLeft, AColors.TopRight, AColors.BottomRight,
    AColors.BottomLeft, LAlphaX, LAlphaY);

  DrawIndexedTriangles(@LVertices[0], @LVertexColors[0], @LIndices[0], Length(LVertices), ASteps, AAdditive);
end;

procedure TCanvas.FillArc(const AX, AY, ARadius, AInitAngle, AEndAngle: Single; const ASteps: Integer;
  const AColors: TColorRect; const AAdditive: Boolean);
begin
  FillArc(PointF(AX, AY), PointF(ARadius, ARadius), AInitAngle, AEndAngle, ASteps, AColors, AAdditive);
end;

procedure TCanvas.FillEllipse(const AOrigin, ARadius: TPointF; ASteps: Integer;
  const AColors: TColorRect; const AAdditive: Boolean);
begin
  FillArc(AOrigin, ARadius, 0, Pi * 2.0, ASteps, AColors, AAdditive);
end;

procedure TCanvas.FillCircle(AX, AY, ARadius: Single; ASteps: Integer; const AColors: TColorRect;
  const AAdditive: Boolean);
begin
  FillArc(PointF(AX, AY), PointF(ARadius, ARadius), 0, Pi * 2.0, ASteps, AColors, AAdditive);
end;

procedure TCanvas.FillRibbon(const AOrigin, AInsideRadius, AOutsideRadius: TPointF; const AInitAngle,
  AEndAngle: Single; const ASteps: Integer; const AColors: TColorRect; const AAdditive: Boolean);
var
  LVertices: packed array of TPointF;
  LVertexColors: packed array of TIntColor;
  LIndices: packed array of LongInt;
  LMarginTopLeft, LMarginBottomRight: TPointF;
  I, LCurVertexCount, CurIndexCount, LAlphaX, LAlphaY: Integer;
  LAlpha, LSinAlpha, LCosAlpha: Single;
begin
  if ASteps < 1 then
    Exit;

  LMarginTopLeft := AOrigin - AOutsideRadius;
  LMarginBottomRight := AOrigin + AOutsideRadius;

  SetLength(LVertices, (ASteps * 2) + 2);
  SetLength(LVertexColors, Length(LVertices));
  SetLength(LIndices, ASteps * 6);

  LCurVertexCount := 0;

  SinCos(AInitAngle, LSinAlpha, LCosAlpha);

  LVertices[LCurVertexCount].X := AOrigin.X + (LCosAlpha * AInsideRadius.X);
  LVertices[LCurVertexCount].Y := AOrigin.Y - (LSinAlpha * AInsideRadius.Y);

  LAlphaX := Round((LVertices[LCurVertexCount].X - LMarginTopLeft.X) * 255.0 / (LMarginBottomRight.X -
    LMarginTopLeft.X));
  LAlphaY := Round((LVertices[LCurVertexCount].Y - LMarginTopLeft.Y) * 255.0 / (LMarginBottomRight.Y -
    LMarginTopLeft.Y));

  LVertexColors[LCurVertexCount] := BlendFourPixels(AColors.TopLeft, AColors.TopRight, AColors.BottomRight,
    AColors.BottomLeft, LAlphaX, LAlphaY);

  Inc(LCurVertexCount);

  LVertices[LCurVertexCount].X := AOrigin.X + (LCosAlpha * AOutsideRadius.X);
  LVertices[LCurVertexCount].Y := AOrigin.Y - (LSinAlpha * AOutsideRadius.Y);

  LAlphaX := Round((LVertices[LCurVertexCount].X - LMarginTopLeft.X) * 255.0 / (LMarginBottomRight.X -
    LMarginTopLeft.X));
  LAlphaY := Round((LVertices[LCurVertexCount].Y - LMarginTopLeft.Y) * 255.0 / (LMarginBottomRight.Y -
    LMarginTopLeft.Y));

  LVertexColors[LCurVertexCount] := BlendFourPixels(AColors.TopLeft, AColors.TopRight, AColors.BottomRight,
    AColors.BottomLeft, LAlphaX, LAlphaY);

  Inc(LCurVertexCount);

  for I := 1 to ASteps do
  begin
    LAlpha := (I * (AEndAngle - AInitAngle) / ASteps) + AInitAngle;
    SinCos(LAlpha, LSinAlpha, LCosAlpha);

    // Inner vertex
    LVertices[LCurVertexCount].X := AOrigin.X + (LCosAlpha * AInsideRadius.X);
    LVertices[LCurVertexCount].Y := AOrigin.Y - (LSinAlpha * AInsideRadius.Y);

    LAlphaX := Round((LVertices[LCurVertexCount].X - LMarginTopLeft.X) * 255.0 / (LMarginBottomRight.X -
      LMarginTopLeft.X));
    LAlphaY := Round((LVertices[LCurVertexCount].Y - LMarginTopLeft.Y) * 255.0 / (LMarginBottomRight.Y -
      LMarginTopLeft.Y));

    LVertexColors[LCurVertexCount] := BlendFourPixels(AColors.TopLeft, AColors.TopRight, AColors.BottomRight,
      AColors.BottomLeft, LAlphaX, LAlphaY);

    Inc(LCurVertexCount);

    // Outer vertex
    LVertices[LCurVertexCount].X := AOrigin.X + (LCosAlpha * AOutsideRadius.X);
    LVertices[LCurVertexCount].Y := AOrigin.Y - (LSinAlpha * AOutsideRadius.Y);

    LAlphaX := Round((LVertices[LCurVertexCount].X - LMarginTopLeft.X) * 255.0 / (LMarginBottomRight.X -
      LMarginTopLeft.X));
    LAlphaY := Round((LVertices[LCurVertexCount].Y - LMarginTopLeft.Y) * 255.0 / (LMarginBottomRight.Y -
      LMarginTopLeft.Y));

    LVertexColors[LCurVertexCount] := BlendFourPixels(AColors.TopLeft, AColors.TopRight, AColors.BottomRight,
      AColors.BottomLeft, LAlphaX, LAlphaY);

    Inc(LCurVertexCount);
  end;

  CurIndexCount := 0;
  for I := 0 to ASteps - 1 do
  begin
    LIndices[(I * 6) + 0] := CurIndexCount;
    LIndices[(I * 6) + 1] := CurIndexCount + 1;
    LIndices[(I * 6) + 2] := CurIndexCount + 2;

    LIndices[(I * 6) + 3] := CurIndexCount + 1;
    LIndices[(I * 6) + 4] := CurIndexCount + 3;
    LIndices[(I * 6) + 5] := CurIndexCount + 2;

    Inc(CurIndexCount, 2);
  end;

  DrawIndexedTriangles(@LVertices[0], @LVertexColors[0], @LIndices[0], Length(LVertices), ASteps * 2,
    AAdditive);
end;

procedure TCanvas.FillRibbon(const AOrigin, AInsideRadius, AOutsideRadius: TPointF; const AInitAngle,
  AEndAngle: Single; const ASteps: Integer; const AInsideColor1, AInsideColor2, AInsideColor3,
  AOutsideColor1, AOutsideColor2, AOutsideColor3: TIntColor; const AAdditive: Boolean);
var
  LVertices: packed array of TPointF;
  LVertexColors: packed array of TIntColor;
  LIndices: packed array of LongInt;
  LInsideColor, LOutsideColor: TIntColor;
  LAlpha, LTheta, LSinAlpha, LCosAlpha: Single;
  I, LCurVertexCount, LCurIndexCount: Integer;
begin
  if ASteps < 1 then
    Exit;

  SetLength(LVertices, (ASteps * 2) + 2);
  SetLength(LVertexColors, Length(LVertices));
  SetLength(LIndices, ASteps * 6);

  LCurVertexCount := 0;
  SinCos(AInitAngle, LSinAlpha, LCosAlpha);

  LVertices[LCurVertexCount].X := AOrigin.X + LCosAlpha * AInsideRadius.X;
  LVertices[LCurVertexCount].Y := AOrigin.Y - LSinAlpha * AInsideRadius.Y;
  LVertexColors[LCurVertexCount] := AInsideColor1;
  Inc(LCurVertexCount);

  LVertices[LCurVertexCount].X := AOrigin.X + LCosAlpha * AOutsideRadius.X;
  LVertices[LCurVertexCount].Y := AOrigin.Y - LSinAlpha * AOutsideRadius.Y;
  LVertexColors[LCurVertexCount] := AOutsideColor1;
  Inc(LCurVertexCount);

  for I := 1 to ASteps do
  begin
    LAlpha := (I * (AEndAngle - AInitAngle) / ASteps) + AInitAngle;
    SinCos(LAlpha, LSinAlpha, LCosAlpha);

    LTheta := I / ASteps;
    if LTheta < 0.5 then
    begin
      LTheta := 2.0 * LTheta;

      LInsideColor := LerpPixels(AInsideColor1, AInsideColor2, LTheta);
      LOutsideColor := LerpPixels(AOutsideColor1, AOutsideColor2, LTheta);
    end
    else
    begin
      LTheta := (LTheta - 0.5) * 2.0;

      LInsideColor := LerpPixels(AInsideColor2, AInsideColor3, LTheta);
      LOutsideColor := LerpPixels(AOutsideColor2, AOutsideColor3, LTheta);
    end;

    // Inner vertex
    LVertices[LCurVertexCount].X := AOrigin.X + LCosAlpha * AInsideRadius.X;
    LVertices[LCurVertexCount].Y := AOrigin.Y - LSinAlpha * AInsideRadius.Y;
    LVertexColors[LCurVertexCount] := LInsideColor;
    Inc(LCurVertexCount);

    // Outer vertex
    LVertices[LCurVertexCount].X := AOrigin.X + LCosAlpha * AOutsideRadius.X;
    LVertices[LCurVertexCount].Y := AOrigin.Y - LSinAlpha * AOutsideRadius.Y;
    LVertexColors[LCurVertexCount] := LOutsideColor;
    Inc(LCurVertexCount);
  end;

  LCurIndexCount := 0;
  for I := 0 to ASteps - 1 do
  begin
    LIndices[(I * 6) + 0] := LCurIndexCount;
    LIndices[(I * 6) + 1] := LCurIndexCount + 1;
    LIndices[(I * 6) + 2] := LCurIndexCount + 2;

    LIndices[(I * 6) + 3] := LCurIndexCount + 1;
    LIndices[(I * 6) + 4] := LCurIndexCount + 3;
    LIndices[(I * 6) + 5] := LCurIndexCount + 2;

    Inc(LCurIndexCount, 2);
  end;

  DrawIndexedTriangles(@LVertices[0], @LVertexColors[0], @LIndices[0], Length(LVertices), ASteps * 2,
    AAdditive);
end;

procedure TCanvas.QuadHole(const AAreaTopLeft, AAreaSize, AHoleOrigin, AHoleRadius: TPointF;
  const AOutsideColor, AInsideColor: TIntColor; const ASteps: Integer; const AAdditive: Boolean);
var
  LVertices: packed array of TPointF;
  LVertexColors: packed array of TIntColor;
  LIndices: packed array of LongInt;
  LTheta, LAngle, LSinAngle, LCosAngle: Single;
  I, LBaseIndex: Integer;
begin
  SetLength(LVertices, ASteps * 2);
  SetLength(LVertexColors, ASteps * 2);
  SetLength(LIndices, (ASteps - 1) * 6);

  for I := 0 to ASteps - 2 do
  begin
    LBaseIndex := I * 6;

    LIndices[LBaseIndex + 0] := I;
    LIndices[LBaseIndex + 1] := I + 1;
    LIndices[LBaseIndex + 2] := ASteps + I;

    LIndices[LBaseIndex + 3] := I + 1;
    LIndices[LBaseIndex + 4] := ASteps + I + 1;
    LIndices[LBaseIndex + 5] := ASteps + I;
  end;

  for I := 0 to ASteps - 1 do
  begin
    LTheta := I / (ASteps - 1);

    LVertices[I].X := AAreaTopLeft.X + LTheta * AAreaSize.X;
    LVertices[I].Y := AAreaTopLeft.Y;
    LVertexColors[I] := AOutsideColor;

    LAngle := Pi * 0.25 + Pi * 0.5 - LTheta * Pi * 0.5;
    SinCos(LAngle, LSinAngle, LCosAngle);

    LVertices[ASteps + I].X := AHoleOrigin.X + LCosAngle * AHoleRadius.X;
    LVertices[ASteps + I].Y := AHoleOrigin.Y - LSinAngle * AHoleRadius.Y;
    LVertexColors[ASteps + I] := AInsideColor;
  end;

  DrawIndexedTriangles(@LVertices[0], @LVertexColors[0], @LIndices[0], Length(LVertices),
    Length(LIndices) div 3, AAdditive);

  for I := 0 to ASteps - 1 do
  begin
    LTheta := I / (ASteps - 1);

    LVertices[I].X := AAreaTopLeft.X + AAreaSize.X;
    LVertices[I].Y := AAreaTopLeft.Y + LTheta * AAreaSize.Y;
    LVertexColors[I] := AOutsideColor;

    LAngle := Pi * 0.25 - LTheta * Pi * 0.5;
    SinCos(LAngle, LSinAngle, LCosAngle);

    LVertices[ASteps + I].X := AHoleOrigin.X + LCosAngle * AHoleRadius.X;
    LVertices[ASteps + I].Y := AHoleOrigin.Y - LSinAngle * AHoleRadius.Y;
    LVertexColors[ASteps + I] := AInsideColor;
  end;

  DrawIndexedTriangles(@LVertices[0], @LVertexColors[0], @LIndices[0], Length(LVertices),
    Length(LIndices) div 3, AAdditive);

  for I := 0 to ASteps - 1 do
  begin
    LTheta := I / (ASteps - 1);

    LVertices[I].X := AAreaTopLeft.X;
    LVertices[I].Y := AAreaTopLeft.Y + LTheta * AAreaSize.Y;
    LVertexColors[I] := AOutsideColor;

    LAngle := Pi * 0.75 + LTheta * Pi * 0.5;
    SinCos(LAngle, LSinAngle, LCosAngle);

    LVertices[ASteps + I].X := AHoleOrigin.X + LCosAngle * AHoleRadius.X;
    LVertices[ASteps + I].Y := AHoleOrigin.Y - LSinAngle * AHoleRadius.Y;
    LVertexColors[ASteps + I] := AInsideColor;
  end;

  DrawIndexedTriangles(@LVertices[0], @LVertexColors[0], @LIndices[0], Length(LVertices),
    Length(LIndices) div 3, AAdditive);

  for I := 0 to ASteps - 1 do
  begin
    LTheta := I / (ASteps - 1);

    LVertices[I].X := AAreaTopLeft.X + LTheta * AAreaSize.X;
    LVertices[I].Y := AAreaTopLeft.Y + AAreaSize.Y;
    LVertexColors[I] := AOutsideColor;

    LAngle := Pi * 1.25 + LTheta * Pi * 0.5;
    SinCos(LAngle, LSinAngle, LCosAngle);

    LVertices[ASteps + I].X := AHoleOrigin.X + LCosAngle * AHoleRadius.X;
    LVertices[ASteps + I].Y := AHoleOrigin.Y - LSinAngle * AHoleRadius.Y;
    LVertexColors[ASteps + I] := AInsideColor;
  end;

  DrawIndexedTriangles(@LVertices[0], @LVertexColors[0], @LIndices[0], Length(LVertices),
    Length(LIndices) div 3, AAdditive);
end;

procedure TCanvas.DrawTexturedTriangles(const ASurface: TPixelSurface; const AVertices,
  ATexCoords: PPointF; const AColors: PIntColor; const AIndices: PLongInt; const AVertexCount,
  ATriangleCount: Integer; const AAdditive: Boolean);
var
  I: Integer;
  LIndex1, LIndex2, LIndex3: PLongInt;
  LVertex1, LVertex2, LVertex3, LTexCoord1, LTexCoord2, LTexCoord3: PPointF;
  LColor1, LColor2, LColor3: PIntColor;
begin
  if (ATriangleCount < 1) or (AVertexCount < 3) or (ASurface = nil) or (FSurface = nil) then
    Exit;

  LIndex1 := AIndices;
  LIndex2 := Pointer(PtrInt(AIndices) + SizeOf(LongInt));
  LIndex3 := Pointer(PtrInt(AIndices) + 2 * SizeOf(LongInt));

  for I := 0 to ATriangleCount - 1 do
  begin
    LVertex1 := Pointer(PtrInt(AVertices) + LIndex1^ * SizeOf(TPointF));
    LVertex2 := Pointer(PtrInt(AVertices) + LIndex2^ * SizeOf(TPointF));
    LVertex3 := Pointer(PtrInt(AVertices) + LIndex3^ * SizeOf(TPointF));

    LTexCoord1 := Pointer(PtrInt(ATexCoords) + LIndex1^ * SizeOf(TPointF));
    LTexCoord2 := Pointer(PtrInt(ATexCoords) + LIndex2^ * SizeOf(TPointF));
    LTexCoord3 := Pointer(PtrInt(ATexCoords) + LIndex3^ * SizeOf(TPointF));

    LColor1 := Pointer(PtrInt(AColors) + LIndex1^ * SizeOf(TIntColor));
    LColor2 := Pointer(PtrInt(AColors) + LIndex2^ * SizeOf(TIntColor));
    LColor3 := Pointer(PtrInt(AColors) + LIndex3^ * SizeOf(TIntColor));

    DrawTriangle(FSurface, ASurface, LVertex3^, LVertex2^, LVertex1^, LTexCoord3^, LTexCoord2^, LTexCoord1^,
      LColor3^, LColor2^, LColor1^, FClipRect, AAdditive);

    LIndex1 := Pointer(PtrInt(LIndex1) + 3 * SizeOf(LongInt));
    LIndex2 := Pointer(PtrInt(LIndex2) + 3 * SizeOf(LongInt));
    LIndex3 := Pointer(PtrInt(LIndex3) + 3 * SizeOf(LongInt));
  end;
end;

procedure TCanvas.TexQuad(const ASurface: TPixelSurface; const AVertices, ATexCoords: TQuad;
  const AColors: TColorRect; const AAdditive: Boolean);
const
  Indices: packed array[0..5] of LongInt = (0, 1, 2, 2, 3, 0);
begin
  DrawTexturedTriangles(ASurface, @AVertices.Values[0], @ATexCoords.Values[0], @AColors.Values[0],
    @Indices[0], 4, 2, AAdditive);
end;

procedure TCanvas.TexQuadPx(const ASurface: TPixelSurface; const AVertices, ATexCoords: TQuad;
  const AColors: TColorRect; const AAdditive: Boolean);

  function PixelToLogical(const ASurface: TPixelSurface; const APosition: TPointF): TPointF; inline;
  begin
    if ASurface.Width > 0 then
      Result.X := APosition.X / ASurface.Width
    else
      Result.X := APosition.X;

    if ASurface.Height > 0 then
      Result.Y := APosition.Y / ASurface.Height
    else
      Result.Y := APosition.Y;
  end;

var
  LTexCoords: TQuad;
begin
  LTexCoords.TopLeft := PixelToLogical(ASurface, ATexCoords.TopLeft);
  LTexCoords.TopRight := PixelToLogical(ASurface, ATexCoords.TopRight);
  LTexCoords.BottomRight := PixelToLogical(ASurface, ATexCoords.BottomRight);
  LTexCoords.BottomLeft := PixelToLogical(ASurface, ATexCoords.BottomLeft);

  TexQuad(ASurface, AVertices, LTexCoords, AColors, AAdditive);
end;

{$ENDREGION}

end.

unit PXL.Types;
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
{< Essential types, constants and functions working with vectors, colors, pixels and rectangles that are
   used throughout the entire framework. }
interface

{$INCLUDE PXL.Config.inc}

uses
  PXL.TypeDef, Types;

{$REGION 'TIntColor'}

type
  // Pointer to @link(TIntColor).
  PIntColor = ^TIntColor;

  // General-purpose color value that is represented as 32-bit unsigned integer, with components allocated
  // according to @italic(TPixelFormat.A8R8G8B8) format.
  TIntColor = {$IFDEF NEXTGEN}Cardinal{$ELSE}LongWord{$ENDIF};

const
  // Predefined constant for opaque Black color.
  IntColorBlack = $FF000000;

  // Predefined constant for opaque White color.
  IntColorWhite = $FFFFFFFF;

  // Predefined constant for translucent Black color.
  IntColorTranslucentBlack = $00000000;

  // Predefined constant for translucent White color.
  IntColorTranslucentWhite = $00FFFFFF;

// Creates 32-bit RGBA color with the specified color value, having its alpha-channel multiplied by the
// specified coefficient and divided by 255.
function IntColor(const AColor: TIntColor; const AAlpha: Integer): TIntColor; overload; inline;

// Creates 32-bit RGBA color where the specified color value has its alpha-channel multiplied by the given
// coefficient.
function IntColor(const AColor: TIntColor; const AAlpha: Single): TIntColor; overload; inline;

// Creates 32-bit RGBA color using specified individual components for red, green, blue and alpha channel.
function IntColorRGB(const ARed, AGreen, ABlue: Integer; const AAlpha: Integer = 255): TIntColor; overload;

// Switches red and blue channels in 32-bit RGBA color value.
function DisplaceRB(const AColor: TIntColor): TIntColor;

// Inverts each of the components in the pixel, including alpha-channel.
function InvertPixel(const AColor: TIntColor): TIntColor;

// Takes 32-bit RGBA color with unpremultiplied alpha and multiplies each of red, green, and blue components
// by its alpha channel, resulting in premultiplied alpha color.
function PremultiplyAlpha(const AColor: TIntColor): TIntColor;

// Takes 32-bit RGBA color with premultiplied alpha channel and divides each of its red, green, and blue
// components by alpha, resulting in unpremultiplied alpha color.
function UnpremultiplyAlpha(const AColor: TIntColor): TIntColor;

// Adds two 32-bit RGBA color values together clamping the resulting values if necessary.
function AddPixels(const AColor1, AColor2: TIntColor): TIntColor;

// Multiplies two 32-bit RGBA color values together.
function MultiplyPixels(const AColor1, AColor2: TIntColor): TIntColor;

// Computes average of two given 32-bit RGBA color values.
function AveragePixels(const AColor1, AColor2: TIntColor): TIntColor;

// Computes alpha-blending for a pair of 32-bit RGBA colors values.
// @italic(AAlpha) can be in [0..255] range.
function BlendPixels(const AColor1, AColor2: TIntColor; const AAlpha: Integer): TIntColor;

// Computes resulting alpha-blended value between four 32-bit RGBA colors using linear interpolation.
// @italic(AAlphaX) and @italic(AAlphaY) can be in [0..255] range.
function BlendFourPixels(const ATopLeft, ATopRight, ABottomRight, ABottomLeft: TIntColor;
  const AAlphaX, AAlphaY: Integer): TIntColor;

// Computes alpha-blending for a pair of 32-bit RGBA colors values using floating-point approach.
// For a faster alternative, use @link(BlendPixels).
// @italic(AAlpha) can be in [0..1] range.
function LerpPixels(const AColor1, AColor2: TIntColor; const AAlpha: Single): TIntColor;

// Returns grayscale value in range of [0..255] from the given 32-bit RGBA color value. The resulting value
// can be considered the color's @italic(luma). The alpha-channel is ignored.
function PixelToGray(const AColor: TIntColor): Integer;

// Returns alpha value of the color.
function GetIntColorAlpha(const AColor: TIntColor): Integer;

{$ENDREGION}
{$REGION 'TColorRect'}

type
  // Pointer to @link(TColorRect).
  PColorRect = ^TColorRect;

  // A combination of four colors, primarily used for displaying colored quads, where each color corresponds
  // to top/left,top/right, bottom/right and bottom/left accordingly (clockwise). The format for specifying
  // colors is defined as @italic(TPixelFormat.A8R8G8B8).
  TColorRect = record
  public
    { @exclude } class operator Implicit(const AColor: TIntColor): TColorRect; inline;

    // Returns @True if at least one of four colors is different from others in red, green, blue or alpha
    // components.
    function HasGradient: Boolean;

    // Returns @True if at least one of the colors has non-zero alpha channel.
    function HasAlpha: Boolean;
  public
    case Cardinal of
      0: (// Color corresponding to top/left corner.
          TopLeft: TIntColor;
          // Color corresponding to top/right corner.
          TopRight: TIntColor;
          // Color corresponding to bottom/right corner.
          BottomRight: TIntColor;
          // Color corresponding to bottom/left corner.
          BottomLeft: TIntColor;
        );
      1: // Four colors represented as an array.
        (Values: array[0..3] of TIntColor);
  end;

const
  // Predefined constant for four opaque Black colors.
  ColorRectBlack: TColorRect = (TopLeft: $FF000000; TopRight: $FF000000; BottomRight: $FF000000;
    BottomLeft: $FF000000);

  // Predefined constant for four opaque White colors.
  ColorRectWhite: TColorRect = (TopLeft: $FFFFFFFF; TopRight: $FFFFFFFF; BottomRight: $FFFFFFFF;
    BottomLeft: $FFFFFFFF);

  // Predefined constant for four translucent Black colors.
  ColorRectTranslucentBlack: TColorRect = (TopLeft: $00000000; TopRight: $00000000; BottomRight: $00000000;
    BottomLeft: $00000000);

  // Predefined constant for four translucent White colors.
  ColorRectTranslucentWhite: TColorRect = (TopLeft: $00FFFFFF; TopRight: $00FFFFFF; BottomRight: $00FFFFFF;
    BottomLeft: $00FFFFFF);

// Creates a construct of four colors using individual components.
function ColorRect(const ATopLeft, ATopRight, ABottomRight, ABottomLeft: TIntColor): TColorRect; overload; inline;

// Creates a construct of four colors having the same component in each corner.
function ColorRect(const AColor: TIntColor): TColorRect; overload; inline;

{$ENDREGION}
{$REGION 'TQuad declarations'}

type
  // Pointer to @link(TQuad).
  PQuad = ^TQuad;

  // Special floating-point quadrilateral defined by four vertices starting from top/left in clockwise order.
  // This is typically used for rendering color filled and textured quads.
  TQuad = record
    { @exclude } class operator Equal(const ARect1, ARect2: TQuad): Boolean;
    { @exclude } class operator NotEqual(const ARect1, ARect2: TQuad): Boolean; inline;

    // Rescales vertices of the given quadrilateral by provided coefficient, optionally centering them around
    // zero origin.
    function Scale(const AScale: Single; const ACentered: Boolean = True): TQuad;

    // Creates quadrilateral from another quadrilateral but having left vertices exchanged with the right
    // ones, effectively mirroring it horizontally.
    function Mirror: TQuad;

    // Creates quadrilateral from another quadrilateral but having top vertices exchanged with the bottom
    // ones, effectively flipping it vertically.
    function Flip: TQuad;

    // Displaces vertices of given quadrilateral by the specified offset.
    function Offset(const ADelta: TPointF): TQuad; overload;

    // Displaces vertices of given quadrilateral by the specified displacement values.
    function Offset(const ADeltaX, ADeltaY: Single): TQuad; overload; inline;

    // Creates quadrilateral with the specified top left corner and the given dimensions, which are scaled by
    // the provided coefficient.
    class function Scaled(const ALeft, ATop, AWidth, AHeight, AScale: Single;
      const ACentered: Boolean = True): TQuad; static;

    // Creates quadrilateral specified by its dimensions. The rectangle is then rotated and scaled around the
    // given middle point (assumed to be inside rectangle's dimensions) and placed in center of the specified
    // origin.
    class function Rotated(const ARotationOrigin, ASize, ARotationCenter: TPointF; const AAngle: Single;
      const AScale: Single = 1.0): TQuad; overload; static;

    // Creates quadrilateral specified by its dimensions. The rectangle is then rotated and scaled around its
    // center and placed at the specified origin.
    class function Rotated(const ARotationOrigin, ASize: TPointF; const AAngle: Single;
      const AScale: Single = 1.0): TQuad; overload; static; inline;

    // Creates quadrilateral specified by top-left corner and size. The rectangle is then rotated and scaled
    // around the specified middle point (assumed to be inside rectangle's dimensions) and placed in the
    // center of the specified origin. The difference between this method and @link(Rotated) is that the
    // rotation does not preserve centering of the rectangle in case where middle point is not actually
    // located in the middle. }
    class function RotatedTL(const ATopLeft, ASize, ARotationCenter: TPointF; const AAngle: Single;
      const AScale: Single = 1.0): TQuad; static; inline;

    case Integer of
      0:( // Top/left vertex position.
          TopLeft: TPointF;
          // Top/right vertex position.
          TopRight: TPointF;
          // Bottom/right vertex position.
          BottomRight: TPointF;
          // Bottom/left vertex position.
          BottomLeft: TPointF;);
      1: // Quadrilateral vertices represented as an array. }
         (Values: array[0..3] of TPointF);
  end;

// Creates quadrilateral with individually specified vertex coordinates.
function Quad(const ATopLeftX, ATopLeftY, ATopRightX, ATopRightY, ABottomRightX, ABottomRightY, ABottomLeftX,
  ABottomLeftY: Single): TQuad; overload;

// Creates quadrilateral with individually specified vertices.
function Quad(const ATopLeft, ATopRight, ABottomRight, ABottomLeft: TPointF): TQuad; overload;

// Creates quadrilateral rectangle with ATop/ALeft position, AWidth and AHeight.
function Quad(const ALeft, ATop, AWidth, AHeight: Single): TQuad; overload;

// Creates quadrilateral rectangle from specified floating-point rectangle.
function Quad(const ARect: TRectF): TQuad; overload;

// Creates quadrilateral rectangle from specified integer rectangle.
function Quad(const ARect: TRect): TQuad; overload;

{$ENDREGION}
{$REGION 'Global declarations'}

// Interpolates between two values linearly, where @italic(ATheta) must be specified in [0..1] range.
function Lerp(const AValue1, AValue2, ATheta: Single): Single;
{$IFNDEF PASDOC} overload; {$ENDIF}

{$IF SIZEOF(Single) > 4} { @exclude }
function Lerp(const AValue1, AValue2, ATheta: Single): Single; overload;
{$ENDIF}

// Ensures that the given value stays within specified range limit, clamping it if necessary.
function Saturate(const AValue, AMinLimit, AMaxLimit: Single): Single; inline;
{$IFNDEF PASDOC} overload; {$ENDIF}

{$IF SIZEOF(Single) > 4} { @exclude }
function Saturate(const AValue, AMinLimit, AMaxLimit: Single): Single; overload; inline;
{$ENDIF}

// Ensures that the given value stays within specified range limit, clamping it if necessary.
function Saturate(const AValue, AMinLimit, AMaxLimit: Integer): Integer; inline;
{$IFNDEF PASDOC} overload; {$ENDIF}

{$IF SIZEOF(Integer) <> 4} { @exclude }
function Saturate(const AValue, AMinLimit, AMaxLimit: LongInt): LongInt; overload; inline;
{$ENDIF}

{$REGION 'TPointF and TRectF utilities'}

{$IFDEF FPC}

type
  // Compatibility workaround for FreePascal RTL.
  PPointF = ^TPointF;

{$ENDIF}

{$ENDREGION}

{$IFDEF FPC}
function PointF(const AX, AY: Single): TPointF; inline;
{$ENDIF}

// Creates rectangle based on top/left position, width and height.
function BoundsF(const ALeft, ATop, AWidth, AHeight: Single): TRectF; overload;

// Creates rectangle based on top/left position and size.
function BoundsF(const AOrigin, ASize: TPointF): TRectF; overload;

// Tests whether a rectangle is empty. This is a compatibility workaround for FreePascal RTL.
function IsEmptyRectF(const ARect: TRectF): Boolean; inline;

// Multiplies one 2D vector by another. This is a compability workaround for FreePascal RTL.
function MultiplyPointF(const ALeft, ARight: TPointF): TPointF; overload; inline;

// Multiplies one 2D vector by a constant. This is a compability workaround for older Delphi RTL.
function MultiplyPointF(const APoint: TPointF; const AScale: Single): TPointF; overload; inline;

// Interpolates between current and destination 2D vectors.
function Lerp(const APoint1, APoint2: TPointF; const ATheta: Single): TPointF; overload; inline;

// Takes source and destination sizes, source rectangle and destination position, then applies clipping to
// ensure that final rectangle stays within valid boundaries of both source and destination sizes.
function ClipCoords(const ASourceSize, ADestSize: TPoint; var ASourceRect: TRect;
  var ADestPos: TPoint): Boolean; overload;

// Takes source and destination sizes, source and destination rectangles, then applies clipping to ensure
// that final rectangle stays within valid boundaries of both source and destination sizes.
function ClipCoords(const ASourceSize, ADestSize: TPointF; var ASourceRect,
  ADestRect: TRectF): Boolean; overload;

{$ENDREGION}
{$REGION 'Embedded declarations'}

{$IFDEF EMBEDDED}
  {$DEFINE INTERFACE}
  {$INCLUDE 'PXL.Types.inc'}
  {$UNDEF INTERFACE}
{$ENDIF}

{$ENDREGION}

implementation

{$IFNDEF EMBEDDED}
uses
  Math;
{$ENDIF}

{$REGION 'Embedded declarations'}

{$IFDEF EMBEDDED}
  {$DEFINE IMPLEMENTATION}
  {$INCLUDE 'PXL.Types.inc'}
  {$UNDEF IMPLEMENTATION}
{$ENDIF}

{$ENDREGION}
{$REGION 'Global Functions'}

function Lerp(const AValue1, AValue2, ATheta: Single): Single;
begin
  Result := AValue1 + (AValue2 - AValue1) * ATheta;
end;

{$IF SIZEOF(Single) > 4}
function Lerp(const AValue1, AValue2, ATheta: Single): Single;
begin
  Result := AValue1 + (AValue2 - AValue1) * ATheta;
end;
{$ENDIF}

function Saturate(const AValue, AMinLimit, AMaxLimit: Single): Single;
begin
  Result := AValue;

  if Result < AMinLimit then
    Result := AMinLimit;

  if Result > AMaxLimit then
    Result := AMaxLimit;
end;

{$IF SIZEOF(Single) > 4}
function Saturate(const AValue, AMinLimit, AMaxLimit: Single): Single;
begin
  Result := AValue;

  if Result < AMinLimit then
    Result := AMinLimit;

  if Result > AMaxLimit then
    Result := AMaxLimit;
end;
{$ENDIF}

function Saturate(const AValue, AMinLimit, AMaxLimit: Integer): Integer;
begin
  Result := AValue;

  if Result < AMinLimit then
    Result := AMinLimit;

  if Result > AMaxLimit then
    Result := AMaxLimit;
end;

{$IF SIZEOF(Integer) <> 4}
function Saturate(const AValue, AMinLimit, AMaxLimit: LongInt): LongInt; overload;
begin
  Result := AValue;

  if Result < AMinLimit then
    Result := AMinLimit;

  if Result > AMaxLimit then
    Result := AMaxLimit;
end;
{$ENDIF}

{$IFDEF FPC}
function PointF(const AX, AY: Single): TPointF;
begin
  Result.X := AX;
  Result.Y := AY;
end;
{$ENDIF}

function BoundsF(const ALeft, ATop, AWidth, AHeight: Single): TRectF;
begin
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Right := ALeft + AWidth;
  Result.Bottom := ATop + AHeight;
end;

function BoundsF(const AOrigin, ASize: TPointF): TRectF;
begin
  Result.Left := AOrigin.X;
  Result.Top := AOrigin.Y;
  Result.Right := AOrigin.X + ASize.X;
  Result.Bottom := AOrigin.Y + ASize.Y;
end;

function IsEmptyRectF(const ARect: TRectF): Boolean;
begin
  Result := (ARect.Right < ARect.Left) or (ARect.Bottom < ARect.Top) or SameValue(ARect.Right, ARect.Left) or
    SameValue(ARect.Bottom, ARect.Top);
end;

function MultiplyPointF(const ALeft, ARight: TPointF): TPointF;
begin
  Result.X := ALeft.X * ARight.X;
  Result.Y := ALeft.Y * ARight.Y;
end;

function MultiplyPointF(const APoint: TPointF; const AScale: Single): TPointF;
begin
  Result.X := APoint.X * AScale;
  Result.Y := APoint.Y * AScale;
end;

function Lerp(const APoint1, APoint2: TPointF; const ATheta: Single): TPointF;
begin
  Result.X := APoint1.X + (APoint2.X - APoint1.X) * ATheta;
  Result.Y := APoint1.Y + (APoint2.Y - APoint1.Y) * ATheta;
end;

function ClipCoords(const ASourceSize, ADestSize: TPoint; var ASourceRect: TRect;
  var ADestPos: TPoint): Boolean;
var
  LDelta: Integer;
begin
  if ASourceRect.Left < 0 then
  begin
    LDelta := -ASourceRect.Left;
    Inc(ASourceRect.Left, LDelta);
    Inc(ADestPos.X, LDelta);
  end;

  if ASourceRect.Top < 0 then
  begin
    LDelta := -ASourceRect.Top;
    Inc(ASourceRect.Top, LDelta);
    Inc(ADestPos.Y, LDelta);
  end;

  if ASourceRect.Right > ASourceSize.X then
    ASourceRect.Right := ASourceSize.X;

  if ASourceRect.Bottom > ASourceSize.Y then
    ASourceRect.Bottom := ASourceSize.Y;

  if ADestPos.X < 0 then
  begin
    LDelta := -ADestPos.X;
    Inc(ADestPos.X, LDelta);
    Inc(ASourceRect.Left, LDelta);
  end;

  if ADestPos.Y < 0 then
  begin
    LDelta := -ADestPos.Y;
    Inc(ADestPos.Y, LDelta);
    Inc(ASourceRect.Top, LDelta);
  end;

  if ADestPos.X + ASourceRect.Width > ADestSize.X then
  begin
    LDelta := ADestPos.X + ASourceRect.Width - ADestSize.X;
    ASourceRect.Width := ASourceRect.Width - LDelta;
  end;

  if ADestPos.Y + ASourceRect.Height > ADestSize.Y then
  begin
    LDelta := ADestPos.Y + ASourceRect.Height - ADestSize.Y;
    ASourceRect.Height := ASourceRect.Height - LDelta;
  end;

  Result := not ASourceRect.IsEmpty;
end;

function ClipCoords(const ASourceSize, ADestSize: TPointF; var ASourceRect, ADestRect: TRectF): Boolean;
var
  LDelta: Single;
  LScale: TPointF;
begin
  if IsEmptyRectF(ASourceRect) or IsEmptyRectF(ADestRect) then
    Exit(False);

  LScale.X := ADestRect.Width / ASourceRect.Width;
  LScale.Y := ADestRect.Height / ASourceRect.Height;

  if ASourceRect.Left < 0 then
  begin
    LDelta := -ASourceRect.Left;
    ASourceRect.Left := ASourceRect.Left + LDelta;
    ADestRect.Left := ADestRect.Left + (LDelta * LScale.X);
  end;

  if ASourceRect.Top < 0 then
  begin
    LDelta := -ASourceRect.Top;
    ASourceRect.Top := ASourceRect.Top + LDelta;
    ADestRect.Top := ADestRect.Top + (LDelta * LScale.Y);
  end;

  if ASourceRect.Right > ASourceSize.X then
  begin
    LDelta := ASourceRect.Right - ASourceSize.X;
    ASourceRect.Right := ASourceRect.Right - LDelta;
    ADestRect.Right := ADestRect.Right - (LDelta * LScale.X);
  end;

  if ASourceRect.Bottom > ASourceSize.Y then
  begin
    LDelta := ASourceRect.Bottom - ASourceSize.Y;
    ASourceRect.Bottom := ASourceRect.Bottom - LDelta;
    ADestRect.Bottom := ADestRect.Bottom - (LDelta * LScale.Y);
  end;

  if ADestRect.Left < 0 then
  begin
    LDelta := -ADestRect.Left;
    ADestRect.Left := ADestRect.Left + LDelta;
    ASourceRect.Left := ASourceRect.Left + (LDelta / LScale.X);
  end;

  if ADestRect.Top < 0 then
  begin
    LDelta := -ADestRect.Top;
    ADestRect.Top := ADestRect.Top + LDelta;
    ASourceRect.Top := ASourceRect.Top + (LDelta / LScale.Y);
  end;

  if ADestRect.Right > ADestSize.X then
  begin
    LDelta := ADestRect.Right - ADestSize.X;
    ADestRect.Right := ADestRect.Right - LDelta;
    ASourceRect.Right := ASourceRect.Right - (LDelta / LScale.X);
  end;

  if ADestRect.Bottom > ADestSize.Y then
  begin
    LDelta := ADestRect.Bottom - ADestSize.Y;
    ADestRect.Bottom := ADestRect.Bottom - LDelta;
    ASourceRect.Bottom := ASourceRect.Bottom - (LDelta / LScale.Y);
  end;

  Result := (not IsEmptyRectF(ASourceRect)) and (not IsEmptyRectF(ADestRect));
end;

{$ENDREGION}
{$REGION 'TIntColor'}

function IntColor(const AColor: TIntColor; const AAlpha: Integer): TIntColor;
begin
  Result := (AColor and $00FFFFFF) or TIntColor((Integer(AColor shr 24) * AAlpha) div 255) shl 24;
end;

function IntColor(const AColor: TIntColor; const AAlpha: Single): TIntColor;
begin
  Result := IntColor(AColor, Integer(Round(AAlpha * 255.0)));
end;

function IntColorRGB(const ARed, AGreen, ABlue: Integer; const AAlpha: Integer = 255): TIntColor;
begin
  Result := TIntColor(ABlue) or (TIntColor(AGreen) shl 8) or (TIntColor(ARed) shl 16) or
    (TIntColor(AAlpha) shl 24);
end;

function DisplaceRB(const AColor: TIntColor): TIntColor;
begin
  Result := ((AColor and $FF) shl 16) or (AColor and $FF00FF00) or ((AColor shr 16) and $FF);
end;

function InvertPixel(const AColor: TIntColor): TIntColor;
begin
  Result := (255 - (AColor and $FF)) or ((255 - ((AColor shr 8) and $FF)) shl 8) or
    ((255 - ((AColor shr 16) and $FF)) shl 16) or ((255 - ((AColor shr 24) and $FF)) shl 24);
end;

function PremultiplyAlpha(const AColor: TIntColor): TIntColor;
begin
  Result :=
    (((AColor and $FF) * (AColor shr 24)) div 255) or
    (((((AColor shr 8) and $FF) * (AColor shr 24)) div 255) shl 8) or
    (((((AColor shr 16) and $FF) * (AColor shr 24)) div 255) shl 16) or
    (AColor and $FF000000);
end;

function UnpremultiplyAlpha(const AColor: TIntColor): TIntColor;
var
  AAlpha: Cardinal;
begin
  AAlpha := AColor shr 24;

  if AAlpha > 0 then
    Result := (((AColor and $FF) * 255) div AAlpha) or
      (((((AColor shr 8) and $FF) * 255) div AAlpha) shl 8) or
      (((((AColor shr 16) and $FF) * 255) div AAlpha) shl 16) or (AColor and $FF000000)
  else
    Result := AColor;
end;

function AddPixels(const AColor1, AColor2: TIntColor): TIntColor;
begin
  Result :=
    TIntColor(Min(Integer(AColor1 and $FF) + Integer(AColor2 and $FF), 255)) or
    (TIntColor(Min(Integer((AColor1 shr 8) and $FF) + Integer((AColor2 shr 8) and $FF), 255)) shl 8) or
    (TIntColor(Min(Integer((AColor1 shr 16) and $FF) + Integer((AColor2 shr 16) and $FF), 255)) shl 16) or
    (TIntColor(Min(Integer((AColor1 shr 24) and $FF) + Integer((AColor2 shr 24) and $FF), 255)) shl 24);
end;

function MultiplyPixels(const AColor1, AColor2: TIntColor): TIntColor;
begin
  Result :=
    TIntColor((Integer(AColor1 and $FF) * Integer(AColor2 and $FF)) div 255) or
    (TIntColor((Integer((AColor1 shr 8) and $FF) * Integer((AColor2 shr 8) and $FF)) div 255) shl 8) or
    (TIntColor((Integer((AColor1 shr 16) and $FF) * Integer((AColor2 shr 16) and $FF)) div 255) shl 16) or
    (TIntColor((Integer((AColor1 shr 24) and $FF) * Integer((AColor2 shr 24) and $FF)) div 255) shl 24);
end;

function AveragePixels(const AColor1, AColor2: TIntColor): TIntColor;
begin
  Result :=
    (((AColor1 and $FF) + (AColor2 and $FF)) div 2) or
    (((((AColor1 shr 8) and $FF) + ((AColor2 shr 8) and $FF)) div 2) shl 8) or
    (((((AColor1 shr 16) and $FF) + ((AColor2 shr 16) and $FF)) div 2) shl 16) or
    (((((AColor1 shr 24) and $FF) + ((AColor2 shr 24) and $FF)) div 2) shl 24);
end;

function BlendPixels(const AColor1, AColor2: TIntColor; const AAlpha: Integer): TIntColor;
begin
  Result :=
    TIntColor(Integer(AColor1 and $FF) + (((Integer(AColor2 and $FF) -
    Integer(AColor1 and $FF)) * AAlpha) div 255)) or

    (TIntColor(Integer((AColor1 shr 8) and $FF) + (((Integer((AColor2 shr 8) and $FF) -
    Integer((AColor1 shr 8) and $FF)) * AAlpha) div 255)) shl 8) or

    (TIntColor(Integer((AColor1 shr 16) and $FF) + (((Integer((AColor2 shr 16) and $FF) -
    Integer((AColor1 shr 16) and $FF)) * AAlpha) div 255)) shl 16) or

    (TIntColor(Integer((AColor1 shr 24) and $FF) + (((Integer((AColor2 shr 24) and $FF) -
    Integer((AColor1 shr 24) and $FF)) * AAlpha) div 255)) shl 24);
end;

function BlendFourPixels(const ATopLeft, ATopRight, ABottomRight, ABottomLeft: TIntColor;
  const AAlphaX, AAlphaY: Integer): TIntColor;
begin
  Result := BlendPixels(BlendPixels(ATopLeft, ATopRight, AAlphaX),
    BlendPixels(ABottomLeft, ABottomRight, AAlphaX), AAlphaY);
end;

function LerpPixels(const AColor1, AColor2: TIntColor; const AAlpha: Single): TIntColor;
begin
  Result :=
    TIntColor(Integer(AColor1 and $FF) + Round((Integer(AColor2 and $FF) -
    Integer(AColor1 and $FF)) * AAlpha)) or

    (TIntColor(Integer((AColor1 shr 8) and $FF) + Round((Integer((AColor2 shr 8) and $FF) -
    Integer((AColor1 shr 8) and $FF)) * AAlpha)) shl 8) or

    (TIntColor(Integer((AColor1 shr 16) and $FF) + Round((Integer((AColor2 shr 16) and $FF) -
    Integer((AColor1 shr 16) and $FF)) * AAlpha)) shl 16) or

    (TIntColor(Integer((AColor1 shr 24) and $FF) + Round((Integer((AColor2 shr 24) and $FF) -
    Integer((AColor1 shr 24) and $FF)) * AAlpha)) shl 24);
end;

function PixelToGray(const AColor: TIntColor): Integer;
begin
  Result := ((Integer(AColor and $FF) * 77) + (Integer((AColor shr 8) and $FF) * 150) +
    (Integer((AColor shr 16) and $FF) * 29)) div 256;
end;

function GetIntColorAlpha(const AColor: TIntColor): Integer;
begin
  Result := AColor shr 24;
end;

{$ENDREGION}
{$REGION 'TColorRect'}

class operator TColorRect.Implicit(const AColor: TIntColor): TColorRect;
begin
  Result.TopLeft := AColor;
  Result.TopRight := AColor;
  Result.BottomRight := AColor;
  Result.BottomLeft := AColor;
end;

function TColorRect.HasGradient: Boolean;
begin
  Result := (TopLeft <> TopRight) or (TopRight <> BottomRight) or (BottomRight <> BottomLeft);
end;

function TColorRect.HasAlpha: Boolean;
begin
  Result := (TopLeft shr 24 > 0) or (TopRight shr 24 > 0) or (BottomRight shr 24 > 0) or (BottomLeft shr 24 > 0);
end;

function ColorRect(const ATopLeft, ATopRight, ABottomRight, ABottomLeft: TIntColor): TColorRect;
begin
  Result.TopLeft := ATopLeft;
  Result.TopRight := ATopRight;
  Result.BottomRight := ABottomRight;
  Result.BottomLeft := ABottomLeft;
end;

function ColorRect(const AColor: TIntColor): TColorRect;
begin
  Result.TopLeft := AColor;
  Result.TopRight := AColor;
  Result.BottomRight := AColor;
  Result.BottomLeft := AColor;
end;

{$ENDREGION}
{$REGION 'TQuad'}

class operator TQuad.Equal(const ARect1, ARect2: TQuad): Boolean;
begin
  Result := (ARect1.TopLeft = ARect2.TopLeft) and (ARect1.TopRight = ARect2.TopRight) and
    (ARect1.BottomRight = ARect2.BottomRight) and (ARect1.BottomLeft = ARect2.BottomLeft);
end;

class operator TQuad.NotEqual(const ARect1, ARect2: TQuad): Boolean;
begin
  Result := not (ARect1 = ARect2);
end;

function TQuad.Scale(const AScale: Single; const ACentered: Boolean): TQuad;
var
  LCenter: TPointF;
begin
  if Abs(AScale - 1.0) <= VectorEpsilon then
    Exit(Self);

  if ACentered then
  begin
    LCenter := MultiplyPointF(TopLeft + TopRight + BottomRight + BottomLeft, 0.25);
    Result.TopLeft := Lerp(LCenter, TopLeft, AScale);
    Result.TopRight := Lerp(LCenter, TopRight, AScale);
    Result.BottomRight := Lerp(LCenter, BottomRight, AScale);
    Result.BottomLeft := Lerp(LCenter, BottomLeft, AScale);
  end
  else
  begin
    Result.TopLeft := MultiplyPointF(TopLeft, AScale);
    Result.TopRight := MultiplyPointF(TopRight, AScale);
    Result.BottomRight := MultiplyPointF(BottomRight, AScale);
    Result.BottomLeft := MultiplyPointF(BottomLeft, AScale);
  end;
end;

function TQuad.Mirror: TQuad;
begin
  Result.TopLeft := TopRight;
  Result.TopRight := TopLeft;
  Result.BottomRight := BottomLeft;
  Result.BottomLeft := BottomRight;
end;

function TQuad.Flip: TQuad;
begin
  Result.TopLeft := BottomLeft;
  Result.TopRight := BottomRight;
  Result.BottomRight := TopRight;
  Result.BottomLeft := TopLeft;
end;

function TQuad.Offset(const ADelta: TPointF): TQuad;
begin
  Result.TopLeft := TopLeft + ADelta;
  Result.TopRight := TopRight + ADelta;
  Result.BottomRight := BottomRight + ADelta;
  Result.BottomLeft := BottomLeft + ADelta;
end;

function TQuad.Offset(const ADeltaX, ADeltaY: Single): TQuad;
begin
  Result := Offset(PointF(ADeltaX, ADeltaY));
end;

class function TQuad.Scaled(const ALeft, ATop, AWidth, AHeight, AScale: Single;
  const ACentered: Boolean): TQuad;
var
  LLeft, LTop, LWidth, LHeight: Single;
begin
  if Abs(AScale - 1.0) <= VectorEpsilon then
    Exit(Quad(ALeft, ATop, AWidth, AHeight));

  if ACentered then
  begin
    LWidth := AWidth * AScale;
    LHeight := AHeight * AScale;
    LLeft := ALeft + (AWidth - LWidth) * 0.5;
    LTop := ATop + (AHeight - LHeight) * 0.5;

    Result := Quad(LLeft, LTop, LWidth, LHeight);
  end
  else
    Result := Quad(ALeft, ATop, AWidth * AScale, AHeight * AScale);
end;

class function TQuad.Rotated(const ARotationOrigin, ASize, ARotationCenter: TPointF; const AAngle,
  AScale: Single): TQuad;
var
  LSinAngle, LCosAngle: Single;
  LScaled: Boolean;
  LPoint: TPointF;
  LIndex: Integer;
begin
  SinCos(AAngle, LSinAngle, LCosAngle);

  Result := Quad(-ARotationCenter.X, -ARotationCenter.Y, ASize.X, ASize.Y);

  LScaled := Abs(AScale - 1.0) > VectorEpsilon;

  for LIndex := 0 to High(Result.Values) do
  begin
    if LScaled then
      Result.Values[LIndex] := MultiplyPointF(Result.Values[LIndex], AScale);

    LPoint.X := Result.Values[LIndex].X * LCosAngle - Result.Values[LIndex].Y * LSinAngle;
    LPoint.Y := Result.Values[LIndex].Y * LCosAngle + Result.Values[LIndex].X * LSinAngle;

    Result.Values[LIndex] := LPoint + ARotationOrigin;
  end;
end;

class function TQuad.Rotated(const ARotationOrigin, ASize: TPointF; const AAngle, AScale: Single): TQuad;
begin
  Result := Rotated(ARotationOrigin, ASize, MultiplyPointF(ASize, 0.5), AAngle, AScale);
end;

class function TQuad.RotatedTL(const ATopLeft, ASize, ARotationCenter: TPointF; const AAngle: Single;
  const AScale: Single): TQuad;
begin
  Result := Rotated(ATopLeft, ASize, ARotationCenter, AAngle, AScale).Offset(ARotationCenter);
end;

function Quad(const ATopLeftX, ATopLeftY, ATopRightX, ATopRightY, ABottomRightX, ABottomRightY, ABottomLeftX,
  ABottomLeftY: Single): TQuad;
begin
  Result.TopLeft.X := ATopLeftX;
  Result.TopLeft.Y := ATopLeftY;
  Result.TopRight.X := ATopRightX;
  Result.TopRight.Y := ATopRightY;
  Result.BottomRight.X := ABottomRightX;
  Result.BottomRight.Y := ABottomRightY;
  Result.BottomLeft.X := ABottomLeftX;
  Result.BottomLeft.Y := ABottomLeftY;
end;

function Quad(const ATopLeft, ATopRight, ABottomRight, ABottomLeft: TPointF): TQuad;
begin
  Result.TopLeft := ATopLeft;
  Result.TopRight := ATopRight;
  Result.BottomRight := ABottomRight;
  Result.BottomLeft := ABottomLeft;
end;

function Quad(const ALeft, ATop, AWidth, AHeight: Single): TQuad;
begin
  Result.TopLeft.X := ALeft;
  Result.TopLeft.Y := ATop;
  Result.TopRight.X := ALeft + AWidth;
  Result.TopRight.Y := ATop;
  Result.BottomRight.X := Result.TopRight.X;
  Result.BottomRight.Y := ATop + AHeight;
  Result.BottomLeft.X := ALeft;
  Result.BottomLeft.Y := Result.BottomRight.Y;
end;

function Quad(const ARect: TRectF): TQuad;
begin
  Result.TopLeft := ARect.TopLeft;
  Result.TopRight := PointF(ARect.Right, ARect.Top);
  Result.BottomRight := ARect.BottomRight;
  Result.BottomLeft := PointF(ARect.Left, ARect.Bottom);
end;

function Quad(const ARect: TRect): TQuad;
begin
  Result.TopLeft := PointF(ARect.Left, ARect.Top);
  Result.TopRight := PointF(ARect.Right, ARect.Top);
  Result.BottomRight := PointF(ARect.Right, ARect.Bottom);
  Result.BottomLeft := PointF(ARect.Left, ARect.Bottom);
end;

{$ENDREGION}

end.

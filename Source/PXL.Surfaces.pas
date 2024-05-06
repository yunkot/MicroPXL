unit PXL.Surfaces;
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
{< Surfaces that provide cross-platform means of storing, converting and processing pixels.  }
interface

{$INCLUDE PXL.Config.inc}

uses
  Types, PXL.TypeDef, PXL.Types;

type
  // Conceptual surface that provide means of reading, writing and drawing individual pixels.
  TConceptualPixelSurface = class abstract
  protected
    // Returns pixel located at specified coordinates. This also includes a sanity check for pixel
    // coordinates to be within valid range. If coordinates are outside of valid range, zero should be
    // returned.
    function GetPixel(AX, AY: Integer): TIntColor; virtual; abstract;

    // Sets pixel located at specified coordinates. This also includes a sanity check for pixel coordinates
    // to be within valid range. If coordinates are outside of valid range, nothing should be done.
    procedure SetPixel(AX, AY: Integer; const AColor: TIntColor); virtual; abstract;

    // Returns pixel located at specified coordinates similarly to @link(GetPixel), but without sanity check
    // for increased performance.
    function GetPixelUnsafe(AX, AY: Integer): TIntColor; virtual; abstract;

    // Sets pixel located at specified coordinates similarly to @link(GetPixel), but without sanity check for
    // increased performance.
    procedure SetPixelUnsafe(AX, AY: Integer; const AColor: TIntColor); virtual; abstract;
  public
    // Draws a single pixel at specified coordinates and color with alpha-blending. It also does a sanity
    // check for specified coordinates and if they are outside of valid range, does nothing.
    procedure DrawPixel(const AX, AY: Integer; const AColor: TIntColor); overload; virtual;

    // Draws a single pixel at specified position and color with alpha-blending. It also does a sanity check
    // for specified position and if it is outside of valid range, does nothing.
    procedure DrawPixel(const APosition: TPoint; const AColor: TIntColor); overload; inline;

    // Draws a single pixel at specified coordinates similarly to @link(DrawPixel), but without sanity check
    // for increased performance.
    procedure DrawPixelUnsafe(const AX, AY: Integer; const AColor: TIntColor); overload;

    // Draws a single pixel at specified position similarly to @link(DrawPixel), but without sanity check for
    // increased performance.
    procedure DrawPixelUnsafe(const APosition: TPoint; const AColor: TIntColor); overload; inline;

    // Provides access to surface's individual pixels. See @link(GetPixel) and @link(SetPixel) on how this
    // actually works.
    property Pixels[AX, AY: Integer]: TIntColor read GetPixel write SetPixel;

    // Provides access to surface's individual pixels without sanity check for increased performance.
    // See @link(GetPixelUnsafe) and @link(SetPixelUnsafe) on how this actually works.
    property PixelsUnsafe[AX, AY: Integer]: TIntColor read GetPixelUnsafe write SetPixelUnsafe;
  end;

  // Surface that stores pixels in one of supported formats, with facilities for pixel format conversion,
  // resizing, copying, drawing, shrinking and so on. This can serve as a base for more advanced
  // hardware-based surfaces, but it also provides full software implementation for all the functions.
  TPixelSurface = class(TConceptualPixelSurface)
  private
    FName: StdString;

    function GetSize: TPoint;
    function GetScanlineAddress(const AIndex: Integer): Pointer; inline;
    function GetPixelAddress(const AX, AY: Integer): PIntColor; inline;
    function GetScanline(const AIndex: Integer): Pointer;
    function GetPixelPtr(const AX, AY: Integer): PIntColor;
  protected
    // Memory reference to top/left corner of pixel data contained by this surface, with horizontal rows
    // arranged linearly from top to bottom.
    FBits: Pointer;

    // Currently set number of bytes each horizontal row of pixels occupies. This may differ than the actual
    // calculated number and may include unused or even protected memory locations, which should simply be
    // skipped.
    FPitch: Cardinal;

    // Current width of surface in pixels.
    FWidth: Integer;

    // Current height of surface in pixels.
    FHeight: Integer;

    // Size of current surface in bytes.
    FBufferSize: Cardinal;

    // Reads pixel from the surface and provides necessary pixel format conversion based on parameters such
    // as @link(FBits), @link(FPitch), @link(FPixelFormat), @link(FBytesPerPixel), @link(FWidth) and
    // @link(FHeight). This function does range checking for @italic(X) and @italic(Y) parameters and if they
    // are outside of valid range, returns completely black/translucent color (in other words, zero).
    function GetPixel(AX, AY: Integer): TIntColor; override;

    // Writes pixel to the surface and provides necessary pixel format conversion based on parameters such as
    // @link(FBits), @link(FPitch), @link(FPixelFormat), @link(FBytesPerPixel), @link(FWidth) and
    // @link(FHeight). This function does range checking for @italic(X) and @italic(Y) parameters and if they
    // are outside of valid range, does nothing.
    procedure SetPixel(AX, AY: Integer; const AColor: TIntColor); override;

    // Reads pixel from the surface similarly to @link(GetPixel), but does not do any range checking for
    // @italic(X) and @italic(Y) with the benefit of increased performance.
    function GetPixelUnsafe(AX, AY: Integer): TIntColor; override;

    // Write pixel to the surface similarly to @link(SetPixel), but does not do any range checking for
    // @italic(X) and @italic(Y) with the benefit of increased performance.
    procedure SetPixelUnsafe(AX, AY: Integer; const AColor: TIntColor); override;

    // Resets pixel surface allocation, releasing any previously allocated memory and setting all relevant
    // parameters to zero.
    procedure ResetAllocation; virtual;

    // Reallocates current pixel surface to a new size, discarding any previous written content.
    // This function returns @True when the operation was successful and @False otherwise.
    function Reallocate(const AWidth, AHeight: Integer): Boolean; virtual;
  public
    // Creates new instance of this class with empty name.
    constructor Create(const AName: StdString = '');
    { @exclude } destructor Destroy; override;

    // Checks whether the surface has non-zero width and height.
    function Empty: Boolean;

    // Redefines surface size to the specified width and height, discarding previous contents. This function
    // provides a sanity check on the specified parameters and calls @link(Reallocate) accordingly.
    // @True is returned when the operation has been successful and @False otherwise.
    function SetSize(AWidth, AHeight: Integer): Boolean; overload;

    // Redefines surface size to the specified size, discarding previous contents. This function provides
    // a sanity check on specified parameters and calls @link(Reallocate) accordingly.
    // @True is returned when the operation has been successful and @False otherwise.
    function SetSize(const ASize: TPoint): Boolean; overload; inline;

    // Copies entire contents from source surface to this one. If the current surface has unspecified size,
    // it will be copied from the source surface as well. This function will try to ensure that current
    // surface size matches the source surface and if if this cannot be achieved, will fail; as an
    // alternative, @link(CopyRect) can be used to instead copy a portion of source surface to this one.
    // @True is returned when the operation was successful and @False otherwise.
    function CopyFrom(const ASource: TPixelSurface): Boolean;

    // Copies a portion of source surface to this one according to specified source rectangle and destination
    // position. If source rectangle is empty, then the entire source surface will be copied. This function
    // does the appropriate clipping. It does not change current surface size. @True is returned when the
    // operation was successful and @False otherwise.
    function CopyRect(ADestPos: TPoint; const ASource: TPixelSurface; ASourceRect: TRect): Boolean;

    // Clears the entire surface with the given color.
    procedure Clear(const AColor: TIntColor = 0); overload;

    // Processes surface pixels, setting alpha-channel to either fully translucent or fully opaque depending
    // on @italic(Opaque) parameter.
    procedure ResetAlpha(const AOpaque: Boolean = True);

    // Processes the whole surface to determine whether it has meaningful alpha-channel. A surface that has
    // all its pixels with alpha-channel set to fully translucent or fully opaque (but not mixed) is
    // considered lacking alpha-channel. On the other hand, a surface that has at least one pixel with
    // alpha-channel value different than any other pixel, is considered to have alpha-channel. This is
    // useful to determine whether the surface can be stored in one of pixel formats lacking alpha-channel,
    // to avoid losing any transparency information.
    function HasAlphaChannel: Boolean;

    // Processes the whole surface, premultiplying each pixel's red, green and blue values by the
    // corresponding alpha-channel value, resulting in image with premultiplied alpha. Note that this is an
    // irreversible process, during which some color information is lost permanently (smaller alpha values
    // contribute to bigger information loss). This is generally useful to prepare the image for generating
    // mipmaps and/or alpha-blending, to get more accurate visual results.
    procedure PremultiplyAlpha;

    // Processes the whole surface, dividing each pixel by its alpha-value, resulting in image with
    // non-premultiplied alpha. This can be considered an opposite or reversal process of
    // @link(PremultiplyAlpha). During this process, some color information may be lost due to precision
    // issues. This can be useful to obtain original pixel information from image that has been previously
    // premultiplied; however, this does not recover lost information during premultiplication process.
    // For instance, pixels that had alpha value of zero and were premultiplied lose all information and
    // cannot be recovered; pixels with alpha value of 128 (that is, 50% opaque) lose half of their precision
    // and after "unpremultiply" process will have values multiple of 2. }
    procedure UnpremultiplyAlpha;

    // Mirrors the visible image on surface horizontally.
    procedure Mirror;

    // Flips the visible image on surface vertically.
    procedure Flip;

    // Unique name of this surface.
    property Name: StdString read FName;

    // Pointer to top/left corner of pixel data contained by this surface, with horizontal rows arranged
    // linearly from top to bottom.
    property Bits: Pointer read FBits;

    // The number of bytes each horizontal row of pixels occupies. This may differ than the actual calculated
    // number and may include unusued or even protected memory locations, which should simply be skipped.
    property Pitch: Cardinal read FPitch;

    // Size of the surface in bytes.
    property BufferSize: Cardinal read FBufferSize;

    // Width of surface in pixels.
    property Width: Integer read FWidth;

    // Height of surface in pixels.
    property Height: Integer read FHeight;

    // Size of surface in pixels.
    property Size: TPoint read GetSize;

    // Provides pointer to left corner of pixel data at the given scanline index (that is, row number).
    // If the specified index is outside of valid range, @nil is returned.
    property Scanline[const AIndex: Integer]: Pointer read GetScanline;

    // Provides pointer to the pixel data at the given coordinates. If the specified coordinates are outside
    // of valid range, @nil is returned.
    property PixelPtr[const AX, AY: Integer]: PIntColor read GetPixelPtr;
  end;

implementation

uses
  SysUtils, Math;

{$REGION 'TConceptualPixelSurface'}

procedure TConceptualPixelSurface.DrawPixel(const AX, AY: Integer; const AColor: TIntColor);
begin
  SetPixel(AX, AY, BlendPixels(GetPixel(AX, AY), AColor, GetIntColorAlpha(AColor)));
end;

procedure TConceptualPixelSurface.DrawPixel(const APosition: TPoint;
  const AColor: TIntColor);
begin
  DrawPixel(APosition.X, APosition.Y, AColor);
end;

procedure TConceptualPixelSurface.DrawPixelUnsafe(const AX, AY: Integer; const AColor: TIntColor);
begin
  SetPixelUnsafe(AX, AY, BlendPixels(GetPixelUnsafe(AX, AY), AColor, GetIntColorAlpha(AColor)));
end;

procedure TConceptualPixelSurface.DrawPixelUnsafe(const APosition: TPoint; const AColor: TIntColor);
begin
  DrawPixelUnsafe(APosition.X, APosition.Y, AColor);
end;

{$ENDREGION}
{$REGION 'TPixelSurface'}

constructor TPixelSurface.Create(const AName: StdString);
begin
  inherited Create;
  FName := AName;
end;

destructor TPixelSurface.Destroy;
begin
  ResetAllocation;
  inherited;
end;

function TPixelSurface.GetSize: TPoint;
begin
  Result := Point(FWidth, FHeight);
end;

function TPixelSurface.GetScanlineAddress(const AIndex: Integer): Pointer;
begin
  Result := Pointer(PtrUInt(FBits) + FPitch * Cardinal(AIndex));
end;

function TPixelSurface.GetPixelAddress(const AX, AY: Integer): PIntColor;
begin
  Result := PIntColor(PtrUInt(FBits) + FPitch * Cardinal(AY) + SizeOf(TIntColor) * Cardinal(AX));
end;

function TPixelSurface.GetScanline(const AIndex: Integer): Pointer;
begin
  if (AIndex >= 0) and (AIndex < FHeight) then
    Result := GetScanlineAddress(AIndex)
  else
    Result := nil;
end;

function TPixelSurface.GetPixelPtr(const AX, AY: Integer): PIntColor;
begin
  if (AX >= 0) and (AY >= 0) and (AX < FWidth) and (AY < FHeight) then
    Result := GetPixelAddress(AX, AY)
  else
    Result := nil;
end;

function TPixelSurface.GetPixel(AX, AY: Integer): TIntColor;
begin
  if (AX >= 0) and (AY >= 0) and (AX < FWidth) and (AY < FHeight) then
    Result := PIntColor(GetPixelAddress(AX, AY))^
  else
    Result := IntColorBlack;
end;

procedure TPixelSurface.SetPixel(AX, AY: Integer; const AColor: TIntColor);
begin
  if (AX >= 0) and (AY >= 0) and (AX < FWidth) and (AY < FHeight) then
    PIntColor(GetPixelAddress(AX, AY))^ := AColor;
end;

function TPixelSurface.GetPixelUnsafe(AX, AY: Integer): TIntColor;
begin
  Result := PIntColor(GetPixelAddress(AX, AY))^
end;

procedure TPixelSurface.SetPixelUnsafe(AX, AY: Integer; const AColor: TIntColor);
begin
  PIntColor(GetPixelAddress(AX, AY))^ := AColor;
end;

function TPixelSurface.Empty: Boolean;
begin
  Result := (FWidth <= 0) or (FHeight <= 0) or (FBits = nil);
end;

procedure TPixelSurface.ResetAllocation;
begin
  FWidth := 0;
  FHeight := 0;
  FPitch := 0;
  FBufferSize := 0;

  FreeMemAndNil(FBits);
end;

function TPixelSurface.Reallocate(const AWidth, AHeight: Integer): Boolean;
begin
  FWidth := AWidth;
  FHeight := AHeight;
  FPitch := Cardinal(FWidth) * SizeOf(TIntColor);
  FBufferSize := Cardinal(FHeight) * FPitch;

  ReallocMem(FBits, FBufferSize);
  Result := True;
end;

function TPixelSurface.SetSize(AWidth, AHeight: Integer): Boolean;
begin
  AWidth := Max(AWidth, 0);
  AHeight := Max(AHeight, 0);

  if (FWidth <> AWidth) or (FHeight <> AHeight) then
  begin
    if (AWidth <= 0) or (AHeight <= 0) then
    begin
      ResetAllocation;
      Result := True
    end
    else
      Result := Reallocate(AWidth, AHeight);
  end
  else
    Result := True;
end;

function TPixelSurface.SetSize(const ASize: TPoint): Boolean;
begin
  Result := SetSize(ASize.X, ASize.Y);
end;

function TPixelSurface.CopyFrom(const ASource: TPixelSurface): Boolean;
var
  I: Integer;
begin
  if (ASource = nil) or ASource.Empty then
    Exit(False);

  if (FWidth <> ASource.Width) or (FHeight <> ASource.Height) then
  begin
    if not SetSize(ASource.Width, ASource.Height) then
      Exit(False);

    if (FWidth <> ASource.Width) or (FHeight <> ASource.Height) then
      Exit(False);
  end;

  if FBits = nil then
    Exit(False);

  for I := 0 to FHeight - 1 do
    Move(ASource.Scanline[I]^, GetScanline(I)^, Cardinal(FWidth) * SizeOf(TIntColor));

  Result := True;
end;

function TPixelSurface.CopyRect(ADestPos: TPoint; const ASource: TPixelSurface;
  ASourceRect: TRect): Boolean;
var
  I: Integer;
begin
  if (ASource = nil) or ASource.Empty then
    Exit(False);

  if ASourceRect.IsEmpty then
    ASourceRect := Bounds(0, 0, ASource.Width, ASource.Height);

  if not ClipCoords(ASource.Size, GetSize, ASourceRect, ADestPos) then
    Exit(False);

    for I := 0 to ASourceRect.Height - 1 do
      Move(ASource.GetPixelPtr(ASourceRect.Left, ASourceRect.Top + I)^,
        GetPixelPtr(ADestPos.X, ADestPos.Y + I)^, Cardinal(ASourceRect.Width) * SizeOf(TIntColor));

  Result := True;
end;

procedure TPixelSurface.Clear(const AColor: TIntColor);
var
  I, J: Integer;
  LDestPixel: PIntColor;
begin
  if Empty then
    Exit;

  for J := 0 to FHeight - 1 do
  begin
    LDestPixel := GetScanline(J);

    for I := 0 to FWidth - 1 do
    begin
      LDestPixel^ := AColor;
      Inc(LDestPixel);
    end;
  end;
end;

procedure TPixelSurface.ResetAlpha(const AOpaque: Boolean);
var
  I, J: Integer;
  LDestPixel: PIntColor;
begin
  if Empty then
    Exit;

  for J := 0 to FHeight - 1 do
  begin
    LDestPixel := GetScanline(J);

    if AOpaque then
      for I := 0 to FWidth - 1 do
      begin
        LDestPixel^ := LDestPixel^ or $FF000000;
        Inc(LDestPixel);
      end
    else
      for I := 0 to FWidth - 1 do
      begin
        LDestPixel^ := LDestPixel^ and $00FFFFFF;
        Inc(LDestPixel);
      end;
  end;
end;

function TPixelSurface.HasAlphaChannel: Boolean;
var
  I, J: Integer;
  LSrcPixel: PIntColor;
  LHasNonZero, LHasNonMax: Boolean;
begin
  if Empty then
    Exit(False);

  LHasNonZero := False;
  LHasNonMax := False;

  for J := 0 to FHeight - 1 do
  begin
    LSrcPixel := GetScanline(J);

    for I := 0 to FWidth - 1 do
    begin
      if (not LHasNonZero) and (GetIntColorAlpha(LSrcPixel^) > 0) then
        LHasNonZero := True;

      if (not LHasNonMax) and (GetIntColorAlpha(LSrcPixel^) < 255) then
        LHasNonMax := True;

      if LHasNonZero and LHasNonMax then
        Exit(True);

      Inc(LSrcPixel);
    end;
  end;

  Result := False;
end;

procedure TPixelSurface.PremultiplyAlpha;
var
  I, J: Integer;
  LDestPixel: PIntColor;
begin
  if Empty then
    Exit;

  for J := 0 to FHeight - 1 do
  begin
    LDestPixel := GetScanline(J);

    for I := 0 to FWidth - 1 do
    begin
      LDestPixel^ := PXL.Types.PremultiplyAlpha(LDestPixel^);
      Inc(LDestPixel);
    end;
  end;
end;

procedure TPixelSurface.UnpremultiplyAlpha;
var
  I, J: Integer;
  LDestPixel: PIntColor;
begin
  if Empty then
    Exit;

  for J := 0 to FHeight - 1 do
  begin
    LDestPixel := GetScanline(J);

    for I := 0 to FWidth - 1 do
    begin
      LDestPixel^ := PXL.Types.UnpremultiplyAlpha(LDestPixel^);
      Inc(LDestPixel);
    end;
  end;
end;

procedure TPixelSurface.Mirror;
var
  I, J: Integer;
  LCopyPixels: TArray<TIntColor>;
  LDestPixel, LSourcePixel: PIntColor;
  LCopyWidth : Cardinal;
begin
  if Empty then
    Exit;

  LCopyWidth := Cardinal(FWidth) * SizeOf(TIntColor);
  SetLength(LCopyPixels, FWidth);

  for J := 0 to FHeight - 1 do
  begin
    Move(GetScanline(J)^, LCopyPixels[0], LCopyWidth);

    LDestPixel := @LCopyPixels[0];
    LSourcePixel := Pointer((PtrUInt(GetScanline(J)) + LCopyWidth) - SizeOf(TIntColor));

    for I := 0 to FWidth - 1 do
    begin
      LDestPixel^ := LSourcePixel^;
      Dec(LSourcePixel);
      Inc(LDestPixel);
    end;

    Move(LCopyPixels[0], GetScanline(J)^, LCopyWidth);
  end;
end;

procedure TPixelSurface.Flip;
var
  I, J: Integer;
  LCopyPixels: TArray<TIntColor>;
  LCopyWidth: Cardinal;
begin
  if Empty then
    Exit;

  LCopyWidth := Cardinal(FWidth) * SizeOf(TINtColor);
  SetLength(LCopyPixels, FWidth);

  for I := 0 to (FHeight div 2) - 1 do
  begin
    J := (FHeight - 1) - I;

    Move(GetScanline(I)^, LCopyPixels[0], LCopyWidth);
    Move(GetScanline(J)^, GetScanline(I)^, LCopyWidth);
    Move(LCopyPixels[0], GetScanline(J)^, LCopyWidth);
  end;
end;

{$ENDREGION}

end.

unit PXL.Fonts;
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
{< Pre-rendered bitmap fonts and visual effects such as border and shadow, rendering using vertical color
   gradient, formatted text among other features. }
interface

{$INCLUDE PXL.Config.inc}

// The following option controls the inclusion of system 8x8 or 9x8 font, which is integrated into executable
// and always available. The inclusion of system font increases application size and memory usage by 2.5 KiB.
{$DEFINE IncludeSystemFont}

uses
  Types, Classes, PXL.TypeDef, PXL.Types, PXL.Surfaces, PXL.Canvas, PXL.XML, PXL.ImageFormats;

type
  // Text alignment when drawing with certain functions.
  TTextAlignment = (
    // Text should be aligned to the beginning (either top or left depending on context).
    Start,

    // Text should be centered in the middle.
    Middle,

    // Text should be aligned to the end (either bottom or right depending on context).
    Final);

{$IFDEF IncludeSystemFont}
  // Type of image for system font.
  TSystemFontImage = (
    // 8x8 font that was commonly used in text mode on EGA displays with 640x350 resolution.
    Font8x8,

    // 9x8 font that was commonly used in text mode on VGA displays with 720x400 resolution.
    Font9x8);
{$ENDIF}

  // Bitmap font implementation.
  TBitmapFont = class
  private type
    TParagraphWord = record
      WordText: UniString;
      ParagraphIndex: Integer;
    end;

    PLetterEntry = ^TLetterEntry;
    TLetterEntry = packed record
      TopBase: Byte;
      BottomBase: Byte;
      LeadingSpace: ShortInt;
      TrailingSpace: ShortInt;
      MapLeft: Word;
      MapTop: Word;
      MapWidth: Byte;
      MapHeight: Byte;
    end;

    // Pixel format of the fonts stored as binary.
    TPixelFormat = (Unknown, A8R8G8B8, X8R8G8B8, A4R4G4B4, X4R4G4B4, R5G6B5, A1R5G5B5, X1R5G5B5, A2R2G2B2,
      R3G3B2, A8R3G3B2, A2B10G10R10, A16B16G16R16, A8L8, A4L4, L16, L8, R16F, G16R16F, A16B16G16R16F,
      R32F, G32R32F, A32B32G32R32F, A8, G16R16, A2R10G10B10, X2R10G10B10, A8B8G8R8, X8B8G8R8, R8G8B8,
      B8G8R8A8, B8G8R8X8, I8);
  public const
    // Default image extension when loading fonts provided as pair of XML and image files.
    DefaultImageExtension = '.png';

    // Default XML extension when loading fonts provided as pair of XML and image files.
    DefaultXMLExtension = '.xml';

    // Default font extension when loading binary fonts.
    DefaultBinaryExtension = '.font';
  public type
    // Event invoked by @link(DrawTextCustom) method for custom text rendering, called for each text letter.
    // @param(ASender Reference to class that invoked this method.)
    // @param(AFontImage Font image that should be used as a source for drawing letter.)
    // @param(ASourceRect Rectangle in font image that contains letter image.)
    // @param(ADestRect Destination rectangle, where font image should be rendered.)
    // @param(AColor Color, which should be used for rendering the letter.)
    // @param(AUserContext User context parameter passed to @link(DrawTextCustom).) }
    TTextEntryEvent = procedure(const ASender: TObject; const ASurface: TPixelSurface;
      const ASourceRect: TRect; const ADestRect: TRectF; const AColor: TColorRect;
      const AUserContext: Pointer);

    // An array of rectangles for each text character.
    TTextRects = TArray<TRectF>;
  private const
    MaxEntriesCount = 65536;
  private
    FImageFormatManager: TCustomImageFormatManager;
    FName: StdString;

    FParagraphWords: array of TParagraphWord;
    FCanvas: TCanvas;

    FParagraphSeparators: UniString;
    FWordSeparators: UniString;

    FScale: Single;
    FInterleave: Single;

    FSpaceWidth: Single;
    FVerticalSpace: Single;

    function ReadFontEntriesFromStream(const AStream: TStream): Boolean;
    function ReadSurfaceFromStream(const AStream: TStream; const AFormat: TPixelFormat;
      const AActualHeight: Integer): Boolean;
    function ReadFontImageFromStream(const AStream: TStream): Boolean;

  {$IFDEF IncludeSystemFont}
    procedure ReadSurfaceFromSystemFont;
  {$ENDIF}

    function ReadEntryFromXML(const ANode: TXMLNode): Boolean;
    function ReadFromXMLNode(const ANode: TXMLNode): Boolean;

    function IsWordSeparator(const AValue: WideChar): Boolean;
    function ExtractParagraphWord(const AText: UniString; var ACharIndex: Integer;
      var AParagraphIndex: Integer; out AWordText: UniString): Boolean;
    procedure SplitTextIntoWords(const AText: UniString);
  protected
    // Current font size that defines maximum rectangle that a letter can occupy.
    FSize: TPoint;

    // Current font image that contains pre-rendered letters.
    FSurface: TPixelSurface;

    // Information regarding locations, spacing and rendering parameters for each of available letters.
    FEntries: array[0..MaxEntriesCount - 1] of TLetterEntry;

    // Loads letter information from XML file located in the stream. Returns @True when succeeded and
    // @False otherwise.
    function LoadEntriesFromXMLStream(const AStream: TStream): Boolean;

    // Loads letter information from external XML file. Returns @True when succeeded and @False otherwise.
    function LoadEntriesFromXMLFile(const AFileName: StdString): Boolean;
  public
    // Creates new instance of @code(TBitmapFont) class bound to the specified device.
    constructor Create(const AImageFormatManager: TCustomImageFormatManager);
    { @exclude } destructor Destroy; override;

    // Draws text by invoking external rendering event for each of the letters.
    //   @param(APosition Starting position of text at top/left.)
    //   @param(AText The actual text to be drawn.)
    //   @param(AColor Two colors representing vertical gradient to fill the letters with.)
    //   @param(AAlpha A separate alpha representing transparency of the font (in addition to alpha provided
    //     in @code(Color)).)
    //   @param(ATextEntryEvent Event to be called for each letter being rendered (this excludes whitespace
    //     characters such as space or #0).)
    //   @param(AUserContext User context parameter that will be passed to each @code(TextEntryEvent) call.)
    //   @param(ARestartStyling Whether the initial style of the text should be reset. This is typically
    //     needed when rendering multi-line text such as in case of @link(DrawTextBox).)
    function DrawTextCustom(const APosition: TPointF; const AText: UniString; const AColor1,
      AColor2: TIntColor; const ATextEntryEvent: TTextEntryEvent; const AUserContext: Pointer): Boolean;

    // Draws text at the given position.
    //   @param(APosition Starting position of text at top/left.)
    //   @param(AText The actual text to be drawn.)
    //   @param(AColor Two colors representing vertical gradient to fill the letters with.)
    //   @param(AAlpha A separate alpha representing transparency of the font (in addition to alpha provided
    //     in @code(Color)).)
    procedure DrawText(const APosition: TPointF; const AText: UniString; const AColor1, AColor2: TIntColor);

    // Draws text at the given position with specific alignment.
    //   @param(APosition Starting position of text at top/left.)
    //   @param(AText The actual text to be drawn.)
    //   @param(AColor Two colors representing vertical gradient to fill the letters with.)
    //   @param(AHorizAlign Horizontal text alignment in relation to starting position.)
    //   @param(AVertAlign Vertical text alignment in relation to starting position.)
    //   @param(AAlpha A separate alpha representing transparency of the font (in addition to alpha provided
    //     in @code(Color)).)
    //   @param(AAlignToPixels Whether to align the resulting text position to start at integer location so
    //     that all letters are properly aligned to pixels. This may result in clearer text but can appear
    //     choppy during text animations (e.g. zoom in or out).)
    procedure DrawTextAligned(const APosition: TPointF; const AText: UniString; const AColor1,
      AColor2: TIntColor; const AHorizAlign, AVertAlign: TTextAlignment);

    // Draws text centered around the specified position.
    //   @param(APosition Origin around which the text will be rendered.)
    //   @param(AText The actual text to be drawn.)
    //   @param(AColor Two colors representing vertical gradient to fill the letters with.)
    //   @param(AAlpha A separate alpha representing transparency of the font (in addition to alpha provided
    //     in @code(Color)).)
    //   @param(AAlignToPixels Whether to align the resulting text position to start at integer location so
    //     that all letters are properly aligned to pixels. This may result in clearer text but can appear
    //     choppy during text animations (e.g. zoom in or out).)
    procedure DrawTextCentered(const APosition: TPointF; const AText: UniString; const AColor1,
      AColor2: TIntColor);

    // Returns total area size that given text string will occupy when rendered.
    function TextExtent(const AText: UniString): TPointF;

    // Returns total area width that given text string will occupy when rendered.
    function TextWidth(const AText: UniString): Single;

    // Returns total area height that given text string will occupy when rendered.
    function TextHeight(const AText: UniString): Single;

    // Returns total area size (rounded to nearest integer) that given text string will occupy when rendered.
    function TextExtentInt(const AText: UniString): TPoint;

    // Returns total area width (rounded to nearest integer) that given text string will occupy when rendered.
    function TextWidthInt(const AText: UniString): Integer;

    // Returns total area height (rounded to nearest integer) that given text string will occupy when rendered.
    function TextHeightInt(const AText: UniString): Integer;

    // Draws text containing multiple lines onto the designated area.
    //   @param(ATopLeft Top/left origin of designated area.)
    //   @param(ABoxSize Width and height of the designated area in relation to top/left origin.)
    //   @param(AParagraphShift Offset to apply when new text paragraph begins.)
    //   @param(AText Multi-line text to be drawn.)
    //   @param(AColor Two colors representing vertical gradient to fill the letters with.)
    //   @param(AAlpha A separate alpha representing transparency of the font (in addition to alpha provided
    //     in @code(Color)).)
    procedure DrawTextBox(const ATopLeft, ABoxSize, AParagraphShift: TPointF; const AText: UniString;
      const AColor1, AColor2: TIntColor);

    // Provides information regarding individual letter position and sizes for the given text string when
    // rendered. This can be useful for components such as text edit box, for highlighting and selecting
    // different letters.
    function TextRects(const AText: UniString): TTextRects;

    // Loads binary font from the given stream. This includes both letter information and font image.
    // The given pixel format, if specified, will be used as a hint for initializing font letters image.
    // Returns @True when successful and @False otherwise.
    function LoadFromBinaryStream(const AStream: TStream): Boolean;

    // Loads binary font from external file. This includes both letter information and font image.
    // The given pixel format, if specified, will be used as a hint for initializing font letters image.
    // Returns @True when successful and @False otherwise.
    function LoadFromBinaryFile(const AFileName: StdString): Boolean;

    // Loads font letter information and letter image from their corresponding streams. This uses image
    // format manager reference from associated device. The image extension indicates what image format for
    // letters image is used. The given pixel format, if specified, will be used as a hint for initializing
    // font letters image. Returns @True when successful and @False otherwise.
    function LoadFromXMLStream(const AImageExtension: StdString; const AImageStream, AXMLStream: TStream): Boolean;

    // Loads font letter information and letter image from external files on disk. This methods accepts that
    // one of file names is left empty and will be guessed by either changing extension from ".xml" to ".png"
    // or vice-versa. This uses image format manager reference from associated device. The given pixel
    // format, if specified, will be used as a hint for initializing font letters image. Returns @True when
    // successful and @False otherwise.
    function LoadFromXMLFile(const AImageFileName: StdString; const AXMLFileName: StdString = ''): Boolean;

  {$IFDEF IncludeSystemFont}
    // Loads and initializes one of the predefined system fonts. These are embedded within the final
    // application and can be used at any time. The drawback of this is that these fonts don't look pretty as
    // the pre-rendered ones and typically contain only ASCII characters. The given pixel format, if
    // specified, will be used as a hint for initializing font letters image. Returns @True when successful
    // and @False otherwise.
    function LoadSystemFont(const AFontImage: TSystemFontImage = TSystemFontImage.Font8x8;
      const APixelFormat: TPixelFormat = TPixelFormat.Unknown): Boolean;
  {$ENDIF}

    // Image format manager for loading and saving different formats.
    property ImageFormatManager: TCustomImageFormatManager read FImageFormatManager;

    // Unique name of the font by which it can be referenced in @link(TBitmapFonts) list.
    property Name: StdString read FName write FName;

    // Destination canvas to which the text should be rendered to. This can be changed between different
    // drawing calls to a different canvas, as long as such canvas is bound to the same device as the font.
    property Canvas: TCanvas read FCanvas write FCanvas;

    // The image containing all available font letters.
    property Surface: TPixelSurface read FSurface;

    // Font size that defines maximum rectangle that a letter can occupy.
    property Size: TPoint read FSize;

    // Font width that defines maximum width in pixels that a letter can occupy.
    property Width: Integer read FSize.X;

    // Font height that defines maximum height in pixels that a letter can occupy.
    property Height: Integer read FSize.Y;

    // Characters that can be used to separate words in multi-line text drawing with @link(DrawTextBox).
    property WordSeparators: UniString read FWordSeparators write FWordSeparators;

    // Characters that can be used to indicate start of new paragraph in multi-line text drawing with
    // @link(DrawTextBox).
    property ParagraphSeparators: UniString read FParagraphSeparators write FParagraphSeparators;

    // Global font scale that is applied to the whole rendered text. Changing this value will likely result
    // in non-pixel-perfect text rendering appearing blurry. However, it can be used for text animations.
    property Scale: Single read FScale write FScale;

    // Global spacing that will be added horizontally between text letters. This can be used to expand or
    // shrink the text.
    property Interleave: Single read FInterleave write FInterleave;

    // The width in pixels corresponding to "space" or other empty characters (that is, characters without
    // an image).
    property SpaceWidth: Single read FSpaceWidth write FSpaceWidth;

    // Global spacing that will be added vertically between text lines when drawing with @link(DrawTextBox).
    property VerticalSpace: Single read FVerticalSpace write FVerticalSpace;
  end;

  // The list that may contain one or more instances of @link(TBitmapFont) and provide facilities to search
  // for fonts by their unique names, font loading and handling "device lost" scenario.
  TBitmapFonts = class
  private
    FImageFormatManager: TCustomImageFormatManager;
    FCanvas: TCanvas;

    FFonts: array of TBitmapFont;
    FSearchList: array of Integer;
    FSearchListDirty: Boolean;

    function GetCount: Integer;
    function GetItem(const AIndex: Integer): TBitmapFont;

    function InsertFont: Integer;
    function GetFont(const AName: StdString): TBitmapFont;

    procedure InitSearchList;
    procedure SwapSearchList(const AIndex1, AIndex2: Integer);
    function CompareSearchList(const AIndex1, AIndex2: Integer): Integer;
    function SplitSearchList(const AStart, AStop: Integer): Integer;
    procedure SortSearchList(const AStart, AStop: Integer);
    procedure UpdateSearchList;
    procedure SetCanvas(const ACanvas: TCanvas);
  public
    // Creates a new instance of font container.
    constructor Create(const AImageFormatManager: TCustomImageFormatManager);
    { @exclude } destructor Destroy; override;

    // Loads binary font from the given stream and adds its to the list with the given name. The given pixel
    // format, if specified, will be used as a hint for initializing font letters image. Returns font index
    // in the list when successful and -1 otherwise.
    function AddFromBinaryStream(const AStream: TStream; const AFontName: StdString = ''): Integer;

    // Loads binary font from external file and adds its to the list with font name equal to file name
    // (without extension). The given pixel format, if specified, will be used as a hint for initializing
    // font letters image. Returns font index in the list when successful and -1 otherwise.
    function AddFromBinaryFile(const AFileName: StdString): Integer;

    // Loads font letter information and letter image from their corresponding streams and adds the resulting
    // font to the list with the given name. This uses image format manager reference from associated device.
    // The image extension indicates what image format for letters image is used. The given pixel format, if
    // specified, will be used as a hint for initializing font letters image. Returns font index in the list
    // when successful and -1 otherwise.
    function AddFromXMLStream(const AImageExtension: StdString; const AImageStream, AXMLStream: TStream;
      const AFontName: StdString = ''): Integer;

    // Loads font letter information and letter image from external files on disk and adds the resulting font
    // to the list with the name equal to that of file name (without extension). This methods accepts that
    // one of file names is left empty and will be guessed by either changing extension from ".xml" to ".png"
    // or vice-versa. This uses image format manager reference from associated device. The given pixel format,
    // if specified, will be used as a hint for initializing font letters image. Returns font index in the
    // list when successful and -1 otherwise.
    function AddFromXMLFile(const AImageFileName: StdString; const AXMLFileName: StdString = ''): Integer;

  {$IFDEF IncludeSystemFont}
    // Adds and initializes one of the predefined system fonts to the list with the given name. These are
    // embedded within the final application and can be used at any time. The drawback of this is that these
    // fonts don't look pretty as the pre-rendered ones and typically contain only ASCII characters.
    // The given pixel format, if specified, will be used as a hint for initializing font letters image.
    // Returns font index in the list when successful and -1 otherwise.
    function AddSystemFont(const AFontImage: TSystemFontImage = TSystemFontImage.Font8x8;
      const AFontName: StdString = ''): Integer;
  {$ENDIF}

    // Returns the index of font with given unique name (not case-sensitive) in the list. If no font with
    // such name exists, returns -1.
    function IndexOf(const AFontName: StdString): Integer; overload;

    // Returns the index of the given font element in the list. If such font is not found, -1 is returned.
    function IndexOf(const AElement: TBitmapFont): Integer; overload;

    // Inserts the given font to the list and returns its index.
    function Insert(const AFont: TBitmapFont): Integer;

    // Includes the specified font to the list, if it wasn't included previously. This implies searching
    // the list before adding the element, which may impact performance. }
    function Include(const AElement: TBitmapFont): Integer;

    // Removes font with the specified index from the list.
    procedure Remove(const AIndex: Integer);

    // Removes all font entries from the list.
    procedure Clear;

    // Indicates that one of the fonts had its name changed, so the list needs to be refreshed to make
    // searching by name (@link(IndexOf) function and @link(Font) property) work properly.
    procedure MarkSearchDirty;

    // Image format manager for loading and saving different formats.
    property ImageFormatManager: TCustomImageFormatManager read FImageFormatManager;

    // Destination canvas to which the text should be rendered to. This can be changed between different
    // drawing calls to a different canvas, as long as such canvas is bound to the same device as the fonts.
    // Note that setting this property changes @code(Canvas) value for all the fonts in the list to this same
    // value.
    property Canvas: TCanvas read FCanvas write SetCanvas;

    // Total number of elements in the list.
    property Count: Integer read GetCount;

    // Provides access to individual fonts in the list by the corresponding index. If the index is outside of
    // valid range, @nil is returned.
    property Items[const AIndex: Integer]: TBitmapFont read GetItem; default;

    // Provides access to individual fonts in the list by unique font name (not case-sensitive). If no font
    // with such name is found, @nil is returned.
    property Font[const AName: StdString]: TBitmapFont read GetFont;
  end;

implementation

uses
  SysUtils, Math, PXL.Consts, PXL.Logs, PXL.Classes;

{$IFDEF IncludeSystemFont}
  {$INCLUDE PXL.SystemFont.inc}
{$ENDIF}

{$REGION 'TBitmapFont Callbacks'}

procedure DrawTextCallback(const ASender: TObject; const ASurface: TPixelSurface; const ASourceRect: TRect;
  const ADestRect: TRectF; const AColor: TColorRect; const AUserContext: Pointer);
begin
  TCanvas(AUserContext).TexQuadPx(ASurface, Quad(ADestRect), Quad(ASourceRect), AColor);
end;

{$ENDREGION}
{$REGION 'TBitmapFont'}

constructor TBitmapFont.Create(const AImageFormatManager: TCustomImageFormatManager);
begin
  inherited Create;

  FImageFormatManager := AImageFormatManager;
  FSurface := TPixelSurface.Create;

  FScale := 1.0;
  FInterleave := -1;
  FSpaceWidth := 5.0;
  FVerticalSpace := 2.0;

  FParagraphSeparators := #10;
  FWordSeparators := #13#32#8;
end;

destructor TBitmapFont.Destroy;
begin
  FSurface.Free;
  inherited;
end;

function TBitmapFont.ReadFontEntriesFromStream(const AStream: TStream): Boolean;
var
  I, LGlyphCount, LCharCode: Integer;
begin
  FillChar(FEntries, SizeOf(FEntries), 0);
  try
    // Font Width and Height
    FSize.X := AStream.GetWord;
    FSize.Y := AStream.GetWord;

    // Width of space or blank characters.
    FSpaceWidth := AStream.GetSmallInt;

    // Number of Glyphs
    LGlyphCount := AStream.GetLongInt;

    // Individual Glyphs
    for I := 0 to LGlyphCount - 1 do
    begin
      // Character Code
      LCharCode := AStream.GetWord;
      if (LCharCode < 0) or (LCharCode > High(Word)) then
        Exit(False);

      with FEntries[LCharCode] do
      begin
        // Vertical Margins
        TopBase := AStream.GetSmallInt;
        BottomBase := AStream.GetSmallInt;

        // Glyph Position
        MapLeft := AStream.GetLongInt;
        MapTop := AStream.GetLongInt;

        // Glyph Size
        MapWidth := AStream.GetWord;
        MapHeight := AStream.GetWord;

        // Horizontal Placement Margins
        LeadingSpace := AStream.GetSmallInt;
        TrailingSpace := AStream.GetSmallInt;
      end;
    end;
  except
    Exit(False);
  end;
  Result := True;
end;

function TBitmapFont.ReadSurfaceFromStream(const AStream: TStream; const AFormat: TPixelFormat;
  const AActualHeight: Integer): Boolean;
var
  I, J, LHeight, LGray: Integer;
  LTempBytes: TBytes;
  LDestPixel: PIntColor;
  LSrcPixel: TIntColor;
begin
  LHeight := Min(AActualHeight, FSurface.Height);

  case AFormat of
    TPixelFormat.A8R8G8B8:
      begin
        for J := 0 to LHeight - 1 do
          AStream.Read(FSurface.Scanline[J]^, FSurface.Width * SizeOf(TIntColor))
      end;

    TPixelFormat.A4R4G4B4:
      begin
        SetLength(LTempBytes, FSurface.Width * 2);

        for J := 0 to LHeight - 1 do
        begin
          AStream.Read(LTempBytes[0], FSurface.Width * 2);
          LDestPixel := FSurface.Scanline[J];

          for I := 0 to FSurface.Width - 1 do
          begin
            LSrcPixel := PWord(@LTempBytes[I * 2])^;
            LDestPixel^ :=
              (((LSrcPixel and $0F) * 255) div 15) or
              (((((LSrcPixel shr 4) and $0F) * 255) div 15) shl 8) or
              (((((LSrcPixel shr 8) and $0F) * 255) div 15) shl 16) or
              (((((LSrcPixel shr 12) and $0F) * 255) div 15) shl 24);

            Inc(LDestPixel);
          end;
        end;
      end;

    TPixelFormat.A8L8:
      begin
        SetLength(LTempBytes, FSurface.Width * 2);

        for J := 0 to LHeight - 1 do
        begin
          AStream.Read(LTempBytes[0], FSurface.Width * 2);
          LDestPixel := FSurface.Scanline[J];

          for I := 0 to FSurface.Width - 1 do
          begin
            LSrcPixel := PWord(@LTempBytes[I * 2])^;
            LGray := LSrcPixel and $FF;

            LDestPixel^ := IntColorRGB(LGray, LGray, LGray, LSrcPixel shr 8);
            Inc(LDestPixel);
          end;
        end;
      end;

    TPixelFormat.A4L4:
      begin
        SetLength(LTempBytes, FSurface.Width);

        for J := 0 to LHeight - 1 do
        begin
          AStream.Read(LTempBytes[0], FSurface.Width);
          LDestPixel := FSurface.Scanline[J];

          for I := 0 to FSurface.Width - 1 do
          begin
            LSrcPixel := PByte(@LTempBytes[I])^;
            LGray := ((LSrcPixel and $F) * 255) div 15;

            LDestPixel^ := IntColorRGB(LGray, LGray, LGray, ((LSrcPixel shr 4) * 255) div 15);
            Inc(LDestPixel);
          end;
        end;
      end;

    TPixelFormat.A8:
      begin
        SetLength(LTempBytes, FSurface.Width);

        for J := 0 to LHeight - 1 do
        begin
          AStream.Read(LTempBytes[0], FSurface.Width);
          LDestPixel := FSurface.Scanline[J];

          for I := 0 to FSurface.Width - 1 do
          begin
            LDestPixel^ := IntColorRGB(255, 255, 255, PByte(@LTempBytes[I])^);
            Inc(LDestPixel);
          end;
        end;
      end;

    TBitmapFont.TPixelFormat.B8G8R8A8:
      begin
        SetLength(LTempBytes, FSurface.Width * SizeOf(TIntColor));

        for J := 0 to LHeight - 1 do
        begin
          AStream.Read(LTempBytes[0], FSurface.Width * SizeOf(TIntColor));
          LDestPixel := FSurface.Scanline[J];

          for I := 0 to FSurface.Width - 1 do
          begin
            LDestPixel^ := DisplaceRB(PIntColor(@LTempBytes[I * SizeOf(TIntColor)])^);
            Inc(LDestPixel);
          end;
        end;
      end;

  else
    Exit(False);
  end;

  for J := LHeight to FSurface.Height - 1 do
    FillChar(FSurface.Scanline[J]^, FSurface.Width * SizeOf(TIntColor), 0);

  Result := True;
end;

function TBitmapFont.ReadFontImageFromStream(const AStream: TStream): Boolean;
var
  LSkippedLines, LActualHeight: Integer;
  LSize: TPoint;
  LFormat: TPixelFormat;
begin
  try
    // Width and Height
    LSize.X := AStream.GetLongInt;
    LSize.Y := AStream.GetLongInt;

    if (LSize.X < 1) or (LSize.Y < 1) then
      Exit(False);

    // Texture Pixel Format
    LFormat := TPixelFormat(AStream.GetByte);
    if (LFormat < Low(TPixelFormat)) or (LFormat > High(TPixelFormat)) or
      (LFormat = TPixelFormat.Unknown) then
      Exit(False);

    if not FSurface.SetSize(LSize) then
      Exit(False);

    // Texture Lines that are skipped
    LSkippedLines := AStream.GetLongInt;
    if LSkippedLines > 0 then
      LActualHeight := Max(LSize.Y - LSkippedLines, 0)
    else
      LActualHeight := LSize.Y;

    // Texture Data
    Result := ReadSurfaceFromStream(AStream, LFormat, LActualHeight);
  except
    Exit(False);
  end;
end;

{$IFDEF IncludeSystemFont}
procedure TBitmapFont.ReadSurfaceFromSystemFont;

  function IsPixelOpaque(const X, Y: Integer): Boolean; inline;
  begin
    Result := SystemFont8x8[(Y shl 4) + (X shr 3)] and (1 shl (X and $07)) > 0;
  end;

var
  I, J, LBlockNo: Integer;
  LDestPixel: PIntColor;
begin
  for J := 0 to FSurface.Height - 1 do
  begin
    LDestPixel := FSurface.Scanline[J];

    if FSurface.Width = 144 then
      for LBlockNo := 0 to 15 do
      begin // 9x8 font
        for I := 0 to 7 do
        begin
          if IsPixelOpaque(LBlockNo * 8 + I, J) then
            LDestPixel^ := IntColorWhite
          else
            LDestPixel^ := IntColorTranslucentBlack;

          Inc(LDestPixel);
        end;

        // Repeat last pixel
        if IsPixelOpaque(LBlockNo * 8 + 7, J) then
          LDestPixel^ := IntColorWhite
        else
          LDestPixel^ := IntColorTranslucentBlack;

        Inc(LDestPixel);
      end
    else
      for I := 0 to FSurface.Width - 1 do
      begin // 8x8 font
        if IsPixelOpaque(I, J) then
          LDestPixel^ := IntColorWhite
        else
          LDestPixel^ := IntColorTranslucentBlack;

        Inc(LDestPixel);
      end;
  end;
end;
{$ENDIF}

function TBitmapFont.LoadFromBinaryStream(const AStream: TStream): Boolean;
begin
  if AStream = nil then
    Exit(False);

  if not ReadFontEntriesFromStream(AStream) then
    Exit(False);

  Result := ReadFontImageFromStream(AStream);
end;

function TBitmapFont.LoadFromBinaryFile(const AFileName: StdString): Boolean;
var
  AStream: TFileStream;
begin
  try
    AStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      Result := LoadFromBinaryStream(AStream);
    finally
      AStream.Free;
    end;
  except
    Exit(False);
  end;

  if Result then
    FName := ChangeFileExt(AFileName, '');
end;

function TBitmapFont.ReadEntryFromXML(const ANode: TXMLNode): Boolean;
var
  LCharCode: Integer;
begin
  LCharCode := StrToIntDef(ANode.FieldValue['ascii'], -1);

  if (LCharCode < 0) or (LCharCode > 255) then
    LCharCode := StrToIntDef(ANode.FieldValue['ucode'], -1);

  if (LCharCode < 0) or (LCharCode > High(Word)) then
    Exit(False);

  with FEntries[LCharCode] do
  begin
    TopBase := Saturate(StrToIntDef(ANode.FieldValue['top'], 0), 0, 255);
    BottomBase := Saturate(StrToIntDef(ANode.FieldValue['bottom'], 0), 0, 255);
    MapLeft := Saturate(StrToIntDef(ANode.FieldValue['x'], 0), 0, 65535);
    MapTop := Saturate(StrToIntDef(ANode.FieldValue['y'], 0), 0, 65535);
    MapWidth := Saturate(StrToIntDef(ANode.FieldValue['width'], 0), 0, 255);
    MapHeight := Saturate(StrToIntDef(ANode.FieldValue['height'], 0), 0, 255);
    LeadingSpace := Saturate(StrToIntDef(ANode.FieldValue['leading'], 0), -128, 127);
    TrailingSpace := Saturate(StrToIntDef(ANode.FieldValue['trailing'], 0), -128, 127);
  end;

  Result := True;
end;

function TBitmapFont.ReadFromXMLNode(const ANode: TXMLNode): Boolean;
var
  LChunk: TXMLChunk;
begin
  Result := False;
  FSize.X := StrToIntDef(ANode.FieldValue['width'], 0);
  FSize.Y := StrToIntDef(ANode.FieldValue['height'], 0);

  FSpaceWidth := StrToIntDef(ANode.FieldValue['space'], 0);
  if FSpaceWidth <= 0 then
    FSpaceWidth := FSize.X div 4;

  for LChunk in ANode do
    if (LChunk is TXMLNode) and SameText(TXMLNode(LChunk).Name, 'item') then
    begin
      Result := ReadEntryFromXML(TXMLNode(LChunk));
      if not Result then
        Break;
    end;
end;

function TBitmapFont.LoadEntriesFromXMLStream(const AStream: TStream): Boolean;
var
  LNode: TXMLNode;
begin
  LNode := LoadXMLFromStream(AStream);
  if LNode = nil then
    Exit(False);
  try
    Result := ReadFromXMLNode(LNode);
  finally
    LNode.Free;
  end;
end;

function TBitmapFont.LoadEntriesFromXMLFile(const AFileName: StdString): Boolean;
var
  LNode: TXMLNode;
begin
  LNode := LoadXMLFromFile(AFileName);
  if LNode = nil then
    Exit(False);
  try
    Result := ReadFromXMLNode(LNode);
  finally
    LNode.Free;
  end;
end;

function TBitmapFont.LoadFromXMLStream(const AImageExtension: StdString; const AImageStream,
  AXMLStream: TStream): Boolean;
begin
  if (AImageStream = nil) or (AXMLStream = nil) then
    Exit(False);

  if not FImageFormatManager.LoadFromStream(AImageExtension, AImageStream, FSurface) then
    Exit(False);

  Result := LoadEntriesFromXMLStream(AXMLStream);
end;

function TBitmapFont.LoadFromXMLFile(const AImageFileName, AXMLFileName: StdString): Boolean;
var
  LText: StdString;
begin
  if (Length(AImageFileName) < 1) and (Length(AXMLFileName) < 1) then
    Exit(False);

  LText := AImageFileName;
  if Length(LText) < 1 then
    LText := ChangeFileExt(AXMLFileName, DefaultImageExtension);

  if not FImageFormatManager.LoadFromFile(LText, FSurface) then
    Exit(False);

  LText := AXMLFileName;
  if Length(LText) < 1 then
    LText := ChangeFileExt(AImageFileName, DefaultXMLExtension);

  Result := LoadEntriesFromXMLFile(LText);
  if Result then
    FName := ChangeFileExt(LText, '');
end;

{$IFDEF IncludeSystemFont}
function TBitmapFont.LoadSystemFont(const AFontImage: TSystemFontImage; const APixelFormat: TPixelFormat): Boolean;
var
  LFontSize: TPoint;
  I: Integer;
begin
  if AFontImage = TSystemFontImage.Font9x8 then
    LFontSize := Point(144, 128)
  else
    LFontSize := Point(128, 128);

  FillChar(FEntries, SizeOf(FEntries), 0);

  if AFontImage = TSystemFontImage.Font9x8 then
  begin
    FSize := Point(9, 8);
    FInterleave := 0;
  end
  else
  begin
    FSize := Point(8, 8);
    FInterleave := 1;
  end;

  FSpaceWidth := 4;
  FVerticalSpace := 0;

  for I := 0 to 255 do
    with FEntries[I] do
    begin
      if AFontImage = TSystemFontImage.Font9x8 then
      begin
        MapLeft := (I mod 16) * 9 + SystemFont8x8Starts[I];
        MapWidth := Max(1 + Integer(SystemFont8x8Ends[I]) - Integer(SystemFont8x8Starts[I]), 0);

        if MapWidth > 0 then
          Inc(MapWidth);
      end
      else
      begin
        MapLeft := (I mod 16) * 8 + SystemFont8x8Starts[I];
        MapWidth := Max(1 + Integer(SystemFont8x8Ends[I]) - Integer(SystemFont8x8Starts[I]), 0);
      end;

      MapTop := (I div 16) * 8;
      MapHeight := 8;
    end;

  if not FSurface.SetSize(LFontSize) then
    Exit(False);

  ReadSurfaceFromSystemFont;
  Result := True;
end;
{$ENDIF}

function TBitmapFont.DrawTextCustom(const APosition: TPointF; const AText: UniString; const AColor1,
  AColor2: TIntColor; const ATextEntryEvent: TTextEntryEvent; const AUserContext: Pointer): Boolean;
var
  LCharEntry: PLetterEntry;
  LCharIndex, LCharCode: Integer;
  LDrawPos: Single;
  LDrawRect: TRectF;
  LColorRect: TColorRect;
begin
  if not Assigned(ATextEntryEvent) then
    Exit(False);

  LDrawPos := APosition.X;
  LCharIndex := 1;

  while LCharIndex <= Length(AText) do
  begin
    LCharCode := Ord(AText[LCharIndex]);
    LCharEntry := @FEntries[LCharCode];

    if (LCharEntry.MapWidth < 1) or (LCharEntry.MapHeight < 1) then
    begin
      Inc(LCharIndex);
      LDrawPos := LDrawPos + FSpaceWidth * FScale;
      Continue;
    end;

    LDrawPos := LDrawPos + LCharEntry.LeadingSpace * FScale;

    LDrawRect.Left := LDrawPos;
    LDrawRect.Top := APosition.Y + LCharEntry.TopBase * FScale;
    LDrawRect.Right := LDrawRect.Left + LCharEntry.MapWidth * FScale;
    LDrawRect.Bottom := LDrawRect.Top + LCharEntry.MapHeight * FScale;

    LColorRect.TopLeft := LerpPixels(AColor1, AColor2, LCharEntry.TopBase / FSize.Y);
    LColorRect.BottomLeft := LerpPixels(AColor1, AColor2, (LCharEntry.TopBase + LCharEntry.MapHeight) /
      FSize.Y);

    LColorRect.TopRight := LColorRect.TopLeft;
    LColorRect.BottomRight := LColorRect.BottomLeft;

    ATextEntryEvent(Self, FSurface, Bounds(LCharEntry.MapLeft, LCharEntry.MapTop, LCharEntry.MapWidth,
      LCharEntry.MapHeight), LDrawRect, LColorRect, AUserContext);

    Inc(LCharIndex);
    LDrawPos := LDrawPos + (LCharEntry.MapWidth + LCharEntry.TrailingSpace + FInterleave) * FScale;
  end;

  Result := True;
end;

function TBitmapFont.TextExtent(const AText: UniString): TPointF;
var
  LCharEntry: PLetterEntry;
  LCharIndex, LCharCode: Integer;
  LKerningAdjust: Boolean;
begin
  LCharIndex := 1;

  Result.X := 0;
  Result.Y := FSize.Y * FScale;

  LKerningAdjust := False;

  while LCharIndex <= Length(AText) do
  begin
    LCharCode := Ord(AText[LCharIndex]);
    LCharEntry := @FEntries[LCharCode];

    if (LCharEntry.MapWidth < 1) or (LCharEntry.MapHeight < 1) then
    begin
      Inc(LCharIndex);

      Result.X := Result.X + FSpaceWidth * FScale;
      Continue;
    end;

    Inc(LCharIndex);

    Result.X := Result.X + (LCharEntry.MapWidth + LCharEntry.LeadingSpace + LCharEntry.TrailingSpace +
      FInterleave) * FScale;

    LKerningAdjust := True;
  end;

  if LKerningAdjust then
    Result.X := Result.X - FInterleave * FScale;
end;

function TBitmapFont.TextRects(const AText: UniString): TTextRects;
var
  LCharIndex, LCharCode: Integer;
  LCharEntry: PLetterEntry;
  LRectPos: Single;
  LRect: TRectF;
begin
  LRectPos := 0;
  LCharIndex := 1;

  LRect.Top := 0;
  LRect.Bottom := FSize.Y * FScale;
  SetLength(Result, 0);

  while LCharIndex <= Length(AText) do
  begin
    LCharCode := Ord(AText[LCharIndex]);
    LCharEntry := @FEntries[LCharCode];

    if (LCharEntry.MapWidth < 1) or (LCharEntry.MapHeight < 1) then
    begin
      Inc(LCharIndex);

      LRect.Left := LRectPos;
      LRect.Right := LRectPos + FSpaceWidth * FScale;
      SetLength(Result, Length(Result) + 1);
      Result[Length(Result) - 1] := LRect;

      LRectPos := LRectPos + FSpaceWidth * FScale;
      Continue;
    end;

    LRectPos := LRectPos + LCharEntry.LeadingSpace * FScale;

    LRect.Left := LRectPos;
    LRect.Right := LRectPos + (LCharEntry.MapWidth + LCharEntry.TrailingSpace) * FScale;
    SetLength(Result, Length(Result) + 1);
    Result[Length(Result) - 1] := LRect;

    Inc(LCharIndex);
    LRectPos := LRectPos + (LCharEntry.MapWidth + LCharEntry.TrailingSpace + FInterleave) * FScale;
  end;
end;

function TBitmapFont.TextWidth(const AText: UniString): Single;
begin
  Result := TextExtent(AText).X;
end;

function TBitmapFont.TextHeight(const AText: UniString): Single;
begin
  Result := TextExtent(AText).Y;
end;

function TBitmapFont.TextExtentInt(const AText: UniString): TPoint;
var
  Ext: TPointF;
begin
  Ext := TextExtent(AText);

  Result.X := Round(Ext.X);
  Result.Y := Round(Ext.Y);
end;

function TBitmapFont.TextWidthInt(const AText: UniString): Integer;
begin
  Result := TextExtentInt(AText).X;
end;

function TBitmapFont.TextHeightInt(const AText: UniString): Integer;
begin
  Result := TextExtentInt(AText).Y;
end;

procedure TBitmapFont.DrawText(const APosition: TPointF; const AText: UniString; const AColor1,
  AColor2: TIntColor);
begin
  if FCanvas <> nil then
    DrawTextCustom(APosition, AText, AColor1, AColor2, DrawTextCallback, FCanvas);
end;

procedure TBitmapFont.DrawTextAligned(const APosition: TPointF; const AText: UniString; const AColor1,
  AColor2: TIntColor; const AHorizAlign, AVertAlign: TTextAlignment);
var
  LDrawAt, LTextSize: TPointF;
begin
  if (AHorizAlign = TTextAlignment.Start) and (AVertAlign = TTextAlignment.Start) then
  begin
    DrawText(APosition, AText, AColor1, AColor2);
    Exit;
  end;

  LDrawAt := APosition;
  LTextSize := TextExtent(AText);

  case AHorizAlign of
    TTextAlignment.Middle:
      LDrawAt.X := APosition.X - LTextSize.X * 0.5;

    TTextAlignment.Final:
      LDrawAt.X := APosition.X - LTextSize.X;

    else
      LDrawAt.X := APosition.X;
  end;

  case AVertAlign of
    TTextAlignment.Middle:
      LDrawAt.Y := APosition.Y - LTextSize.Y * 0.5;

    TTextAlignment.Final:
      LDrawAt.Y := APosition.Y - LTextSize.Y;

    else
      LDrawAt.Y := APosition.Y;
  end;

  DrawText(LDrawAt, AText, AColor1, AColor2);
end;

procedure TBitmapFont.DrawTextCentered(const APosition: TPointF; const AText: UniString; const AColor1,
  AColor2: TIntColor);
begin
  DrawTextAligned(APosition, AText, AColor1, AColor2, TTextAlignment.Middle, TTextAlignment.Middle);
end;

function TBitmapFont.IsWordSeparator(const AValue: WideChar): Boolean;
begin
  Result := (AValue = #32) or (Pos(AValue, FWordSeparators) <> 0);
end;

function TBitmapFont.ExtractParagraphWord(const AText: UniString; var ACharIndex: Integer;
  var AParagraphIndex: Integer; out AWordText: UniString): Boolean;
var
  LWordStart, LWordLength: Integer;
begin
  AWordText := '';

  // Skip all unused characters.
  while (ACharIndex <= Length(AText)) and IsWordSeparator(AText[ACharIndex]) do
    Inc(ACharIndex);

  // Check for end of AText.
  if ACharIndex > Length(AText) then
    Exit(False);

  // Check for next paragraph.
  if Pos(AText[ACharIndex], FParagraphSeparators) <> 0 then
  begin
    Inc(AParagraphIndex);
    Inc(ACharIndex);
    Exit(True);
  end;

  // Start parsing the word.
  LWordStart := ACharIndex;
  LWordLength := 0;

  while (ACharIndex <= Length(AText)) and (Pos(AText[ACharIndex], FWordSeparators) = 0) do
  begin
    Inc(ACharIndex);
    Inc(LWordLength);
  end;

  // -> Extract AText segment.
  AWordText := Copy(AText, LWordStart, LWordLength);
  Result := LWordLength > 0;
end;

procedure TBitmapFont.SplitTextIntoWords(const AText: UniString);

  function AddWord(const AWordText: UniString; const AParagraphIndex: Integer): Integer;
  begin
    Result := Length(FParagraphWords);
    SetLength(FParagraphWords, Result + 1);

    FParagraphWords[Result].WordText := AWordText;
    FParagraphWords[Result].ParagraphIndex := AParagraphIndex;
  end;

var
  LParagraphIndex, LCharIndex: Integer;
  LWordText: UniString;
begin
  SetLength(FParagraphWords, 0);

  LCharIndex := 1;
  LParagraphIndex := 0;

  while ExtractParagraphWord(AText, LCharIndex, LParagraphIndex, LWordText) do
    if Length(LWordText) > 0 then
      AddWord(LWordText, LParagraphIndex);
end;

procedure TBitmapFont.DrawTextBox(const ATopLeft, ABoxSize, AParagraphShift: TPointF;
  const AText: UniString; const AColor1, AColor2: TIntColor);
var
  LParagraphIndex, LNextParagraphIndex: Integer;
  LWordIndex, LLastWordIndexInLine, LWordCountInLine, LSubIndex: Integer;
  LPredWordsInLineWidth, LTotalWordsInLineWidth, LTotalWhiteSpace, LRemainingLineWidth: Single;
  LLineHeight, LDrawOffset, LBlankSpacePerWord: Single;
  LPosition, LCurTextSize: TPointF;
begin
  if FCanvas = nil then
    Exit;

  SplitTextIntoWords(AText);

  LParagraphIndex := -1;
  LWordIndex := 0;

  LPosition.X := ATopLeft.X;

  while LWordIndex < Length(FParagraphWords) do
  begin
    LPredWordsInLineWidth := 0;
    LTotalWordsInLineWidth := 0;
    LTotalWhiteSpace := 0;
    LRemainingLineWidth := ABoxSize.X - (LPosition.X - ATopLeft.X);

    LLastWordIndexInLine := LWordIndex;
    LNextParagraphIndex := LParagraphIndex;

    while (LTotalWordsInLineWidth + LTotalWhiteSpace < LRemainingLineWidth) and
      (LLastWordIndexInLine < Length(FParagraphWords)) and (LNextParagraphIndex = LParagraphIndex) do
    begin
      LPredWordsInLineWidth := LTotalWordsInLineWidth;
      LTotalWordsInLineWidth := LTotalWordsInLineWidth +
        TextWidth(FParagraphWords[LLastWordIndexInLine].WordText);
      LTotalWhiteSpace := LTotalWhiteSpace + FSpaceWidth * FScale;
      LNextParagraphIndex := FParagraphWords[LLastWordIndexInLine].ParagraphIndex;

      Inc(LLastWordIndexInLine);
    end;

    LWordCountInLine := (LLastWordIndexInLine - LWordIndex) - 1;
    if (LLastWordIndexInLine >= Length(FParagraphWords)) and
      (LTotalWordsInLineWidth + LTotalWhiteSpace < LRemainingLineWidth) then
    begin
      Inc(LWordCountInLine);
      LPredWordsInLineWidth := LTotalWordsInLineWidth;
    end;

    if LWordCountInLine < 1 then
    begin
      // Case 1. New paragraph.
      if LNextParagraphIndex <> LParagraphIndex then
      begin
        LPosition.X := ATopLeft.X + AParagraphShift.X;

        if LWordIndex < 1 then
          LPosition.Y := ATopLeft.Y
        else
          LPosition.Y := LPosition.Y + AParagraphShift.Y;

        LParagraphIndex := LNextParagraphIndex;

        Continue;
      end
      else
        // Case 2. Exhausted words or size doesn't fit.
        Break;
    end;

    if LWordCountInLine > 1 then
      LBlankSpacePerWord := (LRemainingLineWidth - LPredWordsInLineWidth) / (LWordCountInLine - 1)
    else
      LBlankSpacePerWord := 0;

    if ((LNextParagraphIndex <> LParagraphIndex) and (LWordCountInLine > 1)) or
      (LWordIndex + LWordCountInLine >= Length(FParagraphWords)) then
      LBlankSpacePerWord := FSpaceWidth * FScale;

    LLineHeight := 0;
    LDrawOffset := 0;

    for LSubIndex := LWordIndex to LWordIndex + LWordCountInLine - 1 do
    begin
      DrawTextCustom(PointF(LPosition.X + Round(LDrawOffset), LPosition.Y),
        FParagraphWords[LSubIndex].WordText, AColor1, AColor2, DrawTextCallback, FCanvas);

      LCurTextSize := TextExtent(FParagraphWords[LSubIndex].WordText);

      LDrawOffset := LDrawOffset + LCurTextSize.X + LBlankSpacePerWord;
      LLineHeight := Max(LLineHeight, LCurTextSize.Y);
    end;

    LPosition.X := ATopLeft.X;
    LPosition.Y := LPosition.Y + LLineHeight + FVerticalSpace;

    if LPosition.Y >= ATopLeft.Y + ABoxSize.Y then
      Break;

    Inc(LWordIndex, LWordCountInLine);
  end;
end;

{$ENDREGION}
{$REGION 'TBitmapFonts'}

constructor TBitmapFonts.Create(const AImageFormatManager: TCustomImageFormatManager);
begin
  inherited Create;

  FImageFormatManager := AImageFormatManager;
end;

destructor TBitmapFonts.Destroy;
begin
  Clear;
  inherited;
end;

function TBitmapFonts.GetCount: Integer;
begin
  Result := Length(FFonts);
end;

function TBitmapFonts.GetItem(const AIndex: Integer): TBitmapFont;
begin
  if (AIndex >= 0) and (AIndex < Length(FFonts)) then
    Result := FFonts[AIndex]
  else
    Result := nil;
end;

procedure TBitmapFonts.SetCanvas(const ACanvas: TCanvas);
var
  I: Integer;
begin
  if FCanvas <> ACanvas then
  begin
    FCanvas := ACanvas;

    for I := 0 to Length(FFonts) - 1 do
      FFonts[I].Canvas := FCanvas;
  end;
end;

function TBitmapFonts.InsertFont: Integer;
begin
  Result := Length(FFonts);
  SetLength(FFonts, Result + 1);

  FFonts[Result] := TBitmapFont.Create(FImageFormatManager);
  FFonts[Result].Canvas := FCanvas;
end;

procedure TBitmapFonts.Remove(const AIndex: Integer);
var
  I: Integer;
begin
  if (AIndex < 0) or (AIndex >= Length(FFonts)) then
    Exit;

  FFonts[AIndex].Free;

  for I := AIndex to Length(FFonts) - 2 do
    FFonts[I] := FFonts[I + 1];

  SetLength(FFonts, Length(FFonts) - 1);
  FSearchListDirty := True;
end;

procedure TBitmapFonts.Clear;
var
  I: Integer;
begin
  for I := Length(FFonts) - 1 downto 0 do
    FFonts[I].Free;

  SetLength(FFonts, 0);
  FSearchListDirty := True;
end;

function TBitmapFonts.AddFromBinaryStream(const AStream: TStream; const AFontName: StdString): Integer;
begin
  Result := InsertFont;
  if not FFonts[Result].LoadFromBinaryStream(AStream) then
  begin
    Remove(Result);
    Exit(-1);
  end;

  FFonts[Result].Name := AFontName;
  FSearchListDirty := True;
end;

function TBitmapFonts.AddFromBinaryFile(const AFileName: StdString): Integer;
begin
  Result := InsertFont;
  if not FFonts[Result].LoadFromBinaryFile(AFileName) then
  begin
    Remove(Result);
    Exit(-1);
  end;
  FSearchListDirty := True;
end;

function TBitmapFonts.AddFromXMLStream(const AImageExtension: StdString; const AImageStream,
  AXMLStream: TStream; const AFontName: StdString): Integer;
begin
  Result := InsertFont;
  if not FFonts[Result].LoadFromXMLStream(AImageExtension, AImageStream, AXMLStream) then
  begin
    Remove(Result);
    Exit(-1);
  end;

  FFonts[Result].Name := AFontName;
  FSearchListDirty := True;
end;

function TBitmapFonts.AddFromXMLFile(const AImageFileName: StdString; const AXMLFileName: StdString): Integer;
begin
  Result := InsertFont;
  if not FFonts[Result].LoadFromXMLFile(AImageFileName, AXMLFileName) then
  begin
    Remove(Result);
    Exit(-1);
  end;
  FSearchListDirty := True;
end;

{$IFDEF IncludeSystemFont}
function TBitmapFonts.AddSystemFont(const AFontImage: TSystemFontImage; const AFontName: StdString): Integer;
begin
  Result := InsertFont;

  if not FFonts[Result].LoadSystemFont(AFontImage) then
  begin
    Remove(Result);
    Exit(-1);
  end;

  FFonts[Result].Name := AFontName;
  FSearchListDirty := True;
end;
{$ENDIF}

procedure TBitmapFonts.InitSearchList;
var
  I: Integer;
begin
  if Length(FSearchList) <> Length(FFonts) then
    SetLength(FSearchList, Length(FFonts));

  for I := 0 to Length(FFonts) - 1 do
    FSearchList[I] := I;
end;

procedure TBitmapFonts.SwapSearchList(const AIndex1, AIndex2: Integer);
var
  LTempValue: Integer;
begin
  LTempValue := FSearchList[AIndex1];
  FSearchList[AIndex1] := FSearchList[AIndex2];
  FSearchList[AIndex2] := LTempValue;
end;

function TBitmapFonts.CompareSearchList(const AIndex1, AIndex2: Integer): Integer;
begin
  Result := CompareText(FFonts[FSearchList[AIndex1]].Name, FFonts[FSearchList[AIndex2]].Name);
end;

function TBitmapFonts.SplitSearchList(const AStart, AStop: Integer): Integer;
var
  LLeft, LRight, LPivot: Integer;
begin
  LLeft := AStart + 1;
  LRight := AStop;
  LPivot := FSearchList[AStart];

  while LLeft <= LRight do
  begin
    while (LLeft <= AStop) and (CompareSearchList(FSearchList[LLeft], LPivot) < 0) do
      Inc(LLeft);

    while (LRight > AStart) and (CompareSearchList(FSearchList[LRight], LPivot) >= 0) do
      Dec(LRight);

    if LLeft < LRight then
      SwapSearchList(LLeft, LRight);
  end;

  SwapSearchList(AStart, LRight);
  Result := LRight;
end;

procedure TBitmapFonts.SortSearchList(const AStart, AStop: Integer);
var
  LSplitPt: Integer;
begin
  if AStart < AStop then
  begin
    LSplitPt := SplitSearchList(AStart, AStop);

    SortSearchList(AStart, LSplitPt - 1);
    SortSearchList(LSplitPt + 1, AStop);
  end;
end;

procedure TBitmapFonts.UpdateSearchList;
begin
  InitSearchList;

  if Length(FSearchList) > 1 then
    SortSearchList(0, Length(FSearchList) - 1);

  FSearchListDirty := False;
end;

function TBitmapFonts.IndexOf(const AFontName: StdString): Integer;
var
  LLeft, LRight, LPivot, LRes: Integer;
begin
  if FSearchListDirty then
    UpdateSearchList;

  LLeft := 0;
  LRight := Length(FSearchList) - 1;

  while LLeft <= LRight do
  begin
    LPivot := (LLeft + LRight) div 2;
    LRes := CompareText(FFonts[FSearchList[LPivot]].Name, AFontName);

    if LRes = 0 then
      Exit(FSearchList[LPivot]);

    if LRes > 0 then
      LRight := LPivot - 1
    else
      LLeft := LPivot + 1;
  end;

  Result := -1;
end;

function TBitmapFonts.IndexOf(const AElement: TBitmapFont): Integer;
var
  I: Integer;
begin
  if AElement = nil then
    Exit(-1);

  for I := 0 to Length(FFonts) - 1 do
    if FFonts[I] = AElement then
      Exit(I);

  Result := -1;
end;

function TBitmapFonts.Insert(const AFont: TBitmapFont): Integer;
begin
  Result := Length(FFonts);
  SetLength(FFonts, Result + 1);

  FFonts[Result] := AFont;
  FFonts[Result].Canvas := FCanvas;
end;

function TBitmapFonts.Include(const AElement: TBitmapFont): Integer;
begin
  Result := IndexOf(AElement);
  if Result = -1 then
    Result := Insert(AElement);
end;

function TBitmapFonts.GetFont(const AName: StdString): TBitmapFont;
var
  Index: Integer;
begin
  Index := IndexOf(AName);
  if Index <> -1 then
    Result := FFonts[Index]
  else
    Result := nil;
end;

procedure TBitmapFonts.MarkSearchDirty;
begin
  FSearchListDirty := True;
end;

{$ENDREGION}

end.

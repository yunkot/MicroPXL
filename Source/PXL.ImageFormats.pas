unit PXL.ImageFormats;
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
{< Base foundation and declarations for supporting loading and saving different image formats in the framework. }
interface

{$INCLUDE PXL.Config.inc}

uses
  Classes, PXL.TypeDef, PXL.Types, PXL.Classes, PXL.Surfaces;

type
  // Abstract image format manager, which provides facilities for loading and saving different image formats.
  TCustomImageFormatManager = class abstract
  public
    // Loads image from specified stream.
    //   @param(AExtension Extension (including dot, e.g. ".png") that represents the format in which
    //     the image is stored in the stream.)
    //   @param(AStream Stream which will be used for reading the image from. The current position of the
    //     stream will be used and after the call it will be adjusted to be right at the end of image data.)
    //   @param(ADestSurface The destination surface where image data will be saved. It does need to be
    //     a valid instance of @link(TPixelSurface), but it may or may not be empty.)
    //   @returns(@True when successful or @False otherwise.)
    function LoadFromStream(const AExtension: StdString; const AStream: TStream;
      const ADestSurface: TPixelSurface): Boolean; virtual; abstract;

    // Saves image to specified stream.
    //   @param(AExtension Extension (including dot, e.g. ".png") that represents the format in which the
    //     image should be stored in the stream.)
    //   @param(AStream Stream which will be used for writing the image to. The current position of the
    //     stream will be used and after the call it will be adjusted to be right at the end of image data.)
    //   @param(ASourceSurface The source surface where image data will be taken from. Note that the surface
    //     pixel format may determine the format in which the image will be saved. However, since not all
    //     pixel formats may be supported, the function may fail. Typically. @italic(TPixelFormat.A8R8G8B8)
    //     is the most widely supported format and should work under most circumstances.)
    //   @param(AQuality Generic parameter that can be used as hint for saved image quality. For instance,
    //     for JPEG files, this is typically just an integer number (typecast to Pointer) representing
    //     quality between 0 and 100.)
    //   @returns(@True when successful or @False otherwise.)
    function SaveToStream(const AExtension: StdString; const AStream: TStream;
      const ASourceSurface: TPixelSurface; const AQuality: Pointer = nil): Boolean; virtual; abstract;

    // Loads image from specified file.
    //   @param(AFileName A valid file name (with extension) that includes full path that represents the
    //     image.)
    //   @param(ADestSurface The destination surface where image data will be saved. It does need to be
    //     a valid instance of @link(TPixelSurface), but it may or may not be empty.)
    //   @returns(@True when successful or @False otherwise.)
    function LoadFromFile(const AFileName: StdString;
      const ADestSurface: TPixelSurface): Boolean; virtual; abstract;

    // Saves image to specified file.
    //   @param(AFileName A valid file name (with extension) that includes full path where the image is to be
    //     saved. The path to this file must exist.)
    //   @param(ASourceSurface The source surface where image data will be taken from. Note that the surface
    //     pixel format may determine the format in which the image will be saved. However, since not all
    //     pixel formats may be supported, the function may fail. Typically. @italic(TPixelFormat.A8R8G8B8)
    //     is the most widely supported format and should work under most circumstances.)
    //   @param(AQuality Generic parameter that can be used as hint for saved image quality. For instance,
    //     for JPEG files, this is typically just an integer number (typecast to Pointer) representing
    //     quality between 0 and 100.)
    //   @returns(@True when successful or @False otherwise.)
    function SaveToFile(const AFileName: StdString; const ASourceSurface: TPixelSurface;
      const AQuality: Pointer = nil): Boolean; virtual; abstract;
  end;

  TImageFormatManager = class;

  // Extension class for @link(TImageFormatManager) that supports saving and loading different image formats
  // and can be plugged to one or more image format managers.
  TCustomImageFormatHandler = class abstract
  private
    FManager: TImageFormatManager;
    FHandlerIndexTemp: Integer;
  protected
    // Returns reference to image format manager that is associated with this handler. If there is more than
    // one manager referring to this handler, then the first one is returned.
    function GetManager: TImageFormatManager; virtual;

    // Registers a specific extension to be processed by this handler along with some custom
    // @italic(AContext) pointer, which will be saved and later provided to @link(LoadFromStream) and
    // @link(SaveToStream) methods.
    procedure RegisterExtension(const AExtension: StdString; const AContext: Pointer = nil); virtual;

    // This method is executed during creation of @link(TCustomImageFormatHandler) class to register
    // extensions that are supported by the handler. During this call, one or more @link(RegisterExtension)
    // calls should be made to register supported extensions.
    procedure RegisterExtensions; virtual; abstract;
  public
    // Creates instance of image format handler and associates it with the provided manager class.
    constructor Create(const AManager: TImageFormatManager);
    { @exclude } destructor Destroy; override;

    // Loads image from the stream. @italic(AContext) parameter will contain the same value as the one passed
    // to @link(RegisterExtension) function during creation. The rest of parameters have the same meaning as
    // in methods inside @link(TCustomImageFormatManager) class.
    function LoadFromStream(const AContext: Pointer; const AExtension: StdString; const AStream: TStream;
      const ADestSurface: TPixelSurface): Boolean; virtual; abstract;

    // Saves image to the stream. @italic(AContext) parameter will contain the same value as the one passed
    // to @link(RegisterExtension) function during creation. The rest of parameters have the same meaning as
    // in methods inside @link(TCustomImageFormatManager) class.
    function SaveToStream(const AContext: Pointer; const AExtension: StdString; const AStream: TStream;
      const ASourceSurface: TPixelSurface; const AQuality: Pointer): Boolean; virtual; abstract;

    // Reference to image format manager that is associated with this class.
    property Manager: TImageFormatManager read GetManager;
  end;

  // General-purpose Image Format Manager that has pluggable mechanism so that handlers (those derived from
  // @link(TCustomImageFormatHandler) class) can be associated with it to load and save different image
  // formats. If multiple handlers that support the same image format are associated, then the one that was
  // most recently associated will be used.
  TImageFormatManager = class(TCustomImageFormatManager)
  private type
    THandlerExtension = record
      Extension: StdString;
      Context: Pointer;
    end;

    THandlerRegistry = record
      Handler: TCustomImageFormatHandler;

      Extensions: array of THandlerExtension;
      ExtensionsDirty: Boolean;

      procedure ExtensionsSwap(const AIndex1, AIndex2: Integer);
      function ExtensionsCompare(const AIndex1, AIndex2: Integer): Integer; inline;
      function ExtensionsSplit(const AStart, AStop: Integer): Integer;
      procedure ExtensionsSort(const AStart, AStop: Integer);
      procedure ProcessExtensions;
      function IndexOfExtension(const AExtension: StdString): Integer;
      function AddExtension(const AExtension: StdString; const AContext: Pointer): Integer;
      procedure RemoveExtension(const AExtesionIndex: Integer);
    end;
  private
    FEntries: array of THandlerRegistry;

    procedure UnregisterHandlerIndex(const AHandlerIndex: Integer);
    procedure FindExtension(const AExtension: StdString; out AHandlerIndex, AExtensionIndex: Integer);
  public
    // Returns index (or the first occurrence) of the specified image format handler that is associated with
    // this class.
    function IndexOfHandler(const AImageFormatHandler: TCustomImageFormatHandler): Integer;

    // Registers specified image format handler with the manager and returns its index in the list.
    function RegisterHandler(const AImageFormatHandler: TCustomImageFormatHandler): Integer;

    // Removes specified image format handler from the list that was previously associated with the manager.
    procedure UnregisterHandler(const AImageFormatHandler: TCustomImageFormatHandler);

    // Removes all the associations with image format handlers from the list.
    procedure Clear;

    // Registers the specified image format handler (that was previously associated by using
    // @link(RegisterHandler) call, to the specified extension. If multiple handlers are registered to the
    // same extension, then the handler that was most recently registered will be used. @italic(Context)
    // parameter will be saved and then passed to the appropriate methods inside
    // @link(TCustomImageFormatHandler) class when loading and saving images.
    function RegisterExtension(const AExtension: StdString; const AHandler: TCustomImageFormatHandler;
      const AContext: Pointer): Boolean;

    // Removes the registry for given extension associated with the provided handler. If the handler is not
    // specified, or is @nil, then the first handler that supports such extension will be looked for. @True
    // is returned when the method success and @False otherwise. If it is necessary to unregister all
    // handlers for specific extension, then this method should be called multiple times until @False is
    // returned.
    function UnregisterExtension(const AExtension: StdString;
      const AHandler: TCustomImageFormatHandler = nil): Boolean;

    // Loads image from specified stream. This function will look through the internal registry and use one
    // of the most recently registered handlers that supports such extension. If no handler supports such
    // extension, the method will fail.
    //   @param(AExtension Extension (including dot, e.g. ".png") that represents the format in which the
    //     image is stored in the stream.)
    //   @param(AStream Stream which will be used for reading the image from. The current position of the
    //     stream will be used and after the call it will be adjusted to be right at the end of image data.)
    //   @param(ADestSurface The destination surface where image data will be saved. It does need to be
    //     a valid instance of @link(TPixelSurface), but it may or may not be empty.)
    //   @returns(@True when successful or @False otherwise.)
    function LoadFromStream(const AExtension: StdString; const AStream: TStream;
      const ADestSurface: TPixelSurface): Boolean; override;

   // Saves image to specified stream. This function will look through the internal registry and use one of
   // the most recently registered handlers that supports such extension. If no handler supports such
   // extension, the method will fail.
   //    @param(Extension Extension (including dot, e.g. ".png") that represents the format in which
   //      the image should be stored in the stream.)
   //    @param(Stream Stream which will be used for writing the image to. The current position of the stream
   //      will be used and after the call it will be adjusted to be right at the end of image data.)
   //    @param(SourceSurface The source surface where image data will be taken from. Note that the surface
   //      pixel format may determine the format in which the image will be saved. However, since not all
   //      pixel formats may be supported, the function may fail. Typically. @italic(TPixelFormat.A8R8G8B8)
   //      is the most widely supported format and should work under most circumstances.)
   //    @param(Quality Generic parameter that can be used as hint for saved image quality. For instance, for
   //      JPEG files, this is typically just an integer number (typecast to Pointer) representing quality
   //      between 0 and 100.)
   //    @returns(@True when successful or @False otherwise.)
    function SaveToStream(const AExtension: StdString; const AStream: TStream;
      const ASourceSurface: TPixelSurface; const AQuality: Pointer = nil): Boolean; override;

    // Loads image from specified file. This function will look through the internal registry and use one of
    // the most recently registered handlers that supports such extension. If no handler supports such
    // extension, the method will fail.
    //    @param(AFileName A valid file name (with extension) that includes full path that represents
    //      the image.)
    //    @param(ADestSurface The destination surface where image data will be saved. It does need to be
    //      a valid instance of @link(TPixelSurface), but it may or may not be empty.)
    //    @returns(@True when successful or @False otherwise.)
    function LoadFromFile(const AFileName: StdString; const ADestSurface: TPixelSurface): Boolean; override;

    // Saves image to specified file. This function will look through the internal registry and use one of
    // the most recently registered handlers that supports such extension. If no handler supports such
    // extension, the method will fail.
    //   @param(AFileName A valid file name (with extension) that includes full path where the image is to
    //     be saved. The path to this file must exist.)
    //   @param(ASourceSurface The source surface where image data will be taken from. Note that the surface
    //     pixel format may determine the format in which the image will be saved. However, since not all
    //     pixel formats may be supported, the function may fail. Typically. @italic(TPixelFormat.A8R8G8B8)
    //     is the most widely supported format and should work under most circumstances.)
    //   @param(AQuality Generic parameter that can be used as hint for saved image quality. For instance,
    //     for JPEG files, this is typically just an integer number (typecast to Pointer) representing
    // quality between 0 and 100.)
    //   @returns(@True when successful or @False otherwise.)
    function SaveToFile(const AFileName: StdString; const ASourceSurface: TPixelSurface;
      const AQuality: Pointer = nil): Boolean; override;
  end;

implementation

uses
  SysUtils;

{$REGION 'TCustomImageFormatHandler'}

constructor TCustomImageFormatHandler.Create(const AManager: TImageFormatManager);
begin
  inherited Create;

  FManager := AManager;
  if FManager <> nil then
  begin
    FHandlerIndexTemp := FManager.RegisterHandler(Self);
    try
      RegisterExtensions;
    finally
      FHandlerIndexTemp := -1;
    end;
  end;
end;

destructor TCustomImageFormatHandler.Destroy;
begin
  if FManager <> nil then
  begin
    FManager.UnregisterHandler(Self);
    FManager := nil;
  end;

  inherited;
end;

function TCustomImageFormatHandler.GetManager: TImageFormatManager;
begin
  Result := FManager;
end;

procedure TCustomImageFormatHandler.RegisterExtension(const AExtension: StdString; const AContext: Pointer);
begin
  if FManager <> nil then
    FManager.RegisterExtension(AExtension, Self, AContext);
end;

{$ENDREGION}
{$REGION 'TImageFormatManager.THandlerRegistry'}

procedure TImageFormatManager.THandlerRegistry.ExtensionsSwap(const AIndex1, AIndex2: Integer);
var
  LTempValue: THandlerExtension;
begin
  LTempValue := Extensions[AIndex1];
  Extensions[AIndex1] := Extensions[AIndex2];
  Extensions[AIndex2] := LTempValue;
end;

function TImageFormatManager.THandlerRegistry.ExtensionsCompare(const AIndex1, AIndex2: Integer): Integer;
begin
  Result := CompareText(Extensions[AIndex1].Extension, Extensions[AIndex2].Extension);
end;

function TImageFormatManager.THandlerRegistry.ExtensionsSplit(const AStart, AStop: Integer): Integer;
var
  LLeft, LRight, LPivot: Integer;
begin
  LLeft := AStart + 1;
  LRight := AStop;
  LPivot := AStart;

  while LLeft <= LRight do
  begin
    while (LLeft <= AStop) and (ExtensionsCompare(LLeft, LPivot) < 0) do
      Inc(LLeft);

    while (LRight > AStart) and (ExtensionsCompare(LRight, LPivot) >= 0) do
      Dec(LRight);

    if LLeft < LRight then
      ExtensionsSwap(LLeft, LRight);
  end;

  ExtensionsSwap(AStart, LRight);
  Result := LRight;
end;

procedure TImageFormatManager.THandlerRegistry.ExtensionsSort(const AStart, AStop: Integer);
var
  LSplitPt: Integer;
begin
  if AStart < AStop then
  begin
    LSplitPt := ExtensionsSplit(AStart, AStop);

    ExtensionsSort(AStart, LSplitPt - 1);
    ExtensionsSort(LSplitPt + 1, AStop);
  end;
end;

procedure TImageFormatManager.THandlerRegistry.ProcessExtensions;
begin
  if Length(Extensions) > 1 then
    ExtensionsSort(0, Length(Extensions) - 1);

  ExtensionsDirty := False;
end;

function TImageFormatManager.THandlerRegistry.IndexOfExtension(const AExtension: StdString): Integer;
var
  LLeft, LRight, LPivot, LRes: Integer;
begin
  if ExtensionsDirty then
    ProcessExtensions;

  LLeft := 0;
  LRight := Length(Extensions) - 1;

  while LLeft <= LRight do
  begin
    LPivot := (LLeft + LRight) div 2;
    LRes := CompareText(Extensions[LPivot].Extension, AExtension);

    if LRes = 0 then
      Exit(LPivot);

    if LRes > 0 then
      LRight := LPivot - 1
    else
      LLeft := LPivot + 1;
  end;

  Result := -1;
end;

function TImageFormatManager.THandlerRegistry.AddExtension(const AExtension: StdString;
  const AContext: Pointer): Integer;
begin
  Result := Length(Extensions);
  SetLength(Extensions, Result + 1);

  Extensions[Result].Extension := AExtension;
  Extensions[Result].Context := AContext;

  ExtensionsDirty := True;
end;

procedure TImageFormatManager.THandlerRegistry.RemoveExtension(const AExtesionIndex: Integer);
var
  I: Integer;
begin
  if (AExtesionIndex < 0) or (AExtesionIndex >= Length(Extensions)) then
    Exit;

  for I := AExtesionIndex to Length(Extensions) - 2 do
    Extensions[I] := Extensions[I + 1];

  SetLength(Extensions, Length(Extensions) - 1);
end;

{$ENDREGION}
{$REGION 'TImageFormatManager'}

function TImageFormatManager.IndexOfHandler(const AImageFormatHandler: TCustomImageFormatHandler): Integer;
var
  I: Integer;
begin
  for I := Length(FEntries) - 1 downto 0 do
    if FEntries[I].Handler = AImageFormatHandler then
      Exit(I);

  Result := -1;
end;

function TImageFormatManager.RegisterHandler(const AImageFormatHandler: TCustomImageFormatHandler): Integer;
begin
  Result := IndexOfHandler(AImageFormatHandler);
  if Result = -1 then
  begin
    Result := Length(FEntries);
    SetLength(FEntries, Result + 1);
  end;

  FEntries[Result].Handler := AImageFormatHandler;
end;

procedure TImageFormatManager.UnregisterHandlerIndex(const AHandlerIndex: Integer);
var
  I: Integer;
begin
  if (AHandlerIndex < 0) or (AHandlerIndex >= Length(FEntries)) then
    Exit;

  for I := AHandlerIndex to Length(FEntries) - 2 do
    FEntries[I] := FEntries[I + 1];

  SetLength(FEntries, Length(FEntries) - 1);
end;

procedure TImageFormatManager.UnregisterHandler(const AImageFormatHandler: TCustomImageFormatHandler);
begin
  UnregisterHandlerIndex(IndexOfHandler(AImageFormatHandler));
end;

procedure TImageFormatManager.Clear;
begin
  SetLength(FEntries, 0);
end;

function TImageFormatManager.RegisterExtension(const AExtension: StdString;
  const AHandler: TCustomImageFormatHandler; const AContext: Pointer): Boolean;
var
  LIndex: Integer;
begin
  if AHandler = nil then
    Exit(False);

  if AHandler.FHandlerIndexTemp <> -1 then
    LIndex := AHandler.FHandlerIndexTemp
  else
    LIndex := IndexOfHandler(AHandler);

  if LIndex = -1 then
    Exit(False);

  Result := FEntries[LIndex].AddExtension(AExtension, AContext) <> -1;
end;

procedure TImageFormatManager.FindExtension(const AExtension: StdString; out AHandlerIndex, AExtensionIndex: Integer);
var
  I: Integer;
begin
  for I := Length(FEntries) - 1 downto 0 do
  begin
    AExtensionIndex := FEntries[I].IndexOfExtension(AExtension);
    if AExtensionIndex <> -1 then
    begin
      AHandlerIndex := I;
      Exit;
    end;
  end;

  AHandlerIndex := -1;
  AExtensionIndex := -1;
end;

function TImageFormatManager.UnregisterExtension(const AExtension: StdString;
  const AHandler: TCustomImageFormatHandler): Boolean;
var
  LHandlerIndex, LExtensionIndex: Integer;
begin
  if AHandler <> nil then
  begin
    LHandlerIndex := IndexOfHandler(AHandler);
    if LHandlerIndex = -1 then
      Exit(False);

    LExtensionIndex := FEntries[LHandlerIndex].IndexOfExtension(AExtension);
  end
  else
    FindExtension(AExtension, LHandlerIndex, LExtensionIndex);

  if (LHandlerIndex = -1) or (LExtensionIndex = -1) then
    Exit(False);

  FEntries[LHandlerIndex].RemoveExtension(LExtensionIndex);
  Result := True;
end;

function TImageFormatManager.LoadFromStream(const AExtension: StdString; const AStream: TStream;
  const ADestSurface: TPixelSurface): Boolean;
var
  LHandlerIndex, LExtensionIndex: Integer;
begin
  if (AStream = nil) or (ADestSurface = nil) then
    Exit(False);

  FindExtension(AExtension, LHandlerIndex, LExtensionIndex);
  if (LHandlerIndex = -1) or (LExtensionIndex = -1) then
    Exit(False);

  Result := FEntries[LHandlerIndex].Handler.LoadFromStream(
    FEntries[LHandlerIndex].Extensions[LExtensionIndex].Context, AExtension, AStream, ADestSurface);
end;

function TImageFormatManager.SaveToStream(const AExtension: StdString; const AStream: TStream;
  const ASourceSurface: TPixelSurface; const AQuality: Pointer): Boolean;
var
  LHandlerIndex, LExtensionIndex: Integer;
begin
  if (AStream = nil) or (ASourceSurface = nil) then
    Exit(False);

  FindExtension(AExtension, LHandlerIndex, LExtensionIndex);
  if (LHandlerIndex = -1) or (LExtensionIndex = -1) then
    Exit(False);

  Result := FEntries[LHandlerIndex].Handler.SaveToStream(FEntries[LHandlerIndex].Extensions[LExtensionIndex].Context,
    AExtension, AStream, ASourceSurface, AQuality);
end;

function TImageFormatManager.LoadFromFile(const AFileName: StdString;
  const ADestSurface: TPixelSurface): Boolean;
var
  LStream: TFileStream;
begin
  try
    LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      Result := LoadFromStream(ExtractFileExt(AFileName), LStream, ADestSurface);
    finally
      LStream.Free;
    end;
  except
    Exit(False);
  end;
end;

function TImageFormatManager.SaveToFile(const AFileName: StdString; const ASourceSurface: TPixelSurface;
  const AQuality: Pointer): Boolean;
var
  LStream: TFileStream;
begin
  try
    LStream := TFileStream.Create(AFileName, fmCreate or fmShareExclusive);
    try
      Result := SaveToStream(ExtractFileExt(AFileName), LStream, ASourceSurface, AQuality);
    finally
      LStream.Free;
    end;
  except
    Exit(False);
  end;
end;

{$ENDREGION}

end.

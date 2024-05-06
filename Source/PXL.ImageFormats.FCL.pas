unit PXL.ImageFormats.FCL;
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
  Classes, PXL.TypeDef, PXL.Types, PXL.Surfaces, PXL.ImageFormats;

type
  TFCLImageFormatHandler = class(TCustomImageFormatHandler)
  protected
    procedure RegisterExtensions; override;
  public
    function LoadFromStream(const AContext: Pointer; const AExtension: StdString; const AStream: TStream;
      const ADestSurface: TPixelSurface): Boolean; override;
    function SaveToStream(const AContext: Pointer; const AExtension: StdString; const AStream: TStream;
      const ASourceSurface: TPixelSurface; const AQuality: Pointer): Boolean; override;
  end;

implementation

uses
  zstream, fpreadpng, fpreadbmp, fpreadjpeg, fpreadtiff, fpwritepng, fpwritebmp, fpwritejpeg, fpwritetiff,
  fpimage, SysUtils;

{$REGION 'Global Types and Constants'}

const
  MaxContextIndex = 4;

  InitialMemoryImageSize: TPoint = (X: 4; Y: 4);

  ContextImageReaders: array[0..MaxContextIndex - 1] of TFPCustomImageReaderClass = (
    TFPReaderBMP,
    TFPReaderPNG,
    TFPReaderJPEG,
    TFPReaderTIFF);

  ContextImageWriters: array[0..MaxContextIndex - 1] of TFPCustomImageWriterClass = (
    TFPWriterBMP,
    TFPWriterPNG,
    TFPWriterJPEG,
    TFPWriterTIFF);

{$ENDREGION}
{$REGION 'TFCLImageFormatHandler'}

procedure TFCLImageFormatHandler.RegisterExtensions;
begin
  RegisterExtension('.bmp', Pointer(PtrInt(0)));
  RegisterExtension('.png', Pointer(PtrInt(1)));
  RegisterExtension('.jpg', Pointer(PtrInt(2)));
  RegisterExtension('.jpeg', Pointer(PtrInt(2)));
  RegisterExtension('.tif', Pointer(PtrInt(3)));
  RegisterExtension('.tiff', Pointer(PtrInt(3)));
end;

function TFCLImageFormatHandler.LoadFromStream(const AContext: Pointer; const AExtension: StdString;
  const AStream: TStream; const ADestSurface: TPixelSurface): Boolean;
var
  LImage: TFPCustomImage;
  LReader: TFPCustomImageReader;
  LSrcColor: TFPColor;
  LDestPixel: PIntColor;
  I, J: Integer;
begin
  LImage := TFPMemoryImage.Create(InitialMemoryImageSize.X, InitialMemoryImageSize.Y);
  try
    LReader := ContextImageReaders[PtrInt(AContext)].Create;
    if LReader = nil then
      Exit(False);
    try
      try
        LImage.LoadFromStream(AStream, LReader);
      except
        Exit(False);
      end;

      ADestSurface.SetSize(LImage.Width, LImage.Height);

      for J := 0 to ADestSurface.Height - 1 do
      begin
        LDestPixel := ADestSurface.Scanline[J];

        for I := 0 to ADestSurface.Width - 1 do
        begin
          LSrcColor := LImage.Colors[I, J];
          LDestPixel^ := TIntColor(LSrcColor.red shr 8) or (TIntColor(LSrcColor.green shr 8) shl 8) or
            (TIntColor(LSrcColor.blue shr 8) shl 16) or (TIntColor(LSrcColor.alpha shr 8) shl 24);

          Inc(LDestPixel);
        end;
      end;
    finally
      LReader.Free;
    end;
  finally
    LImage.Free;
  end;
  Result := True;
end;

function TFCLImageFormatHandler.SaveToStream(const AContext: Pointer; const AExtension: StdString;
  const AStream: TStream; const ASourceSurface: TPixelSurface; const AQuality: Pointer): Boolean;
var
  LImage: TFPCustomImage;
  LWriter: TFPCustomImageWriter;
  LSrcPixel: PIntColor;
  LDestColor: TFPColor;
  I, J: Integer;
begin
  LWriter := ContextImageWriters[PtrInt(AContext)].Create;
  if LWriter = nil then
    Exit(False);
  try
    if LWriter is TFPWriterPNG then
    begin
      TFPWriterPNG(LWriter).WordSized := False;
      TFPWriterPNG(LWriter).UseAlpha := ASourceSurface.HasAlphaChannel;
      TFPWriterPNG(LWriter).CompressionLevel := clmax;
    end
    else if LWriter is TFPWriterJPEG then
      TFPWriterJPEG(LWriter).CompressionQuality := SizeInt(AQuality);

    LImage := TFPMemoryImage.Create(ASourceSurface.Width, ASourceSurface.Height);
    try
      for J := 0 to ASourceSurface.Height - 1 do
      begin
        LSrcPixel := ASourceSurface.Scanline[J];

        for I := 0 to ASourceSurface.Width - 1 do
        begin
          LDestColor.red := (Integer(LSrcPixel^ and $FF) * $FFFF) div 255;
          LDestColor.green := (Integer((LSrcPixel^ shr 8) and $FF) * $FFFF) div 255;
          LDestColor.blue := (Integer((LSrcPixel^ shr 16) and $FF) * $FFFF) div 255;
          LDestColor.alpha := (Integer((LSrcPixel^ shr 24) and $FF) * $FFFF) div 255;

          LImage.Colors[I, J] := LDestColor;
          Inc(LSrcPixel);
        end;
      end;

      try
        LImage.SaveToStream(AStream, LWriter);
      except
        Exit(False);
      end;
    finally
      LImage.Free;
    end;
  finally
    LWriter.Free;
  end;

  Result := True;
end;

{$ENDREGION}

end.

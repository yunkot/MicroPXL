unit PXL.ImageFormats.WIC;
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
{$IFDEF FPC}
  PXL.Windows.Wincodec,
{$ELSE}
  Winapi.Wincodec,
{$ENDIF}

  Classes, PXL.TypeDef, PXL.Types, PXL.Surfaces, PXL.ImageFormats;

type
  TWICImageFormatHandler = class(TCustomImageFormatHandler)
  private
    FImagingFactory: IWICImagingFactory;
  protected
    procedure RegisterExtensions; override;
  public
    constructor Create(const AManager: TImageFormatManager);

    function LoadFromStream(const AContext: Pointer; const AExtension: StdString; const AStream: TStream;
      const ADestSurface: TPixelSurface): Boolean; override;
    function SaveToStream(const AContext: Pointer; const AExtension: StdString; const AStream: TStream;
      const ASourceSurface: TPixelSurface; const AQuality: Pointer): Boolean; override;

    property ImagingFactory: IWICImagingFactory read FImagingFactory;
  end;

implementation

uses
  Windows, ActiveX, SysUtils;

const
  IID_EMPTY: TGuid = '{00000000-0000-0000-0000-000000000000}';

{$REGION 'TWICImageFormatHandler'}

constructor TWICImageFormatHandler.Create(const AManager: TImageFormatManager);
begin
  inherited;

  if Failed(CoCreateInstance(CLSID_WICImagingFactory, nil, CLSCTX_INPROC_SERVER or CLSCTX_LOCAL_SERVER,
    IUnknown, FImagingFactory)) then
    FImagingFactory := nil;
end;

procedure TWICImageFormatHandler.RegisterExtensions;
begin
  RegisterExtension('.bmp', @GUID_ContainerFormatBmp);
  RegisterExtension('.png', @GUID_ContainerFormatPng);
  RegisterExtension('.jpg', @GUID_ContainerFormatJpeg);
  RegisterExtension('.jpeg', @GUID_ContainerFormatJpeg);
  RegisterExtension('.tiff', @GUID_ContainerFormatTiff);
  RegisterExtension('.tif', @GUID_ContainerFormatTiff);
  RegisterExtension('.gif', @GUID_ContainerFormatGif);
  RegisterExtension('.ico', @GUID_ContainerFormatIco);
  RegisterExtension('.hdp', @GUID_ContainerFormatWmp);
end;

function TWICImageFormatHandler.LoadFromStream(const AContext: Pointer; const AExtension: StdString;
  const AStream: TStream; const ADestSurface: TPixelSurface): Boolean;
var
  LDecoder: IWICBitmapDecoder;
  LFrame: IWICBitmapFrameDecode;
  LConverter: IWICFormatConverter;
  LWidth, LHeight: UINT;
begin
  if FImagingFactory = nil then
    Exit(False);

  try
    if Failed(FImagingFactory.CreateDecoderFromStream(TStreamAdapter.Create(AStream) as IStream, IID_EMPTY,
      WICDecodeMetadataCacheOnDemand, LDecoder)) or (LDecoder = nil) then
      Exit(False);

    if Failed(LDecoder.GetFrame(0, LFrame)) or (LFrame = nil) then
      Exit(False);

    if Failed(FImagingFactory.CreateFormatConverter(LConverter)) or (LConverter = nil) then
      Exit(False);

    if Failed(LConverter.Initialize(LFrame, GUID_WICPixelFormat32bppRGBA, WICBitmapDitherTypeNone, nil,
      0, 0)) then
      Exit(False);

    if Failed(LConverter.GetSize(LWidth, LHeight)) then
      Exit(False);

    ADestSurface.SetSize(LWidth, LHeight);

    Result := Succeeded(LConverter.CopyPixels(nil, ADestSurface.Pitch, ADestSurface.Pitch *
      ADestSurface.Height, ADestSurface.Bits));
  except
    Exit(False);
  end;
end;

function TWICImageFormatHandler.SaveToStream(const AContext: Pointer; const AExtension: StdString;
  const AStream: TStream; const ASourceSurface: TPixelSurface; const AQuality: Pointer): Boolean;
var
  LEncoderType: TGuid;
  LEncoder: IWICBitmapEncoder;
  LWStream: IWICStream;
  LFrame: IWICBitmapFrameEncode;
  LPropertyBag: IPropertyBag2;
  LPropertyName: TPropBag2;
  LPropertyValue: TPropVariant;
  LNativeFormat: WICPixelFormatGUID;
  LBitmap: IWICBitmap;
  LConverter: IWICFormatConverter;
begin
  if FImagingFactory = nil then
    Exit(False);

  LEncoderType := PGuid(AContext)^;

  if CompareMem(@LEncoderType, @IID_EMPTY, SizeOf(TGuid)) then
    Exit(False);

  try
    if Failed(FImagingFactory.CreateEncoder(LEncoderType, IID_EMPTY, LEncoder)) or (LEncoder = nil) then
      Exit(False);

    if Failed(FImagingFactory.CreateStream(LWStream)) or (LWStream = nil) then
      Exit(False);

    if Failed(LWStream.InitializeFromIStream(TStreamAdapter.Create(AStream) as IStream)) then
      Exit(False);

    if Failed(LEncoder.Initialize(LWStream, WICBitmapEncoderNoCache)) then
      Exit(False);

    LPropertyBag := nil;

    if Failed(LEncoder.CreateNewFrame(LFrame, LPropertyBag)) or (LFrame = nil) then
      Exit(False);

    if CompareMem(@LEncoderType, @GUID_ContainerFormatJpeg, SizeOf(TGuid)) then
    begin
      FillChar(LPropertyName, SizeOf(TPropBag2), 0);
      FillChar(LPropertyValue, SizeOf(TPropVariant), 0);

      LPropertyName.dwType := 1;
      LPropertyName.vt := VT_R4;
      LPropertyName.pstrName := POleStr(UniString('ImageQuality'#0));
      LPropertyValue.vt := VT_R4;
      LPropertyValue.fltVal := SizeInt(AQuality) / 100.0;

      if Failed(LPropertyBag.Write(1, @LPropertyName, @LPropertyValue)) then
        Exit(False);
    end;

    if Failed(LFrame.Initialize(LPropertyBag)) then
      Exit(False);

    if Failed(LFrame.SetSize(ASourceSurface.Width, ASourceSurface.Height)) then
      Exit(False);

    LNativeFormat := GUID_WICPixelFormat32bppRGBA;

    if Failed(LFrame.SetPixelFormat(LNativeFormat)) then
      Exit(False);

    if CompareMem(@LNativeFormat, @GUID_WICPixelFormat32bppRGBA, SizeOf(TGuid)) then
    begin // Native Pixel Format
      if Failed(LFrame.WritePixels(ASourceSurface.Height, ASourceSurface.Pitch, ASourceSurface.Pitch *
        ASourceSurface.Height, ASourceSurface.Bits)) then
        Exit(False);

      if Failed(LFrame.Commit) then
        Exit(False);

      Result := Succeeded(LEncoder.Commit);
    end
    else
    begin // Pixel Format Conversion
      if Failed(FImagingFactory.CreateBitmapFromMemory(ASourceSurface.Width, ASourceSurface.Height,
        LNativeFormat, ASourceSurface.Pitch, ASourceSurface.Pitch * ASourceSurface.Height,
        ASourceSurface.Bits, LBitmap)) or (LBitmap = nil) then
        Exit(False);

      if Failed(FImagingFactory.CreateFormatConverter(LConverter)) or (LConverter = nil) then
        Exit(False);

      if Failed(LConverter.Initialize(LBitmap, GUID_WICPixelFormat32bppRGBA, WICBitmapDitherTypeNone,
        nil, 0, 0)) then
        Exit(False);

      if Failed(LFrame.WriteSource(LBitmap, nil)) then
        Exit(False);

      if Failed(LFrame.Commit) then
        Exit(False);

      Result := Succeeded(LEncoder.Commit);
    end;
  except
    Exit(False);
  end;
end;

{$ENDREGION}

end.

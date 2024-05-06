unit PXL.Cameras.V4L2;
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

// V4L2 video capture can be quite troublesome depending on drivers and hardware, especially when using big
// video size on devices such as Raspberry PI. The following option enables debug text logging to standard
// output, which could help figuring out what is going wrong.
{.$DEFINE V4L2_CAMERA_DEBUG}

uses
  SysUtils, Classes, SyncObjs, PXL.Linux.videodev2, PXL.TypeDef, PXL.Types, PXL.Surfaces;

type
  TV4L2Camera = class
  private type
    TCaptureThread = class(TThread)
    private type
      TBufferType = record
        Memory: Pointer;
        Size: Cardinal;
      end;
    private
      FCamera: TV4L2Camera;
      FHandle: TUntypedHandle;
      FBufferCount: Integer;
      FBuffers: array of TBufferType;

      FImageBufferSection: TCriticalSection;
      FImageBuffer: Pointer;
      FImageBufferSize: Cardinal;

      procedure CreateBuffers;
      procedure ReleaseBuffers;
    protected
      procedure Execute; override;
    public
      constructor Create(const ACamera: TV4L2Camera; const AHandle: TUntypedHandle;
        const ABufferCount: Integer);
      destructor Destroy; override;

      property Camera: TV4L2Camera read FCamera;

      property BufferCount: Integer read FBufferCount;

      property ImageBufferSection: TCriticalSection read FImageBufferSection;

      property ImageBuffer: Pointer read FImageBuffer;
      property ImageBufferSize: Cardinal read FImageBufferSize;
    end;
  public type
    TCaptureNotifyEvent = procedure(const Sender: TObject; const Buffer: Pointer;
      const BufferSize: Cardinal) of object;
  public const
    DefaultSystemPath = '/dev/video0';
    DefaultBufferCount = 2;
    DefaultVideoSize: TPoint = (X: 640; Y: 480);
  private
    FSystemPath: StdString;
    FHandle: TUntypedHandle;
    FSize: TPoint;
    FPixelFormat: Cardinal;
    FCaptureStream: TCaptureThread;
    FOnCapture: TCaptureNotifyEvent;
    FFramesCaptured: Integer;

    function FormatToString(const AVideoFormat: Cardinal): StdString;
    function GetCapturing: Boolean;
    function TryVideoFormat(const AVideoFormat: Cardinal): Boolean;

    procedure SetSize(const ASize: TPoint);
    procedure ConvertImageYUYV(const ASource: Pointer; const ASurface: TPixelSurface);
    procedure ConvertImageYU12(const ASource: Pointer; const ASurface: TPixelSurface);
  public
    constructor Create(const ASystemPath: StdString = DefaultSystemPath);
    destructor Destroy; override;

    // Create a new video capturing thread with the specified number of buffers to start recording.
    // The number of buffers should be at least 2. Higher number of buffers could reduce issues and/or
    // prevent camera stalling, at the expense of higher memory footprint.
    procedure StartCapture(const ABufferCount: Integer = DefaultBufferCount);

    // Tries to stop camera capture and release the working thread.
    procedure StopCapture;

    // Takes a single image snapshot from the camera.
    procedure TakeSnapshot(const ADestSurface: TPixelSurface);

    // Currently used path to V4L2 video device.
    property SystemPath: StdString read FSystemPath;

    // The size of video image captured from camera.
    property Size: TPoint read FSize write SetSize;

    // Pixel format of video image captured from camera according to V4L2 "FOURCC" codes.
    property PixelFormat: Cardinal read FPixelFormat;

    // Indicates whether the camera is currently capturing.
    property Capturing: Boolean read GetCapturing;

    // Indicates how many frames were captured so far.
    property FramesCaptured: Integer read FFramesCaptured;

    // This event is called from a different thread whenever a buffer has been captured. The pointer to that
    // buffer and its size are returned. The actual video feed will have size and format according to "Size"
    // and "PixelFormat". The direct access to video buffers is provided and the code inside this event
    // should execute as fast as possible to prevent camera from stalling, which depending on drivers could
    // be unrecoverable. If this event is assigned, the recording thread won't copy its buffers to
    // a secondary location and "TakeSnapshot" won't work.
    property OnCapture: TCaptureNotifyEvent read FOnCapture write FOnCapture;
  end;

  EV4L2Generic = class(Exception);
  EV4L2FileOpen = class(EV4L2Generic);

  EV4L2Format = class(EV4L2Generic);
  EV4L2GetFormat = class(EV4L2Format);
  EV4L2SetFormat = class(EV4L2Format);
  EV4L2SetVideoSize = class(EV4L2SetFormat);
  EV4L2UnsupportedFormat = class(EV4L2Format);

  EV4L2Buffers = class(EV4L2Generic);
  EV4L2RequestBuffers = class(EV4L2Buffers);
  EV4L2AssociateBuffer = class(EV4L2Buffers);
  EV4L2MemoryMapBuffer = class(EV4L2Buffers);
  EV4L2QueueBuffer = class(EV4L2Buffers);
  EV4L2ReceiveBuffers = class(EV4L2Buffers);

  EV4L2Stream = class(EV4L2Generic);
  EV4L2StreamStart = class(EV4L2Stream);
  EV4L2StreamWait = class(EV4L2Stream);
  EV4L2NotStreaming = class(EV4L2Stream);
  EV4L2AlreadyStreaming = class(EV4L2Stream);

resourcestring
  SCannotOpenCameraDeviceFile = 'Cannot open camera device file <%s> for reading and writing.';
  SCannotObtainCameraFormat = 'Cannot obtain camera device format.';
  SUnsupportedCameraFormat = 'Unsupported camera device format (%s).';
  SCannotSetCameraVideoSize = 'Cannot set new video size (%d by %d).';
  SCannotObtainCameraBuffers = 'Cannot obtaim %d camera device buffers.';
  SCannotAssociateCameraBuffer = 'Cannot associate buffer %d with camera device.';
  SCannotMemoryMapCameraBuffer = 'Cannot map camera device buffer %d to memory.';
  SCannotQueueCameraBuffer = 'Cannot queue camera device buffer %d.';
  SCannotReceiveCameraBuffers = 'Cannot receive camera device buffers.';
  SCannotStartCameraStreaming = 'Cannot start camera device streaming.';
  SFailedWaitingForCameraStream = 'Failed waiting for camera device stream.';
  SCameraIsCurrentlyNotStreaming = 'Camera is currently not capturing.';
  SCameraIsAlreadyStreaming = 'Camera is already capturing.';

implementation

uses
  BaseUnix, PXL.Formats;

{$REGION 'TV4L2Camera.TCaptureThread'}

constructor TV4L2Camera.TCaptureThread.Create(const ACamera: TV4L2Camera; const AHandle: TUntypedHandle;
  const ABufferCount: Integer);
begin
{$IFDEF V4L2_CAMERA_DEBUG}
  WriteLn('[CT] Created.');
{$ENDIF}

  FCamera := ACamera;
  FHandle := AHandle;

  FBufferCount := ABufferCount;
  if FBufferCount < 2 then
    FBufferCount := 2;

  FImageBufferSection := TCriticalSection.Create;
  CreateBuffers;

  inherited Create(False);
end;

destructor TV4L2Camera.TCaptureThread.Destroy;
begin
  inherited;

  ReleaseBuffers;
  FreeAndNil(FImageBufferSection);

{$IFDEF V4L2_CAMERA_DEBUG}
  WriteLn('[CT] Destroyed.');
{$ENDIF}
end;

procedure TV4L2Camera.TCaptureThread.CreateBuffers;
const
  PageSize = {$IFDEF FPC_MMAP2}4096{$ELSE}1{$ENDIF};
var
  LBufferRequest: v4l2_requestbuffers;
  LBufferDecl: v4l2_buffer;
  I: Integer;
begin
{$IFDEF V4L2_CAMERA_DEBUG}
  Write('[CT] Requesting buffers...');
{$ENDIF}

  FillChar(LBufferRequest, SizeOf(v4l2_requestbuffers), 0);

  LBufferRequest.count := FBufferCount;
  LBufferRequest.&type := V4L2_BUF_TYPE_VIDEO_CAPTURE;
  LBufferRequest.memory := V4L2_MEMORY_MMAP;

  if FpIOCtl(FHandle, VIDIOC_REQBUFS, @LBufferRequest) < 0 then
    raise EV4L2RequestBuffers.Create(Format(SCannotObtainCameraBuffers, [FBufferCount]));

{$IFDEF V4L2_CAMERA_DEBUG}
  WriteLn('OK.');
{$ENDIF}

  SetLength(FBuffers, FBufferCount);

  for I := 0 to Length(FBuffers) - 1 do
  begin
    FBuffers[I].Memory := nil;
    FBuffers[I].Size := 0;
  end;

  FImageBufferSize := 0;

  for I := 0 to Length(FBuffers) - 1 do
  begin
  {$IFDEF V4L2_CAMERA_DEBUG}
    Write('[CT] Querying buffer #', I, '...');
  {$ENDIF}

    FillChar(LBufferDecl, SizeOf(v4l2_buffer), 0);

    LBufferDecl.index := I;
    LBufferDecl.&type := V4L2_BUF_TYPE_VIDEO_CAPTURE;
    LBufferDecl.memory := V4L2_MEMORY_MMAP;

    if FpIOCtl(FHandle, VIDIOC_QUERYBUF, @LBufferDecl) < 0 then
      raise EV4L2AssociateBuffer.Create(Format(SCannotAssociateCameraBuffer, [I]));

  {$IFDEF V4L2_CAMERA_DEBUG}
    WriteLn('OK.');
    Write('[CT] Mapping buffer #', I, '...');
  {$ENDIF}

    FBuffers[I].Size := LBufferDecl.length;
    FBuffers[I].Memory := Fpmmap(nil, FBuffers[I].Size, PROT_READ, MAP_SHARED, FHandle, LBufferDecl.offset div PageSize);

    if (FBuffers[I].Memory = nil) or (FBuffers[I].Memory = MAP_FAILED) then
    begin
      FBuffers[I].Memory := nil;
      FBuffers[I].Size := 0;

      raise EV4L2MemoryMapBuffer.Create(Format(SCannotMemoryMapCameraBuffer, [I]));
    end;

  {$IFDEF V4L2_CAMERA_DEBUG}
    WriteLn('OK.');
  {$ENDIF}

    if FImageBufferSize < LBufferDecl.length then
      FImageBufferSize := LBufferDecl.length;
  end;

  if (FCamera = nil) or (not Assigned(FCamera.FOnCapture)) then
    FImageBuffer := AllocMem(FImageBufferSize);
end;

procedure TV4L2Camera.TCaptureThread.ReleaseBuffers;
var
  I: Integer;
begin
  FreeMemAndNil(FImageBuffer);
  FImageBufferSize := 0;

{$IFDEF V4L2_CAMERA_DEBUG}
  Write('[CS] Releasing buffers...');
{$ENDIF}

  for I := Length(FBuffers) - 1 downto 0 do
    if FBuffers[I].Memory <> nil then
    begin
      Fpmunmap(FBuffers[I].Memory, FBuffers[I].Size);

      FBuffers[I].Memory := nil;
      FBuffers[I].Size := 0;
    end;

  SetLength(FBuffers, 0);

{$IFDEF V4L2_CAMERA_DEBUG}
  WriteLn('OK.');
{$ENDIF}
end;

procedure TV4L2Camera.TCaptureThread.Execute;
var
  I, LStatus, LRes: Integer;
  LFDStatus: TFDSet;
  LTime: timeval;
  LBuffer: v4l2_buffer;
begin
  for I := 0 to FBufferCount - 1 do
  begin
  {$IFDEF V4L2_CAMERA_DEBUG}
    Write('[CT] Queing Lbuffer ', I, '...');
  {$ENDIF}

    FillChar(LBuffer, SizeOf(v4l2_buffer), 0);

    LBuffer.index := I;
    LBuffer.&type := V4L2_BUF_TYPE_VIDEO_CAPTURE;
    LBuffer.memory := V4L2_MEMORY_MMAP;
    if FpIOCtl(FHandle, VIDIOC_QBUF, @LBuffer) < 0 then
      raise EV4L2QueueBuffer.Create(Format(SCannotQueueCameraBuffer, [I]));

  {$IFDEF V4L2_CAMERA_DEBUG}
    WriteLn('OK.');
  {$ENDIF}
  end;

{$IFDEF V4L2_CAMERA_DEBUG}
  Write('[CS] Starting streaming...');
{$ENDIF}

  LStatus := V4L2_BUF_TYPE_VIDEO_CAPTURE;
  if FpIOCtl(FHandle, VIDIOC_STREAMON, @LStatus) < 0 then
    raise EV4L2StreamStart.Create(SCannotStartCameraStreaming);
  try
  {$IFDEF V4L2_CAMERA_DEBUG}
    WriteLn('OK.');
  {$ENDIF}

    while not Terminated do
    begin
    {$IFDEF V4L2_CAMERA_DEBUG}
      Write('[CS] Waiting...');
    {$ENDIF}

      repeat
        fpFD_ZERO(LFDStatus);
        fpFD_SET(FHandle, LFDStatus);

        LTime.tv_sec := 10;
        LTime.tv_usec := 0;

        LRes := fpSelect(FHandle + 1, @LFDStatus, nil, nil, @LTime);
      until (LRes <> -1) or (errno <> ESysEINTR);

      if LRes = -1 then
        raise EV4L2StreamWait.Create(SFailedWaitingForCameraStream);

    {$IFDEF V4L2_CAMERA_DEBUG}
      WriteLn('DONE.');
      Write('[CS] Dequeuing Lbuffer...');
    {$ENDIF}

      FillChar(LBuffer, SizeOf(v4l2_buffer), 0);
      LBuffer.&type := V4L2_BUF_TYPE_VIDEO_CAPTURE;
      LBuffer.memory := V4L2_MEMORY_MMAP;
      if FpIOCtl(FHandle, VIDIOC_DQBUF, @LBuffer) < 0 then
        raise EV4L2ReceiveBuffers.Create(SCannotReceiveCameraBuffers);

    {$IFDEF V4L2_CAMERA_DEBUG}
      WriteLn('got #', LBuffer.index, '.');
    {$ENDIF}

      if (FCamera <> nil) and Assigned(FCamera.FOnCapture) then
      begin
        FCamera.FOnCapture(FCamera, FBuffers[LBuffer.index].Memory, LBuffer.length);

      {$IFDEF V4L2_CAMERA_DEBUG}
        WriteLn('[CS] Notified OnCapture event about ', LBuffer.length, ' bytes.');
      {$ENDIF}
      end
      else if (FImageBuffer <> nil) and (FImageBufferSize >= LBuffer.length) then
      begin
        FImageBufferSection.Enter;
        try
          Move(FBuffers[LBuffer.index].Memory^, FImageBuffer^, LBuffer.length);
        finally
          FImageBufferSection.Leave;
        end;

      {$IFDEF V4L2_CAMERA_DEBUG}
        WriteLn('[CS] Copied ', LBuffer.length, ' bytes to front Lbuffer.');
      {$ENDIF}
      end;

      if FCamera <> nil then
        InterLockedIncrement(FCamera.FFramesCaptured);

    {$IFDEF V4L2_CAMERA_DEBUG}
      Write('[CS] Queuing Lbuffer #', LBuffer.index, '...');
    {$ENDIF}

      if FpIOCtl(FHandle, VIDIOC_QBUF, @LBuffer) < 0 then
        raise EV4L2QueueBuffer.Create(Format(SCannotQueueCameraBuffer, [I]));

    {$IFDEF V4L2_CAMERA_DEBUG}
      WriteLn('OK.');
    {$ENDIF}
    end;
  finally
    LStatus := V4L2_BUF_TYPE_VIDEO_CAPTURE;
    FpIOCtl(FHandle, VIDIOC_STREAMOFF, @LStatus);
  end;

{$IFDEF V4L2_CAMERA_DEBUG}
  WriteLn('[CS] Streaming Stopped.');
{$ENDIF}
end;

{$ENDREGION}
{$REGION 'TV4L2Camera'}

constructor TV4L2Camera.Create(const ASystemPath: StdString);
begin
  inherited Create;

  FSystemPath := ASystemPath;

  FHandle := FpOpen(FSystemPath, O_RDWR or O_NONBLOCK);
  if FHandle < 0 then
  begin
    FHandle := 0;
    raise EV4L2FileOpen.Create(Format(SCannotOpenCameraDeviceFile, [FSystemPath]));
  end;

{$IFDEF V4L2_CAMERA_DEBUG}
  Write('[V4L2] Setting video format...');
{$ENDIF}

  if (not TryVideoFormat(V4L2_PIX_FMT_BGR32)) and (not TryVideoFormat(V4L2_PIX_FMT_YUYV)) and
    (not TryVideoFormat(V4L2_PIX_FMT_YUV420)) then
    raise EV4L2UnsupportedFormat.Create(Format(SUnsupportedCameraFormat, [FormatToString(FPixelFormat)]));

{$IFDEF V4L2_CAMERA_DEBUG}
  WriteLn('OK.');
  Write('Setting video size...');
{$ENDIF}

  SetSize(DefaultVideoSize);

{$IFDEF V4L2_CAMERA_DEBUG}
  WriteLn('OK.');
{$ENDIF}
end;

destructor TV4L2Camera.Destroy;
begin
  if FCaptureStream <> nil then
    StopCapture;

  if FHandle <> 0 then
  begin
    FpClose(FHandle);
    FHandle := 0;
  end;

  inherited;
end;

function TV4L2Camera.FormatToString(const AVideoFormat: Cardinal): StdString;
var
  Chars: array[0..3] of AnsiChar absolute AVideoFormat;
begin
  Result := Chars[0] + Chars[1] + Chars[2] + Chars[3];
end;

function TV4L2Camera.TryVideoFormat(const AVideoFormat: Cardinal): Boolean;
var
  LFormat: v4l2_format;
begin
  FillChar(LFormat, SizeOf(v4l2_format), 0);
  LFormat.&type := V4L2_BUF_TYPE_VIDEO_CAPTURE;

  if FpIOCtl(FHandle, VIDIOC_G_FMT, @LFormat) < 0 then
    raise EV4L2GetFormat.Create(SCannotObtainCameraFormat);

//  Format.pix.field := V4L2_FIELD_INTERLACED;  // - this is not necessary
  LFormat.pix.pixelformat := AVideoFormat;

  if FpIOCtl(FHandle, VIDIOC_S_FMT, @LFormat) < 0 then
    Exit(False);

// Uncomment to show some interesting information about current camera format.
{ WriteLn('Width: ', LFormat.pix.width);
  WriteLn('Height: ', LFormat.pix.height);
  WriteLn('Bytes per Line: ', LFormat.pix.bytesperline);
  WriteLn('Size Image: ', LFormat.pix.sizeimage);
  WriteLn('Pixel Format: ', FormatToString(LFormat.pix.pixelformat)); }

  FPixelFormat := LFormat.pix.pixelformat;
  Result := LFormat.pix.pixelformat = AVideoFormat;
end;

procedure TV4L2Camera.SetSize(const ASize: TPoint);
var
  LWasCapturing: Boolean;
  LFormat: v4l2_format;
begin
  if FSize <> ASize then
  begin
    LWasCapturing := GetCapturing;
    if LWasCapturing then
      StopCapture;

    FSize := ASize;

    FillChar(LFormat, SizeOf(v4l2_format), 0);
    LFormat.&type := V4L2_BUF_TYPE_VIDEO_CAPTURE;

    if FpIOCtl(FHandle, VIDIOC_G_FMT, @LFormat) < 0 then
      raise EV4L2GetFormat.Create(SCannotObtainCameraFormat);

    LFormat.pix.width := FSize.X;
    LFormat.pix.height := FSize.Y;

    if FpIOCtl(FHandle, VIDIOC_S_FMT, @LFormat) < 0 then
      raise EV4L2SetVideoSize.Create(Format(SCannotSetCameraVideoSize, [FSize.X, FSize.Y]));

    FSize.X := LFormat.pix.width;
    FSize.Y := LFormat.pix.height;

    if LWasCapturing then
      StartCapture;
  end;
end;

function TV4L2Camera.GetCapturing: Boolean;
begin
  Result := FCaptureStream <> nil;
end;

procedure TV4L2Camera.StartCapture(const ABufferCount: Integer);
begin
  if FCaptureStream <> nil then
    raise EV4L2AlreadyStreaming.Create(SCameraIsAlreadyStreaming);

  FFramesCaptured := 0;
  FCaptureStream := TCaptureThread.Create(Self, FHandle, ABufferCount);
end;

procedure TV4L2Camera.StopCapture;
begin
  if FCaptureStream = nil then
    raise EV4L2NotStreaming.Create(SCameraIsCurrentlyNotStreaming);

  FCaptureStream.Terminate;
  FCaptureStream.WaitFor;

  FreeAndNil(FCaptureStream);
end;

procedure TV4L2Camera.ConvertImageYUYV(const ASource: Pointer; const ASurface: TPixelSurface);
type
  PPixelYUYV = ^TPixelYUYV;
  TPixelYUYV = record
    Y1, U, Y2, V: Byte;
  end;

  function PixelYUVToRGB(const AY, AU, AV: Integer): TIntColor; inline;
  var
    LTempY: Integer;
  begin
    LTempY := (AY - 16) * 298;

    TIntColorRec(Result).Red := Saturate((LTempY + 409 * (AV - 128) + 128) div 256, 0, 255);
    TIntColorRec(Result).Green := Saturate((LTempY - 100 * (AU - 128) - 208 * (AV - 128) + 128) div 256,
      0, 255);
    TIntColorRec(Result).Blue := Saturate((LTempY + 516 * (AU - 128) + 128) div 256, 0, 255);
    TIntColorRec(Result).Alpha := 255;
  end;

  procedure PixelToColors(LSrcPixel: PPixelYUYV; var DestPixels: PIntColor); inline;
  begin
    DestPixels^ := PixelYUVToRGB(LSrcPixel.Y1, LSrcPixel.U, LSrcPixel.V);
    Inc(DestPixels);

    DestPixels^ := PixelYUVToRGB(LSrcPixel.Y2, LSrcPixel.U, LSrcPixel.V);
    Inc(DestPixels);
  end;

var
  I, J: Integer;
  LSrcPixel: PPixelYUYV;
  LDestPixel: PIntColor;
begin
  LSrcPixel := ASource;

  for J := 0 to ASurface.Height - 1 do
  begin
    LDestPixel := ASurface.Scanline[J];

    for I := 0 to (ASurface.Width div 2) - 1 do
    begin
      PixelToColors(LSrcPixel, LDestPixel);
      Inc(LSrcPixel);
    end;
  end;
end;

procedure TV4L2Camera.ConvertImageYU12(const ASource: Pointer; const ASurface: TPixelSurface);

  function PixelYUVToRGB(const AY, AU, AV: Integer): TIntColor; inline;
  begin
    TIntColorRec(Result).Red := Saturate(AY + (351 * (AV - 128)) div 256, 0, 255);
    TIntColorRec(Result).Green := Saturate(AY - (179 * (AV - 128) + 86 * (AU - 128)) div 256, 0, 255);
    TIntColorRec(Result).Blue := Saturate(AY + (444 * (AU - 128)) div 256, 0, 255);
    TIntColorRec(Result).Alpha := 255;
  end;

var
  I, J: Integer;
  LUVPitch, LUVOffset: Cardinal;
  LStartU, LStartV: PtrUInt;
  LSrcY, LSrcU, LSrcV: PByte;
  LDestPixel: PIntColor;
begin
  LSrcY := ASource;

  LUVPitch := Cardinal(FSize.X) div 2;

  LStartU := PtrUInt(ASource) + Cardinal(FSize.X) * Cardinal(FSize.Y);
  LStartV := LStartU + LUVPitch * Cardinal(FSize.Y div 2);

  for J := 0 to ASurface.Height - 1 do
  begin
    LDestPixel := ASurface.Scanline[J];

    for I := 0 to ASurface.Width - 1 do
    begin
      LUVOffset := (J div 2) * LUVPitch + (I div 2);

      LSrcU := Pointer(LStartU + LUVOffset);
      LSrcV := Pointer(LStartV + LUVOffset);

      LDestPixel^ := PixelYUVToRGB(LSrcY^, LSrcU^, LSrcV^);

      Inc(LSrcY);
      Inc(LDestPixel);
    end;
  end;
end;

procedure TV4L2Camera.TakeSnapshot(const ADestSurface: TPixelSurface);
var
  LBuffer: Pointer;
  I: Integer;
begin
  if (FCaptureStream = nil) or (FCaptureStream.ImageBufferSection = nil) then
    raise EV4L2NotStreaming.Create(SCameraIsCurrentlyNotStreaming);

  GetMem(LBuffer, FCaptureStream.ImageBufferSize);
  try
    FCaptureStream.ImageBufferSection.Enter;
    try
      Move(FCaptureStream.ImageBuffer^, LBuffer^, FCaptureStream.ImageBufferSize);
    finally
      FCaptureStream.ImageBufferSection.Leave;
    end;

    if FPixelFormat = V4L2_PIX_FMT_BGR32 then
    begin // X8B8G8R8
      if (ADestSurface.Size <> FSize) or (ADestSurface.PixelFormat <> TPixelFormat.X8B8G8R8) then
        ADestSurface.SetSize(FSize, TPixelFormat.X8B8G8R8);

      for I := 0 to FSize.Y - 1 do
        Move(Pointer(PtrUInt(LBuffer) + (I * FSize.X * SizeOf(TIntColor)))^, ADestSurface.Scanline[I]^,
          FSize.X * SizeOf(TIntColor));
    end
    else if FPixelFormat = V4L2_PIX_FMT_YUV420 then
    begin // YU12
      if (ADestSurface.Size <> FSize) or ((ADestSurface.PixelFormat <> TPixelFormat.X8R8G8B8) and
        (ADestSurface.PixelFormat <> TPixelFormat.A8R8G8B8)) then
        ADestSurface.SetSize(FSize, TPixelFormat.X8R8G8B8);

      ConvertImageYU12(LBuffer, ADestSurface);
    end
    else
    begin // YUYV
      if (ADestSurface.Size <> FSize) or ((ADestSurface.PixelFormat <> TPixelFormat.X8R8G8B8) and
        (ADestSurface.PixelFormat <> TPixelFormat.A8R8G8B8)) then
        ADestSurface.SetSize(FSize, TPixelFormat.X8R8G8B8);

      ConvertImageYUYV(LBuffer, ADestSurface);
    end;
  finally
    FreeMem(LBuffer);
  end;
end;

{$ENDREGION}

end.

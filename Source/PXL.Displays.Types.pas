unit PXL.Displays.Types;
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

// Comment this out to prevent the component from releasing the pins in destructor.
{$DEFINE DISPLAY_RESET_PINS_AFTER_DONE}

uses
  Types, PXL.Types, PXL.Surfaces, PXL.ImageFormats, PXL.Canvas, PXL.Fonts, PXL.Boards.Types;

const
  PinNumberUnused = -1;

type
  TCustomDisplay = class(TConceptualPixelSurface)
  public type
    TOrientation = (Landscape, Portrait, InverseLandscape, InversePortrait);
    TOrientationChangedEvent = procedure(const ADisplay: TCustomDisplay) of object;
  private const
    SDisplayCommandWrite = 'Failed to write display command <0x%x>.';
    SDisplayCommandBytesWrite = 'Failed to write <%d> bytes of display commands.';
    SDisplayDataWrite = 'Failed to write display data <0x%x>.';
    SDisplayDataBytesWrite = 'Failed to write <%d> bytes of display data.';
  private
    FImageFormatManager: TImageFormatManager;
    FImageFormatHandler: TCustomImageFormatHandler;
    FCanvas: TCanvas;
    FFonts: TBitmapFonts;

    FOnOrientationChanged: TOrientationChangedEvent;
    FAdjustedOrientation: TOrientation;

    procedure SetLogicalOrientation(const AValue: TOrientation);
    procedure AdjustPosition(var AX, AY: Integer); inline;
  protected
    FPhysicalOrientation: TOrientation;
    FPhysicalSize: TPoint;

    FLogicalOrientation: TOrientation;
    FLogicalSize: TPoint;

    FScreenBufferSize: Integer;
    FScreenBuffer: Pointer;

    function GetPixel(AX, AY: Integer): TIntColor; override;
    procedure SetPixel(AX, AY: Integer; const Color: TIntColor); override;

    function GetPixelUnsafe(AX, AY: Integer): TIntColor; override;
    procedure SetPixelUnsafe(AX, AY: Integer; const Color: TIntColor); override;

    procedure Reset; virtual; abstract;
    procedure InitSequence; virtual; abstract;
    procedure PresentBuffer(const ARect: TRect); virtual; abstract;

    function ReadPixel(const AX, AY: Integer): TIntColor; virtual; abstract;
    procedure WritePixel(const AX, AY: Integer; const Color: TIntColor); virtual; abstract;

    function GetScanline(const AIndex: Integer): Pointer; virtual; abstract;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Initialize; virtual;
    procedure Present(const ARect: TRect); overload;
    procedure Present; overload;
    procedure Clear; virtual;

    property PhysicalOrientation: TOrientation read FPhysicalOrientation;
    property PhysicalSize: TPoint read FPhysicalSize;

    property LogicalOrientation: TOrientation read FLogicalOrientation write SetLogicalOrientation;
    property LogicalSize: TPoint read FLogicalSize;

    property ScreenBuffer: Pointer read FScreenBuffer;
    property ScreenBufferSize: Integer read FScreenBufferSize;

    property Scanline[const Index: Integer]: Pointer read GetScanline;

    property OnOrientationChanged: TOrientationChangedEvent read FOnOrientationChanged;

    property ImageFormatManager: TImageFormatManager read FImageFormatManager;
    property Canvas: TCanvas read FCanvas;
    property Fonts: TBitmapFonts read FFonts;
  end;

  TCustomDrivenDisplay = class(TCustomDisplay)
  protected
    FGPIO: TCustomGPIO;
    FDataPort: TCustomDataPort;
    FPinDC: Integer;
    FPinRST: Integer;
  protected
    procedure Reset; override;

    procedure WriteCommand(const AValue: Byte); overload; virtual;
    procedure WriteCommand(const AValues: array of Byte); overload; virtual;
    procedure WriteData(const AValue: Byte); overload; virtual;
    procedure WriteData(const AValues: array of Byte); overload; virtual;
  public
    constructor Create(const AGPIO: TCustomGPIO; const ADataPort: TCustomDataPort;
      const APinDC: Integer; const APinRST: Integer = PinNumberUnused);
    destructor Destroy; override;

    property GPIO: TCustomGPIO read FGPIO;
    property PinDC: Integer read FPinDC;
    property PinRST: Integer read FPinRST;
  end;

  TCustomDrivenDualDisplay = class(TCustomDrivenDisplay)
  protected const
    // I2C codes that differentiate command and data values.
    DisplayCommandID = $00;
    DisplayDataID = $40;
  private type
    TI2CBlock = packed record
      Control: Byte;
      Data: Byte;
    end;
  protected
    FAddress: Integer;

    procedure WriteCommand(const AValue: Byte); override;
    procedure WriteCommand(const AValues: array of Byte); override;
    procedure WriteData(const AValue: Byte); override;
    procedure WriteData(const AValues: array of Byte); override;
  public
    constructor Create(const AGPIO: TCustomGPIO; const ADataPort: TCustomDataPort;
      const APinDC: Integer; const APinRST: Integer = PinNumberUnused; const AAddress: Integer = PinNumberUnused);

    property Address: Integer read FAddress;
  end;

implementation

uses
{$IFNDEF DISPLAY_SILENT}
  PXL.Logs,
{$ENDIF}

  SysUtils, PXL.ImageFormats.FCL;

{$REGION 'TCustomDisplay'}

constructor TCustomDisplay.Create;
begin
  inherited;

  FImageFormatManager := TImageFormatManager.Create;
  FImageFormatHandler := TFCLImageFormatHandler.Create(FImageFormatManager);

  FCanvas := TCanvas.Create;
  FCanvas.Surface := Self;

  FFonts := TBitmapFonts.Create(FImageFormatManager);

  FLogicalOrientation := FPhysicalOrientation;
  FLogicalSize := FPhysicalSize;
end;

destructor TCustomDisplay.Destroy;
begin
  FreeMem(FScreenBuffer);
  FFonts.Free;
  FCanvas.Free;
  FImageFormatHandler.Free;
  FImageFormatManager.Free;

  inherited;
end;

procedure TCustomDisplay.SetLogicalOrientation(const AValue: TOrientation);
var
  LAdjustedValue: Integer;
begin
  if FLogicalOrientation <> AValue then
  begin
    FLogicalOrientation := AValue;
    LAdjustedValue := Ord(FLogicalOrientation) - Ord(FPhysicalOrientation);

    if LAdjustedValue < 0 then
      Inc(LAdjustedValue, 4)
    else
      LAdjustedValue := LAdjustedValue mod 4;

    FAdjustedOrientation := TOrientation(LAdjustedValue);

    if FAdjustedOrientation in [TOrientation.Portrait, TOrientation.InversePortrait] then
      FLogicalSize := Point(FPhysicalSize.Y, FPhysicalSize.X)
    else
      FLogicalSize := FPhysicalSize;

    FCanvas.ClipRect := Bounds(0, 0, FLogicalSize.X, FLogicalSize.Y);

    if Assigned(FOnOrientationChanged) then
      FOnOrientationChanged(Self);
  end;
end;

procedure TCustomDisplay.Initialize;
begin
  Reset;
  InitSequence;
end;

procedure TCustomDisplay.Present(const ARect: TRect);

  procedure Exchange(var AValue1, AValue2: Integer);
  var
    TempValue: Integer;
  begin
    TempValue := AValue1;
    AValue1 := AValue2;
    AValue2 := TempValue;
  end;

var
  LLeft, LTop, LRight, LBottom: Integer;
begin
  LLeft := ARect.Left;
  LTop := ARect.Top;
  LRight := ARect.Right - 1;
  LBottom := ARect.Bottom - 1;

  AdjustPosition(LLeft, LTop);
  AdjustPosition(LRight, LBottom);

  if LLeft > LRight then
    Exchange(LLeft, LRight);

  if LTop > LBottom then
    Exchange(LTop, LBottom);

  LLeft := Saturate(LLeft, 0, FPhysicalSize.X);
  LRight := Saturate(LRight + 1, 0, FPhysicalSize.X);
  LTop := Saturate(LTop, 0, FPhysicalSize.Y);
  LBottom := Saturate(LBottom + 1, 0, FPhysicalSize.Y);

  if (LLeft < LRight) and (LTop < LBottom) then
    PresentBuffer(TRect.Create(LLeft, LTop, LRight, LBottom));
end;

procedure TCustomDisplay.Present;
begin
  Present(Bounds(0, 0, FLogicalSize.X, FLogicalSize.Y));
end;

procedure TCustomDisplay.Clear;
begin
  FillChar(FScreenBuffer^, FScreenBufferSize, 0);
end;

procedure TCustomDisplay.AdjustPosition(var AX, AY: Integer);
var
  LTempValue: Integer;
begin
  case FAdjustedOrientation of
    TOrientation.Portrait:
    begin
      LTempValue := AY;
      AY := AX;
      AX := (FPhysicalSize.X - 1) - LTempValue;
    end;

    TOrientation.InverseLandscape:
    begin
      AX := (FPhysicalSize.X - 1) - AX;
      AY := (FPhysicalSize.Y - 1) - AY;
    end;

    TOrientation.InversePortrait:
    begin
      LTempValue := AY;
      AY := (FPhysicalSize.Y - 1) - AX;
      AX := LTempValue;
    end;
  end;
end;

function TCustomDisplay.GetPixel(AX, AY: Integer): TIntColor;
begin
  if (AX >= 0) and (AY >= 0) and (AX < FLogicalSize.X) and (AY < FLogicalSize.Y) then
  begin
    AdjustPosition(AX, AY);
    Result := ReadPixel(AX, AY);
  end
  else
    Result := IntColorTranslucentBlack;
end;

procedure TCustomDisplay.SetPixel(AX, AY: Integer; const Color: TIntColor);
begin
  if (AX >= 0) and (AY >= 0) and (AX < FLogicalSize.X) and (AY < FLogicalSize.Y) then
  begin
    AdjustPosition(AX, AY);
    WritePixel(AX, AY, Color);
  end
end;

function TCustomDisplay.GetPixelUnsafe(AX, AY: Integer): TIntColor;
begin
  AdjustPosition(AX, AY);
  Result := ReadPixel(AX, AY);
end;

procedure TCustomDisplay.SetPixelUnsafe(AX, AY: Integer; const Color: TIntColor);
begin
  AdjustPosition(AX, AY);
  WritePixel(AX, AY, Color);
end;

{$ENDREGION}
{$REGION 'TCustomDrivenDisplay'}

constructor TCustomDrivenDisplay.Create(const AGPIO: TCustomGPIO; const ADataPort: TCustomDataPort;
  const APinDC: Integer; const APinRST: Integer);
begin
  FGPIO := AGPIO;
  FDataPort := ADataPort;
  FPinDC := APinDC;
  FPinRST := APinRST;

  inherited Create;

  if FPinRST <> -1 then
    FGPIO.PinMode[FPinRST] := TPinMode.Output;

  if (FPinDC <> -1) and (FDataPort is TCustomPortSPI) then
    FGPIO.PinMode[FPinDC] := TPinMode.Output;
end;

destructor TCustomDrivenDisplay.Destroy;
begin
{$IFDEF DISPLAY_RESET_PINS_AFTER_DONE}
  if (FPinDC <> -1) and (FDataPort is TCustomPortSPI) then
    FGPIO.PinMode[FPinDC] := TPinMode.Input;

  if FPinRST <> -1 then
    FGPIO.PinMode[FPinRST] := TPinMode.Input;
{$ENDIF}

  inherited;
end;

procedure TCustomDrivenDisplay.Reset;
begin
  if FPinRST <> -1 then
  begin
    FGPIO.PinValue[FPinRST] := TPinValue.High;
    Sleep(5);
    FGPIO.PinValue[FPinRST] := TPinValue.Low;
    Sleep(10);
    FGPIO.PinValue[FPinRST] := TPinValue.High;
  end;
end;

procedure TCustomDrivenDisplay.WriteCommand(const AValue: Byte);
begin
  FGPIO.PinValue[FPinDC] := TPinValue.Low;

{$IFDEF DISPLAY_SILENT}
  FDataPort.Write(@AValue, 1);
{$ELSE}
  if FDataPort.Write(@AValue, 1) <> 1 then
    LogText(Format(SDisplayCommandWrite, [AValue]));
{$ENDIF}
end;

procedure TCustomDrivenDisplay.WriteCommand(const AValues: array of Byte);
begin
  if Length(AValues) > 0 then
  begin
    FGPIO.PinValue[FPinDC] := TPinValue.Low;

  {$IFDEF DISPLAY_SILENT}
    FDataPort.Write(@AValues[0], Length(AValues));
  {$ELSE}
    if FDataPort.Write(@AValues[0], Length(AValues)) <> Length(AValues) then
      LogText(Format(SDisplayCommandBytesWrite, [Length(AValues)]));
  {$ENDIF}
  end;
end;

procedure TCustomDrivenDisplay.WriteData(const AValue: Byte);
begin
  FGPIO.PinValue[FPinDC] := TPinValue.High;

{$IFDEF DISPLAY_SILENT}
  FDataPort.Write(@AValue, 1);
{$ELSE}
  if FDataPort.Write(@AValue, 1) <> 1 then
    LogText(Format(SDisplayDataWrite, [AValue]));
{$ENDIF}
end;

procedure TCustomDrivenDisplay.WriteData(const AValues: array of Byte);
begin
  if Length(AValues) > 0 then
  begin
    FGPIO.PinValue[FPinDC] := TPinValue.High;

  {$IFDEF DISPLAY_SILENT}
    FDataPort.Write(@AValues[0], Length(AValues));
  {$ELSE}
    if FDataPort.Write(@AValues[0], Length(AValues)) <> Length(AValues) then
      LogText(Format(SDisplayDataBytesWrite, [Length(AValues)]));
  {$ENDIF}
  end;
end;

{$ENDREGION}
{$REGION 'TCustomDrivenDisplay'}

constructor TCustomDrivenDualDisplay.Create(const AGPIO: TCustomGPIO; const ADataPort: TCustomDataPort;
  const APinDC, APinRST, AAddress: Integer);
begin
  if (AAddress <> -1) and (ADataPort is TCustomPortI2C) then
    FAddress := AAddress
  else
    FAddress := -1;

  inherited Create(AGPIO, ADataPort, APinDC, APinRST);
end;

procedure TCustomDrivenDualDisplay.WriteCommand(const AValue: Byte);
begin
  if FAddress <> -1 then
  begin
    TCustomPortI2C(FDataPort).SetAddress(FAddress);
    TCustomPortI2C(FDataPort).WriteByteData(DisplayCommandID, AValue);
  end
  else
    inherited;
end;

procedure TCustomDrivenDualDisplay.WriteCommand(const AValues: array of Byte);
var
  I: Integer;
begin
  if FAddress <> -1 then
  begin
    for I := 0 to Length(AValues) - 1 do
      WriteCommand(AValues[I]);
  end
  else
    inherited;
end;

procedure TCustomDrivenDualDisplay.WriteData(const AValue: Byte);
begin
  if FAddress <> -1 then
  begin
    TCustomPortI2C(FDataPort).SetAddress(FAddress);
    TCustomPortI2C(FDataPort).WriteByteData(DisplayDataID, AValue);
  end
  else
    inherited;
end;

procedure TCustomDrivenDualDisplay.WriteData(const AValues: array of Byte);
var
  I: Integer;
begin
  if FAddress <> -1 then
  begin
    for I := 0 to Length(AValues) - 1 do
      WriteData(AValues[I]);
  end
  else
    inherited;
end;

{$ENDREGION}

end.

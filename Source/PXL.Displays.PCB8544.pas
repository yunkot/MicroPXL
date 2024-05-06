unit PXL.Displays.PCB8544;
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
  Note: Nokia 5110 LCD display driver can only operate at SPI frequencies of 4 mHz or lower (default 8 mHz won't work).
}
interface

{$INCLUDE PXL.Config.inc}

uses
  Types, PXL.Types, PXL.Boards.Types, PXL.Displays.Types;

type
  TDisplay = class(TCustomDrivenDisplay)
  public const
    Nokia84x48: TPoint = (X: 84; Y: 48);
  private
    FScreenSize: TPoint;
    FContrast: Integer;

    procedure SetContrast(const AContrast: Integer);
  protected
    procedure InitSequence; override;
    procedure PresentBuffer(const ARect: TRect); override;

    function ReadPixel(const AX, AY: Integer): TIntColor; override;
    procedure WritePixel(const AX, AY: Integer; const AColor: TIntColor); override;

    function GetScanline(const AIndex: Integer): Pointer; override;
  public
    constructor Create(const AScreenSize: TPoint; const AGPIO: TCustomGPIO; const ADataPort: TCustomDataPort;
      const APinDC: Integer; const APinRST: Integer = -1);

    property ScreenSize: TPoint read FScreenSize;
    property Contrast: Integer read FContrast write SetContrast;
  end;

implementation

uses
  Math;

const
  CMD_DISPLAY_CONTROL = $08;
  CMD_FUNCTION_SET = $20;
  CMD_SET_BIAS = $10;
  CMD_SET_COL_ADDRESS = $40;
  CMD_SET_CONTRAST = $80;
  CMD_SET_ROW_ADDRESS = $80;

  MASK_DISPLAY_NORMAL = $4;
  MASK_EXTENDED_FUNCTION = $01;

constructor TDisplay.Create(const AScreenSize: TPoint; const AGPIO: TCustomGPIO; const ADataPort: TCustomDataPort;
  const APinDC, APinRST: Integer);
begin
  FScreenSize := AScreenSize;

  FPhysicalOrientation := TOrientation.Landscape;
  FPhysicalSize := FScreenSize;

  FScreenBufferSize := (FPhysicalSize.X * FPhysicalSize.Y) div 8;
  FScreenBuffer := AllocMem(FScreenBufferSize);

  FContrast := 60;

  inherited Create(AGPIO, ADataPort, APinDC, APinRST);
end;

procedure TDisplay.SetContrast(const AContrast: Integer);
var
  LValue: Integer;
begin
  LValue := Saturate(AContrast, 0, $7F);
  if FContrast <> LValue then
  begin
    FContrast := LValue;
    WriteCommand(CMD_SET_CONTRAST or FContrast);
  end;
end;

procedure TDisplay.InitSequence;
const
  DefaultBias = $04;
begin
  WriteCommand(CMD_FUNCTION_SET or MASK_EXTENDED_FUNCTION);
  WriteCommand(CMD_SET_BIAS or DefaultBias);
  WriteCommand(CMD_SET_CONTRAST or FContrast);

  WriteCommand(CMD_FUNCTION_SET);
  WriteCommand(CMD_DISPLAY_CONTROL or MASK_DISPLAY_NORMAL);
end;

procedure TDisplay.PresentBuffer(const ARect: TRect);
var
  I, LStartPos, LBytesToCopy: Integer;
begin
  if (ARect.Left = 0) and (ARect.Top = 0) and (ARect.Right = FPhysicalSize.X) and
    (ARect.Bottom = FPhysicalSize.Y) then
  begin // Full burst copy.
    WriteCommand(CMD_SET_COL_ADDRESS or 0);
    WriteCommand(CMD_SET_ROW_ADDRESS or 0);

    if FPinDC <> -1 then
      FGPIO.PinValue[FPinDC] := TPinValue.High;

    for I := 0 to FScreenBufferSize div MaxSPITransferSize do
    begin
      LStartPos := I * MaxSPITransferSize;
      LBytesToCopy := Min(FScreenBufferSize - LStartPos, MaxSPITransferSize);

      if LBytesToCopy > 0 then
        FDataPort.Write(Pointer(PtrUInt(FScreenBuffer) + Cardinal(LStartPos)), LBytesToCopy)
      else
        Break;
    end;
  end
  else
    for I := 0 to ARect.Height - 1 do
    begin // Copy one scanline at a time.
      WriteCommand(CMD_SET_COL_ADDRESS or ((ARect.Top + I) div 8));
      WriteCommand(CMD_SET_ROW_ADDRESS or ARect.Left);

      if FPinDC <> -1 then
        FGPIO.PinValue[FPinDC] := TPinValue.High;

      LStartPos := ((ARect.Top + I) div 8) * FPhysicalSize.X + ARect.Left;
      LBytesToCopy := ARect.Width;

      FDataPort.Write(Pointer(PtrUInt(FScreenBuffer) + Cardinal(LStartPos)), LBytesToCopy);
    end;
end;

function TDisplay.ReadPixel(const AX, AY: Integer): TIntColor;
var
  LLocation: PByte;
begin
  LLocation := Pointer(PtrUInt(FScreenBuffer) + (Cardinal(AY) div 8) * Cardinal(FPhysicalSize.X) +
    Cardinal(AX));

  if LLocation^ and (1 shl (AY mod 8)) > 0 then
    Result := IntColorWhite
  else
    Result := IntColorTranslucentBlack;
end;

procedure TDisplay.WritePixel(const AX, AY: Integer; const AColor: TIntColor);
var
  LLocation: PByte;
begin
  LLocation := Pointer(PtrUInt(FScreenBuffer) + (Cardinal(AY) div 8) * Cardinal(FPhysicalSize.X) +
    Cardinal(AX));

  if PixelToGray(AColor) > 127 then
    LLocation^ := LLocation^ or (1 shl (AY mod 8))
  else
    LLocation^ := LLocation^ and ($FF xor (1 shl (AY mod 8)));
end;

function TDisplay.GetScanline(const AIndex: Integer): Pointer;
begin
  Result := Pointer(PtrUInt(FScreenBuffer) + (Cardinal(AIndex) div 8) * Cardinal(FPhysicalSize.X));
end;

end.

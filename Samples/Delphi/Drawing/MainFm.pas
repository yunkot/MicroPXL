unit MainFm;
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

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Types, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, PXL.TypeDef, PXL.Types, PXL.Timing, PXL.ImageFormats, PXL.Surfaces,
  PXL.Canvas, PXL.Fonts, PXL.Surfaces.GDI;

type
  TMainForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    { Private declarations }
    FImageFormatManager: TImageFormatManager;
    FImageFormatHandler: TCustomImageFormatHandler;

    FSurface: TGDIPixelSurface;
    FImageLenna: TPixelSurface;

    FCanvas: TCanvas;
    FFonts: TBitmapFonts;
    FTimer: TMultimediaTimer;

    FDisplaySize: TPoint;
    FEngineTicks: Integer;
    FFontTahoma: Integer;

    procedure ApplicationIdle(Sender: TObject; var Done: Boolean);

    procedure EngineTiming(const Sender: TObject);
    procedure EngineProcess(const Sender: TObject);

    procedure RenderWindow;
    procedure RenderScene;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation
{$R *.dfm}

uses
  PXL.Classes, PXL.ImageFormats.WIC;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  ReportMemoryLeaksOnShutdown := True;

  FSurface := TGDIPixelSurface.Create;
  FSurface.SetSize(ClientWidth, ClientHeight);

  FImageLenna := TPixelSurface.Create;

  FImageFormatManager := TImageFormatManager.Create;
  FImageFormatHandler := TWICImageFormatHandler.Create(FImageFormatManager);

  FDisplaySize := Point(ClientWidth, ClientHeight);
  FCanvas := TCanvas.Create;

  if not FImageFormatManager.LoadFromFile(CrossFixFileName('..\..\Media\Lenna.png'), FImageLenna) then
  begin
    MessageDlg('Could not load Lenna image.', mtError, [mbOk], 0);
    Application.Terminate;
    Exit;
  end;

  FFonts := TBitmapFonts.Create(FImageFormatManager);
  FFonts.Canvas := FCanvas;

  FFontTahoma := FFonts.AddFromBinaryFile(CrossFixFileName('..\..\Media\Tahoma9b.font'));
  if FFontTahoma = -1 then
  begin
    MessageDlg('Could not load Tahoma font.', mtError, [mbOk], 0);
    Application.Terminate;
    Exit;
  end;

  FTimer := TMultimediaTimer.Create;
  FTimer.OnTimer := EngineTiming;
  FTimer.OnProcess := EngineProcess;
  FTimer.MaxFPS := 4000;

  Application.OnIdle := ApplicationIdle;
  FEngineTicks := 0;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FTimer.Free;
  FFonts.Free;
  FCanvas.Free;
  FImageFormatHandler.Free;
  FImageFormatManager.Free;
  FImageLenna.Free;
  FSurface.Free;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  FDisplaySize := Point(ClientWidth, ClientHeight);

  if not FSurface.SetSize(ClientWidth, ClientHeight) then
    raise Exception.Create('Could not resize rendering surface');

  RenderWindow;
  FTimer.Reset;
end;

procedure TMainForm.ApplicationIdle(Sender: TObject; var Done: Boolean);
begin
  FTimer.NotifyTick;
  Done := False;
end;

procedure TMainForm.EngineTiming(const Sender: TObject);
begin
  RenderWindow;
end;

procedure TMainForm.EngineProcess(const Sender: TObject);
begin
  Inc(FEngineTicks);
end;

procedure TMainForm.RenderWindow;
var
  LDestDC: TUntypedHandle;
begin
  FSurface.Clear(0);

  FCanvas.Surface := FSurface;
  FCanvas.ClipRect := Bounds(0, 0, FSurface.Width, FSurface.Height);

  RenderScene;

  LDestDC := GetDC(WindowHandle);
  if LDestDC <> 0 then
  try
    FSurface.BitBlt(LDestDC, Point(0, 0), FSurface.Size, Point(0, 0));
  finally
    ReleaseDC(WindowHandle, LDestDC);
  end;

  FTimer.Process;
end;

procedure TMainForm.RenderScene;
var
  J, I: Integer;
  LOmega, LKappa: Single;
begin
  // Draw gray background.
  for J := 0 to FDisplaySize.Y div 40 do
    for I := 0 to FDisplaySize.X div 40 do
      FCanvas.FillQuad(
        Quad(I * 40, J * 40, 40, 40),
        ColorRect($FF585858, $FF505050, $FF484848, $FF404040));

  for I := 0 to FDisplaySize.X div 40 do
    FCanvas.Line(
      PointF(I * 40.0, 0.0),
      PointF(I * 40.0, FDisplaySize.Y),
      $FF555555);

  for J := 0 to FDisplaySize.Y div 40 do
    FCanvas.Line(
      PointF(0.0, J * 40.0),
      PointF(FDisplaySize.X, J * 40.0),
      $FF555555);

  // Draw an animated hole.
  FCanvas.QuadHole(
    PointF(0.0, 0.0),
    PointF(FDisplaySize.X, FDisplaySize.Y),
    PointF(
      FDisplaySize.X * 0.5 + Cos(FEngineTicks * 0.0073) * FDisplaySize.X * 0.25,
      FDisplaySize.Y * 0.5 + Sin(FEngineTicks * 0.00312) * FDisplaySize.Y * 0.25),
    PointF(80.0, 100.0),
    $20FFFFFF, $80955BFF, 16);

  // Draw the image of famous Lenna.
  FCanvas.TexQuadPx(FImageLenna,
    TQuad.Rotated(
    PointF(FDisplaySize.X * 0.5, FDisplaySize.Y * 0.5),
    PointF(300.0, 300.0),
    FEngineTicks * 0.01),
    Quad(0, 0, 512, 512),
    $80FFFFFF);

  // Draw an animated Arc.
  LOmega := FEngineTicks * 0.0274;
  LKappa := 1.25 * Pi + Sin(FEngineTicks * 0.01854) * 0.5 * Pi;

  FCanvas.FillArc(
    PointF(FDisplaySize.X * 0.1, FDisplaySize.Y * 0.9),
    PointF(75.0, 50.0),
    LOmega, LOmega + LKappa, 32,
    ColorRect($FFFF0000, $FF00FF00, $FF0000FF, $FFFFFFFF));

  // Draw an animated Ribbon.
  LOmega := FEngineTicks * 0.02231;
  LKappa := 1.25 * Pi + Sin(FEngineTicks * 0.024751) * 0.5 * Pi;

  FCanvas.FillRibbon(
    PointF(FDisplaySize.X * 0.9, FDisplaySize.Y * 0.85),
    PointF(25.0, 20.0),
    PointF(70.0, 80.0),
    LOmega, LOmega + LKappa, 32,
    ColorRect($FFFF0000, $FF00FF00, $FF0000FF, $FFFFFFFF));

  FFonts[FFontTahoma].DrawText(
    PointF(4.0, 4.0),
    'FPS: ' + IntToStr(FTimer.FrameRate),
    $FFFFE887, $FFFF0000);
end;

end.

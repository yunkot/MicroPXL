unit PXL.Consts;
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
  PXL.TypeDef;

resourcestring
  SAssetManagerNotSpecified = 'Asset Manager has not been specified.';
  SCannotRestoreTexture = 'Cannot restore texture to working status on device recovery.';
  SCannotRestoreTextures = 'Cannot restore textures to working status on device recovery.';
  SCannotRestoreCanvas = 'Cannot restore canvas to working status on device recovery.';
  SCannotRestoreImages = 'Cannot restore images to working status on device recovery.';
  SCanvasGeometryTooBig = 'Geometry passed to canvas is too big to be rendered.';
  SCouldNotActivateShaderEffect = 'Shader effect could not be activated.';

implementation

end.

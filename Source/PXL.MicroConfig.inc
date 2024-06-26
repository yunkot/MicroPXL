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

// Indicates that this config file has been processed (to avoid redeclaring or redefining of parameters in
// other configuration files).
{$DEFINE PXL_MICRO_CONFIG}

{.$HINTS OFF}
{.$WARNINGS OFF}

{$SCOPEDENUMS ON}
{$B-}
{$I-}

{$IFDEF FPC}
  {$MODE ObjFPC}
  {$MODESWITCH ADVANCEDRECORDS}
  {$MODESWITCH TYPEHELPERS}
  {$MODESWITCH AUTODEREF}

  {$IFDEF CPU32}
    {$IFDEF I386}
      {$DEFINE CPUX86}
    {$ENDIF}
  {$ENDIF}

  {$IFDEF CPU64}
    {$DEFINE CPUX64}
    {$DEFINE PUREPASCAL}
  {$ENDIF}

  {$IF DEFINED(CPUARM) AND DEFINED(FPC_ABI_EABI)}
    {$DEFINE FPC_MMAP2}
  {$ELSE}
    {$DEFINE FPC_OLDMMAP}
  {$ENDIF}
{$ENDIF}

{$IFDEF EMBEDDED}
  {$DEFINE SINGLEBOARD}
  {.$DEFINE MICROBOARD}
  {$ALIGN 2}
{$ENDIF}



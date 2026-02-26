# zignbt

`zignbt` is a small, strongly-typed Minecraft NBT (Named Binary Tag) parsing and writing library for Zig.

It provides generic serialization and deserialization of Zig types to and from the NBT binary format, with minimal boilerplate and optional customization hooks.

## Roadmap (no particular order)
 - [ ] support SNBT
 - [ ] examples
 - [ ] better definition of tags inferring when writing
 - [ ] support enum arrays and maps
 - [ ] parse and write unions

---

## Features

- Read and write full NBT compounds
- Automatic mapping between Zig types and NBT tags
- Support for:
  - Integers (`i8`–`i64`, `u8`–`u64`)
  - Floats (`f32`, `f64`)
  - `bool`
  - `[]const u8` (NBT String)
  - Slices and arrays (List / ByteArray / IntArray / LongArray)
  - Structs (Compound)
  - Enums
  - Backed enums and packed structs
- Default field handling
- Duplicate field detection
- Optional trailing-field capture via string hash maps
- Custom per-type read/write overrides

---

## Installation

Import the module `zignbt` in your `build.zig`.
This library only supports zig version `0.15.x`


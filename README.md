<p align="center">
  <img width="256" height="256" src="https://raw.githubusercontent.com/nijilife/branding/main/logo/logo_transparent_256.png">
</p>

[日本語](https://github.com/nijigenerate/nijilife/blob/main/README.ja.md)
[简体中文](https://github.com/nijigenerate/nijilife/blob/main/README.zh.md)

# nijilife
[![Support me on Patreon](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-patreon.vercel.app%2Fapi%3Fusername%3Dclipsey%26type%3Dpatrons&style=for-the-badge)](https://patreon.com/clipsey)
[![Discord](https://img.shields.io/discord/855173611409506334?label=Community&logo=discord&logoColor=FFFFFF&style=for-the-badge)](https://discord.com/invite/abnxwN6r9v)

nijilife is a library for realtime 2D puppet animation and the reference implementation of the nijilife Puppet standard. nijilife works by deforming 2D meshes created from layered art at runtime based on parameters, this deformation tricks the viewer in to seeing 3D depth and movement in the 2D art.

&nbsp;


https://user-images.githubusercontent.com/7032834/166389697-02eeeedb-6a44-4570-9254-f6aa4f095300.mp4

*Video from Beta 0.7.2, [LunaFoxgirlVT](https://twitter.com/LunaFoxgirlVT), model art by [kpon](https://twitter.com/kawaiipony2)*

&nbsp;

# For Riggers and VTubers
If you're a model rigger you may want to check out [nijigenerate](https://github.com/nijigenerate/nijigenerate), the official nijilife rigging app in development.
If you're a VTuber you may want to check out [Inochi Session](https://github.com/nijilife/inochi-session).
This repository is purely for the standard and is not useful if you're an end user.

&nbsp;

# Documentation
Documentation is currently in the process of being written for the spec and the official tools. You can find the official documentation page [here](https://docs.nijilife.com).

&nbsp;

# Supported platforms
The reference implementation available here currently requires a OpenGL 3.1 context to function, `inInit` should be called *after* a OpenGL 3.1 (or higher) context has been established.

We will be working on splitting the rendering out from the frontend, so that developers can plug their own backend in. We provide [nijilife-c](https://github.com/nijigenerate/nijilife-c) as a way to use this library from non-D languages, additionally a second workgroup is making a pure Rust implementation of the nijilife specification over at [Inox2D](https://github.com/nijilife/inox2d).

&nbsp;


---

The nijilife logo was designed by [James Daniel](https://twitter.com/rakujira)

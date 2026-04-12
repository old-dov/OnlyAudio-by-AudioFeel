# -*- mode: python ; coding: utf-8 -*-
from kivy_deps import sdl2, glew, angle
from PyInstaller.utils.hooks import collect_submodules

block_cipher = None

hiddenimports = (
    collect_submodules('pygame') +
    collect_submodules('PIL') +
    collect_submodules('mutagen') +
    collect_submodules('flask') +
    [
        'win32timezone',
        'kivy.core.window.window_sdl2',
        'kivy.core.image.img_sdl2',
        'kivy.core.image.img_pil',
        'kivy.core.text.text_sdl2',
        'kivy.core.clipboard.clipboard_sdl2',
        'kivy.core.audio.audio_sdl2',
        'kivy.graphics.cgl_backend.cgl_glew',
        'kivy.graphics.cgl_backend.cgl_sdl2',
    ]
)

a = Analysis(
    ['onlyaudio.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('bg_default.png', '.'),
        ('onlyaudio.ico', '.'),
    ],
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['numpy', 'scipy', 'tkinter', 'unittest'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='OnlyAudio',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    icon='onlyaudio.ico',
    version='version_info.txt',
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    *[Tree(p) for p in sdl2.dep_bins + glew.dep_bins + angle.dep_bins],
    strip=False,
    upx=True,
    upx_exclude=[],
    name='OnlyAudio',
)

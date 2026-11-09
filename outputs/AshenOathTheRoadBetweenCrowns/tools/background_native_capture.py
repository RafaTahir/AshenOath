"""Launch an owned renderer on a Windows desktop which never becomes input.

The engine's --position is clamped onto a monitor during window creation.
CREATE_NO_WINDOW hides only its console. An explicit STARTUPINFO.lpDesktop
keeps the native window off the user's desktop from its first frame, without
changing the renderer or switching desktops. Only output/NUL handles are
inherited. No browser, existing window, foreground or cursor is manipulated.

API references:
https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-createdesktopw
https://learn.microsoft.com/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfow
https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattributelist
"""

from __future__ import annotations

import ctypes
from ctypes import wintypes as wt
import math
import os
from pathlib import Path
import subprocess
import uuid


class _StartupInfo(ctypes.Structure):
    _fields_ = [("cb", wt.DWORD), ("lpReserved", wt.LPWSTR),
                ("lpDesktop", wt.LPWSTR), ("lpTitle", wt.LPWSTR),
                ("dwX", wt.DWORD), ("dwY", wt.DWORD),
                ("dwXSize", wt.DWORD), ("dwYSize", wt.DWORD),
                ("dwXCountChars", wt.DWORD), ("dwYCountChars", wt.DWORD),
                ("dwFillAttribute", wt.DWORD), ("dwFlags", wt.DWORD),
                ("wShowWindow", wt.WORD), ("cbReserved2", wt.WORD),
                ("lpReserved2", ctypes.POINTER(ctypes.c_byte)),
                ("hStdInput", wt.HANDLE), ("hStdOutput", wt.HANDLE),
                ("hStdError", wt.HANDLE)]


class _StartupInfoEx(ctypes.Structure):
    _fields_ = [("StartupInfo", _StartupInfo), ("lpAttributeList", ctypes.c_void_p)]


class _ProcessInfo(ctypes.Structure):
    _fields_ = [("hProcess", wt.HANDLE), ("hThread", wt.HANDLE),
                ("dwProcessId", wt.DWORD), ("dwThreadId", wt.DWORD)]


class _Windows:
    def __init__(self):
        if os.name != "nt":
            raise OSError("background rendered capture requires the verified Windows desktop launcher")
        user = ctypes.WinDLL("user32", use_last_error=True)
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)

        def bind(dll, name, arguments, result):
            function = getattr(dll, name)
            function.argtypes, function.restype = arguments, result
            return function

        pointer = ctypes.c_void_p
        self.create_desktop = bind(user, "CreateDesktopW", [wt.LPCWSTR, wt.LPCWSTR, pointer, wt.DWORD, wt.DWORD, pointer], wt.HANDLE)
        self.close_desktop = bind(user, "CloseDesktop", [wt.HANDLE], wt.BOOL)
        self.open_input = bind(user, "OpenInputDesktop", [wt.DWORD, wt.BOOL, wt.DWORD], wt.HANDLE)
        self.thread_desktop = bind(user, "GetThreadDesktop", [wt.DWORD], wt.HANDLE)
        self.object_information = bind(user, "GetUserObjectInformationW", [wt.HANDLE, ctypes.c_int, pointer, wt.DWORD, ctypes.POINTER(wt.DWORD)], wt.BOOL)
        self.current_process = bind(kernel, "GetCurrentProcess", [], wt.HANDLE)
        self.duplicate_handle = bind(kernel, "DuplicateHandle", [wt.HANDLE, wt.HANDLE, wt.HANDLE, ctypes.POINTER(wt.HANDLE), wt.DWORD, wt.BOOL, wt.DWORD], wt.BOOL)
        self.close_handle = bind(kernel, "CloseHandle", [wt.HANDLE], wt.BOOL)
        self.initialize_attributes = bind(kernel, "InitializeProcThreadAttributeList", [pointer, wt.DWORD, wt.DWORD, ctypes.POINTER(ctypes.c_size_t)], wt.BOOL)
        self.update_attributes = bind(kernel, "UpdateProcThreadAttribute", [pointer, wt.DWORD, ctypes.c_size_t, pointer, ctypes.c_size_t, pointer, pointer], wt.BOOL)
        self.delete_attributes = bind(kernel, "DeleteProcThreadAttributeList", [pointer], None)
        self.create_process = bind(kernel, "CreateProcessW", [wt.LPCWSTR, wt.LPWSTR, pointer, pointer, wt.BOOL, wt.DWORD, pointer, wt.LPCWSTR, ctypes.POINTER(_StartupInfoEx), ctypes.POINTER(_ProcessInfo)], wt.BOOL)
        self.wait_process = bind(kernel, "WaitForSingleObject", [wt.HANDLE, wt.DWORD], wt.DWORD)
        self.exit_code = bind(kernel, "GetExitCodeProcess", [wt.HANDLE, ctypes.POINTER(wt.DWORD)], wt.BOOL)
        self.terminate_process = bind(kernel, "TerminateProcess", [wt.HANDLE, wt.UINT], wt.BOOL)

    def name(self, desktop):
        required = wt.DWORD()
        self.object_information(desktop, 2, None, 0, ctypes.byref(required))
        if not required.value:
            raise ctypes.WinError(ctypes.get_last_error())
        # A just-created thread can finish binding its named desktop between
        # the size query and copy; keep room for any normal desktop name.
        buffer = ctypes.create_unicode_buffer(max(256, required.value // ctypes.sizeof(ctypes.c_wchar) + 1))
        if not self.object_information(desktop, 2, buffer, ctypes.sizeof(buffer), ctypes.byref(required)):
            raise ctypes.WinError(ctypes.get_last_error())
        return buffer.value

    def input_name(self):
        desktop = self.open_input(0, False, 0x0001)  # DESKTOP_READOBJECTS
        if not desktop:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            return self.name(desktop)
        finally:
            self.close_desktop(desktop)


class BackgroundProcess:
    """Popen-sized lifetime interface; close() releases only owned handles."""

    def __init__(self, api, process, desktop, args, desktop_name, input_before):
        self._api, self._handle, self._desktop = api, process.hProcess, desktop
        self.args, self.pid, self.returncode = args, int(process.dwProcessId), None
        self.desktop_receipt = {"mode":"background-rendered", "desktop":desktop_name,
                                "input_desktop_before":input_before, "input_desktop_after_launch":api.input_name(),
                                "desktop_switch_requested":False, "binding":"STARTUPINFO.lpDesktop"}
        if self.desktop_receipt["input_desktop_after_launch"] == desktop_name:
            raise OSError("owned capture desktop unexpectedly became the input desktop")

    def poll(self):
        if self.returncode is not None:
            return self.returncode
        status = self._api.wait_process(self._handle, 0)
        if status == 258:  # WAIT_TIMEOUT
            return None
        if status != 0:
            raise ctypes.WinError(ctypes.get_last_error())
        code = wt.DWORD()
        if not self._api.exit_code(self._handle, ctypes.byref(code)):
            raise ctypes.WinError(ctypes.get_last_error())
        self.returncode = int(code.value)
        return self.returncode

    def wait(self, timeout=None):
        if timeout is not None and (not math.isfinite(timeout) or timeout < 0):
            raise ValueError("process timeout must be finite and nonnegative")
        milliseconds = 0xFFFFFFFF if timeout is None else min(0xFFFFFFFE, math.ceil(timeout * 1000))
        status = self._api.wait_process(self._handle, milliseconds)
        if status == 258:
            raise subprocess.TimeoutExpired(self.args, timeout)
        if status != 0:
            raise ctypes.WinError(ctypes.get_last_error())
        return self.poll()

    def kill(self):
        if self.poll() is None and not self._api.terminate_process(self._handle, 1):
            raise ctypes.WinError(ctypes.get_last_error())

    terminate = kill

    def close(self):
        if self._handle is None:
            return
        if self.poll() is None:
            raise RuntimeError("terminate or wait for the owned process before closing its desktop")
        try:
            self.desktop_receipt["input_desktop_after_exit"] = self._api.input_name()
        finally:
            self._api.close_handle(self._handle)
            self._handle = None
            if not self._api.close_desktop(self._desktop):
                raise ctypes.WinError(ctypes.get_last_error())
            self._desktop = None


def spawn_background(command, *, cwd, stdout, env=None):
    """Create the renderer directly on a fresh desktop; never show/switch it."""
    if not command or not Path(command[0]).is_file() or not Path(cwd).is_dir():
        raise ValueError("background capture requires an existing executable and working directory")
    api = _Windows()
    import msvcrt

    name = "AshenOathCapture_" + uuid.uuid4().hex
    input_before = api.input_name()
    # Read/create/enumerate/write objects, deliberately no DESKTOP_SWITCHDESKTOP.
    desktop = api.create_desktop(name, None, None, 0, 0x00C7, None)
    if not desktop:
        raise ctypes.WinError(ctypes.get_last_error())
    duplicates, attributes, initialized, process = [], None, False, _ProcessInfo()
    try:
        with open(os.devnull, "rb") as null_input:
            for file in (null_input, stdout):
                copied = wt.HANDLE()
                owner = api.current_process()
                if not api.duplicate_handle(owner, msvcrt.get_osfhandle(file.fileno()), owner, ctypes.byref(copied), 0, True, 2):
                    raise ctypes.WinError(ctypes.get_last_error())
                duplicates.append(copied.value)
        needed = ctypes.c_size_t()
        api.initialize_attributes(None, 1, 0, ctypes.byref(needed))
        attributes = ctypes.create_string_buffer(needed.value)
        if not api.initialize_attributes(attributes, 1, 0, ctypes.byref(needed)):
            raise ctypes.WinError(ctypes.get_last_error())
        initialized = True
        inherited = (wt.HANDLE * len(duplicates))(*duplicates)
        if not api.update_attributes(attributes, 0, 0x00020002, inherited, ctypes.sizeof(inherited), None, None):
            raise ctypes.WinError(ctypes.get_last_error())
        startup = _StartupInfoEx()
        startup.StartupInfo.cb = ctypes.sizeof(startup)
        startup.StartupInfo.lpDesktop = name
        startup.StartupInfo.dwFlags = 0x00000100 | 0x00000080  # USESTDHANDLES | FORCEOFFFEEDBACK
        startup.StartupInfo.hStdInput = duplicates[0]
        startup.StartupInfo.hStdOutput = startup.StartupInfo.hStdError = duplicates[1]
        startup.lpAttributeList = ctypes.cast(attributes, ctypes.c_void_p)
        environment = dict(os.environ if env is None else env)
        environment["ASHENOATH_CAPTURE_DESKTOP"] = name
        block = ctypes.create_unicode_buffer("\0".join(key + "=" + str(value) for key, value in sorted(environment.items(), key=lambda item:item[0].casefold())) + "\0\0")
        arguments = [str(value) for value in command]
        line = ctypes.create_unicode_buffer(subprocess.list2cmdline(arguments))
        flags = 0x08000000 | 0x00000400 | 0x00080000  # NO_WINDOW | UNICODE_ENVIRONMENT | EXTENDED_STARTUPINFO
        if not api.create_process(arguments[0], line, None, None, True, flags, block, str(cwd), ctypes.byref(startup), ctypes.byref(process)):
            raise ctypes.WinError(ctypes.get_last_error())
        return BackgroundProcess(api, process, desktop, arguments, name, input_before)
    except BaseException:
        if process.hProcess:
            api.terminate_process(process.hProcess, 1)
            api.wait_process(process.hProcess, 15000)
            api.close_handle(process.hProcess)
        api.close_desktop(desktop)
        raise
    finally:
        if process.hThread:
            api.close_handle(process.hThread)
        if initialized:
            api.delete_attributes(attributes)
        for handle in duplicates:
            api.close_handle(handle)

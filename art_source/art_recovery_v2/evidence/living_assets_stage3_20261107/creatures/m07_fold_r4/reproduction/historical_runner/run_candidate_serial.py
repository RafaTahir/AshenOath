"""Bounded explicit creature queue; reuses run_candidate_authoring.py unchanged.

Source/readiness inspection is the default. --execute requires the parent's
exclusive engine grant. A successful item proves authoring/source contract
only; its previews are not in-level, native, performance or user acceptance.
"""
from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

import run_candidate_authoring as single

ROOT = single.ROOT
HERE = Path(__file__).resolve().parent
RUNNER = HERE / 'run_candidate_authoring.py'


def utc_deadline(value):
    result = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.tzinfo is None or result.utcoffset() != dt.timedelta(0):
        raise ValueError('Deadline must explicitly use UTC (Z or +00:00)')
    return result.astimezone(dt.timezone.utc)


def seconds_left(deadline):
    return (deadline-dt.datetime.now(dt.timezone.utc)).total_seconds()


def inputs_unchanged(rows):
    try:
        return single.unchanged(rows)
    except (OSError, ValueError):
        return False


def prepare_plan(assets, label, deadline, author_timeout=480, source_timeout=90):
    if not assets or len(set(assets)) != len(assets):
        raise ValueError('Provide a nonempty explicit asset list without duplicates')
    if not re.fullmatch(r'[a-z0-9_-]+', label):
        raise ValueError('Use a fresh simple batch label')
    if not 10 <= author_timeout <= 480 or not 10 <= source_timeout <= 90:
        raise ValueError('Keep the maintained per-stage timeout bounds')
    if seconds_left(deadline) < 45:
        raise ValueError('UTC deadline leaves no safe authoring/cleanup window')
    output = (HERE / 'serial' / label).resolve()
    if not output.is_relative_to(HERE.resolve()) or output.exists():
        raise ValueError('Fresh workspace-contained batch receipt directory required')
    common = [single.row(Path(__file__)), single.row(RUNNER), single.row(Path(sys.executable))]
    union = {row['path']: row for row in common}
    items = []
    for asset in assets:
        source, folder, inputs = single.prepare(asset)
        if not folder.resolve().is_relative_to(ROOT.resolve()):
            raise ValueError('Candidate output leaves the isolated workspace')
        item_label = 'serial_' + label
        receipt = (HERE / asset / item_label / 'receipt.json').resolve()
        if not receipt.is_relative_to(HERE.resolve()) or receipt.parent.exists():
            raise ValueError('Prior per-asset receipts must not be overwritten: ' + asset)
        for row in inputs:
            if row['path'] in union and union[row['path']] != row:
                raise ValueError('Input changed while preparing the explicit queue')
            union[row['path']] = row
        items.append({'asset': asset, 'source': str(source), 'folder': str(folder),
                      'label': item_label, 'inputs': inputs, 'receipt': str(receipt)})
    frozen = list(union.values())
    if not inputs_unchanged(frozen):
        raise ValueError('Staged inputs changed during preflight')
    return {'assets': list(assets), 'label': label, 'deadline_utc': deadline.isoformat(),
            'author_timeout': author_timeout, 'source_timeout': source_timeout,
            'output': str(output), 'frozen_inputs': frozen, 'items': items}


def settle_owned_job(active, terminate, timed_out, clock=None, sleeper=None):
    """Allow accounting publication to settle inside the existing 5s budget.

    The root process handle may signal before the job publishes its final
    active-process decrement. Actual descendants still active after 250ms
    are rejected and terminated; a timeout never waits for that grace.
    """
    clock = clock or time.monotonic
    sleeper = sleeper or time.sleep
    began = clock()
    cleanup_deadline = began+5.0
    initial = active()
    count = initial

    def drain(until):
        nonlocal count
        while count and clock() < until:
            sleeper(min(.01, max(0.0, until-clock())))
            count = active()

    result = {'active_processes_after_root_wait': initial,
              'accounting_quiescence_seconds': 0.0,
              'termination_requested': False, 'owned_tree_exited': False}
    if timed_out:
        result['termination_requested'] = True
        terminate()
        count = active()
    elif count:
        drain(min(cleanup_deadline, began+.25))
        result['accounting_quiescence_seconds'] = round(clock()-began, 6)
        if count:
            result['unexpected_live_descendants'] = True
            result['termination_requested'] = True
            terminate()
            count = active()
    drain(cleanup_deadline)
    result['owned_tree_exited'] = count == 0
    result['active_processes_after_cleanup'] = count
    result['cleanup_seconds'] = round(clock()-began, 6)
    return result


def launch_owned(command, log, timeout):
    """Create a hidden suspended runner inside a kill-on-close Windows job.

    Assignment happens before resume, so even an early runner exception cannot
    orphan Blender. No process enumeration or unrelated PID termination occurs.
    """
    if os.name != 'nt':
        raise RuntimeError('This owned Windows process runner requires Windows')
    import msvcrt
    from ctypes import wintypes as w

    class Startup(ctypes.Structure):
        _fields_ = [('cb', w.DWORD), ('reserved', w.LPWSTR), ('desktop', w.LPWSTR),
                    ('title', w.LPWSTR), ('x', w.DWORD), ('y', w.DWORD),
                    ('xsize', w.DWORD), ('ysize', w.DWORD), ('xchars', w.DWORD),
                    ('ychars', w.DWORD), ('fill', w.DWORD), ('flags', w.DWORD),
                    ('show', w.WORD), ('reserved_size', w.WORD), ('reserved_ptr', ctypes.c_void_p),
                    ('stdin', w.HANDLE), ('stdout', w.HANDLE), ('stderr', w.HANDLE)]

    class Process(ctypes.Structure):
        _fields_ = [('process', w.HANDLE), ('thread', w.HANDLE), ('pid', w.DWORD), ('tid', w.DWORD)]

    class Limits(ctypes.Structure):
        _fields_ = [('process_time', ctypes.c_longlong), ('job_time', ctypes.c_longlong),
                    ('flags', w.DWORD), ('minimum', ctypes.c_size_t), ('maximum', ctypes.c_size_t),
                    ('active_limit', w.DWORD), ('affinity', ctypes.c_size_t),
                    ('priority', w.DWORD), ('scheduling', w.DWORD)]

    class IO(ctypes.Structure):
        _fields_ = [(name, ctypes.c_ulonglong) for name in
                    ('read_ops', 'write_ops', 'other_ops', 'read_bytes', 'write_bytes', 'other_bytes')]

    class Extended(ctypes.Structure):
        _fields_ = [('basic', Limits), ('io', IO), ('process_memory', ctypes.c_size_t),
                    ('job_memory', ctypes.c_size_t), ('peak_process', ctypes.c_size_t),
                    ('peak_job', ctypes.c_size_t)]

    class Accounting(ctypes.Structure):
        _fields_ = [(name, ctypes.c_longlong) for name in ('user', 'kernel', 'period_user', 'period_kernel')]
        _fields_ += [(name, w.DWORD) for name in ('faults', 'total', 'active', 'terminated')]

    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    declarations = {
        'CreateJobObjectW': ([ctypes.c_void_p, w.LPCWSTR], w.HANDLE),
        'SetInformationJobObject': ([w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD], w.BOOL),
        'QueryInformationJobObject': ([w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD, ctypes.c_void_p], w.BOOL),
        'AssignProcessToJobObject': ([w.HANDLE, w.HANDLE], w.BOOL),
        'CreateProcessW': ([w.LPCWSTR, w.LPWSTR, ctypes.c_void_p, ctypes.c_void_p, w.BOOL, w.DWORD,
                            ctypes.c_void_p, w.LPCWSTR, ctypes.POINTER(Startup), ctypes.POINTER(Process)], w.BOOL),
        'ResumeThread': ([w.HANDLE], w.DWORD),
        'WaitForSingleObject': ([w.HANDLE, w.DWORD], w.DWORD),
        'GetExitCodeProcess': ([w.HANDLE, ctypes.POINTER(w.DWORD)], w.BOOL),
        'TerminateJobObject': ([w.HANDLE, w.UINT], w.BOOL),
        'TerminateProcess': ([w.HANDLE, w.UINT], w.BOOL),
        'CloseHandle': ([w.HANDLE], w.BOOL),
    }
    for name, (arguments, result) in declarations.items():
        function = getattr(kernel, name); function.argtypes = arguments; function.restype = result

    def require(ok):
        if not ok:
            raise ctypes.WinError(ctypes.get_last_error())

    job = kernel.CreateJobObjectW(None, None)
    require(job)
    process = Process()
    assigned = False
    began = time.monotonic()
    result = {'passed': False, 'timed_out': False, 'owned_tree_exited': False}

    def active():
        count = Accounting()
        require(kernel.QueryInformationJobObject(job, 1, ctypes.byref(count), ctypes.sizeof(count), None))
        return count.active

    try:
        limits = Extended(); limits.basic.flags = 0x2000  # KILL_ON_JOB_CLOSE
        require(kernel.SetInformationJobObject(job, 9, ctypes.byref(limits), ctypes.sizeof(limits)))
        with Path(log).open('xb') as stream, open(os.devnull, 'rb') as empty:
            handles = [msvcrt.get_osfhandle(stream.fileno()), msvcrt.get_osfhandle(empty.fileno())]
            startup = Startup(); startup.cb = ctypes.sizeof(startup); startup.flags = 0x100
            startup.stdin = handles[1]; startup.stdout = handles[0]; startup.stderr = handles[0]
            for handle in handles: os.set_handle_inheritable(handle, True)
            try:
                require(kernel.CreateProcessW(str(command[0]), ctypes.create_unicode_buffer(subprocess.list2cmdline(command)),
                    None, None, True, 0x08000000 | 0x00000004, None, str(ROOT), ctypes.byref(startup), ctypes.byref(process)))
            finally:
                for handle in handles: os.set_handle_inheritable(handle, False)
            require(kernel.AssignProcessToJobObject(job, process.process)); assigned = True
            if kernel.ResumeThread(process.thread) == 0xFFFFFFFF:
                raise ctypes.WinError(ctypes.get_last_error())
            result['pid'] = process.pid
            print(json.dumps({'owned_runner_pid': process.pid, 'timeout_seconds': timeout}), flush=True)
            wait = kernel.WaitForSingleObject(process.process, max(1, int(timeout*1000)))
            if wait == 258:
                result['timed_out'] = True
            elif wait != 0:
                raise ctypes.WinError(ctypes.get_last_error())
            result.update(settle_owned_job(active, lambda: require(kernel.TerminateJobObject(job, 1)),
                                           result['timed_out']))
            code = w.DWORD(); require(kernel.GetExitCodeProcess(process.process, ctypes.byref(code)))
            result['exit_code'] = code.value
            result['passed'] = (code.value == 0 and result['owned_tree_exited'] and
                                not result['timed_out'] and not result.get('unexpected_live_descendants'))
    except Exception as error:
        result['error'] = str(error)
        if process.process:
            if assigned: kernel.TerminateJobObject(job, 1)
            else: kernel.TerminateProcess(process.process, 1)
            kernel.WaitForSingleObject(process.process, 5000)
        if assigned:
            try: result['owned_tree_exited'] = active() == 0
            except OSError: pass
    finally:
        # Closing the job also terminates any remaining owned descendants.
        kernel.CloseHandle(job)
        if process.thread: kernel.CloseHandle(process.thread)
        if process.process: kernel.CloseHandle(process.process)
    result['seconds'] = round(time.monotonic()-began, 3)
    return result


def inspect_asset(item):
    receipt_path = Path(item['receipt'])
    receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
    if (receipt.get('asset') != item['asset'] or receipt.get('passed') is not True or
        receipt.get('sources_unchanged') is not True or receipt.get('inputs') != item['inputs'] or
        any(receipt.get(key) is not False for key in
            ('production_overwritten', 'native_verified', 'visual_accepted', 'attack_profiles_recalibrated'))):
        raise ValueError('Per-asset receipt does not prove the exact bounded source scope')
    runs = receipt.get('runs', [])
    if [run.get('stage') for run in runs] != ['blender_author', 'source_contract']:
        raise ValueError('Both maintained authoring and source validation must finish in order')
    if any(run.get('passed') is not True or run.get('exit_code') != 0 or run.get('timed_out') is not False
           or run.get('owned_process_exited') is not True for run in runs):
        raise ValueError('A per-asset child failed or did not exit')
    folder = Path(item['folder'])
    authored = json.loads((folder/'authoring.json').read_text())
    contract = json.loads((folder/'source_contract.json').read_text())
    if contract.get('status') != 'source_contract_pass' or contract.get('asset') != item['asset']:
        raise ValueError('Missing exact successful source contract')
    outputs = single.verify_outputs(folder, item['asset'], authored, contract)
    if outputs != receipt.get('outputs') or not inputs_unchanged(item['inputs']):
        raise ValueError('Per-asset source or exact output inventory changed')
    return {'asset': item['asset'], 'receipt': single.row(receipt_path), 'outputs': outputs,
            'candidate_bytes': receipt['candidate_bytes'], 'net_source_bytes': receipt['net_source_bytes'],
            'authoring_verified': True, 'source_contract_verified': True,
            'native_verified': False, 'source_previews_reviewed': False, 'in_level_accepted': False,
            'performance_verified': False, 'user_accepted': False, 'production_overwritten': False}


def write_receipt(folder, receipt):
    temporary = folder/'receipt.json.tmp'
    temporary.write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    temporary.replace(folder/'receipt.json')


def execute_plan(plan, launcher=launch_owned, inspector=inspect_asset):
    output = Path(plan['output']); output.mkdir(parents=True, exist_ok=False)
    (output/'frozen_inputs.json').write_text(json.dumps(plan, indent=2)+'\n', encoding='utf-8')
    deadline = utc_deadline(plan['deadline_utc'])
    receipt = {'scope': 'Serial candidate authoring and source contracts only', 'passed': False,
               'frozen_inputs': single.row(output/'frozen_inputs.json'), 'assets': plan['assets'],
               'deadline_utc': plan['deadline_utc'],
               'completed': [], 'runs': [], 'failure': None, 'production_overwritten': False,
               'native_verified': False, 'source_previews_reviewed': False, 'in_level_accepted': False,
               'performance_verified': False, 'user_accepted': False}
    write_receipt(output, receipt)
    try:
        for item in plan['items']:
            if not inputs_unchanged(plan['frozen_inputs']):
                raise ValueError('Frozen batch input changed before '+item['asset'])
            remaining = seconds_left(deadline)
            if remaining < 45:
                raise ValueError('UTC production boundary reached; no next asset launched')
            if Path(item['receipt']).parent.exists() or (Path(item['folder']).exists() and any(Path(item['folder']).iterdir())):
                raise ValueError('An output appeared after preflight; refusing overwrite')
            command = [sys.executable, str(RUNNER), '--asset', item['asset'], '--label', item['label'], '--execute',
                       '--author-timeout', str(plan['author_timeout']), '--source-timeout', str(plan['source_timeout']),
                       '--deadline-utc', plan['deadline_utc']]
            timeout = min(plan['author_timeout']+plan['source_timeout']+35, remaining-5)
            result = launcher(command, output/(item['asset']+'.runner.log'), timeout)
            receipt['runs'].append({'asset': item['asset'], 'command': command, **result})
            write_receipt(output, receipt)
            if not result.get('passed') or not result.get('owned_tree_exited'):
                raise ValueError('Owned candidate process failed or cleanup unconfirmed: '+item['asset'])
            if not inputs_unchanged(plan['frozen_inputs']):
                raise ValueError('Frozen batch input changed during '+item['asset'])
            receipt['completed'].append(inspector(item))
            write_receipt(output, receipt)
        receipt['passed'] = len(receipt['completed']) == len(plan['items'])
    except Exception as error:
        receipt['failure'] = str(error)
    finally:
        receipt['sources_unchanged'] = inputs_unchanged(plan['frozen_inputs'])
        receipt['production_overwritten'] = any(not inputs_unchanged([next(row for row in item['inputs']
            if row['path']==item['source'])]) for item in plan['items'])
        receipt['passed'] = bool(receipt['passed'] and receipt['sources_unchanged'] and not receipt['production_overwritten'])
        receipt['remaining_assets'] = plan['assets'][len(receipt['completed']):]
        write_receipt(output, receipt)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets', nargs='+', required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--deadline-utc', required=True)
    parser.add_argument('--author-timeout', type=int, default=480)
    parser.add_argument('--source-timeout', type=int, default=90)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    plan = prepare_plan(args.assets,args.label,utc_deadline(args.deadline_utc),args.author_timeout,args.source_timeout)
    print(json.dumps({'ready': True, 'execute': args.execute, **plan}), flush=True)
    if not args.execute:
        return 0
    receipt = execute_plan(plan)
    print(json.dumps({key:value for key,value in receipt.items() if key not in ('completed','runs')}), flush=True)
    return 0 if receipt['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

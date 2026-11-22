using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;

public static class AshenStackSampler {
    [StructLayout(LayoutKind.Sequential)] struct Address { public ulong Offset; public ushort Segment; public uint Mode; }
    [StructLayout(LayoutKind.Sequential)] struct KdHelp {
        public ulong Thread; public uint CallbackStack, CallbackStore, NextCallback, FramePointer;
        public ulong UserMode, Dispatcher, RangeStart, ExceptionDispatcher, StackBase, StackLimit;
        public uint BuildVersion, TableSize; public ulong Table; public uint StubOffset, StubSize;
        public ulong Reserved0, Reserved1;
    }
    [StructLayout(LayoutKind.Sequential)] struct Frame {
        public Address PC, Return, Base, Stack, Store; public IntPtr FunctionTable;
        public ulong P0, P1, P2, P3; public int Far, Virtual; public ulong R0, R1, R2; public KdHelp Help;
    }
    [StructLayout(LayoutKind.Sequential)] struct ThreadEntry { public uint Size, Usage, Id, Owner; public int BasePriority, Delta; public uint Flags; }
    [StructLayout(LayoutKind.Sequential)] struct FileTime { public uint Low, High; public long Ticks { get { return ((long)High << 32) | Low; } } }
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenThread(uint access, bool inherit, uint id);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError=true)] static extern uint SuspendThread(IntPtr h);
    [DllImport("kernel32.dll", SetLastError=true)] static extern uint ResumeThread(IntPtr h);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetThreadContext(IntPtr h, IntPtr context);
    [DllImport("kernel32.dll")] static extern bool GetThreadTimes(IntPtr h, out FileTime c, out FileTime e, out FileTime k, out FileTime u);
    [DllImport("kernel32.dll")] static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);
    [DllImport("kernel32.dll")] static extern bool Thread32First(IntPtr h, ref ThreadEntry entry);
    [DllImport("kernel32.dll")] static extern bool Thread32Next(IntPtr h, ref ThreadEntry entry);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("dbghelp.dll", CharSet=CharSet.Unicode)] static extern bool SymInitializeW(IntPtr process, string search, bool invade);
    [DllImport("dbghelp.dll")] static extern bool SymCleanup(IntPtr process);
    [DllImport("dbghelp.dll")] static extern uint SymSetOptions(uint options);
    [DllImport("dbghelp.dll")] static extern bool SymRefreshModuleList(IntPtr process);
    [DllImport("dbghelp.dll")] static extern IntPtr SymFunctionTableAccess64(IntPtr process, ulong address);
    [DllImport("dbghelp.dll")] static extern ulong SymGetModuleBase64(IntPtr process, ulong address);
    delegate IntPtr FunctionTable(IntPtr process, ulong address);
    delegate ulong ModuleBase(IntPtr process, ulong address);
    [DllImport("dbghelp.dll", SetLastError=true)] static extern bool StackWalk64(uint machine, IntPtr process, IntPtr thread, ref Frame frame, IntPtr context, IntPtr read, FunctionTable table, ModuleBase module, IntPtr translate);
    static readonly FunctionTable TableCallback = SymFunctionTableAccess64;
    static readonly ModuleBase ModuleCallback = SymGetModuleBase64;
    sealed class ThreadRecord { public uint Id; public IntPtr Handle; public long Created, Cpu, Delta; }
    sealed class Module { public ulong Start, End; public string Name; }

    static List<Module> Modules(Process process) {
        var result = new List<Module>();
        foreach (ProcessModule module in process.Modules) {
            ulong start = (ulong)module.BaseAddress.ToInt64();
            result.Add(new Module { Start=start, End=start+(ulong)module.ModuleMemorySize, Name=module.ModuleName });
        }
        return result;
    }
    static string Label(ulong address, List<Module> modules) {
        foreach(var module in modules) if(address>=module.Start && address<module.End) return module.Name+"+0x"+(address-module.Start).ToString("x");
        return "unknown+0x"+address.ToString("x");
    }
    static List<ulong> Stack(IntPtr process, IntPtr thread, out double suspendedMs) {
        var result = new List<ulong>();
        IntPtr raw=Marshal.AllocHGlobal(1250), context=new IntPtr((raw.ToInt64()+15)&~15L);
        for(int i=0;i<1232;i+=8) Marshal.WriteInt64(context,i,0);
        Marshal.WriteInt32(context,48,0x100003);
        var timer=Stopwatch.StartNew();
        bool suspended=false;
        try {
            if(SuspendThread(thread)==uint.MaxValue) throw new System.ComponentModel.Win32Exception();
            suspended=true;
            if(!GetThreadContext(thread,context)) throw new System.ComponentModel.Win32Exception();
            var frame=new Frame();
            frame.PC.Offset=(ulong)Marshal.ReadInt64(context,248); frame.PC.Mode=3;
            frame.Stack.Offset=(ulong)Marshal.ReadInt64(context,152); frame.Stack.Mode=3;
            frame.Base.Offset=(ulong)Marshal.ReadInt64(context,160); frame.Base.Mode=3;
            result.Add(frame.PC.Offset);
            for(int i=0;i<24;i++) {
                if(!StackWalk64(0x8664,process,thread,ref frame,context,IntPtr.Zero,TableCallback,ModuleCallback,IntPtr.Zero)) break;
                if(frame.PC.Offset==0) break;
                if(result[result.Count-1]!=frame.PC.Offset) result.Add(frame.PC.Offset);
            }
        } finally {
            if(suspended && ResumeThread(thread)==uint.MaxValue) throw new System.ComponentModel.Win32Exception();
            suspendedMs=timer.Elapsed.TotalMilliseconds;
            Marshal.FreeHGlobal(raw);
        }
        return result;
    }
    static void Discover(int pid, Dictionary<uint,ThreadRecord> threads) {
        IntPtr snapshot=CreateToolhelp32Snapshot(4,0);
        if(snapshot==new IntPtr(-1)) throw new System.ComponentModel.Win32Exception();
        try {
            var entry=new ThreadEntry(); entry.Size=(uint)Marshal.SizeOf(entry);
            for(bool valid=Thread32First(snapshot,ref entry);valid;valid=Thread32Next(snapshot,ref entry)) {
                if(entry.Owner!=(uint)pid || threads.ContainsKey(entry.Id)) continue;
                IntPtr h=OpenThread(0x004a,false,entry.Id);
                if(h==IntPtr.Zero) continue;
                FileTime c,e,k,u;
                if(GetThreadTimes(h,out c,out e,out k,out u)) threads.Add(entry.Id,new ThreadRecord{Id=entry.Id,Handle=h,Created=c.Ticks,Cpu=k.Ticks+u.Ticks});
                else CloseHandle(h);
            }
        } finally { CloseHandle(snapshot); }
    }
    public static string SelfTest(string scratch) {
        uint id=0; bool done=false;
        var thread=new Thread(()=>{id=GetCurrentThreadId(); while(!Volatile.Read(ref done)) Thread.Sleep(20);});
        thread.Start(); while(id==0) Thread.Sleep(1);
        var process=Process.GetCurrentProcess(); var modules=Modules(process);
        SymSetOptions(0x80000|0x200|0x1000|0x4);
        if(!SymInitializeW(process.Handle,scratch,true)) throw new Exception("SymInitialize failed");
        IntPtr h=OpenThread(0x004a,false,id);
        try {
            double elapsed; var stack=Stack(process.Handle,h,out elapsed);
            if(stack.Count<3) throw new Exception("Self-test stack too short: "+stack.Count);
            return "PASS depth="+stack.Count+" suspend_ms="+elapsed.ToString("F3")+" "+String.Join(";",stack.Select(x=>Label(x,modules)));
        } finally { CloseHandle(h); SymCleanup(process.Handle); Volatile.Write(ref done,true); thread.Join(); }
    }
    public static string Sample(int pid, string output, int seconds) {
        var process=Process.GetProcessById(pid); IntPtr handle=process.Handle;
        var modules=Modules(process); var threads=new Dictionary<uint,ThreadRecord>();
        var lines=new List<string>(); lines.Add("utc_ticks,elapsed_ms,thread,cpu_delta_ms,suspend_ms,stack");
        SymSetOptions(0x80000|0x200|0x1000|0x4);
        if(!SymInitializeW(handle,output,true)) throw new Exception("SymInitialize failed");
        double max=0,total=0; int count=0;
        var timer=Stopwatch.StartNew(); long nextDiscovery=0;
        try {
            while(!process.HasExited && timer.Elapsed.TotalSeconds<seconds) {
                long iteration=timer.ElapsedMilliseconds;
                if(iteration>=nextDiscovery) {
                    Discover(pid,threads); modules=Modules(process); SymRefreshModuleList(handle); nextDiscovery=iteration+2000;
                }
                foreach(var t in threads.Values) {
                    FileTime c,e,k,u;
                    if(GetThreadTimes(t.Handle,out c,out e,out k,out u) && e.Ticks==0) { long cpu=k.Ticks+u.Ticks; t.Delta=Math.Max(0,cpu-t.Cpu); t.Cpu=cpu; }
                    else t.Delta=-1;
                }
                var alive=threads.Values.Where(t=>t.Delta>=0).ToList();
                if(alive.Count==0) break;
                var main=alive.OrderBy(t=>t.Created).First();
                var selected=alive.Where(t=>t.Delta>0 && t.Id!=main.Id).OrderByDescending(t=>t.Delta).Take(2).ToList();
                selected.Insert(0,main);
                foreach(var t in selected) {
                    double elapsed; long utc=DateTime.UtcNow.Ticks; var stack=Stack(handle,t.Handle,out elapsed);
                    max=Math.Max(max,elapsed); total+=elapsed; count++;
                    lines.Add(String.Format(CultureInfo.InvariantCulture,"{0},{1},{2},{3:F3},{4:F3},{5}",utc,timer.Elapsed.TotalMilliseconds,t.Id,t.Delta/10000.0,elapsed,String.Join(";",stack.Select(x=>Label(x,modules)))));
                }
                int rest=200-(int)(timer.ElapsedMilliseconds-iteration); if(rest>0) Thread.Sleep(rest);
            }
        } finally {
            SymCleanup(handle); foreach(var t in threads.Values) CloseHandle(t.Handle);
            File.WriteAllLines(Path.Combine(output,"stacks.csv"),lines);
            File.WriteAllLines(Path.Combine(output,"modules.tsv"),modules.Select(m=>m.Name+"\t"+m.Start+"\t"+m.End));
        }
        return "samples="+count+" total_suspend_ms="+total.ToString("F3")+" max_suspend_ms="+max.ToString("F3")+" wall_ms="+timer.ElapsedMilliseconds;
    }
}

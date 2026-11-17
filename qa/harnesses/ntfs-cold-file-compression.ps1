# File-only NTFS LZNT1 compression. One locked handle owns identity, hashing,
# compression and allocation measurements; directories and shared files reject.
if (-not ('Syndocal.Maintenance.ColdCompression' -as [type])) {
Add-Type -TypeDefinition @'
namespace Syndocal.Maintenance {
using System;
using System.IO;
using System.Text;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using Microsoft.Win32.SafeHandles;
public sealed class CompressionRecord {
 public string Path {get;set;} public string Status {get;set;}
 public uint Volume {get;set;} public ulong FileId {get;set;}
 public long WriteTime {get;set;} public long LogicalBytes {get;set;}
 public long AllocatedBefore {get;set;} public long AllocatedAfter {get;set;}
 public ushort FormatBefore {get;set;} public ushort FormatAfter {get;set;}
 public string Sha256 {get;set;}
 public string VerifiedSha256 {get;set;}
 public string Failure {get;set;}
 public long CreatedTime {get;set;}
}
public static class ColdCompression {
 [StructLayout(LayoutKind.Sequential)] struct FT {public uint Low,High;}
 [StructLayout(LayoutKind.Sequential)] struct Identity {
  public uint Attributes; public FT Created,Accessed,Written;
  public uint Volume,SizeHigh,SizeLow,Links,IndexHigh,IndexLow;
 }
 [StructLayout(LayoutKind.Sequential)] struct CompressionInfo {
  public long Size; public ushort Format; public byte Unit,Chunk,Cluster,R0,R1,R2;
 }
 [StructLayout(LayoutKind.Sequential)] struct StandardInfo {
  public long AllocationSize,EndOfFile;public uint Links;
  public byte DeletePending,Directory;
 }
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern IntPtr CreateFileW(string p,uint access,uint share,IntPtr sa,uint creation,uint flags,IntPtr template);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(IntPtr h,out Identity i);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandleEx(IntPtr h,int c,out CompressionInfo i,uint n);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandleEx(IntPtr h,int c,out StandardInfo i,uint n);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetFinalPathNameByHandleW(IntPtr h,StringBuilder b,uint n,uint flags);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool DeviceIoControl(IntPtr h,uint code,ref ushort value,uint n,IntPtr output,uint outSize,out uint returned,IntPtr overlap);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool FlushFileBuffers(IntPtr h);
 static void Check(bool ok) {if(!ok)throw new Win32Exception(Marshal.GetLastWin32Error());}
 static ulong Id(Identity i) {return ((ulong)i.IndexHigh<<32)|i.IndexLow;}
 static long Time(Identity i) {return ((long)i.Written.High<<32)|i.Written.Low;}
 static long Born(Identity i) {return ((long)i.Created.High<<32)|i.Created.Low;}
 static CompressionInfo Info(IntPtr h) {CompressionInfo i;Check(GetFileInformationByHandleEx(h,8,out i,16));return i;}
 static long Stored(IntPtr h,CompressionInfo c) {if(c.Format!=0)return c.Size;StandardInfo s;Check(GetFileInformationByHandleEx(h,1,out s,24));return s.AllocationSize;}
 static void Set(IntPtr h,ushort format) {uint returned;Check(DeviceIoControl(h,0x0009C040,ref format,2,IntPtr.Zero,0,out returned,IntPtr.Zero));Check(FlushFileBuffers(h));}
 static string Hash(FileStream stream) {stream.Position=0;using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","");}
 static string Verify(IntPtr h,FileStream stream,Identity before,long length,string sha,string full) {
  Identity final;Check(GetFileInformationByHandle(h,out final));
  string actual=Hash(stream);
  if(final.Volume!=before.Volume||Id(final)!=Id(before)||final.Links!=1||Time(final)!=Time(before)||Born(final)!=Born(before)||(((long)final.SizeHigh<<32)|final.SizeLow)!=length||actual!=sha||!String.Equals(Final(h),full,StringComparison.OrdinalIgnoreCase))throw new IOException("Identity, path, length, timestamp or SHA changed");
  return actual;
 }
 static string Final(IntPtr h) {
  var b=new StringBuilder(32768);uint n=GetFinalPathNameByHandleW(h,b,32768,0);
  if(n==0)throw new Win32Exception(Marshal.GetLastWin32Error());
  if(n>=32768)throw new IOException("Resolved path too long");
  string p=b.ToString();return p.StartsWith(@"\\?\UNC\")?@"\\"+p.Substring(8):p.StartsWith(@"\\?\")?p.Substring(4):p;
 }
 public static CompressionRecord Process(string path,bool apply,CompressionRecord expected) {
  if(apply&&expected==null)throw new ArgumentException("Apply requires reviewed plan proof");
  string full=System.IO.Path.GetFullPath(path);
  if(full.IndexOf(':',2)>=0)throw new IOException("Alternate data streams rejected");
  string native=full.StartsWith(@"\\")?@"\\?\UNC\"+full.Substring(2):@"\\?\"+full;
  // OPEN_REPARSE_POINT, SEQUENTIAL_SCAN; share READ only denies writers/rename.
  IntPtr h=CreateFileW(native,0xC0000000,1,IntPtr.Zero,3,0x08300000,IntPtr.Zero);
  if(h==new IntPtr(-1))throw new Win32Exception(Marshal.GetLastWin32Error());
  try {
   Identity before;Check(GetFileInformationByHandle(h,out before));
   const uint denied=0x10|0x200|0x400|0x1000|0x4000|0x40000|0x100000|0x400000;
   if((before.Attributes&denied)!=0||before.Links!=1)throw new IOException("Nonregular, sparse, offline, encrypted, recalled or shared file rejected");
   if(!String.Equals(Final(h),full,StringComparison.OrdinalIgnoreCase))throw new IOException("Resolved path differs");
   long length=((long)before.SizeHigh<<32)|before.SizeLow;
   if(length<65536||length>30L*1024*1024*1024)throw new IOException("File outside bounded compression size");
   using(var stream=new FileStream(new SafeFileHandle(h,false),FileAccess.Read,1048576,false)) {
    var first=Info(h);long storedBefore=Stored(h,first);string sha=Hash(stream);
    if(expected!=null&&(!String.Equals(expected.Path,full,StringComparison.OrdinalIgnoreCase)||expected.Volume!=before.Volume||expected.FileId!=Id(before)||expected.WriteTime!=Time(before)||expected.CreatedTime!=Born(before)||expected.LogicalBytes!=length||expected.Sha256!=sha))throw new IOException("File changed since reviewed plan");
    var record=new CompressionRecord {Path=full,Volume=before.Volume,FileId=Id(before),WriteTime=Time(before),CreatedTime=Born(before),LogicalBytes=length,AllocatedBefore=storedBefore,AllocatedAfter=storedBefore,FormatBefore=first.Format,FormatAfter=first.Format,Sha256=sha,Status="Planned"};
    if(!apply)return record;
    if(first.Format!=0){record.Status="AlreadyCompressed";record.VerifiedSha256=sha;return record;}
    try {
     Set(h,1);var after=Info(h);
     if(Stored(h,after)>=storedBefore){Set(h,0);after=Info(h);record.Status="NoGainReverted";}else{record.Status="Compressed";}
     record.VerifiedSha256=Verify(h,stream,before,length,sha,full);
     record.AllocatedAfter=Stored(h,after);record.FormatAfter=after.Format;
     return record;
    } catch(Exception original) {
     try {
      Set(h,first.Format);record.VerifiedSha256=Verify(h,stream,before,length,sha,full);
      var restored=Info(h);if(restored.Format!=first.Format)throw new IOException("Compression format rollback differs");
      record.AllocatedAfter=Stored(h,restored);record.FormatAfter=restored.Format;
      record.Status="FailedRolledBack";record.Failure=original.Message;return record;
     } catch(Exception rollback) {
      throw new IOException("Compression failed: "+original.Message+"; rollback/integrity check failed: "+rollback.Message,new AggregateException(original,rollback));
     }
    }
   }
  } finally {CloseHandle(h);}
 }
}
}
'@
}

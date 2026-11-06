param([Parameter(Mandatory = $true)][string]$ArchivePath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$nativeArchive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ArchivePath).Path)
$checkedLibraries = 0
try {
    foreach ($entry in $nativeArchive.Entries) {
        if ($entry.FullName -notmatch '^(base/)?lib/(arm64-v8a|x86_64)/.+\.so$') { continue }
        $entryStream = $entry.Open()
        $nativeMemory = [IO.MemoryStream]::new()
        try { $entryStream.CopyTo($nativeMemory); $nativeBytes = $nativeMemory.ToArray() }
        finally { $entryStream.Dispose(); $nativeMemory.Dispose() }
        if ($nativeBytes.Length -lt 64 -or $nativeBytes[0] -ne 127 -or
            [Text.Encoding]::ASCII.GetString($nativeBytes,1,3) -ne 'ELF' -or
            $nativeBytes[4] -ne 2 -or $nativeBytes[5] -ne 1) { throw "Not a supported ELF64 library: $($entry.FullName)" }
        $programOffset = [BitConverter]::ToUInt64($nativeBytes,32)
        $programSize = [BitConverter]::ToUInt16($nativeBytes,54)
        $programCount = [BitConverter]::ToUInt16($nativeBytes,56)
        if ($programSize -lt 56) { throw 'Invalid ELF program header size.' }
        $loadCount = 0
        for ($programIndex=0; $programIndex -lt $programCount; $programIndex++) {
            $headerOffset = [int]($programOffset + $programIndex * $programSize)
            if ($headerOffset -lt 0 -or $headerOffset + 56 -gt $nativeBytes.Length) { throw 'ELF header out of bounds.' }
            if ([BitConverter]::ToUInt32($nativeBytes,$headerOffset) -ne 1) { continue }
            $loadCount++
            $alignment = [BitConverter]::ToUInt64($nativeBytes,$headerOffset+48)
            $fileOffset = [BitConverter]::ToUInt64($nativeBytes,$headerOffset+8)
            $virtualAddress = [BitConverter]::ToUInt64($nativeBytes,$headerOffset+16)
            if ($alignment -lt 16384 -or $fileOffset % 16384 -ne $virtualAddress % 16384) {
                throw "64-bit library has incompatible 16 KB LOAD alignment: $($entry.FullName)"
            }
        }
        if (!$loadCount) { throw 'ELF has no LOAD segments.' }
        $checkedLibraries++
    }
    if (!$checkedLibraries) { throw 'No 64-bit native libraries inspected.' }
    [pscustomobject]@{ Archive=[IO.Path]::GetFileName($ArchivePath); Elf64Libraries=$checkedLibraries; LoadAlignment16K=$true }
} finally { $nativeArchive.Dispose() }

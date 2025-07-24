#Requires AutoHotkey v2.0

Sleep 3000  ; 3 secondes pour placer le curseur, avant le début de la frappe

delay := 100  ; Délai entre chaque caractère pour simuler la frappe

commands := [
    " diskpart",
    " select disk 0",
    " clean",
    " convert gpt",
    " create partition efi size=100",
    " format quick fs=fat32 label=`"System`"",
    " create partition msr size=16",
    " create partition primary size=1024",
    " format quick fs=ntfs label=`"Recovery`"",
    " set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac",
    " gpt attributes=0x8000000000000001",
    " create partition primary",
    " format quick fs=ntfs label=`"Windows`""
]

for command in commands {
    for char in StrSplit(command) {
        Send(char)
        Sleep(delay)
    }
    Send("{Enter}")
}

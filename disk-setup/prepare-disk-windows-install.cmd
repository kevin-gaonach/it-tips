rem === Utilitaire de gestion des disques ===
diskpart

rem === Nettoyage complet du disque ===
select disk 0
clean
convert gpt

rem === Partition EFI ===
create partition efi size=100
format quick fs=fat32 label="System"

rem === Partition MSR ===
create partition msr size=16

rem === Partition de recuperation ===
create partition primary size=1024
format quick fs=ntfs label="Recovery"
set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
gpt attributes=0x8000000000000001

rem === Partition principale Windows ===
create partition primary
format quick fs=ntfs label="Windows"
exit

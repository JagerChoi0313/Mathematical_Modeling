all : sack.obj sack.exe

sack.obj : sack.c
	cl -c sack.c

sack.exe : ..\..\lingd11.lib sack.obj
	cl sack.obj ..\..\lingd11.lib -Fesack.exe

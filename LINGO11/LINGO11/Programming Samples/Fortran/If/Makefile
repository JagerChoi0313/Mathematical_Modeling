all : simple.obj simple.exe

simple.obj : simple.for
	ifort /I..\..\ /define:OS_WIN /define:BIT_32 /c simple.for

simple.exe : ..\..\lingd11.lib simple.obj
	ifort simple.obj ..\..\lingd11.lib /FeSimple.exe


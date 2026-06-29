all : simple.obj simple.exe

simple.obj : simple.c
	cl -c simple.c

simple.exe : ..\..\lingd11.lib simple.obj
	cl simple.obj ..\..\lingd11.lib -Fesimple.exe

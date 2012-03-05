LIBS = class.lua
SRCS = conf.lua devices.lua main.lua
APPN = netwars.love

build: $(SRCS)
	zip $(APPN) $(LIBS) $(SRCS)

LIBS = class.lua
SRCS = conf.lua menu.lua devices.lua main.lua
APPN = netwars.love

build: $(SRCS)
	zip $(APPN) $(LIBS) $(SRCS)

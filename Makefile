LIBS = class.lua
SRCS = conf.lua main.lua menu.lua client.lua \
	devices.lua devices_gui.lua devices_net.lua
SRVS = netwars.lua devices.lua server.lua
APPN = netwars

build: $(SRCS)
	zip $(APPN).love $(LIBS) $(SRCS)

srvpkg: $(SRVS)
	tar -czf netwars.tgz $(LIBS) $(SRVS)

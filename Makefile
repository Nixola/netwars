LIBS = class.lua
SRCS = conf.lua main.lua menu.lua client.lua \
	devices.lua devices_gui.lua devices_net.lua
IMGS = imgs
SRVS = netwars.lua devices.lua server.lua
APPN = netwars

build: $(SRCS)
	zip -r $(APPN).love $(LIBS) $(SRCS) $(IMGS)

srvpkg: $(SRVS)
	tar -czf $(APPN).tgz $(LIBS) $(SRVS)

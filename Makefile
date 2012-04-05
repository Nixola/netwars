LIBS = class.lua sphash.lua
SRCS = conf.lua main.lua menu.lua client.lua chat.lua \
	devices.lua devices_gui.lua init.lua
IMGS = imgs
SRVS = netwars.lua devices.lua server.lua
APPN = netwars

build: $(SRCS)
	zip -r $(APPN).love $(LIBS) $(SRCS) LICENSE $(IMGS)

srvpkg: $(SRVS)
	tar -czf $(APPN).tgz $(LIBS) $(SRVS) LICENSE

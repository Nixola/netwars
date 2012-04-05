LIBS = class.lua sphash.lua
COMMON = devices.lua
EXTRA = LICENSE
SRCS = conf.lua main.lua menu.lua client.lua chat.lua init.lua \
	devices_gui.lua
IMGS = imgs
SRVS = netwars.lua server.lua
APPN = netwars

.PHONY: build srvpkg

build:
	zip -r $(APPN).love $(LIBS) $(COMMON) $(SRCS) $(EXTRA) $(IMGS)

srvpkg:
	tar -czf $(APPN).tgz $(LIBS) $(COMMON) $(SRVS) $(EXTRA)

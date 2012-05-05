LIBS = class.lua sphash.lua
COMMON = devices.lua
EXTRA = LICENSE
SRCS = conf.lua main.lua menu.lua client.lua chat.lua init.lua \
	devices_gui.lua
IMGS = imgs
EXCL = imgs/.gitattributes
SRVS = netwars.lua server.lua devices_srv.lua
APPN = netwars

.PHONY: build srvpkg clean

build:
	zip -r $(APPN).love $(LIBS) $(COMMON) $(SRCS) $(EXTRA) $(IMGS) -x $(EXCL)

srvpkg:
	tar -czf $(APPN).tgz $(LIBS) $(COMMON) $(SRVS) $(EXTRA)

clean:
	rm -f $(APPN).love $(APPN).tgz

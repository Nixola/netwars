LIBS = class.lua sphash.lua
COMMON = LICENSE devices.lua
SRCS = conf.lua readline.lua main.lua menu.lua console.lua chat.lua init.lua \
	client.lua devices_gui.lua
IMGS = imgs
EXCL = imgs/.gitattributes
SRVS = netwars.lua server.lua devices_srv.lua
APPN = netwars

.PHONY: build srvpkg clean

build:
	zip -r $(APPN).love $(LIBS) $(COMMON) $(SRCS) $(IMGS) -x $(EXCL)

srvpkg:
	tar -czf $(APPN).tgz $(LIBS) $(COMMON) $(SRVS)

clean:
	rm -f $(APPN).love $(APPN).tgz

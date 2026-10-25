SWIFT ?= swift

.PHONY: reproduce build kernel
reproduce: build kernel
	.build/debug/ThreadedCgroupRepro

build:
	$(SWIFT) build -Xswiftc -Xfrontend -Xswiftc -enable-cross-import-overlays
	codesign --force --sign - --entitlements repro.entitlements .build/debug/ThreadedCgroupRepro

kernel:
	$(MAKE) -C .build/checkouts/containerization fetch-default-kernel

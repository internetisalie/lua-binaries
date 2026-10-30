# Builds standalone PUC Lua `lua` and `luac` from checksummed lua.org tarballs.
#
#   make TARGET=linux-x86_64              all versions for one target
#   make TARGET=linux-x86_64 VERSION=5.4.8 build
#
# TARGET is <os>-<arch>: linux-x86_64, linux-arm64, windows-x86_64, macos-x86_64, macos-arm64.
# Outputs land in dist/$(TARGET)/ as lua<VV>-$(TARGET)[.exe] and luac<VV>-$(TARGET)[.exe].

VERSIONS := 5.1.5 5.2.4 5.3.6 5.4.8 5.5.0
VERSION  ?= 5.4.8
TARGET   ?= linux-x86_64

# lua.org's published digests, as pinned by Lunar's toolchain feed.
SHA256_5.1.5 := 2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333
SHA256_5.2.4 := b9e2e4aad6789b3b63a056d442f7b39f0ecfca3ae0f1fc0ae4e9614401b69f4b
SHA256_5.3.6 := fc5fd69bb8736323f026672b1b7235da613d7177e72558893a0bdcd320466d60
SHA256_5.4.8 := 4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae
SHA256_5.5.0 := 57ccc32bbbd005cab75bcc52444052535af691789dba2b9016d5c50640d68b3d

MIRRORS := https://www.lua.org/ftp https://webserver2.tecgraf.puc-rio.br/lua/mirror/ftp

# The compatibility defines lua.org's own src/Makefile sets for each release, so these
# binaries behave like a stock `make` of the same tarball.
UPSTREAM_CFLAGS_5.1.5 :=
UPSTREAM_CFLAGS_5.2.4 := -DLUA_COMPAT_ALL
UPSTREAM_CFLAGS_5.3.6 := -DLUA_COMPAT_5_2
UPSTREAM_CFLAGS_5.4.8 := -DLUA_COMPAT_5_3
UPSTREAM_CFLAGS_5.5.0 :=

# 5.2 ties its C99 features to LUA_USE_LINUX/LUA_USE_MACOSX rather than LUA_USE_POSIX.
POSIX_C99_CFLAGS_5.2.4 := -DLUA_USE_STRTODHEX -DLUA_USE_AFORMAT -DLUA_USE_LONGLONG

OS   := $(firstword $(subst -, ,$(TARGET)))
ARCH := $(lastword $(subst -, ,$(TARGET)))
VV   := $(subst .,,$(basename $(VERSION)))

ifeq ($(OS),linux)
  # musl, fully static. No LUA_USE_DLOPEN: a static binary cannot load C modules.
  CC_DEFAULT := musl-gcc
  OS_CFLAGS  := -DLUA_USE_POSIX $(POSIX_C99_CFLAGS_$(VERSION))
  OS_LDFLAGS := -static -s
  EXE :=
  STRIP := true
else ifeq ($(OS),windows)
  # MinGW-w64 cross build; luaconf.h selects LUA_USE_WINDOWS (LoadLibrary) from _WIN32.
  CC_DEFAULT := x86_64-w64-mingw32-gcc
  OS_CFLAGS  :=
  OS_LDFLAGS := -static -s
  EXE := .exe
  STRIP := true
else ifeq ($(OS),macos)
  # libSystem is always dynamic on macOS; everything else is linked in. dlopen is part of
  # libSystem, so C modules built with `-bundle -undefined dynamic_lookup` can load.
  MACOSX_DEPLOYMENT_TARGET ?= 11.0
  export MACOSX_DEPLOYMENT_TARGET
  MAC_ARCH   := $(if $(filter arm64,$(ARCH)),arm64,x86_64)
  MAC_FLAGS  := -arch $(MAC_ARCH) -mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET)
  CC_DEFAULT := clang
  OS_CFLAGS  := $(MAC_FLAGS) -DLUA_USE_POSIX -DLUA_USE_DLOPEN $(POSIX_C99_CFLAGS_$(VERSION))
  OS_LDFLAGS := $(MAC_FLAGS)
  EXE :=
  # -x keeps the global symbols that dynamically looked-up C modules bind to.
  STRIP := strip -x
else
  $(error unknown TARGET '$(TARGET)')
endif

ifeq ($(origin CC),default)
  CC := $(CC_DEFAULT)
endif

CFLAGS := -std=gnu99 -O2 -Wall $(UPSTREAM_CFLAGS_$(VERSION)) $(OS_CFLAGS) $(EXTRA_CFLAGS)
LDFLAGS := $(OS_LDFLAGS) $(EXTRA_LDFLAGS)
LIBS := -lm

DL     := build/dl
SRCDIR := build/src/lua-$(VERSION)
OBJDIR := build/obj/$(TARGET)/$(VERSION)
OUT    := dist/$(TARGET)
LUA    := $(OUT)/lua$(VV)-$(TARGET)$(EXE)
LUAC   := $(OUT)/luac$(VV)-$(TARGET)$(EXE)
SUMS   := $(OUT)/SHA256SUMS-$(TARGET).txt

SHA256SUM := $(shell command -v sha256sum >/dev/null 2>&1 && echo sha256sum || echo shasum -a 256)

.PHONY: all build sums flags clean
.DELETE_ON_ERROR:
.SECONDARY:

all:
	@for v in $(VERSIONS); do $(MAKE) --no-print-directory build VERSION=$$v || exit 1; done
	@$(MAKE) --no-print-directory sums

build: $(LUA) $(LUAC)

flags:
	@echo "TARGET=$(TARGET) VERSION=$(VERSION) CC=$(CC)"
	@echo "CFLAGS=$(CFLAGS)"
	@echo "LDFLAGS=$(LDFLAGS) $(LIBS)"

$(DL)/lua-%.tar.gz:
	@test -n "$(SHA256_$*)" || { echo "no pinned sha256 for Lua $*" >&2; exit 1; }
	@mkdir -p $(DL)
	@for m in $(MIRRORS); do curl -fsSL --retry 3 -o $@.part "$$m/lua-$*.tar.gz" && break; done
	echo "$(SHA256_$*)  $@.part" | $(SHA256SUM) -c -
	@mv $@.part $@

build/src/lua-%/.extracted: $(DL)/lua-%.tar.gz
	@mkdir -p build/src
	tar -xzf $< -C build/src
	@touch $@

# One recipe produces both binaries (no grouped targets: macOS ships GNU make 3.81).
$(LUAC): $(LUA)

$(LUA): $(SRCDIR)/.extracted
	@rm -rf $(OBJDIR) && mkdir -p $(OBJDIR) $(OUT)
	@echo "CC=$(CC) CFLAGS=$(CFLAGS)"
	@for f in $(SRCDIR)/src/*.c; do \
	  $(CC) $(CFLAGS) -c -o $(OBJDIR)/$$(basename $$f .c).o $$f || exit 1; \
	done
	$(CC) $(LDFLAGS) -o $(LUA) $$(ls $(OBJDIR)/*.o | grep -v '/luac\.o$$') $(LIBS)
	$(CC) $(LDFLAGS) -o $(LUAC) $$(ls $(OBJDIR)/*.o | grep -v '/lua\.o$$') $(LIBS)
	$(STRIP) $(LUA) $(LUAC)

sums:
	cd $(OUT) && $(SHA256SUM) lua*-$(TARGET)$(EXE) > $(notdir $(SUMS))
	@cat $(SUMS)

clean:
	rm -rf build dist

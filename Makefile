TEXT_PAGINATION := true
LIBDIR := lib
-include $(LIBDIR)/main.mk

$(LIBDIR)/main.mk:
ifneq (,$(shell grep "path *= *$(LIBDIR)" .gitmodules 2>/dev/null))
	git submodule sync
	git submodule update --init
else
ifneq (,$(wildcard $(ID_TEMPLATE_HOME)))
	ln -s "$(ID_TEMPLATE_HOME)" $(LIBDIR)
else
	git clone -q --depth 10 -b main \
	    https://github.com/martinthomson/i-d-template $(LIBDIR)
endif
endif

prep: lists.md sourcecode

lists.md: draft-ietf-core-comi.xml
	kramdown-rfc-extract-figures-tables -trfc $< >$@.new
	if cmp $@.new $@; then rm -v $@.new; else mv -v $@.new $@; fi

sourcecode: draft-ietf-core-comi.xml
	kramdown-rfc-extract-sourcecode -tfiles $<


yang: sourcecode
	pyang -p .:/Users/cabo/std/yang --sid-list --sid-update-file ietf-coreconf-2024-03-04.sid sourcecode/yang/ietf-coreconf-2026-03-02.yang

siddiff: ietf-coreconf-2024-03-04.sid ietf-coreconf@2026-03-02.sid
	diff $^


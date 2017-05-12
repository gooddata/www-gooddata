.PHONY: all clean tarball srpm rpm

PACKAGE_NAME = perl-WWW-Gooddata

VERSION = $(shell  grep -Po "(?<=our \\\$$VERSION \= ')[0-9]+(\.[0-9]+)*" lib/WWW/GoodData.pm)
RELEASE = 1
SDIR ?= $(CURDIR)
CHANGELOG = $(SDIR)/CHANGELOG

SRPM_NAME = $(PACKAGE_NAME)-$(VERSION)-$(RELEASE).src.rpm
RPM_NAME = $(PACKAGE_NAME)-$(VERSION)-$(RELEASE).x86_64.rpm

TAR_FILE = $(PACKAGE_NAME)-$(VERSION).tar
SPEC_FILE = $(PACKAGE_NAME).spec

DIST_FILES = $(shell git ls-files)

GITCHANGELOG = git log --no-merges --pretty="tformat:* %cd %an <%ae>%n- %s" | \
    sed 's/\([0-9]\) [0-9]*:[0-9]*:[0-9]* /\1 /'

$(CHANGELOG):
	if [ -e "$(CHANGELOG)" ]; then \
	    $(GITCHANGELOG) > "$@.tmp"; \
	    if !diff "$@" "$@.tmp"; then \
	        mv "$@.tmp" "$@"; \
	    fi; \
	else \
	    $(GITCHANGELOG) > "$@"; \
	fi

$(SPEC_FILE): $(DIST_FILES) $(CHANGELOG)
	cp www-gooddata.spec.in $@
	sed -i -e "s/%VERSION%/$(VERSION)/g" \
	       -e "s/%RELEASE%/$(RELEASE)/g" \
	       -e "s/%PACKAGE_NAME%/$(PACKAGE_NAME)/g" $@
	echo %changelog >> $@
	cat $(CHANGELOG) >> $@

$(TAR_FILE): $(DIST_FILES) $(SPEC_FILE)
	tar -cvf $@ $(DIST_FILES) $(SPEC_FILE)

tarball: $(TAR_FILE)

$(SRPM_NAME): $(TAR_FILE)
	mkdir -p $(SDIR)/rpmbuild/{SOURCES,SPEC,RPMS,SRPMS}
	rpmbuild --define "_topdir $(SDIR)/rpmbuild/" -ts $(TAR_FILE)
	cp -f $(SDIR)/rpmbuild/SRPMS/$(SRPM_NAME) $@

$(RPM_NAME): $(TAR_FILE)
	mkdir -p $(SDIR)/rpmbuild/{SOURCES,SPEC,RPMS,SRPMS}
	rpmbuild --define "_topdir $(SDIR)/rpmbuild/" -tb $(TAR_FILE)
	cp -f $(SDIR)/rpmbuild/RPMS/x86_64/$(RPM_NAME) $@

srpm: $(SRPM_NAME)

rpm: $(RPM_NAME)

all: tarball srpm rpm

clean:
	rm -Rf $(TAR_FILE)
	rm -Rf $(CHANGELOG)
	rm -Rf $(SPEC_FILE)
	rm -Rf *.rpm
	rm -Rf rpmbuild

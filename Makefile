#SCHEME48=/usr/local/bin/scheme48 -h 60000000
SCHEME48=scheme48 -h 60000000

SCHEME_FILES=bhl/first-pages.sch build-web-site.sch articles.sch journal-meta.sch \
    pdf-file-sizes.sch dois.sch
RESOURCE_FILES=seal150.png style.css robots.txt
TOC_FILE=compare/merged-toc.txt

# Where to put the derived files.
BUILD_DIR=build

all: $(BUILD_DIR)/103/toc.html $(RESOURCE_FILES)
	cp -p $(RESOURCE_FILES) $(BUILD_DIR)/
	find $(BUILD_DIR) -name "*~" -exec rm {} \;

# Create static web site files
$(BUILD_DIR)/103/toc.html: $(SCHEME_FILES) $(TOC_FILE) text/52/52-001.txt
	mkdir -p $(BUILD_DIR)
	(echo ,batch ;\
	 echo ,config ,load web/web-config.scm ;\
	 echo ,open define-record-types sorting c-system-function tables ;\
	 echo ,open extended-ports signals posix-files ;\
	 echo ,open html xml web-utils  ;\
	 echo ,load $(SCHEME_FILES) ;\
	 echo '(doit "$(TOC_FILE)" "$(BUILD_DIR)")' ) | $(SCHEME48)


#THERE=pluto.mumble.net
#THEREHOST=aarau.csail.mit.edu
#THEREDIR=/nfs/web/www/projects/psyche
THEREHOST=norbert.csail.mit.edu
THEREDIR=/raid/www/roots/psyche

toc: $(TOC_FILE)

$(TOC_FILE): compare/Makefile compare/compare.py compare/batch.py toc.txt
	$(MAKE) -C compare merged-toc.txt

bhl/first-pages.sch: bhl/first-pages.py
	python bhl/first-pages.py

THERE=$(THEREHOST):$(THEREDIR)

TARBALL=/tmp/psyche.tgz

tarball: $(TARBALL)

$(TARBALL): $(BUILD_DIR)/index.html
	(cd $(BUILD_DIR); tar czf $(TARBALL) .)

export: $(TARBALL)
	scp $(TARBALL) $(THEREHOST):$(TARBALL)
	ssh $(THEREHOST) "cd $(THEREDIR); tar -x -z -p -f $(TARBALL)"

# This is too slow.  Don't do it.
export_naively:
	scp -r $(BUILD_DIR)/* $(THERE)/

tags:
	etags -l scheme `find . -name "*.sc*"`

clean:
	rm -rf $(BUILD_DIR)/*

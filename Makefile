SCHEME48=/usr/local/bin/scheme48

SCHEME_FILES=build-web-site.sch articles.sch journal-meta.sch \
    pdf-file-sizes.sch dois.sch
RESOURCE_FILES=seal150.png style.css robots.txt
TOC_FILE=toc/processed-toc.txt

# Where to put the derived files.
BUILD_DIR=build

all: $(BUILD_DIR)/index.html $(RESOURCE_FILES)
	cp -p $(RESOURCE_FILES) $(BUILD_DIR)/
	find $(BUILD_DIR) -name "*~" -exec rm {} \;

# Create static web site files
$(BUILD_DIR)/index.html: $(SCHEME_FILES) $(TOC_FILE)
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

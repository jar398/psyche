all: merged-toc.txt

merged-toc.txt: compare.out

compare.out: clean-doi-metadata.csv ../toc.txt compare.py batch.py \
	     cec-pdf-list.csv bhl-start-pages.csv 
	python compare.py clean-doi-metadata.csv ../toc.txt >compare.out.new
	mv -f compare.out.new compare.out

clean-doi-metadata.csv: all-doi-metadata.csv clean_doi_metadata.py
	python clean_doi_metadata.py all-doi-metadata.csv

cec-pdf-list.csv: import_cec_pdf_list.py ../articles.sch
	python import_cec_pdf_list.py ../articles.sch >cec-pdf-list.csv

bhl-start-pages.csv: import_bhl_start_pages.py ../bhl/first-pages.sch
	python import_bhl_start_pages.py ../bhl/first-pages.sch >bhl-start-pages.csv.new
	mv bhl-start-pages.csv.new bhl-start-pages.csv

# Not used any more
toc.csv: ../toc.txt toc_to_csv.py
	python toc_to_csv.py ../toc.txt toc.csv


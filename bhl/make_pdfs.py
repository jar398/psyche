# Download a page images (jpeg): https://www.biodiversitylibrary.org/pageimage/11809641

# For lossless conversion to PDF, use img2pdf (needs python 3)

# This is lossy:
"""
gs \
 -sDEVICE=pdfwrite \
 -o foo.pdf \
  /usr/local/share/ghostscript/8.71/lib/viewjpeg.ps \
 -c \(my.jpg\) viewJPEG

Multipage: 
gs \
 -sDEVICE=pdfwrite \
 -o foo.pdf \
  /usr/local/share/ghostscript/9.02/lib/viewjpeg.ps \
 -c "(1st.jpg)  viewJPEG showpage \
     (2nd.jpg)  viewJPEG showpage \
     (3rd.jpg)  viewJPEG showpage \
     (last.jpg) viewJPEG showpage"

Give exiftool a try, it is available from the package libimage-exiftool-perl in the repositories.

As an example, If you have a pdf file called drawing.pdf and you want
to update its metadata, use the utility, exiftool, in this way:

exiftool -Title="This is the Title" -Author="Happy Man" -Subject="PDF Metadata" drawing.pdf

need to set public domain.

"""

import os, csv

print 'mkdir -p pageimage article'

with open('article-pages.csv', 'r') as infile:
    for (volume, first, last, title, pageids, guessed, missing) in csv.reader(infile):
        merged = 'article/%s-%s-%s.pdf' % (volume, first, last)
        print '[ ! -e %s ] && (' % merged
        ids = pageids.split(';')
        images = []
        for pageid in ids:
            image = 'pageimage/%s.jpeg' % pageid
            # The wget is really slow, but we don't want to overload BHL
            print 'sleep 1'
            print '[ ! -e %s ] && wget -O %s https://www.biodiversitylibrary.org/pageimage/%s' % \
                (image, image, pageid)
            images.append(image)
        # Combine the individual page PDFs into one article PDF
        view = '/usr/local/Cellar/ghostscript/9.21_2/share/ghostscript/9.21/lib/viewjpeg.ps'
        command = ' '.join(map((lambda image: '(%s) viewJPEG showpage' % image), images))
        print 'gs -sDEVICE=pdfwrite -o %s %s -c "%s"' % (merged, view, command)
        print ')'

#        print 'gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=%s %s' % \
#            (merged, ' '.join(images))

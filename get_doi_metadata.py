
import sys, requests

doi = sys.argv[1]

url = 'https://doi.org/' + doi

!!! WORK IN PROGRESS

requests.get(sys.argv[1], ...)

we want to get the effect of:

curl -LH "Accept: application/json" http://dx.doi.org/10.1155/1927/94318 | python ~/a/ot/repo/reference-taxonomy/util/jsonpp.py 

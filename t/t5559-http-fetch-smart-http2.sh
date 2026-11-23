#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t5559-http-fetch-smart-http2.sh
# (https://github.com/git/git/blob/v2.56.1/t/t5559-http-fetch-smart-http2.sh). GPL-2.0, see LICENSE.

HTTP_PROTO=HTTP/2
LIB_HTTPD_SSL=1
. ./t5551-http-fetch-smart.sh

= kronk

* https://github.com/yaksnrainbows/kronk

== DESCRIPTION:

Kronk runs diffs against data from live and cached http responses. 
Kronk was made possible by the sponsoring of AT&T Interactive.

== FEATURES/PROBLEMS:

* Parse and diff data from http response body and/or headers.

* Include or exclude particular data points.

* Supports json, rails-ish xml, and plist.

* Support for custom data parsers.

== FUTURE:

* Line numbered and custom diff output.

* Auto-queryer with optional param randomizing.

* Support for test suites.

* Support for proxies, ssl, and http auth.

== SYNOPSIS:

Check if your json response returns the same data as your xml variety:

  $ kronk http://host.com/path.json http://host.com/path.xml

Compare headers only but only content type and date:

  $ kronk http://host.com/path1 http://host.com/path2 -I Content-Type,Date

Compare body structure only:

  $ kronk http://host.com/path.json http://host.com/path.xml --struct

Call comparison with similar uri suffixes:

  $ kronk http://host.com/path.json http://host.com/path.xml --suff '?page=1'

Compare body and headers:

  $ kronk http://host.com/path.json http://host.com/path.xml -i

Compare body and content type header:

  $ kronk http://host.com/path.json http://host.com/path.xml -i Content-Type

Compare response with the previous call:

  $ kronk http://host.com/path --prev

Compare response with a local file:

  $ kronk http://host.com/path.json ./saved_response.json

Do a simple text diff on the http response, including headers:

  $ kronk http://host.com/A/path.json http://host.com/B/path.json --raw -i

Run it to display formatted data:

  $ kronk http://host.com/path.json

  $ kronk http://host.com/path.json -i

Run it to display raw data with headers:

  $ kronk http://host.com/path.json --raw -i
  
== REQUIREMENTS:

* FIX (list of requirements)

== INSTALL:

* sudo gem install kronk

== DEVELOPERS:

After checking out the source, run:

  $ rake newb

This task will install any missing dependencies, run the tests/specs,
and generate the RDoc.

== LICENSE:

(The MIT License)

Copyright (c) 2010 Jeremie Castagna

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

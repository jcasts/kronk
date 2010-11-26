= kronk

* https://github.com/yaksnrainbows/kronk

== DESCRIPTION:

Run diffs against data from http responses. 

== FEATURES/PROBLEMS:

* Parse and diff data from http response body and/or headers.

* Exclude particular data points.

* Auto-queryer with optional param randomizing.

* Supports json, basic xml, and plist.

* Support for custom data parsers.

* Support for test suites.

== SYNOPSIS:

Check if your json response returns the same data as your xml variety:

  $ kronk http://host.com/path.json http://host.com/path.xml

Compare headers only but exclude content type:

  $ kronk -I -Content-Type http://host.com/path.json http://host.com/path.xml

Compare both body and headers excluding content type:

  $ kronk -i -Content-Type http://host.com/path.json http://host.com/path.xml

Compare response with the previous call:

  $ kronk --prev http://host.com/path

Compare response with a local file:

  $ kronk http://host.com/path.json ./saved_response.json

Do a simple text diff on the http response, including headers:

  $ kronk --raw -i http://host.com/A/path.json http://host.com/B/path.json

Run it to display formatted data:

  $ kronk http://host.com/path.json

  $ kronk -i http://host.com/path.json

Run it to display raw data with headers:

  $ kronk --raw -i http://host.com/path.json
  
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

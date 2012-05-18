                                               /
                                            |
                                           /|
                     _______I_I_I_________/ |
               D====/ ____________________  |  - -
                    ||   __| | | |___  || \ |
                    \\__[_=|_[[|_|==_]_//  \|
                     \_________________/    |  \
                            = = =

	Satchmo.coffee
	(c) 2012 Reprovinci Internetdiensten bv
	Satchmo is freely distributable under the MIT license.
	Portions of Satchmo are inspired or borrowed from cmlenz's
	 jQuery Ajax transport plugin.

The [Satchmo](http://en.wikipedia.org/wiki/Louis_Armstrong) [jQuery](http://jquery.com/) plugin implements two methods
for the asynchronous submission of forms. The first is used when the browser supports the XMLHttpRequest 2 API or when
the form contains no file fields. The fallback transparently submits the form using a hidden `<iframe>`.

The [source for Satchmo](https://github.com/reprovinci/satchmo) is available on Github, and released under the MIT
license.

## Usage

To use this plugin, just submit your form using jQuery's `$.ajax()`:

	var xhr = $.ajax({ satchmo: $("#myform") });

You can listen for progress events by calling `xhr.progress(<callback>)`. Your callback will receive a
`XMLHttpRequestProgressEvent` which exposes the following properties:

	boolean lengthComputable
	   long loaded  # Bytes loaded until now
	   long total   # Total of bytes that will be sent

> **Nota bene:** `loaded` and `total` may only be used when `lengthComputable` is `true`.

## Response status and data type

As the iframe transport layer does not have access to the HTTP headers of the server response, it is not as simple to
make use of the automatic content type detection provided by jQuery as with regular XHR.  
Another problem with using an iframe for file uploads is that it is impossible for the javascript code to determine the
HTTP status code of the servers response. Effectively, all of the calls you make will look like they are getting
successful responses, and thus invoke the `done()` or `complete()` callbacks.
If you can't set the expected response data type (for example because it may vary), you will need to employ a workaround
on the server side.  
In case the iframe transport layer kicks in, an additional `Satchmo__wrap` variable is sent along with the request to
tell the server this is an emulated AJAX request. When this variable is present, you may choose to wrap your response
in an XML document. This document should conform to the following specification:

	<?xml version="1.0" encoding="UTF-8"?>
	<response status="404">
		<headers>
			<header name="Content-Type">application/json</header>
		</headers>
		<content>
			<![CDATA[{"ok": true, "message": "Thanks so much"}]]>
		</content>
	</response>

The `status` attribute is optional, as is the `<headers>` element.
#                                                /
#                                             |
#                                            /|
#                      _______I_I_I_________/ |
#                D====/ ____________________  |  - -
#                     ||   __| | | |___  || \ |
#                     \\__[_=|_[[|_|==_]_//  \|
#                      \_________________/    |  \
#                             = = =

# 	Satchmo.coffee
# 	(c) 2012 Reprovinci Internetdiensten bv
# 	Satchmo is freely distributable under the MIT license.
# 	Portions of Satchmo are inspired or borrowed from cmlenz's
# 	 jQuery Ajax transport plugin.

# The [Satchmo](http://en.wikipedia.org/wiki/Louis_Armstrong) [jQuery](http://jquery.com/) plugin implements two methods
# for the asynchronous submission of forms. The first is used when the browser supports the XMLHttpRequest 2 API or when
# the form contains no file fields. The fallback transparently submits the form using a hidden `<iframe>`.

# ## Source

# The [source for Satchmo](https://github.com/reprovinci/satchmo) is available on Github, and released under the MIT
# license.

# ## Usage

# To use this plugin, just submit your form using jQuery's `$.ajax()`:
#
# 	var xhr = $.ajax({ satchmo: $("#myform") });
#
# You can listen for progress events by calling `xhr.progress(<callback>)`. Your callback will receive a
# `XMLHttpRequestProgressEvent` which exposes the following properties:
#
# 	boolean lengthComputable
# 	   long loaded  # Bytes loaded until now
# 	   long total   # Total of bytes that will be sent
#
# > **Nota bene:** `loaded` and `total` may only be used when `lengthComputable` is `true`.

# ## Response status and data type

# As the iframe transport layer does not have access to the HTTP headers of the server response, it is not as simple to
# make use of the automatic content type detection provided by jQuery as with regular XHR.  
# Another problem with using an iframe for file uploads is that it is impossible for the javascript code to determine the
# HTTP status code of the servers response. Effectively, all of the calls you make will look like they are getting
# successful responses, and thus invoke the `done()` or `complete()` callbacks.
# If you can't set the expected response data type (for example because it may vary), you will need to employ a workaround
# on the server side.  
# In case the iframe transport layer kicks in, an additional `Satchmo__wrap` variable is sent along with the request to
# tell the server this is an emulated AJAX request. When this variable is present, you may choose to wrap your response
# in an HTML document. This document should conform to the following specification:

# 	HTTP/1.x 200 OK
# 	Content-Type: text/html; charset=<charset_here>
#
# 	<!DOCTYPE html>
# 	<body status="404">
# 		<ul>
# 			<li>Content-Type: application/json</li>
# 		</ul>
# 		<pre>{&quot;data&quot;:{&quot;42&quot;:&quot;So long ↵
# 			and thanks for all the fish!&quot;}}</pre>
# 	</body>

# The `status` attribute is optional, as is the `<ul>` element.

# ## Annotated source

"use strict"

# A comprehensive list of status codes for HTTP status code translation courtesy of Apache Commons.
HTTP_STATUS_TEXT =
	100: "Continue"
	101: "Switching Protocols"
	102: "Processing"
	200: "OK"
	201: "Created"
	202: "Accepted"
	203: "Non Authoritative Information"
	204: "No Content"
	205: "Reset Content"
	206: "Partial Content"
	207: "Multi-Status"
	300: "Mutliple Choices"
	301: "Moved Permanently"
	302: "Moved Temporarily"
	303: "See Other"
	304: "Not Modified"
	305: "Use Proxy"
	307: "Temporary Redirect"
	400: "Bad Request"
	401: "Unauthorized"
	402: "Payment Required"
	403: "Forbidden"
	404: "Not Found"
	405: "Method Not Allowed"
	406: "Not Acceptable"
	407: "Proxy Authentication Required"
	408: "Request Timeout"
	409: "Conflict"
	410: "Gone"
	411: "Length Required"
	412: "Precondition Failed"
	413: "Request Entity Too Large"
	414: "Request-URI Too Long"
	415: "Unsupported Media Type"
	416: "Requested Range Not Satisfiable"
	417: "Expectation Failed"
	419: "Insufficient Space on Resource"
	420: "Method Failure"
	422: "Unprocessable Entity"
	423: "Locked"
	424: "Failed Dependency"
	500: "Server Error"
	501: "Not Implemented"
	502: "Bad Gateway"
	503: "Service Unavailable"
	504: "Gateway Timeout"
	505: "HTTP Version Not Supported"
	507: "Insufficient Storage"

# Detect XMLHttpRequest 2 support. For *Satchmo*, this requires the presence of the FormData API.
xml2_support = !!window.FormData

# Defers execution for `ms` milliseconds. `ms` may be omitted:
# 
# 	defer     -> console.log "Deferred!"
# 	defer 100 -> console.log "Deferred for 100 milliseconds!"
defer = (ms, func) ->
	if typeof ms is "function"
		func = ms
		ms = 0
	setTimeout func, ms

# Creates a version of the function that can only be called one time.
once = (f) ->
	ran = no
	return ->
		return if ran
		ran = yes
		f.apply this, arguments

# ## The XMLHttpRequest 2 prefilter

# Register a pre-filter that checks whether the `satchmo` option is set, switching to the `satchmo` data type if the
# option contains a form.
$.ajaxPrefilter (options, original_options, xhr) ->
	$form = $(options.satchmo)

	return unless $form.is "form"

	# Unless the browser supports XMLHttpRequest 2 or the forms contains no file inputs, return the `satchmo` data type,
	# which in turn will trigger the `satchmo` data transport.
	return "satchmo" unless xml2_support || $form.has("input[type=file]").length == 0

	# Set `url` based on the form's `action` attribute.
	options.url = $form.prop("action") || ""

	# Get data from form, trying the XMLHttpRequest 2 API, falling back to basic serialisation.
	options.data =
		if FormData
			new FormData $form.get(0)
		else
			$form.serialize()

	# Set request method according to form's method, falling back to `GET`.
	options.type = $form.prop("method").toUpperCase() or "GET"

	# Setting `contentType` to false, preventing jQuery from setting a `Content-Type` header that is missing the
	# boundary string.
	options.contentType = false

	# Setting `processData` to false, preventing jQuery from modifying the data before passing it to
	# `XMLHttpRequest#send()`. `FormData` is not convertible to string.
	options.processData = false


	# Create a new deferred for `progress` events. 
	dfd = $.Deferred()
	xhr.progress = dfd.progress

	# Intercept `XMLHttpRequest` and pipe all `progress` upload events to our `dfd`.
	# > **Nota bene:** some browsers do not fire a progress event when the upload finishes (i.e. upload is at 100%).
	old_xhr = options.xhr
	options.xhr = ->
		xhr = old_xhr()

		if XMLHttpRequestUpload? && xhr.upload instanceof XMLHttpRequestUpload
			xhr.upload.addEventListener "progress", ( -> dfd.notify arguments... ), false

		return xhr
	return

# ## The iframe transport

# Register the iframe transport. It will only activate when the browser supports XMLHttpRequest 2 or no file
# inputs are present on the form.
$.ajaxTransport "satchmo", (options, orig_options, xhr) ->
	$form = $(options.satchmo)

	return unless $form.is "form"

	# Remove `iframe` from the data types list so that further processing is based on the content type returned by the
	# server, without attempting an (unsupported) conversion from `iframe` to the actual type.
	options.dataTypes = (dt for dt in options.dataTypes when dt isnt "satchmo")

	# Create a unique request id. It will be used to name the `<iframe>`, which the form will target.
	request_id = "satchmo-#{parseInt(Math.random()*100000)}"

	transport =
		# The `send` function is called by jQuery when the request should be sent.
		send: (headers, complete) ->

			# Create the iframe, setting its `name` to our request id.
			$iframe = $("<iframe src=\"javascript:false;\" name=\"#{request_id}\" style=\"display:none\"></iframe>")

			# Create a hidden form, which does not have our original form's events and let it target our new iframe.
			$new_form = $("<form enctype=\"multipart/form-data\"></form>").appendTo document.body
			$new_form.prop
				action: $form.prop "action"
				method: $form.prop "method"
				target: request_id

			# Also send the `Satchmo__wrap` parameter, which will signal the server an HTML response document may be
			# sent.
			$("<input type=\"hidden\" name=\"Satchmo__wrap\" value=\"1\">").appendTo $new_form

			# Temporarily move the original form elements into the new form
			$form.children().appendTo $new_form

			# The first load event gets fired after the iframe has been injected into the DOM, and is used to prepare
			# the actual submission.
			$iframe.on "load.satchmo", once ->
				# The second load event gets fired when the response to the form submission is received. The
				# implementation detects whether the actual payload is embedded in an HTML document, and prepares the
				# required conversions to be made in that case.
				$iframe.on "load.satchmo", once ->
					document  = @contentWindow?.document or @contentDocument?.document or @document
					$document = $(document)
					$root     = $document.find "body"

					# An HTML document has been retrieved with information about the request status.
					if $root.is "body"
						status = $root.attr "status" || 200
						statusText = $root.attr("status-text") || HTTP_STATUS_TEXT[status]
						content =
							text: $root.children("pre").text()
						headers = []
						for header in $root.children("ul").children("li")
							$header = $(header)
							headers.push $header.text()
						headers = headers.join "\r\n"

					# Complete the AJAX request successfully, as no information can be retrieved from the `<iframe>`'s
					# response.
					else
						root = document.documentElement || document.body

						status = 200
						statusText = "OK"
						content =
							html: root.innerHTML
							text: root.textContent || root.innerText

					# Complete our fake AJAX request and remove the iframe and new form from the DOM.
					complete status, statusText, content, headers || ""

					$iframe.remove();
					$new_form.remove();

				# Submit our new form, containing all form elements, and revert the form elements' positions.
				$new_form.submit()
				$new_form.children().appendTo $form

			$iframe.appendTo document.body

		# Stop listening to load events, tell the iframe we no longer need our resource and clean up.
		abort: ->
			$iframe.off "load.satchmo"
			$iframe.prop "src", "javascript:false;"

			$iframe.remove()
			$new_form.remove()
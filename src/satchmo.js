(function() {
  "use strict";
  var HTTP_STATUS_TEXT, defer, once, xml2_support;

  HTTP_STATUS_TEXT = {
    100: "Continue",
    101: "Switching Protocols",
    102: "Processing",
    200: "OK",
    201: "Created",
    202: "Accepted",
    203: "Non Authoritative Information",
    204: "No Content",
    205: "Reset Content",
    206: "Partial Content",
    207: "Multi-Status",
    300: "Mutliple Choices",
    301: "Moved Permanently",
    302: "Moved Temporarily",
    303: "See Other",
    304: "Not Modified",
    305: "Use Proxy",
    307: "Temporary Redirect",
    400: "Bad Request",
    401: "Unauthorized",
    402: "Payment Required",
    403: "Forbidden",
    404: "Not Found",
    405: "Method Not Allowed",
    406: "Not Acceptable",
    407: "Proxy Authentication Required",
    408: "Request Timeout",
    409: "Conflict",
    410: "Gone",
    411: "Length Required",
    412: "Precondition Failed",
    413: "Request Entity Too Large",
    414: "Request-URI Too Long",
    415: "Unsupported Media Type",
    416: "Requested Range Not Satisfiable",
    417: "Expectation Failed",
    419: "Insufficient Space on Resource",
    420: "Method Failure",
    422: "Unprocessable Entity",
    423: "Locked",
    424: "Failed Dependency",
    500: "Server Error",
    501: "Not Implemented",
    502: "Bad Gateway",
    503: "Service Unavailable",
    504: "Gateway Timeout",
    505: "HTTP Version Not Supported",
    507: "Insufficient Storage"
  };

  xml2_support = !!window.FormData;

  defer = function(ms, func) {
    if (typeof ms === "function") {
      func = ms;
      ms = 0;
    }
    return setTimeout(func, ms);
  };

  once = function(f) {
    var ran;
    ran = false;
    return function() {
      if (ran) return;
      ran = true;
      return f.apply(this, arguments);
    };
  };

  $.ajaxPrefilter(function(options, original_options, xhr) {
    var $form, dfd, old_xhr;
    $form = $(options.satchmo);
    if (!$form.is("form")) return;
    if (!(xml2_support || $form.has("input[type=file]").length === 0)) {
      return "satchmo";
    }
    options.url = $form.prop("action") || "";
    options.data = FormData ? new FormData($form.get(0)) : $form.serialize();
    options.type = $form.prop("method").toUpperCase() || "GET";
    options.contentType = false;
    options.processData = false;
    dfd = $.Deferred();
    xhr.progress = dfd.progress;
    old_xhr = options.xhr;
    options.xhr = function() {
      xhr = old_xhr();
      if ((typeof XMLHttpRequestUpload !== "undefined" && XMLHttpRequestUpload !== null) && xhr.upload instanceof XMLHttpRequestUpload) {
        xhr.upload.addEventListener("progress", (function() {
          return dfd.notify.apply(dfd, arguments);
        }), false);
      }
      return xhr;
    };
  });

  $.ajaxTransport("satchmo", function(options, orig_options, xhr) {
    var $form, dt, request_id, transport;
    $form = $(options.satchmo);
    if (!$form.is("form")) return;
    options.dataTypes = (function() {
      var _i, _len, _ref, _results;
      _ref = options.dataTypes;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dt = _ref[_i];
        if (dt !== "satchmo") _results.push(dt);
      }
      return _results;
    })();
    request_id = "satchmo-" + (parseInt(Math.random() * 100000));
    return transport = {
      send: function(headers, complete) {
        var $iframe, $new_form;
        $iframe = $("<iframe src=\"javascript:false;\" name=\"" + request_id + "\" style=\"display:none\"></iframe>");
        $new_form = $("<form enctype=\"multipart/form-data\"></form>").appendTo(document.body);
        $new_form.prop({
          action: $form.prop("action"),
          method: $form.prop("method"),
          target: request_id
        });
        $("<input type=\"hidden\" name=\"Satchmo__wrap\" value=\"1\">").appendTo($new_form);
        $form.children().appendTo($new_form);
        $iframe.on("load.satchmo", once(function() {
          $iframe.on("load.satchmo", once(function() {
            var $document, $header, $root, content, document, header, root, status, statusText, _i, _len, _ref, _ref2, _ref3;
            document = ((_ref = this.contentWindow) != null ? _ref.document : void 0) || ((_ref2 = this.contentDocument) != null ? _ref2.document : void 0) || this.document;
            $document = $(document);
            $root = $document.find("body");
            if ($root.is("body")) {
              status = $root.attr("status" || 200);
              statusText = $root.attr("status-text") || HTTP_STATUS_TEXT[status];
              content = {
                text: $root.children("pre").text()
              };
              headers = [];
              _ref3 = $root.children("ul").children("li");
              for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
                header = _ref3[_i];
                $header = $(header);
                headers.push($header.text());
              }
              headers = headers.join("\r\n");
            } else {
              root = document.documentElement || document.body;
              status = 200;
              statusText = "OK";
              content = {
                html: root.innerHTML,
                text: root.textContent || root.innerText
              };
            }
            complete(status, statusText, content, headers || "");
            $iframe.remove();
            return $new_form.remove();
          }));
          $new_form.submit();
          return $new_form.children().appendTo($form);
        }));
        return $iframe.appendTo(document.body);
      },
      abort: function() {
        $iframe.off("load.satchmo");
        $iframe.prop("src", "javascript:false;");
        $iframe.remove();
        return $new_form.remove();
      }
    };
  });

}).call(this);

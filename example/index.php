<?

// Handles our upload. Please don't handle it like this in your controllers :)
if($_SERVER["REQUEST_METHOD"] === "POST") {
	$content_type = "application/json";
	$data = json_encode(array(
		"data" => array(
			42 => "So long and thanks for all the fish!",
		)
	));
	if(isset($_POST["Satchmo__wrap"])) {
		header("Content-Type: text/xml");
		print(
			"<?xml version=\"1.0\" encoding=\"UTF-8\"?>
			<response>
				<headers>
					<header name=\"Content-Type\">$content_type</header>
					<header name=\"X-Singer\">Louis Armstrong</header>
				</headers>
				<content>
					<![CDATA[$data]]>
				</content>
			</response>"
		);
	} else {
		header("Content-Type: $content_type");
		header("X-Singer: Louis Armstrong");
		print($data);
	}
	exit();
}

?>
<!DOCTYPE html>
<html>
<body>
	<form action="" method="post">
		<input type="file" name="file">
		<button type="submit">Upload!</button>
	</form>

	<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js"></script>
	<script src="../src/satchmo.js"></script>
	<script>
		!function() {
			// Provide fallback `Console.log` if necessary.
			var console = window["console"] || {
				log: function() {}
			};

			// Override default form submission functionality.
			$("form").submit(function(e) {
				// Submit form using Satchmo
				var xhr = $.ajax({ satchmo: this });

				// Watch progress and report failure or success.
				xhr.progress(function(e) {
					var percent = parseInt(e.loaded/e.total*100);
					console.log("Upload at ", percent, "%");
				});
				xhr.fail(function(jqXHR, textStatus, errorThrown) {
					console.log("Upload failed:", jqXHR, textStatus, errorThrown);
				});
				xhr.done(function(data, textStatus, jqXHR) {
					console.log("Upload success:", data, textStatus, jqXHR);
				});

				// Prevent default submit.
				e.preventDefault();
				return false;
			});
		}();
	</script>
</body>
</html>
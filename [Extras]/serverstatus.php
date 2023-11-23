<?php
	// error_reporting(E_ALL);
	// ini_set("display_errors", 1);

	require __DIR__ . "/SourceQuery/bootstrap.php";
	require __DIR__ . "/steamid.php";

	use xPaw\SourceQuery\SourceQuery;

	define("SQ_SERVER_ADDR", "74.91.127.130");
	define("SQ_SERVER_PORT", 27015);
	define("SQ_TIMEOUT", 1);
	define("SQ_ENGINE", SourceQuery::SOURCE);

	$query = new SourceQuery();

	try {
		$query->Connect(SQ_SERVER_ADDR, SQ_SERVER_PORT, SQ_TIMEOUT, SQ_ENGINE);

		$info = $query->GetInfo();
		$players = $query->GetPlayers();
		$rules = $query->GetRules();

		if (isset($_GET["info"])) {
			Header("Content-Type: text/plain");

			print_r($info);
			print_r($players);
			print_r($rules);

			return;
		}
	} catch(Exception $e) {
		echo $e->getMessage();
	} finally {
		$query->Disconnect();
	}
?>

<!DOCTYPE html>
<html>
	<head>
		<title><?php echo $info["HostName"]?></title>
		<meta charset="utf-8">

		<style>
			.banner {
				margin: 0px !important;
				padding: 0px !important;
				margin-bottom: 20px !important;
			}
			html{
				color:black;
			}
			.c {
				text-align: center !important;
			}
			.dc {
				margin: 0 auto;
			}

			.i-container {
				height: 480px;
			}
			.i-container .img-responsive {
				display: block;
				height: auto;
				max-height : 100%;
			}
			.fullscreen-bg {
    			position: fixed;
    			top: 0;
    			right: 0;
    			bottom: 0;
   			    left: 0;
    			overflow: hidden;
    			z-index: -100;
			}
		</style>

		<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css">
		<link rel="shortcut icon" href="http://czarchasm.club/img/bhop.ico" />
		<script src="https://code.jquery.com/jquery-3.2.1.min.js" integrity="sha256-hwg4gsxgFZhOsEEamdOYGBf13FyQuiTwlAQgxVSNgt4=" crossorigin="anonymous"></script>
		<script src="jquery.query-object.js"></script>
	</head>
	<body>
				<h1 class="banner"><!--?php echo $info["HostName"]?--><img src="img/megabanner.png" alt="banner"></h1>
				<div class="c">
					<a href="steam://connect/<?php echo SQ_SERVER_ADDR . ":" . SQ_SERVER_PORT; ?>" class="btn btn-large btn-success">Join Server</a>
					<a href="http://czarchasm.club/resources.html" class="btn btn-large btn-info">Resources/Rules</a>
					<a href="http://czarchasm.club/fastdl/" class="btn btn-large btn-warning">FastDL</a>				
				</div>
				<div class="fullscreen-bg"><img src="img/bg.png"></div>
		<h2 class="c">On <?php echo $info["Map"]?></h2>

		<?php
			if (is_file("../map_images/" . $info["Map"] . ".jpg")) {
				echo "<div class='i-container'>";
				echo "<img class='img-responsive img-thumbnail center-block' src='";
				echo "http://rutas.world/map_images/";
				echo $info["Map"];
				echo ".jpg' alt ='";
				echo $info["Map"];
				echo "'></div>";
			}
		?>
		
		<h4 class="c"><?php echo $info["Players"] . "/" .$info["MaxPlayers"]?> players</h4>
		<table class="dc">
			<tr>
				<th>Player</th>
			</tr>
			<?php
				//$pdat = json_decode(file_get_contents("http://rutas.world/info/server_steamids.php?server=bhop", FILE_USE_INCLUDE_PATH), true);

				foreach ($players as $key => $value) {
					//if (!isset($pdat[$value["Name"]])) {
					//	continue;
					//}
					//$s3 = $pdat[$value["Name"]];

					/*if ($s3 != "None") {
						$s = new SteamID($s3);
						$s64 = $s->ConvertToUInt64() . PHP_EOL;

						echo "<tr>
							<td><a href='http://rutas.world/info/getplayerinfo.php?simple&sql&profile=" . $s64 . "'>" . $value["Name"] . "</a></td></tr>";
					} else {*/
						echo "<tr><td>" . $value["Name"] . "</td></tr>";
					//}
				}
			?>
		</table>

		<div class="checkbox text-center">
			<label>
				<input type="checkbox" value="" id="refresher">Auto-refresh
			</label>
		</div>

		<script>
			window.setInterval(function() {
				if ($("#refresher").is(":checked")) {
					window.location.search = $.query.set("refresh", 1);
				}
			}, 5000)

			if ($.query.get("refresh") == 1) {
				$("#refresher").prop("checked", true);
			}
		</script>
	</body>
</html>
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import thx.semver.Version;

using StringTools;

class ArpPublish {

	static final haxelibs = ["ArpDomain", "ArpEngine", "ArpSupport", "ArpHitTest", "ArpThirdparty"];

	static var args:Array<String>;
	static var version:Version;
	static var releaseNote:String;
	static var haxelibPassword:String;

	static function main() {
		args = Sys.args();
		switch (args.shift()) {
			case "publish":
				publishMain();
			case "version":
			case _:
				versionMain();
		}
	}

	static function die(message:String) {
		Sys.stderr().writeString(message);
		Sys.stderr().writeString("\n");
		Sys.exit(1);
	}

	static function readDefaults() {
		var haxelibPath = '../ArpDomain/haxelib.json';
		var haxelibDef:HaxelibDef = Json.parse(File.getContent(haxelibPath));
		version = haxelibDef.version;
		releaseNote = haxelibDef.releasenote;

		haxelibPassword = Sys.getEnv("HAXELIB_PASSWORD");
	}

	static function versionArg() {
		Sys.stdout().writeString('Previous version number: $version\nVersion number: ');
		var value = Sys.stdin().readLine();
		switch (value.trim()) {
			case "":
			case "M", "major":
				version = version.nextMajor();
			case "m", "minor":
				version = version.nextMinor();
			case "p", "patch":
				version = version.nextPatch();
			case _:
				if (!~/^\d+\.\d+\.\d+$/.match(value)) {
					die('Invalid version number ${value.trim()}');
				}
				version = value;
		};
		Sys.stdout().writeString('$version\n');
	}

	static function releaseNoteArg() {
		Sys.stdout().writeString('Previous release note: \n---\n$releaseNote\n---\nRelease note: ');
		var value = Sys.stdin().readLine();
		if (value.trim() == "") {
			Sys.stdout().writeString('$releaseNote\n');
			return;
		};
		if (~/"/.match(value)) {
			die('Unsupported release note ${value.trim()}');
		}
		releaseNote = value;
	}

	static function versionMain() {
		readDefaults();
		versionArg();
		releaseNoteArg();

		for (haxelib in haxelibs) {
			Sys.stdout().writeString(haxelib + "\n");
			var haxelibPath = '../$haxelib/haxelib.json';
			var content = File.getContent(haxelibPath);
			if (version != null) {
				var oldVersion = ~/"version"\s*:\s*"[^"]+?"/;
				var newVersion = '"version": "$version"';
				content = oldVersion.replace(content, newVersion);
			}
			if (releaseNote.trim() != "") {
				var oldReleaseNote = ~/"releasenote"\s*:\s*"[^"]*?"/;
				var newReleaseNote = '"releasenote": "$releaseNote"';
				content = oldReleaseNote.replace(content, newReleaseNote);
			}
			File.saveContent(haxelibPath, content);
		}
	}

	static function updateDeps(version:String) {
		for (haxelib in haxelibs) {
			var haxelibPath = '../$haxelib/haxelib.json';
			var content = File.getContent(haxelibPath);
			var oldVersion = ~/"(arp_[a-z]+)"\s*:\s*"[^"]+?"/g;
			var newVersion = '"$1": "$version"';
			content = oldVersion.replace(content, newVersion);
			File.saveContent(haxelibPath, content);
		}
	}

	static function publishMain() {
		readDefaults();

		updateDeps(version);
		for (haxelib in haxelibs) {
			var wd = Sys.getCwd();
			Sys.setCwd(FileSystem.fullPath('../$haxelib'));
			var haxelibDef:HaxelibDef = Json.parse(File.getContent("haxelib.json"));
			var haxelibName = haxelibDef.name;
			var haxelibZip = '$haxelibName.zip';
			Sys.command('rm -f $haxelibZip');
			Sys.command("haxe haxelib.hxml");
			Sys.stdout().writeString('publish $haxelib as $haxelibName\n');
			var command = 'haxelib submit $haxelibZip $haxelibPassword --always';
			if (haxelibPassword == null) {
				Sys.stdout().writeString('# $command\n');
			} else {
				Sys.command(command);
			}

			Sys.setCwd(wd);
		}
		updateDeps("dev");

		if (haxelibPassword == null) die('please set HAXELIB_PASSWORD');
	}
}

typedef HaxelibDef = {
	var name:String;
	var version:String;
	var releasenote:String;
	// don't care other things
}


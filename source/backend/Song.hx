package backend;

import haxe.Json;
import lime.utils.Assets;

import backend.Section;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	@:optional var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	@:optional var format:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var offset:Float = 0;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';

	public static var chartPath:String;
	public static var loadedSongName:String;

	public static function convert(songJson:Dynamic) // Convert charts for PE073 compatibility
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		// PE104 compatibility: Ensure sectionBeats and format conversion
		var sectionsData:Array<SwagSection> = songJson.notes;
		if(sectionsData == null) return;

		// Check if this is PE104 format (psych_v1 or psych_v1_convert)
		var fmt:String = songJson.format;
		if(fmt == null) fmt = 'unknown';
		
		trace('Chart format: $fmt - checking if PE104 reverse conversion needed');
		
		// Only reverse convert if format starts with 'psych_v1' (PE104 format)
		var isPE104:Bool = fmt.startsWith('psych_v1');
		
		for (section in sectionsData)
		{
			var beats:Null<Float> = cast section.sectionBeats;
			if (beats == null || Math.isNaN(beats))
			{
				section.sectionBeats = 4;
				if(Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');
			}

			if (isPE104)
			{
				// Reverse conversion: PE104 absolute positions (0-7) -> PE073 relative positions (0-3)
				for (note in section.sectionNotes)
				{
					var noteData:Int = note[1];
					if (noteData >= 0 && noteData < 8) // Normal notes only (0-7)
					{
						var lane:Int = noteData % 4; // 0-3 lane
						// PE104: 0-3 = player lane, 4-7 = opponent lane (absolute)
						var isPlayerLane:Bool = (noteData < 4);
						
						if (section.mustHitSection)
						{
							// PE073 player section: 0-3 = player notes, 4-7 = opponent notes
							if (isPlayerLane)
								note[1] = lane; // 0-3 (player)
							else
								note[1] = lane + 4; // 4-7 (opponent)
						}
						else
						{
							// PE073 opponent section: 0-3 = opponent notes, 4-7 = player notes
							if (isPlayerLane)
								note[1] = lane + 4; // 4-7 (player, because it's opponent section)
							else
								note[1] = lane; // 0-3 (opponent)
						}
					}
				}
			}
		}
	}

	private static function onLoadJson(songJson:Dynamic) // Backward compatibility
	{
		convert(songJson);
	}

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		loadedSongName = folder;
		var songJson:SwagSong = getChart(jsonInput, folder);
		if(songJson != null)
		{
			chartPath = _lastPath;
			#if windows
			// Prevent any saving errors by fixing the path on Windows
			chartPath = chartPath.replace('/', '\\');
			#end
			if(jsonInput != 'events') StageData.loadDirectory(songJson);
		}
		return songJson;
	}

	static var _lastPath:String;
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var rawJson = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		_lastPath = Paths.json(formattedFolder + '/' + formattedSong);
		
		#if MODS_ALLOWED
		var moddyFile:String = Paths.modsJson(formattedFolder + '/' + formattedSong);
		if(FileSystem.exists(moddyFile)) {
			rawJson = File.getContent(moddyFile).trim();
			_lastPath = moddyFile;
		}
		#end

		if(rawJson == null) {
			var path:String = Paths.json(formattedFolder + '/' + formattedSong);

			#if sys
			if(FileSystem.exists(path)) {
				rawJson = File.getContent(path).trim();
				_lastPath = path;
			}
			else
			#end
				rawJson = Assets.getText(Paths.json(formattedFolder + '/' + formattedSong)).trim();
		}

		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}

		return parseJSON(rawJson, jsonInput);
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		return parseJSON(rawJson);
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);
		
		// Handle both {song: {...}} and direct {...} formats
		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		// Always convert to ensure compatibility
		convert(songJson);
		
		return songJson;
	}
}

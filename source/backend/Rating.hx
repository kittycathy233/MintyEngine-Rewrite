package backend;

import backend.ClientPrefs;
import backend.Paths;
#if MODS_ALLOWED
import backend.Mods;
import sys.FileSystem;
#end

class Rating
{
	public var name:String = '';
	public var image:String = '';
	public var hitWindow:Null<Int> = 0; //ms
	public var ratingMod:Float = 1;
	public var score:Int = 350;
	public var noteSplash:Bool = true;
	public var hits:Int = 0;

	public function new(name:String)
	{
		this.name = name;
		this.image = name;
		this.hitWindow = 0;

		var window:String = name + 'Window';
		try
		{
			this.hitWindow = Reflect.field(ClientPrefs.data, window);
		}
		catch(e) FlxG.log.error(e);
	}

	public static function loadDefault():Array<Rating>
	{
		var ratingsData:Array<Rating> = [];
		
		if (!ClientPrefs.data.removePerfects) 
			ratingsData.push(new Rating('perfect'));

		ratingsData.push(new Rating('sick')); //highest rating goes first

		var rating:Rating = new Rating('good');
		rating.ratingMod = 0.67;
		rating.score = 200;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.ratingMod = 0.34;
		rating.score = 100;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.ratingMod = 0;
		rating.score = 50;
		rating.noteSplash = false;
		ratingsData.push(rating);
		return ratingsData;
	}

	public static function getRatingImage(ratingName:String, uiPrefix:String = "", uiSuffix:String = ""):String
	{
		var imagePath:String = uiPrefix + ratingName + uiSuffix;
		
		if (ratingName == 'perfect' && ClientPrefs.data.useSickForMissingPerfect)
		{
			if (!modImageExists(imagePath))
			{
				return uiPrefix + 'sick' + uiSuffix;
			}
		}
		
		return imagePath;
	}

	#if MODS_ALLOWED
	private static function modImageExists(imageKey:String):Bool
	{
		var imagePath:String = 'images/$imageKey.png';
		
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var modPath:String = Paths.mods(Mods.currentModDirectory + '/' + imagePath);
			if (FileSystem.exists(modPath))
				return true;
		}

		for (mod in Mods.getGlobalMods())
		{
			var modPath:String = Paths.mods(mod + '/' + imagePath);
			if (FileSystem.exists(modPath))
				return true;
		}

		var mainModPath:String = Paths.mods(imagePath);
		if (FileSystem.exists(mainModPath))
			return true;

		return false;
	}
	#else
	private static function modImageExists(imageKey:String):Bool
	{
		return Paths.fileExists('images/$imageKey.png', IMAGE);
	}
	#end
}

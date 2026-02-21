package backend;

import backend.Song;
import backend.Section;
import objects.Note;

class PrecisionConductor
{
	public static var bpm(default, set):Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float = 0;
	public static var offset:Float = 0;
	public static var safeZoneOffset:Float = 0;

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	private static var highPrecisionTime:Float = 0;
	private static var lastUpdateTime:Float = 0;
	private static var isInitialized:Bool = false;
	private static var isPaused:Bool = false;

	public static function initialize():Void
	{
		if (!isInitialized)
		{
			highPrecisionTime = 0;
			lastUpdateTime = haxe.Timer.stamp();
			isInitialized = true;
			isPaused = false;
		}
	}

	public static function pause():Void
	{
		if (!isPaused)
		{
			isPaused = true;
		}
	}

	public static function resume():Void
	{
		if (isPaused)
		{
			isPaused = false;
			lastUpdateTime = haxe.Timer.stamp();
		}
	}

	public static function update(playbackRate:Float = 1):Void
	{
		if (!isInitialized) initialize();

		if (!isPaused)
		{
			var currentTime:Float = haxe.Timer.stamp();
			var deltaTime:Float = currentTime - lastUpdateTime;
			highPrecisionTime += deltaTime * 1000 * playbackRate;
			lastUpdateTime = currentTime;
		}

		songPosition = highPrecisionTime;
	}

	public static function setSongTime(time:Float):Void
	{
		if (!isInitialized) initialize();

		highPrecisionTime = time;
		songPosition = time;
		lastUpdateTime = haxe.Timer.stamp();
	}

	public static function reset():Void
	{
		highPrecisionTime = 0;
		songPosition = 0;
		lastUpdateTime = haxe.Timer.stamp();
		isPaused = false;
		isInitialized = true;
	}

	public static function judgeNote(arr:Array<Rating>, diff:Float=0):Rating
	{
		var data:Array<Rating> = arr;
		var diffAbs:Float = Math.abs(diff);
		for(i in 0...data.length-1)
			if (diffAbs <= data[i].hitWindow)
				return data[i];

		return data[data.length - 1];
	}

	public static function getCrotchetAtTime(time:Float)
	{
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepCrochet*4;
	}

	public static function getBPMFromSeconds(time:Float)
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		};
		for (i in 0...bpmChangeMap.length)
		{
			if (time >= bpmChangeMap[i].songTime)
				lastChange = bpmChangeMap[i];
		}

		return lastChange;
	}

	public static function getBPMFromStep(step:Float)
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		};
		for (i in 0...bpmChangeMap.length)
		{
			if (bpmChangeMap[i].stepTime<=step)
				lastChange = bpmChangeMap[i];
		}

		return lastChange;
	}

	public static function beatToSeconds(beat:Float): Float
	{
		var step = beat * 4;
		var lastChange = getBPMFromStep(step);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm / 60)/4) * 1000;
	}

	public static function getStep(time:Float)
	{
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getStepRounded(time:Float)
	{
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + Math.floor(time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getBeat(time:Float)
	{
		return getStep(time)/4;
	}

	public static function getBeatRounded(time:Float):Int
	{
		return Math.floor(getStepRounded(time)/4);
	}

	public static function mapBPMChanges(song:SwagSong)
	{
		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			if(song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
			{
				curBPM = song.notes[i].bpm;
				var event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					stepCrochet: calculateCrochet(curBPM)/4
				};
				bpmChangeMap.push(event);
			}

			var deltaSteps:Int = Math.round(getSectionBeats(song, i) * 4);
			totalSteps += deltaSteps;
			totalPos += ((60 / curBPM) * 1000 / 4) * deltaSteps;
		}
	}

	static function getSectionBeats(song:SwagSong, section:Int)
	{
		var val:Null<Float> = null;
		if(song.notes[section] != null) val = song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}

	inline public static function calculateCrochet(bpm:Float)
	{
		return (60/bpm)*1000;
	}

	public static function set_bpm(newBPM:Float):Float
	{
		bpm = newBPM;
		crochet = calculateCrochet(bpm);
		stepCrochet = crochet / 4;

		return bpm;
	}
}

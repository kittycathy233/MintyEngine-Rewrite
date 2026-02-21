package substates;

import states.StoryMenuState;
import states.FreeplayState;
import states.PlayState;
import backend.Mods;
import backend.Rating;
import backend.ClientPrefs;
import backend.Difficulty;
import backend.HitGraph;
import openfl.geom.Matrix;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.text.TextFieldAutoSize;
import flixel.system.FlxSound;
import flixel.util.FlxAxes;
import flixel.FlxSubState;
import flixel.input.FlxInput;
import flixel.input.keyboard.FlxKey;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;

using StringTools;

class ResultsScreen extends FlxSubState
{
	public var overlaySprite:Sprite;

	public var background:FlxSprite;
	public var text:TextField;

	public var graph:HitGraph;

	public var comboText:TextField;
	public var contText:TextField;
	public var settingsText:TextField;

	public var music:FlxSound;

	public var graphData:BitmapData;

	public var ranking:String;
	public var accuracy:String;

	override function create()
	{
		overlaySprite = new Sprite();

		background = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		background.alpha = 0;
		background.scrollFactor.set();
		add(background);

		if (FlxG.stage != null)
		{
			FlxG.stage.addChild(overlaySprite);
		}

		var stageWidth:Float = FlxG.stage.stageWidth;
		var stageHeight:Float = FlxG.stage.stageHeight;

		var scaleX:Float = stageWidth / 1280;
		var scaleY:Float = stageHeight / 720;
		var scale:Float = Math.min(scaleX, scaleY);

		graph = new HitGraph(Math.floor(stageWidth - 560 * scale), Math.floor(20 * scale), Math.floor(500 * scale), Math.floor(250 * scale));
		graph.alpha = 0;
		overlaySprite.addChild(graph);

		music = new FlxSound().loadEmbedded(Paths.music('breakfast'), true, true);
		music.volume = 0;
		music.play(false, FlxG.random.int(0, Std.int(music.length / 2)));
		FlxG.sound.list.add(music);

		var perfects = 0;
		var sicks = 0;
		var goods = 0;
		var bads = 0;
		var shits = 0;
		for (r in PlayState.instance.ratingsData)
		{
			switch (r.name)
			{
				case "perfect":
					perfects = r.hits;
				case "sick":
					sicks = r.hits;
				case "good":
					goods = r.hits;
				case "bad":
					bads = r.hits;
				case "shit":
					shits = r.hits;
			}
		}

		text = createTextField(Math.floor(20 * scale), Math.floor(-80 * scale), Math.floor(stageWidth - 300 * scale), FlxColor.WHITE, Math.floor(42 * scale));
		text.text = "Song Cleared!";
		overlaySprite.addChild(text);

		var score = PlayState.instance.songScore;
		if (PlayState.isStoryMode)
		{
			score = PlayState.campaignScore;
			text.text = "Week Cleared!";
		}

		var comboStr = 'Judgements:\n'
			+ (!ClientPrefs.data.removePerfects ? 'Perfects - ${perfects}\n' : "")
			+ 'Sicks - ${sicks}\n'
			+ 'Goods - ${goods}\n'
			+ 'Bads - ${bads}\n'
			+ 'Shits - ${shits}\n\n'
			+ 'Combo Breaks: ${PlayState.instance.songMisses}\n'
			+ 'Score: ${PlayState.instance.songScore}\n'
			+ 'Accuracy: ${Std.string(Math.floor(PlayState.instance.ratingPercent * 10000) / 100)}%\n\n\n'
			+ 'Note Rate: ${PlayState.instance.songSpeed} x';

		var comboTextY = (stageHeight - Math.floor(150 * scale)) / 2;
		comboText = createTextField(Math.floor(20 * scale), Math.floor(-100 * scale), Math.floor(stageWidth - 300 * scale), FlxColor.WHITE,
			Math.floor(32 * scale));
		comboText.text = comboStr;
		overlaySprite.addChild(comboText);

		var idx = 0;
		if (!ClientPrefs.data.removePerfects)
		{
			idx = comboStr.indexOf('Perfects');
			comboText.setTextFormat(new TextFormat("assets/fonts/vcr.ttf", Math.floor(32 * scale), 0xFFFFC0CB), idx, idx + ('Perfects - ${perfects}'.length));
		}
		idx = comboStr.indexOf('Sicks');
		comboText.setTextFormat(new TextFormat("assets/fonts/vcr.ttf", Math.floor(32 * scale), 0xFF87CEFA), idx, idx + ('Sicks - ${sicks}'.length));
		idx = comboStr.indexOf('Goods');
		comboText.setTextFormat(new TextFormat("assets/fonts/vcr.ttf", Math.floor(32 * scale), 0xFF66CDAA), idx, idx + ('Goods - ${goods}'.length));
		idx = comboStr.indexOf('Bads');
		comboText.setTextFormat(new TextFormat("assets/fonts/vcr.ttf", Math.floor(32 * scale), 0xFFF4A460), idx, idx + ('Bads - ${bads}'.length));
		idx = comboStr.indexOf('Shits');
		comboText.setTextFormat(new TextFormat("assets/fonts/vcr.ttf", Math.floor(32 * scale), 0xFFFF4500), idx, idx + ('Shits - ${shits}'.length));

		contText = createTextField(Math.floor(stageWidth - 520 * scale), Math.floor(stageHeight + 80 * scale), Math.floor(500 * scale), FlxColor.WHITE,
			Math.floor(32 * scale));
		contText.text = #if mobile 'Touch Screen to continue.' #else 'Press \'ENTER\' to continue.' #end;
		overlaySprite.addChild(contText);

		if (PlayState.instance.hitHistory != null && PlayState.instance.hitHistory.length > 0)
		{
			for (hitData in PlayState.instance.hitHistory)
			{
				graph.addToHistory(hitData[0], hitData[1], hitData[2]);
			}
			graph.update();
		}

		if (sicks == Math.POSITIVE_INFINITY)
			sicks = 0;
		if (goods == Math.POSITIVE_INFINITY)
			goods = 0;

		var averageMs:Float = 0;
		@:privateAccess
		averageMs = PlayState.instance.allNotesMs / PlayState.instance.songHits;

		settingsText = createTextField(Math.floor(20 * scale), Math.floor(stageHeight + 60 * scale), Math.floor(stageWidth - 300 * scale), FlxColor.WHITE,
			Math.floor(18 * scale));
		settingsText.text = 'Avg: ${Math.round(averageMs * 100) / 100}ms (${!ClientPrefs.data.removePerfects ? "PERFECT:" + ClientPrefs.data.perfectWindow + "ms," : ""}SICK:${ClientPrefs.data.sickWindow}ms,GOOD:${ClientPrefs.data.goodWindow}ms,BAD:${ClientPrefs.data.badWindow}ms)';
		overlaySprite.addChild(settingsText);

		FlxTween.tween(background, {alpha: 0.5}, 0.5);
		FlxTween.num(-80 * scale, 20 * scale, 0.5, {ease: FlxEase.expoInOut}, (val) -> text.y = val);
		FlxTween.num(-100 * scale, comboTextY, 0.5, {ease: FlxEase.expoInOut}, (val) -> comboText.y = val);
		FlxTween.num(stageHeight + 60 * scale, stageHeight - 60 * scale, 0.5, {ease: FlxEase.expoInOut}, (val) -> contText.y = val);
		FlxTween.num(stageHeight + 60 * scale, stageHeight - 50 * scale, 0.5, {ease: FlxEase.expoInOut}, (val) -> settingsText.y = val);
		FlxTween.num(0, 1.0, 0.5, {ease: FlxEase.expoInOut}, (val) -> graph.alpha = val);

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		super.create();
	}

	var frames = 0;

	private function handleContinue():Void
	{
		trace('WENT BACK TO FREEPLAY??');
		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		PlayState.changedDifficulty = false;
		Mods.loadTopMod();
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		MusicBeatState.switchState(new FreeplayState());
		close();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (music != null)
			if (music.volume < 0.5)
				music.volume += 0.01 * elapsed;

		if (FlxG.keys.justPressed.ENTER)
		{
			handleContinue();
		}

		#if !desktop
		if (FlxG.mouse.justPressed || FlxG.touches.justStarted().length > 0)
		{
			handleContinue();
		}
		#end
	}

	override function destroy()
	{
		if (overlaySprite != null && FlxG.stage != null && FlxG.stage.contains(overlaySprite))
		{
			FlxG.stage.removeChild(overlaySprite);
			overlaySprite = null;
		}

		super.destroy();
	}

	private function createTextField(X:Float = 0, Y:Float = 0, Width:Float = 0, Color:FlxColor = FlxColor.WHITE, Size:Int = 12):TextField
	{
		var tf = new TextField();
		tf.x = X;
		tf.y = Y;
		tf.width = Width;
		tf.multiline = true;
		tf.wordWrap = true;
		tf.embedFonts = true;
		tf.selectable = false;
		tf.defaultTextFormat = new TextFormat("assets/fonts/vcr.ttf", Size, Color.to24Bit());
		tf.alpha = Color.alphaFloat;
		tf.autoSize = TextFieldAutoSize.LEFT;
		return tf;
	}
}

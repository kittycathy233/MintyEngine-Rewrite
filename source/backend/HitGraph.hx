package backend;

import flixel.FlxG;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.text.TextFieldAutoSize;
import flixel.system.FlxAssets;
import openfl.text.TextFormat;
import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormatAlign;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import states.PlayState;
import backend.ClientPrefs;

class HitGraph extends Sprite
{
	static inline var AXIS_COLOR:FlxColor = 0xffffff;
	static inline var AXIS_ALPHA:Float = 0.5;
	inline static var HISTORY_MAX:Int = 30;

	public var minLabel:TextField;
	public var curLabel:TextField;
	public var maxLabel:TextField;
	public var avgLabel:TextField;

	public var minValue:Float = -(Math.floor(FlxG.sound.music.length / 1000) + 95);
	public var maxValue:Float = Math.floor(FlxG.sound.music.length / 1000) + 95;

	public var showInput:Bool = true;

	public var graphColor:FlxColor;

	public var history:Array<Dynamic> = [];

	public var bitmap:Bitmap;

	public var ts:Float;

	var _axis:Shape;

	function getMaxWindow():Float
	{
		var maxWindow:Float = 166;

		var windows:Array<Float> = [];

		if (!ClientPrefs.data.removePerfects)
			windows.push(ClientPrefs.data.perfectWindow);
		windows.push(ClientPrefs.data.sickWindow);
		windows.push(ClientPrefs.data.goodWindow);
		windows.push(ClientPrefs.data.badWindow);
		windows.push(ClientPrefs.data.safeFrames * (1000 / 60));

		for (window in windows)
		{
			if (window > maxWindow)
				maxWindow = window;
		}

		return maxWindow;
	}
	var _width:Int;
	var _height:Int;
	var _unit:String;
	var _labelWidth:Int;
	var _label:String;

	public static var ratingColors:Map<String, FlxColor> = [
		"perfect" => 0xFFC0CB,
		"sick" => 0x87CEFA,
		"good" => 0x66CDAA,
		"bad" => 0xF4A460,
		"shit" => 0xFF4500
	];

	public function new(X:Int, Y:Int, Width:Int, Height:Int)
	{
		super();
		x = X;
		y = Y;
		_width = Width;
		_height = Height;

		var bm = new BitmapData(Width, Height);
		bm.draw(this);
		bitmap = new Bitmap(bm);

		_axis = new Shape();
		_axis.x = _labelWidth + 10;

		var maxWindow:Float = getMaxWindow();
		ts = Math.floor(FlxG.sound.music.length / 1000) / maxWindow;

		minValue = -maxWindow;
		maxValue = maxWindow;

		var early = createTextField(10, 10, FlxColor.WHITE, 20);
		var late = createTextField(10, _height - 20, FlxColor.WHITE, 20);

		early.text = "Early (" + -maxWindow + "ms)";
		late.text = "Late (" + maxWindow + "ms)";

		addChild(early);
		addChild(late);

		addChild(_axis);

		drawAxes();
	}

	function drawAxes():Void
	{
		var gfx = _axis.graphics;
		gfx.clear();
		gfx.lineStyle(1, AXIS_COLOR, AXIS_ALPHA);

		gfx.moveTo(0, 0);
		gfx.lineTo(0, _height);

		gfx.moveTo(0, _height);
		gfx.lineTo(_width, _height);

		gfx.moveTo(0, _height / 2);
		gfx.lineTo(_width, _height / 2);
	}

	public static function createTextField(X:Float = 0, Y:Float = 0, Color:FlxColor = FlxColor.WHITE, Size:Int = 12):TextField
	{
		return initTextField(new TextField(), X, Y, Color, Size);
	}

	public static function initTextField<T:TextField>(tf:T, X:Float = 0, Y:Float = 0, Color:FlxColor = FlxColor.WHITE, Size:Int = 12):T
	{
		tf.x = X;
		tf.y = Y;
		tf.multiline = false;
		tf.wordWrap = false;
		tf.embedFonts = true;
		tf.selectable = false;
		#if flash
		tf.antiAliasType = AntiAliasType.NORMAL;
		tf.gridFitType = GridFitType.PIXEL;
		#end
		tf.defaultTextFormat = new TextFormat("assets/fonts/vcr.ttf", Size, Color.to24Bit());
		tf.alpha = Color.alphaFloat;
		tf.autoSize = TextFieldAutoSize.LEFT;
		return tf;
	}

	function drawJudgementLine(ms:Float):Void
	{
		var gfx:Graphics = graphics;

		gfx.lineStyle(3, graphColor, 0.3);

		var range:Float = Math.max(maxValue - minValue, maxValue * 0.1);

		var value = (ms - minValue) / range;

		var pointY = _axis.y + ((-value * _height - 1) + _height);

		var graphX = _axis.x + 1;

		gfx.drawRect(graphX, pointY, _width, 3);

		gfx.lineStyle(3, graphColor, 1);
	}

	function drawGraph():Void
	{
		var gfx:Graphics = graphics;
		gfx.clear();
		gfx.lineStyle(1, graphColor, 1);

		var perfectWindow:Float = ClientPrefs.data.perfectWindow;
		var sickWindow:Float = ClientPrefs.data.sickWindow;
		var goodWindow:Float = ClientPrefs.data.goodWindow;
		var badWindow:Float = ClientPrefs.data.badWindow;
		var safeFrames:Float = ClientPrefs.data.safeFrames * (1000 / 60);

		if (!ClientPrefs.data.removePerfects && perfectWindow > 0)
		{
			gfx.beginFill(ratingColors.get("perfect"));
			drawJudgementLine(perfectWindow);
			gfx.endFill();
		}

		if (sickWindow > 0)
		{
			gfx.beginFill(ratingColors.get("sick"));
			drawJudgementLine(sickWindow);
			gfx.endFill();
		}

		if (goodWindow > 0)
		{
			gfx.beginFill(ratingColors.get("good"));
			drawJudgementLine(goodWindow);
			gfx.endFill();
		}

		if (badWindow > 0)
		{
			gfx.beginFill(ratingColors.get("bad"));
			drawJudgementLine(badWindow);
			gfx.endFill();
		}

		if (safeFrames > 0)
		{
			gfx.beginFill(ratingColors.get("shit"));
			drawJudgementLine(safeFrames);
			gfx.endFill();
		}

		if (!ClientPrefs.data.removePerfects && perfectWindow > 0)
		{
			gfx.beginFill(ratingColors.get("perfect"));
			drawJudgementLine(-perfectWindow);
			gfx.endFill();
		}

		if (sickWindow > 0)
		{
			gfx.beginFill(ratingColors.get("sick"));
			drawJudgementLine(-sickWindow);
			gfx.endFill();
		}

		if (goodWindow > 0)
		{
			gfx.beginFill(ratingColors.get("good"));
			drawJudgementLine(-goodWindow);
			gfx.endFill();
		}

		if (badWindow > 0)
		{
			gfx.beginFill(ratingColors.get("bad"));
			drawJudgementLine(-badWindow);
			gfx.endFill();
		}

		if (safeFrames > 0)
		{
			gfx.beginFill(ratingColors.get("shit"));
			drawJudgementLine(-safeFrames);
			gfx.endFill();
		}

		var range:Float = Math.max(maxValue - minValue, maxValue * 0.1);
		var graphX = _axis.x + 1;

		for (i in 0...history.length)
		{
			var value = (history[i][0] - minValue) / range;
			var judge = history[i][1];

			var color = ratingColors.get(judge);
			if (color == null)
			{
				switch (judge)
				{
					case "sick":
						color = 0x00FFFF;
					case "good":
						color = 0x00FF00;
					case "bad":
						color = 0xFF0000;
					case "shit":
						color = 0x8b0000;
					case "miss":
						color = 0x580000;
					default:
						color = 0xFFFFFF;
				}
			}
			gfx.lineStyle();
			gfx.beginFill(color);
			var pointY = ((-value * _height - 1) + _height);
			var pointX = fitX(history[i][2]);

			gfx.drawCircle(pointX, pointY, 2.5);

			gfx.endFill();
		}

		var bm = new BitmapData(_width, _height);
		bm.draw(this);
		bitmap = new Bitmap(bm);
	}

	public function fitX(x:Float)
	{
		return ((x / (FlxG.sound.music.length)) * width);
	}

	public function addToHistory(diff:Float, judge:String, time:Float)
	{
		history.push([diff, judge, time]);
	}

	public function update():Void
	{
		drawGraph();
	}

	public function average():Float
	{
		var sum:Float = 0;
		for (value in history)
			sum += value;
		return sum / history.length;
	}

	public function destroy():Void
	{
		_axis = FlxDestroyUtil.removeChild(this, _axis);
		history = null;
	}
}

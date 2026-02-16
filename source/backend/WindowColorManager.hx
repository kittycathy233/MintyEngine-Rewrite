package backend;

import flixel.FlxG;
import flixel.util.FlxColor;
#if (cpp && windows)
import hxwindowmode.WindowColorMode;
#end

class WindowColorManager
{
	private static var targetR:Int = 0;
	private static var targetG:Int = 0;
	private static var targetB:Int = 0;
	
	private static var currentR:Int = 0;
	private static var currentG:Int = 0;
	private static var currentB:Int = 0;
	
	private static var isPhillyGlowActive:Bool = false;
	private static var transitionSpeed:Float = 0.08;
	
	public static function init():Void
	{
		setColor(FlxColor.BLACK, false);
	}
	
	public static function update(elapsed:Float):Void
	{
		#if (cpp && windows)
		if (!isPhillyGlowActive)
		{
			var deltaR:Int = targetR - currentR;
			var deltaG:Int = targetG - currentG;
			var deltaB:Int = targetB - currentB;
			
			if (Math.abs(deltaR) > 1)
				currentR += Math.round(deltaR * transitionSpeed);
			else
				currentR = targetR;
				
			if (Math.abs(deltaG) > 1)
				currentG += Math.round(deltaG * transitionSpeed);
			else
				currentG = targetG;
				
			if (Math.abs(deltaB) > 1)
				currentB += Math.round(deltaB * transitionSpeed);
			else
				currentB = targetB;
			
			applyColor();
		}
		#end
	}
	
	public static function setColor(color:FlxColor, immediate:Bool = false):Void
	{
		#if (cpp && windows)
		var r:Int = (color >> 16) & 0xFF;
		var g:Int = (color >> 8) & 0xFF;
		var b:Int = color & 0xFF;
		
		targetR = r;
		targetG = g;
		targetB = b;
		
		if (immediate)
		{
			currentR = r;
			currentG = g;
			currentB = b;
			applyColor();
		}
		#end
	}
	
	public static function setPhillyGlowActive(active:Bool, ?color:FlxColor):Void
	{
		#if (cpp && windows)
		isPhillyGlowActive = active;
		
		if (active && color != null)
		{
			setColor(color, true);
		}
		#end
	}
	
	private static function applyColor():Void
	{
		#if (cpp && windows)
		WindowColorMode.setWindowBorderColor([currentR, currentG, currentB], true, false);
		if (WindowColorMode.isWindows10)
		{
			WindowColorMode.redrawWindowHeader();
		}
		#end
	}
	
	public static function reset():Void
	{
		#if (cpp && windows)
		setPhillyGlowActive(false);
		setColor(FlxColor.BLACK, false);
		#end
	}
}

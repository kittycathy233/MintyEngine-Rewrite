package debug;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System as OpenFlSystem;
import lime.system.System as LimeSystem;
import openfl.display.Sprite;
import openfl.display.Shape;
import states.MainMenuState;
import backend.ClientPrefs;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
#if cpp
#if windows
@:cppFileCode('#include <windows.h>')
#elseif (ios || mac)
@:cppFileCode('#include <mach-o/arch.h>')
#else
@:headerInclude('sys/utsname.h')
#end
#end
class FPSCounter extends Sprite
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Float;

	/**
		Reserved memory (total allocated memory by GC)
	**/
	public var memoryReserved(get, never):Float;

	/**
		Current memory (currently allocated memory)
	**/
	public var memoryCurrent(get, never):Float;

	/**
		Large object memory
	**/
	public var memoryLarge(get, never):Float;

	/**
		Memory usage percentage
	**/
	public var memoryUsagePercent(get, never):Float;

	/**
		Average FPS over time
	**/
	public var averageFPS(default, null):Float;

	/**
		Minimum FPS recorded
	**/
	public var minFPS(default, null):Int;

	/**
		Maximum FPS recorded
	**/
	public var maxFPS(default, null):Int;

	/**
		Frame time in milliseconds
	**/
	public var frameTime(default, null):Float;

	/**
		Total frames rendered
	**/
	public var totalFrames(default, null):Int;

	/**
		Total runtime in seconds
	**/
	public var totalRuntime(default, null):Float;

	/**
		Target framerate (what the game is trying to achieve)
	**/
	public var targetFramerate(default, null):Int;

	/**
		Display refresh rate (from monitor)
	**/
	public var displayRefreshRate(default, null):Int;

	/**
		VSync is enabled
	**/
	public var vsyncEnabled(default, null):Bool;

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var frameTimes:Array<Float>;

	public var os:String = '';
	public var peakMemory:Float = 0;
	public var minMemory:Float = 0;

	var textField:TextField;
	var bg:Shape;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		if (LimeSystem.platformName == LimeSystem.platformVersion || LimeSystem.platformVersion == null)
			os = '\n${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end;
		else
			os = '\n${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end + ' - ${LimeSystem.platformVersion}';

		bg = new Shape();
		bg.alpha = 0.5;
		addChild(bg);

		textField = new TextField();
		textField.selectable = false;
		textField.mouseEnabled = false;
		textField.defaultTextFormat = new TextFormat(Paths.font("HarmonyOS_Sans_Bold.ttf"), 14, color, true);
		textField.width = 200;
		textField.height = 60;
		textField.multiline = true;
		textField.text = "FPS: ";
		addChild(textField);

		positionFPS(x, y);

		currentFPS = 0;
		averageFPS = 0;
		minFPS = 999;
		maxFPS = 0;
		frameTime = 0;
		totalFrames = 0;
		totalRuntime = 0;
		times = [];
		frameTimes = [];
		minMemory = 0;

		updateFramerateInfo();
	}

	var deltaTimeout:Float = 0.0;
	var lastFrameTime:Float = 0;
	var startTime:Float = 0;
	var lastTextUpdateTime:Float = 0;
	var textUpdateInterval:Float = 100; // 更新间隔，单位毫秒

	function updateFramerateInfo()
	{
		#if (lime_cffi && !macro)
		if (FlxG.stage != null && FlxG.stage.application != null && FlxG.stage.application.window != null)
		{
			displayRefreshRate = FlxG.stage.application.window.displayMode.refreshRate;
		}
		#end
		targetFramerate = FlxG.updateFramerate;
		vsyncEnabled = ClientPrefs.data.vsync;
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		if (deltaTimeout > 1000) {
			deltaTimeout = 0.0;
			return;
		}

		final now:Float = haxe.Timer.stamp() * 1000;
		
		if (startTime == 0)
			startTime = now / 1000;

		totalRuntime = (now / 1000) - startTime;
		
		if (lastFrameTime > 0)
		{
			frameTime = now - lastFrameTime;
			frameTimes.push(frameTime);
			if (frameTimes.length > 60)
				frameTimes.shift();
		}
		lastFrameTime = now;

		times.push(now);
		while (times[0] < now - 1000) times.shift();

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
		
		if (currentFPS > maxFPS && currentFPS < FlxG.updateFramerate)
			maxFPS = currentFPS;
		if (currentFPS < minFPS && currentFPS > 0)
			minFPS = currentFPS;

		totalFrames++;
		averageFPS = totalFrames / totalRuntime;

		// 减少文本更新频率，提高性能
		if (now - lastTextUpdateTime > textUpdateInterval) {
			updateText();
			lastTextUpdateTime = now;
		}

		deltaTimeout += deltaTime;
	}

	public dynamic function updateText():Void
	{
		var currentMem = memoryMegas;
		if (currentMem > peakMemory) peakMemory = currentMem;
		if (minMemory == 0 || currentMem < minMemory) minMemory = currentMem;

		// 减少 updateFramerateInfo 的调用频率，因为它涉及到平台特定的操作
		if (haxe.Timer.stamp() % 1 > 0.9) // 大约每秒调用一次
			updateFramerateInfo();

		var text = '';
		
		if (ClientPrefs.data.fpsDisplayMode == 'Simple')
		{
			text = '${currentFPS} FPS';
		}
		else if (ClientPrefs.data.fpsDisplayMode == 'Detailed')
		{
			text = '${currentFPS} FPS (Avg: ${Math.floor(averageFPS)})\n' +
				'MEM: ${flixel.util.FlxStringUtil.formatBytes(currentMem)} | Peak: ${flixel.util.FlxStringUtil.formatBytes(peakMemory)}';
		}
		else if (ClientPrefs.data.fpsDisplayMode == 'Advanced')
		{
			text = '${currentFPS} FPS | Min: ${minFPS} | Max: ${maxFPS}\n' +
				'MEM: ${flixel.util.FlxStringUtil.formatBytes(currentMem)} | Peak: ${flixel.util.FlxStringUtil.formatBytes(peakMemory)} | Min: ${flixel.util.FlxStringUtil.formatBytes(minMemory)}\n' +
				'Frame: ${Math.floor(frameTime)}ms | Total: ${totalFrames}';
		}
		else if (ClientPrefs.data.fpsDisplayMode == 'Full')
		{
			text = '${currentFPS} FPS (Avg: ${Math.floor(averageFPS)})\n' +
				'Min: ${minFPS} | Max: ${maxFPS}\n' +
				'MEM: ${flixel.util.FlxStringUtil.formatBytes(currentMem)} | Peak: ${flixel.util.FlxStringUtil.formatBytes(peakMemory)}\n' +
				'Reserved: ${flixel.util.FlxStringUtil.formatBytes(memoryReserved)}\n' +
				'Current: ${flixel.util.FlxStringUtil.formatBytes(memoryCurrent)}\n' +
				'Large: ${flixel.util.FlxStringUtil.formatBytes(memoryLarge)}\n' +
				'Usage: ${Math.floor(memoryUsagePercent)}%\n' +
				'Frame: ${Math.floor(frameTime)}ms\n' +
				'Total: ${totalFrames} frames\n' +
				'Runtime: ${Math.floor(totalRuntime)}s\n' +
				'Target: ${targetFramerate} FPS\n' +
				'Display: ${displayRefreshRate} Hz\n' +
				'VSync: ${vsyncEnabled ? "ON" : "OFF"}';
		}

		if (ClientPrefs.data.showOSInFPS)
			text += os;
		if (ClientPrefs.data.showEngineVersion)
			text += '\nMinty ${MainMenuState.mintyEngineVersion} | Psych ${MainMenuState.psychEngineVersion}';

		// 只有当文本真正改变时才更新 TextField
		if (textField.text != text) {
			textField.text = text;

			textField.width = textField.textWidth + 10;
			textField.height = textField.textHeight + 4;

			bg.graphics.clear();
			bg.graphics.beginFill(0x000000);
			bg.graphics.drawRect(0, 0, textField.width, textField.height);
			bg.graphics.endFill();
		}

		// 根据 FPS 动态调整文本颜色
		var newColor:Int = 0xFFFFFFFF;
		if (currentFPS < FlxG.drawFramerate * 0.5)
			newColor = 0xFFFF0000;
		else if (currentFPS < FlxG.drawFramerate * 0.75)
			newColor = 0xFFFFFF00;

		// 只有当颜色真正改变时才更新
		if (textField.textColor != newColor)
			textField.textColor = newColor;
	}

	inline function get_memoryMegas():Float
		return cast(OpenFlSystem.totalMemory, UInt);

	#if cpp
	inline function get_memoryReserved():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_RESERVED);

	inline function get_memoryCurrent():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_CURRENT);

	inline function get_memoryLarge():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_LARGE);

	inline function get_memoryUsagePercent():Float
	{
		var reserved = memoryReserved;
		return reserved > 0 ? (memoryMegas / reserved) * 100 : 0;
	}
	#else
	inline function get_memoryReserved():Float
		return 0;

	inline function get_memoryCurrent():Float
		return 0;

	inline function get_memoryLarge():Float
		return 0;

	inline function get_memoryUsagePercent():Float
		return 0;
	#end

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1){
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;
		x = FlxG.game.x + X;
		y = FlxG.game.y + Y;
	}

	public function resetStats()
	{
		peakMemory = 0;
		minMemory = 0;
		minFPS = 999;
		maxFPS = 0;
		totalFrames = 0;
		averageFPS = 0;
		frameTimes = [];
		startTime = haxe.Timer.stamp() * 1000;
	}

	public function toggleDisplayMode():Void
	{
		var modes:Array<String> = ['Simple', 'Detailed', 'Advanced', 'Full'];
		var currentIndex = modes.indexOf(ClientPrefs.data.fpsDisplayMode);
		if (currentIndex == -1) currentIndex = 0;
		var nextIndex = (currentIndex + 1) % modes.length;
		ClientPrefs.data.fpsDisplayMode = modes[nextIndex];
		ClientPrefs.saveSettings();
	}

	#if cpp
	#if windows
	@:functionCode('
		SYSTEM_INFO osInfo;

		GetSystemInfo(&osInfo);

		switch(osInfo.wProcessorArchitecture)
		{
			case 9:
				return ::String("x86_64");
			case 5:
				return ::String("ARM");
			case 12:
				return ::String("ARM64");
			case 6:
				return ::String("IA-64");
			case 0:
				return ::String("x86");
			default:
				return ::String("Unknown");
		}
	')
	#elseif (ios || mac)
	@:functionCode('
		const NXArchInfo *archInfo = NXGetLocalArchInfo();
    	return ::String(archInfo == NULL ? "Unknown" : archInfo->name);
	')
	#else
	@:functionCode('
		struct utsname osInfo{};
		uname(&osInfo);
		return ::String(osInfo.machine);
	')
	#end
	@:noCompletion
	private function getArch():String
	{
		return "Unknown";
	}
	#end
}

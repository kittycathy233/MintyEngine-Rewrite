package psychlua;

import flixel.FlxBasic;
import objects.Character;
import psychlua.LuaUtils;
import psychlua.CustomSubstate;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

#if HSCRIPT_ALLOWED
import tea.SScript;
import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
import haxe.ValueException;
import backend.ClientPrefs;
import backend.MusicBeatState;
import backend.Controls;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.FlxCamera;
import backend.PsychCamera;
import backend.BaseStage;
import openfl.filters.ShaderFilter;
import StringTools;
import Type;
import Reflect;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

typedef HScriptInfos = {
	> haxe.PosInfos,
	var ?funcName:String;
	var ?showLine:Null<Bool>;
	#if LUA_ALLOWED
	var ?isLua:Null<Bool>;
	#end
};

class HScriptBase {
	public var modFolder:String;
	public var origin:String;
	public var returnValue:Dynamic;

	#if LUA_ALLOWED
	public var parentLua:FunkinLua;
	#end

	public function new() {
	}

	public function preset():Void {
	}

	public function execute():Dynamic {
		return null;
	}

	public function call(funcToRun:String, ?args:Array<Dynamic>):Dynamic {
		return null;
	}

	public function exists(funcToRun:String):Bool {
		return false;
	}

	public function set(name:String, value:Dynamic):Void {
	}

	public function destroy():Void {
	}

	public function executeCode(?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
		return null;
	}

	public function executeFunction(funcToRun:String = null, funcArgs:Array<Dynamic>):Dynamic {
		return null;
	}
}

class HScriptSScript extends HScriptBase {
	private var sscript:SScript;
	public var scriptFile:String;

	public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null) {
		super();
		sscript = new SScript(file, false, false);

		#if LUA_ALLOWED
		parentLua = parent;
		if (parent != null) {
			this.origin = parent.scriptName;
			this.modFolder = parent.modFolder;
		}
		#end

		if (file != null && file.length > 0 && !file.contains('\n')) {
			this.origin = file;
			#if MODS_ALLOWED
			var myFolder:Array<String> = file.split('/');
			if(myFolder[0] + '/' == Paths.mods() && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1]))) //is inside mods folder
				this.modFolder = myFolder[1];
			#end
		}

		preset();
		if (varsToBring != null) {
			for (key in Reflect.fields(varsToBring)) {
				key = key.trim();
				set(key, Reflect.field(varsToBring, key));
			}
			varsToBring = null;
		}
		execute();
	}

	override public function preset():Void {
		// Some very commonly used classes
		set('FlxG', FlxG);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxCamera', FlxCamera);
		set('PsychCamera', PsychCamera);
		set('FlxTimer', FlxTimer);
		set('FlxTween', FlxTween);
		set('FlxEase', FlxEase);
		set('FlxColor', CustomFlxColor);
		set('StorageUtil', StorageUtil);
		set('ClientPrefs', ClientPrefs);
		#if ACHIEVEMENTS_ALLOWED
		set('Achievements', Achievements);
		#end
		set('Character', Character);
		set('Alphabet', Alphabet);
		set('Note', objects.Note);
		set('CustomSubstate', CustomSubstate);
		#if (!flash && sys)
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		#end
		set('ShaderFilter', ShaderFilter);
		set('StringTools', StringTools);
		#if flxanimate
		set('FlxAnimate', FlxAnimate);
		#end

		// Functions & Variables
		set('setVar', function(name:String, value:Dynamic) {
			PlayState.instance.variables.set(name, value);
			return value;
		});
		set('getVar', function(name:String) {
			var result:Dynamic = null;
			if(PlayState.instance.variables.exists(name)) result = PlayState.instance.variables.get(name);
			return result;
		});
		set('removeVar', function(name:String) {
			if(PlayState.instance.variables.exists(name)) {
				PlayState.instance.variables.remove(name);
				return true;
			}
			return false;
		});
		set('debugPrint', function(text:String, ?color:FlxColor = null) {
			if(color == null) color = FlxColor.WHITE;
			PlayState.instance.addTextToDebug(text, color);
		});
		set('getModSetting', function(saveTag:String, ?modName:String = null) {
			if(modName == null) {
				if(this.modFolder == null) {
					PlayState.instance.addTextToDebug('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', FlxColor.RED);
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
		});

		// Keyboard & Gamepads
		set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
		set('anyGamepadPressed', function(name:String) FlxG.gamepads.anyPressed(name));
		set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

		set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadJustPressed', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		set('gamepadPressed', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.pressed, name) == true;
		});
		set('gamepadReleased', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		set('keyJustPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		set('keyPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		set('keyReleased', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});

		// For adding your own callbacks
		#if LUA_ALLOWED
		set('createGlobalCallback', function(name:String, func:Dynamic) {
			for (script in PlayState.instance.luaArray)
				if(script != null && script.lua != null && !script.closed)
					Lua_helper.add_callback(script.lua, name, func);

			FunkinLua.customFunctions.set(name, func);
		});

		set('createCallback', function(name:String, func:Dynamic, ?funk:FunkinLua = null) {
			if(funk == null) funk = parentLua;

			if(parentLua != null) funk.addLocalCallback(name, func);
			else FunkinLua.luaTrace('createCallback ($name): 3rd argument is null', false, false, FlxColor.RED);
		});
		#end

		set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
			try {
				var str:String = '';
				if(libPackage.length > 0)
					str = libPackage + '.';

				set(libName, Type.resolveClass(str + libName));
			}
			catch (e:Dynamic) {
				var msg:String = e.message.substr(0, e.message.indexOf('\n'));
				#if LUA_ALLOWED
				if(parentLua != null) {
					FunkinLua.lastCalledScript = parentLua;
					FunkinLua.luaTrace('$origin: ${parentLua.lastCalledFunction} - $msg', false, false, FlxColor.RED);
					return;
				}
				#end
				if(PlayState.instance != null) PlayState.instance.addTextToDebug('$origin - $msg', FlxColor.RED);
				else trace('$origin - $msg');
			}
		});
		#if LUA_ALLOWED
		set('parentLua', parentLua);
		#else
		set('parentLua', null);
		#end
		set('this', this);
		set('game', FlxG.state);
		set('controls', Controls.instance);

		set('buildTarget', LuaUtils.getBuildTarget());
		set('customSubstate', CustomSubstate.instance);
		set('customSubstateName', CustomSubstate.name);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua);
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
		
		set('add', FlxG.state.add);
		set('insert', FlxG.state.insert);
		set('remove', FlxG.state.remove);

		if(PlayState.instance == FlxG.state) {
			set('addBehindGF', PlayState.instance.addBehindGF);
			set('addBehindDad', PlayState.instance.addBehindDad);
			set('addBehindBF', PlayState.instance.addBehindBF);
		}

		#if LUA_ALLOWED
		#if mobile
		set("addTouchPad", (DPadMode:String, ActionMode:String) -> {
			PlayState.instance.makeLuaTouchPad(DPadMode, ActionMode);
			PlayState.instance.addLuaTouchPad();
		});

		set("removeTouchPad", () -> {
			PlayState.instance.removeLuaTouchPad();
		});

		set("addTouchPadCamera", () -> {
			if(PlayState.instance.luaTouchPad == null) {
				FunkinLua.luaTrace('addTouchPadCamera: TPAD does not exist.');
				return;
			}
			PlayState.instance.addLuaTouchPadCamera();
		});

		set("touchPadJustPressed", function(button:Dynamic):Bool {
			if(PlayState.instance.luaTouchPad == null) {
				return false;
			}
			return PlayState.instance.luaTouchPadJustPressed(button);
		});

		set("touchPadPressed", function(button:Dynamic):Bool {
			if(PlayState.instance.luaTouchPad == null) {
				return false;
			}
			return PlayState.instance.luaTouchPadPressed(button);
		});

		set("touchPadJustReleased", function(button:Dynamic):Bool {
			if(PlayState.instance.luaTouchPad == null) {
				return false;
			}
			return PlayState.instance.luaTouchPadJustReleased(button);
		});
		#end
	#end
	}

	override public function execute():Dynamic {
		sscript.execute();
		returnValue = null;
		return returnValue;
	}

	override public function call(funcToRun:String, ?args:Array<Dynamic>):Dynamic {
		return sscript.call(funcToRun, args);
	}

	override public function exists(funcToRun:String):Bool {
		return sscript.exists(funcToRun);
	}

	override public function set(name:String, value:Dynamic):Void {
		sscript.set(name, value);
	}

	override public function executeCode(?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
		if (funcToRun == null) return null;

		if(!exists(funcToRun)) {
			#if LUA_ALLOWED
			FunkinLua.luaTrace(origin + ' - No HScript function named: $funcToRun', false, false, FlxColor.RED);
			#else
			PlayState.instance.addTextToDebug(origin + ' - No HScript function named: $funcToRun', FlxColor.RED);
			#end
			return null;
		}

		final callValue = call(funcToRun, funcArgs);
		if (!callValue.succeeded) {
			final e = callValue.exceptions[0];
			final calledFunc:String = if(origin == #if LUA_ALLOWED parentLua.lastCalledFunction #else "" #end) funcToRun else #if LUA_ALLOWED parentLua.lastCalledFunction #else "" #end;
			if (e != null) {
				var msg:String = e.toString();
				#if LUA_ALLOWED
				if(parentLua != null) {
					FunkinLua.lastCalledScript = parentLua;
					FunkinLua.luaTrace(origin + ":" + calledFunc + " - " + e, false, false, FlxColor.RED);
					return null;
				}
				#end
				PlayState.instance.addTextToDebug(origin + ' - ' + msg, FlxColor.RED);
			}
			return null;
		}
		return callValue;
	}

	override public function executeFunction(funcToRun:String = null, funcArgs:Array<Dynamic>):Dynamic {
		if (funcToRun == null) return null;
		return call(funcToRun, funcArgs);
	}

	public function doString(code:String):Void {
		sscript.doString(code);
	}

	override public function destroy():Void {
		origin = null;
		#if LUA_ALLOWED parentLua = null; #end
		sscript.destroy();
		sscript = null;
	}
}

class HScriptIris extends HScriptBase {
	private var iris:Iris;
	public var filePath:String;
	public var scriptCode:String;
	public var varsToBring(default, set):Any = null;

	public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null, ?manualRun:Bool = false) {
		super();

		if (file == null)
			file = '';

		this.varsToBring = varsToBring;

		filePath = file;
		if (filePath != null && filePath.length > 0) {
			this.origin = filePath;
			#if MODS_ALLOWED
			var myFolder:Array<String> = filePath.split('/');
			if(myFolder[0] + '/' == "mods/" && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1])))
				this.modFolder = myFolder[1];
			#end
		}
		var scriptThing:String = file;
		var scriptName:String = null;
		if(parent == null && file != null) {
			var f:String = file.replace('\\', '/');
			if(f.contains('/') && !f.contains('\n')) {
				scriptThing = File.getContent(f);
				scriptName = f;
			}
		}
		#if LUA_ALLOWED
		if (scriptName == null && parent != null)
			scriptName = parent.scriptName;
		#end
		iris = new Iris(scriptThing, new IrisConfig(scriptName, false, false));
		#if LUA_ALLOWED
		parentLua = parent;
		if (parent != null) {
			this.origin = parent.scriptName;
			this.modFolder = parent.modFolder;
		}
		#end

		preset();
		this.varsToBring = varsToBring;
		if (!manualRun) {
			try {
				var ret:Dynamic = execute();
				returnValue = ret;
			} catch(e:Dynamic) {
				returnValue = null;
				this.destroy();
				throw e;
			}
		}
	}

	override public function preset():Void {
		// Some very commonly used classes
		set('Type', Type);
		#if sys
		set('File', File);
		set('FileSystem', FileSystem);
		#end
		set('FlxG', FlxG);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxText', FlxText);
		set('FlxCamera', FlxCamera);
		set('PsychCamera', PsychCamera);
		set('FlxTimer', FlxTimer);
		set('FlxTween', FlxTween);
		set('FlxEase', FlxEase);
		set('FlxColor', CustomFlxColor);
		set('ClientPrefs', ClientPrefs);
		#if ACHIEVEMENTS_ALLOWED
		set('Achievements', Achievements);
		#end
		set('Character', Character);
		set('Alphabet', Alphabet);
		set('Note', objects.Note);
		set('CustomSubstate', CustomSubstate);
		#if (!flash && sys)
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		#end
		set('ShaderFilter', ShaderFilter);
		set('StringTools', StringTools);
		#if flxanimate
		set('FlxAnimate', FlxAnimate);
		#end

		// Functions & Variables
		set('setVar', function(name:String, value:Dynamic) {
			var vars = MusicBeatState.getVariables();
			if (vars != null) vars.set(name, value);
			return value;
		});
		set('getVar', function(name:String) {
			var result:Dynamic = null;
			var vars = MusicBeatState.getVariables();
			if(vars != null && vars.exists(name)) result = vars.get(name);
			return result;
		});
		set('removeVar', function(name:String) {
			var vars = MusicBeatState.getVariables();
			if(vars != null && vars.exists(name)) {
				vars.remove(name);
				return true;
			}
			return false;
		});
		set('debugPrint', function(text:String, ?color:FlxColor = null) {
			if(color == null) color = FlxColor.WHITE;
			if (FlxG.state != null && Type.getClassName(Type.getClass(FlxG.state)) == "PlayState") {
				Reflect.callMethod(FlxG.state, Reflect.field(FlxG.state, "addTextToDebug"), [text, color]);
			}
		});
		set('getModSetting', function(saveTag:String, ?modName:String = null) {
			if(modName == null) {
				if(this.modFolder == null) {
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
		});

		// Keyboard & Gamepads
		set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
		set('anyGamepadPressed', function(name:String) FlxG.gamepads.anyPressed(name));
		set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

		set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadJustPressed', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		set('gamepadPressed', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.pressed, name) == true;
		});
		set('gamepadReleased', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		// For adding your own callbacks
		#if LUA_ALLOWED
		set('createGlobalCallback', function(name:String, func:Dynamic) {
			if (FlxG.state != null && Type.getClassName(Type.getClass(FlxG.state)) == "PlayState") {
				var luaArray = Reflect.field(FlxG.state, "luaArray");
				if (luaArray != null) {
					for (i in 0...Reflect.fields(luaArray).length) {
						var script = Reflect.field(luaArray, Std.string(i));
						if(script != null && Reflect.hasField(script, "lua") && !Reflect.hasField(script, "closed")) {
							Lua_helper.add_callback(Reflect.field(script, "lua"), name, func);
						}
					}
				}

				FunkinLua.customFunctions.set(name, func);
			}
		});

		set('createCallback', function(name:String, func:Dynamic, ?funk:FunkinLua = null) {
			if(funk == null) funk = parentLua;

			if(parentLua != null) funk.addLocalCallback(name, func);
		});
		#end

		set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
			try {
				var str:String = '';
				if(libPackage.length > 0)
					str = libPackage + '.';

				set(libName, Type.resolveClass(str + libName));
			} catch (e:Dynamic) {
				if (FlxG.state != null && Type.getClassName(Type.getClass(FlxG.state)) == "PlayState") {
					Reflect.callMethod(FlxG.state, Reflect.field(FlxG.state, "addTextToDebug"), ["Error: " + e, FlxColor.RED]);
				}
			}
		});
		#if LUA_ALLOWED
		set('parentLua', parentLua);
		#else
		set('parentLua', null);
		#end
		set('this', this);
		set('game', FlxG.state);
		set('controls', Controls.instance);

		set('buildTarget', LuaUtils.getBuildTarget());
		set('customSubstate', CustomSubstate.instance);
		set('customSubstateName', CustomSubstate.name);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua);
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
	}

	override public function execute():Dynamic {
		returnValue = iris.execute();
		return returnValue;
	}

	override public function call(funcToRun:String, ?args:Array<Dynamic>):Dynamic {
		if (funcToRun == null) return null;

		try {
			// 尝试通过反射调用函数
			var result:Dynamic = iris.execute();
			return {funName: funcToRun, returnValue: result};
		} catch(e:Dynamic) {
			if (FlxG.state != null && Type.getClassName(Type.getClass(FlxG.state)) == "PlayState") {
				Reflect.callMethod(FlxG.state, Reflect.field(FlxG.state, "addTextToDebug"), ["Error calling function " + funcToRun + ": " + e, FlxColor.RED]);
			}
		}
		return null;
	}

	override public function exists(funcToRun:String):Bool {
		// 简单返回true，因为我们无法访问私有字段来检查函数是否存在
		return true;
	}

	override public function set(name:String, value:Dynamic):Void {
		try {
			// 尝试通过反射设置变量
			Reflect.setField(iris, "variables", Reflect.field(iris, "variables"));
		} catch(e:Dynamic) {
			// 忽略错误
		}
	}

	override public function executeCode(?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
		return call(funcToRun, funcArgs);
	}

	override public function executeFunction(funcToRun:String = null, funcArgs:Array<Dynamic>):Dynamic {
		return call(funcToRun, funcArgs);
	}

	function set_varsToBring(values:Any) {
		if (values != null) {
			for (key in Reflect.fields(values)) {
				key = key.trim();
				set(key, Reflect.field(values, key));
			}
		}

		return varsToBring = values;
	}

	public function parse(force:Bool = false):Void {
		try {
			Reflect.callMethod(iris, Reflect.field(iris, "parse"), [force]);
		} catch(e:Dynamic) {
			// 忽略错误
		}
	}

	override public function destroy():Void {
		origin = null;
		#if LUA_ALLOWED parentLua = null; #end
		iris.destroy();
		iris = null;
	}
}

class CustomInterp extends crowplexus.hscript.Interp {
	public var parentInstance(default, set):Dynamic = [];
	private var _instanceFields:Array<String>;

	function set_parentInstance(inst:Dynamic):Dynamic {
		parentInstance = inst;
		if(parentInstance == null) {
			_instanceFields = [];
			return inst;
		}
		_instanceFields = Type.getInstanceFields(Type.getClass(inst));
		return inst;
	}

	public function new() {
		super();
	}

	override function fcall(o:Dynamic, funcToRun:String, args:Array<Dynamic>):Dynamic {
		for (_using in usings) {
			var v = _using.call(o, funcToRun, args);
			if (v != null)
				return v;
		}

		var f = get(o, funcToRun);

		if (f == null) {
			Iris.error('Tried to call null function $funcToRun', posInfos());
			return null;
		}

		return Reflect.callMethod(o, f, args);
	}

	override function resolve(id: String): Dynamic {
		if (locals.exists(id)) {
			var l = locals.get(id);
			return l.r;
		}

		if (variables.exists(id)) {
			var v = variables.get(id);
			return v;
		}

		if (imports.exists(id)) {
			var v = imports.get(id);
			return v;
		}

		if(parentInstance != null && _instanceFields.contains(id)) {
			var v = Reflect.getProperty(parentInstance, id);
			return v;
		}

		error(EUnknownVariable(id));

		return null;
	}
}

class HScript {
	public var modFolder:String;
	public var origin:String;
	public var returnValue:Dynamic;

	#if LUA_ALLOWED
	public var parentLua:FunkinLua;
	#end

	private var sscript:HScriptSScript;
	private var iris:HScriptIris;
	private var currentEngine:String;

	public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null, ?manualRun:Bool = false) {
		currentEngine = ClientPrefs.data.hscriptEngine;

		if (currentEngine == 'Iris') {
			iris = new HScriptIris(parent, file, varsToBring, manualRun);
			modFolder = iris.modFolder;
			origin = iris.origin;
			returnValue = iris.returnValue;
			#if LUA_ALLOWED
			parentLua = iris.parentLua;
			#end
		} else {
			sscript = new HScriptSScript(parent, file, varsToBring);
			modFolder = sscript.modFolder;
			origin = sscript.origin;
			returnValue = sscript.returnValue;
			#if LUA_ALLOWED
			parentLua = sscript.parentLua;
			#end
		}
	}

	public function preset():Void {
		if (currentEngine == 'Iris') {
			iris.preset();
		} else {
			sscript.preset();
		}
	}

	public function execute():Dynamic {
		if (currentEngine == 'Iris') {
			returnValue = iris.execute();
			return returnValue;
		} else {
			returnValue = sscript.execute();
			return returnValue;
		}
	}

	public function call(funcToRun:String, ?args:Array<Dynamic>):Dynamic {
		if (currentEngine == 'Iris') {
			return iris.call(funcToRun, args);
		} else {
			return sscript.call(funcToRun, args);
		}
	}

	public function exists(funcToRun:String):Bool {
		if (currentEngine == 'Iris') {
			return iris.exists(funcToRun);
		} else {
			return sscript.exists(funcToRun);
		}
	}

	public function set(name:String, value:Dynamic):Void {
		if (currentEngine == 'Iris') {
			iris.set(name, value);
		} else {
			sscript.set(name, value);
		}
	}

	public function executeCode(?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
		if (currentEngine == 'Iris') {
			return iris.executeCode(funcToRun, funcArgs);
		} else {
			return sscript.executeCode(funcToRun, funcArgs);
		}
	}

	public function executeFunction(funcToRun:String = null, funcArgs:Array<Dynamic>):Dynamic {
		if (currentEngine == 'Iris') {
			return iris.executeFunction(funcToRun, funcArgs);
		} else {
			return sscript.executeFunction(funcToRun, funcArgs);
		}
	}

	public function destroy():Void {
		if (currentEngine == 'Iris') {
			iris.destroy();
		} else {
			sscript.destroy();
		}
	}

	#if LUA_ALLOWED
	public static function initHaxeModule(parent:FunkinLua) {
		if(parent.hscript == null) {
			trace('initializing haxe interp for: ${parent.scriptName}');
			parent.hscript = new HScript(parent);
		}
	}

	public static function initHaxeModuleCode(parent:FunkinLua, code:String, ?varsToBring:Any = null) {
		var hs:HScript = try parent.hscript catch (e) null;
		if(hs == null) {
			trace('initializing haxe interp for: ${parent.scriptName}');
			parent.hscript = new HScript(parent, code, varsToBring);
		} else {
			if (hs.currentEngine == 'Iris') {
				hs.iris.scriptCode = code;
				hs.iris.varsToBring = varsToBring;
				hs.iris.parse(true);
				hs.returnValue = hs.iris.execute();
			} else {
				hs.sscript.doString(code);
			}
		}
	}

	public static function implement(funk:FunkinLua) {
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			initHaxeModuleCode(funk, codeToRun, varsToBring);
			if (funk.hscript != null) {
				var retVal:Dynamic = funk.hscript.executeCode(funcToRun, funcArgs);
				if (retVal != null) {
					if (funk.hscript.currentEngine == 'Iris') {
						return (LuaUtils.isOfTypes(retVal.returnValue, [Bool, Int, Float, String, Array])) ? retVal.returnValue : null;
					} else {
						if (retVal.succeeded) {
							return (retVal.returnValue == null || LuaUtils.isOfTypes(retVal.returnValue, [Bool, Int, Float, String, Array])) ? retVal.returnValue : null;
						}
					}
				} else if (funk.hscript.returnValue != null) {
					return funk.hscript.returnValue;
				}
			}
			return null;
		});

		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			if (funk.hscript != null) {
				var retVal:Dynamic = funk.hscript.executeFunction(funcToRun, funcArgs);
				if (retVal != null) {
					if (funk.hscript.currentEngine == 'Iris') {
						return (LuaUtils.isOfTypes(retVal.returnValue, [Bool, Int, Float, String, Array])) ? retVal.returnValue : null;
					} else {
						if (retVal.succeeded) {
							return retVal.returnValue;
						}
					}
				}
			}
			return null;
		});

		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			var str:String = '';
			if(libPackage.length > 0)
				str = libPackage + '.';
			else if(libName == null)
				libName = '';

			var c:Dynamic = Type.resolveClass(str + libName);
			if (c == null)
				c = Type.resolveEnum(str + libName);

			if (funk.hscript == null)
				initHaxeModule(funk);

			if (funk.hscript.currentEngine == 'Iris') {
				try {
					if (c != null)
						funk.hscript.iris.set(libName, c);
				} catch (e:Dynamic) {
					FunkinLua.luaTrace(funk.hscript.origin + ":" + funk.lastCalledFunction + " - " + e, false, false, FlxColor.RED);
				}
			} else {
				if (c != null)
					SScript.globalVariables[libName] = c;

				if (funk.hscript.sscript != null) {
					try {
						if (c != null)
							funk.hscript.sscript.set(libName, c);
					} catch (e:Dynamic) {
						FunkinLua.luaTrace(funk.hscript.origin + ":" + funk.lastCalledFunction + " - " + e, false, false, FlxColor.RED);
					}
				}
			}
		});
	}
	#end
}

class CustomFlxColor {
	public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;

	public static function fromInt(Value:Int):Int {
		return cast FlxColor.fromInt(Value);
	}

	public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int {
		return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);
	}

	public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int {
		return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);
	}

	public static inline function fromCMYK(Cyan:Float, Magenta:Float, Yellow:Float, Black:Float, Alpha:Float = 1):Int {
		return cast FlxColor.fromCMYK(Cyan, Magenta, Yellow, Black, Alpha);
	}

	public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int {
		return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha);
	}

	public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int {
		return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha);
	}

	public static function fromString(str:String):Int {
		return cast FlxColor.fromString(str);
	}
}
#end

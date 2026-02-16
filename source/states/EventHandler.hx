package states;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

import objects.Character;
import objects.Note.EventNote;

import psychlua.LuaUtils;

#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
import psychlua.FunkinLua;
import psychlua.HScript;
#end

#if (cpp && windows)
import hxwindowmode.WindowColorMode;
#end

enum CharacterType
{
	BOYFRIEND;
	OPPONENT;
	GIRLFRIEND;
}

class EventHandler
{
	public var playState:PlayState;

	public function new(playState:PlayState)
	{
		this.playState = playState;
	}

	private function parseCharacterType(value:String):CharacterType
	{
		if (value == null) return CharacterType.BOYFRIEND;
		
		var normalized = value.toLowerCase().trim();
		
		var numericValue = Std.parseInt(normalized);
		if (!Math.isNaN(numericValue))
		{
			switch (numericValue)
			{
				case 0: return CharacterType.BOYFRIEND;
				case 1: return CharacterType.OPPONENT;
				case 2: return CharacterType.GIRLFRIEND;
			}
		}
		
		switch (normalized)
		{
			case 'bf' | 'boyfriend': return CharacterType.BOYFRIEND;
			case 'dad' | 'opponent': return CharacterType.OPPONENT;
			case 'gf' | 'girlfriend': return CharacterType.GIRLFRIEND;
			default: return CharacterType.BOYFRIEND;
		}
	}

	private function getCharacterByType(charType:CharacterType):Character
	{
		switch (charType)
		{
			case CharacterType.BOYFRIEND: return playState.boyfriend;
			case CharacterType.OPPONENT: return playState.dad;
			case CharacterType.GIRLFRIEND: return playState.gf;
		}
	}

	public function eventPushed(event:EventNote)
	{
		eventPushedUnique(event);
		if(playState.eventsPushed.contains(event.event))
		{
			return;
		}

		for (stage in playState.stages)
			if(stage != null && stage.exists && stage.active)
				stage.eventPushed(event);

		playState.eventsPushed.push(event.event);
	}

	public function eventPushedUnique(event:EventNote)
	{
		switch(event.event)
		{
			case "Change Character":
				var charType = parseCharacterType(event.value1);
				var charTypeInt:Int = switch(charType)
				{
					case CharacterType.BOYFRIEND: 0;
					case CharacterType.OPPONENT: 1;
					case CharacterType.GIRLFRIEND: 2;
				}
				
				var newCharacter:String = event.value2;
				playState.addCharacterToList(newCharacter, charTypeInt);

			case 'Play Sound':
				Paths.sound(event.value1);
		}

		for (stage in playState.stages)
			if(stage != null && stage.exists && stage.active)
				stage.eventPushedUnique(event);
	}

	public function eventEarlyTrigger(event:EventNote):Float
	{
		var returnedValue:Null<Float> = playState.callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.value3, event.value4, event.strumTime], true, [], [0]);
		if(returnedValue != null && returnedValue != 0 && returnedValue != LuaUtils.Function_Continue)
		{
			return returnedValue;
		}

		switch(event.event)
		{
			case 'Kill Henchmen':
				return 280;
		}
		return 0;
	}

	public function checkEventNote()
	{
		while(playState.eventNotes.length > 0)
		{
			var leStrumTime:Float = playState.eventNotes[0].strumTime;
			if(Conductor.songPosition < leStrumTime)
			{
				return;
			}

			var value1:String = '';
			if(playState.eventNotes[0].value1 != null)
				value1 = playState.eventNotes[0].value1;

			var value2:String = '';
			if(playState.eventNotes[0].value2 != null)
				value2 = playState.eventNotes[0].value2;

			var value3:String = '';
			if(playState.eventNotes[0].value3 != null)
				value3 = playState.eventNotes[0].value3;

			var value4:String = '';
			if(playState.eventNotes[0].value4 != null)
				value4 = playState.eventNotes[0].value4;

			triggerEvent(playState.eventNotes[0].event, value1, value2, value3, value4, leStrumTime);
			playState.eventNotes.shift();
		}
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, value3:String, value4:String, strumTime:Float)
	{
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		var flValue3:Null<Float> = Std.parseFloat(value3);
		var flValue4:Null<Float> = Std.parseFloat(value4);
		if(Math.isNaN(flValue1)) flValue1 = null;
		if(Math.isNaN(flValue2)) flValue2 = null;
		if(Math.isNaN(flValue3)) flValue3 = null;
		if(Math.isNaN(flValue4)) flValue4 = null;

		switch(eventName)
		{
			case 'Hey!':
				triggerHeyEvent(value1, flValue2);

			case 'Set GF Speed':
				triggerSetGFSpeedEvent(flValue1);

			case 'Add Camera Zoom':
				triggerAddCameraZoomEvent(flValue1, flValue2);

			case 'Play Animation':
				triggerPlayAnimationEvent(value1, value2, flValue2);

			case 'Camera Follow Pos':
				triggerCameraFollowPosEvent(flValue1, flValue2);

			case 'Alt Idle Animation':
				triggerAltIdleAnimationEvent(value1, value2);

			case 'Screen Shake':
				triggerScreenShakeEvent(value1, value2);

			case 'Change Character':
				triggerChangeCharacterEvent(value1, value2);

			case 'Change Scroll Speed':
				triggerChangeScrollSpeedEvent(flValue1, flValue2);

			case 'Set Property':
				triggerSetPropertyEvent(value1, value2);

			case 'Play Sound':
				triggerPlaySoundEvent(value1, flValue2);

			case 'Custom Event':
				triggerCustomEvent(value1, value2, value3, value4, flValue1, flValue2, flValue3, flValue4);

			#if (cpp && windows)
			case 'Set Window Color Mode':
				triggerWindowColorModeEvent(value1);
			case 'Set Window Border Color':
				triggerWindowBorderColorEvent(value1, value2);
			case 'Set Window Title Color':
				triggerWindowTitleColorEvent(value1);
			case 'Set Window Corner Type':
				triggerWindowCornerTypeEvent(flValue1);
			#end
		}

		for (stage in playState.stages)
			if(stage != null && stage.exists && stage.active)
				stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime, value3, value4);

		playState.callOnScripts('onEvent', [eventName, value1, value2, value3, value4, strumTime]);
	}

	private function triggerHeyEvent(value1:String, flValue2:Null<Float>)
	{
		var charType = parseCharacterType(value1);
		
		if(flValue2 == null || flValue2 <= 0) flValue2 = 0.6;

		if(charType != CharacterType.BOYFRIEND)
		{
			var targetChar = playState.dad.curCharacter.startsWith('gf') ? playState.dad : playState.gf;
			if (targetChar != null)
			{
				targetChar.playAnim('cheer', true);
				targetChar.specialAnim = true;
				targetChar.heyTimer = flValue2;
			}
		}
		if(charType != CharacterType.GIRLFRIEND)
		{
			playState.boyfriend.playAnim('hey', true);
			playState.boyfriend.specialAnim = true;
			playState.boyfriend.heyTimer = flValue2;
		}
	}

	private function triggerSetGFSpeedEvent(flValue1:Null<Float>)
	{
		if(flValue1 == null || flValue1 < 1) flValue1 = 1;
		playState.gfSpeed = Math.round(flValue1);
	}

	private function triggerAddCameraZoomEvent(flValue1:Null<Float>, flValue2:Null<Float>)
	{
		if(ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35)
		{
			if(flValue1 == null) flValue1 = 0.015;
			if(flValue2 == null) flValue2 = 0.03;

			FlxG.camera.zoom += flValue1;
			playState.camHUD.zoom += flValue2;
		}
	}

	private function triggerPlayAnimationEvent(value1:String, value2:String, flValue2:Null<Float>)
	{
		var char:Character = playState.dad;
		var charType = parseCharacterType(value2);
		
		char = getCharacterByType(charType);

		if (char != null)
		{
			char.playAnim(value1, true);
			char.specialAnim = true;
		}
	}

	private function triggerCameraFollowPosEvent(flValue1:Null<Float>, flValue2:Null<Float>)
	{
		if(playState.camFollow != null)
		{
			playState.isCameraOnForcedPos = false;
			if(flValue1 != null || flValue2 != null)
			{
				playState.isCameraOnForcedPos = true;
				if(flValue1 == null) flValue1 = 0;
				if(flValue2 == null) flValue2 = 0;
				playState.camFollow.x = flValue1;
				playState.camFollow.y = flValue2;
			}
		}
	}

	private function triggerAltIdleAnimationEvent(value1:String, value2:String)
	{
		var charType = parseCharacterType(value1);
		var char = getCharacterByType(charType);

		if (char != null)
		{
			char.idleSuffix = value2;
			char.recalculateDanceIdle();
		}
	}

	private function triggerScreenShakeEvent(value1:String, value2:String)
	{
		var valuesArray:Array<String> = [value1, value2];
		var targetsArray:Array<FlxCamera> = [playState.camGame, playState.camHUD];
		for (i in 0...targetsArray.length)
		{
			var split:Array<String> = valuesArray[i].split(',');
			var duration:Float = 0;
			var intensity:Float = 0;
			if(split[0] != null) duration = Std.parseFloat(split[0].trim());
			if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
			if(Math.isNaN(duration)) duration = 0;
			if(Math.isNaN(intensity)) intensity = 0;

			if(duration > 0 && intensity != 0)
			{
				targetsArray[i].shake(intensity, duration);
			}
		}
	}

	private function triggerChangeCharacterEvent(value1:String, value2:String)
	{
		var charType = parseCharacterType(value1);
		
		switch(charType)
		{
			case CharacterType.BOYFRIEND:
				changeBoyfriend(value2);
			case CharacterType.OPPONENT:
				changeDad(value2);
			case CharacterType.GIRLFRIEND:
				changeGF(value2);
		}
		playState.reloadHealthBarColors();
	}

	private function changeBoyfriend(value2:String)
	{
		if(playState.boyfriend.curCharacter != value2)
		{
			if(!playState.boyfriendMap.exists(value2))
			{
				playState.addCharacterToList(value2, 0);
			}

			var lastAlpha:Float = playState.boyfriend.alpha;
			playState.boyfriend.alpha = 0.00001;
			playState.boyfriend = playState.boyfriendMap.get(value2);
			playState.boyfriend.alpha = lastAlpha;
			playState.iconP1.changeIcon(playState.boyfriend.healthIcon);
		}
		playState.setOnScripts('boyfriendName', playState.boyfriend.curCharacter);
	}

	private function changeDad(value2:String)
	{
		if(playState.dad.curCharacter != value2)
		{
			if(!playState.dadMap.exists(value2))
			{
				playState.addCharacterToList(value2, 1);
			}

			var wasGf:Bool = playState.dad.curCharacter.startsWith('gf-') || playState.dad.curCharacter == 'gf';
			var lastAlpha:Float = playState.dad.alpha;
			playState.dad.alpha = 0.00001;
			playState.dad = playState.dadMap.get(value2);
			if(!playState.dad.curCharacter.startsWith('gf-') && playState.dad.curCharacter != 'gf')
			{
				if(wasGf && playState.gf != null)
				{
					playState.gf.visible = true;
				}
			}
			else if(playState.gf != null)
			{
				playState.gf.visible = false;
			}
			playState.dad.alpha = lastAlpha;
			playState.iconP2.changeIcon(playState.dad.healthIcon);
		}
		playState.setOnScripts('dadName', playState.dad.curCharacter);
	}

	private function changeGF(value2:String)
	{
		if(playState.gf != null)
		{
			if(playState.gf.curCharacter != value2)
			{
				if(!playState.gfMap.exists(value2))
				{
					playState.addCharacterToList(value2, 2);
				}

				var lastAlpha:Float = playState.gf.alpha;
				playState.gf.alpha = 0.00001;
				playState.gf = playState.gfMap.get(value2);
				playState.gf.alpha = lastAlpha;
			}
			playState.setOnScripts('gfName', playState.gf.curCharacter);
		}
	}

	private function triggerChangeScrollSpeedEvent(flValue1:Null<Float>, flValue2:Null<Float>)
	{
		if (playState.songSpeedType != "constant")
		{
			if(flValue1 == null) flValue1 = 1;
			if(flValue2 == null) flValue2 = 0;

			var newValue:Float = PlayState.SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
			if(flValue2 <= 0)
				playState.songSpeed = newValue;
			else
				playState.songSpeedTween = FlxTween.tween(playState, {songSpeed: newValue}, flValue2 / playState.playbackRate, {ease: FlxEase.linear, onComplete:
					function (twn:FlxTween)
					{
						playState.songSpeedTween = null;
					}
				});
		}
	}

	private function triggerSetPropertyEvent(value1:String, value2:String)
	{
		if(value1 == null || value1.length == 0)
		{
			return;
		}

		try
		{
			var split:Array<String> = value1.split('.');
			if(split.length > 1)
			{
				var targetObj:Dynamic = LuaUtils.getPropertyLoop(split);
				if(targetObj == null)
				{
					FlxG.log.warn('ERROR ("Set Property" Event) - Cannot find property path: ' + value1);
					return;
				}
				LuaUtils.setVarInArray(targetObj, split[split.length-1], value2);
			}
			else
			{
				LuaUtils.setVarInArray(playState, value1, value2);
			}
		}
		catch(e:Dynamic)
		{
			var len:Int = e.message.indexOf('\n') + 1;
			if(len <= 0) len = e.message.length;
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			playState.addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, len), FlxColor.RED);
			#else
			FlxG.log.warn('ERROR ("Set Property" Event) - ' + e.message.substr(0, len));
			#end
		}
	}

	private function triggerPlaySoundEvent(value1:String, flValue2:Null<Float>)
	{
		if(flValue2 == null) flValue2 = 1;
		FlxG.sound.play(Paths.sound(value1), flValue2);
	}

	private function triggerCustomEvent(value1:String, value2:String, value3:String, value4:String, flValue1:Null<Float>, flValue2:Null<Float>, flValue3:Null<Float>, flValue4:Null<Float>)
	{
		if(flValue1 == null) flValue1 = 0;
		if(flValue2 == null) flValue2 = 0;
		if(flValue3 == null) flValue3 = 0;
		if(flValue4 == null) flValue4 = 0;

		switch(value1.toLowerCase())
		{
			case 'example':
				if(value2 != null && value3 != null)
				{
					var duration:Float = flValue2;
					var intensity:Float = flValue3;
					if(duration > 0 && intensity > 0)
					{
						playState.camGame.shake(intensity, duration);
					}
				}

			case 'multi property':
				if(value2 != null && value3 != null)
				{
					try
					{
						LuaUtils.setVarInArray(playState, value2, value3);
						if(value4 != null)
						{
							LuaUtils.setVarInArray(playState, value4, flValue4);
						}
					}
					catch(e:Dynamic)
					{
						FlxG.log.warn('ERROR ("Custom Event") - ' + e.message);
					}
				}
		}
	}

	#if (cpp && windows)
	private function triggerWindowColorModeEvent(value1:String)
	{
		var isDark:Bool = false;
		
		if(value1 != null)
		{
			var normalized = value1.toLowerCase().trim();
			if(normalized == 'dark' || normalized == 'true' || normalized == '1')
			{
				isDark = true;
			}
		}
		
		WindowColorMode.setWindowColorMode(isDark);
		
		if(WindowColorMode.isWindows10)
		{
			WindowColorMode.redrawWindowHeader();
		}
	}

	private function triggerWindowBorderColorEvent(value1:String, value2:String)
	{
		var colorArray:Array<Int> = [255, 255, 255];
		
		if(value1 != null)
		{
			var split:Array<String> = value1.split(',');
			if(split.length >= 3)
			{
				colorArray[0] = Std.parseInt(split[0].trim());
				colorArray[1] = Std.parseInt(split[1].trim());
				colorArray[2] = Std.parseInt(split[2].trim());
				
				if(Math.isNaN(colorArray[0])) colorArray[0] = 255;
				if(Math.isNaN(colorArray[1])) colorArray[1] = 255;
				if(Math.isNaN(colorArray[2])) colorArray[2] = 255;
			}
		}
		
		var setHeader:Bool = true;
		var setBorder:Bool = true;
		
		if(value2 != null)
		{
			var normalized = value2.toLowerCase().trim();
			if(normalized == 'header' || normalized == 'h')
			{
				setBorder = false;
			}
			else if(normalized == 'border' || normalized == 'b')
			{
				setHeader = false;
			}
		}
		
		WindowColorMode.setWindowBorderColor(colorArray, setHeader, setBorder);
		
		if(WindowColorMode.isWindows10)
		{
			WindowColorMode.redrawWindowHeader();
		}
	}

	private function triggerWindowTitleColorEvent(value1:String)
	{
		var colorArray:Array<Int> = [255, 255, 255];
		
		if(value1 != null)
		{
			var split:Array<String> = value1.split(',');
			if(split.length >= 3)
			{
				colorArray[0] = Std.parseInt(split[0].trim());
				colorArray[1] = Std.parseInt(split[1].trim());
				colorArray[2] = Std.parseInt(split[2].trim());
				
				if(Math.isNaN(colorArray[0])) colorArray[0] = 255;
				if(Math.isNaN(colorArray[1])) colorArray[1] = 255;
				if(Math.isNaN(colorArray[2])) colorArray[2] = 255;
			}
		}
		
		WindowColorMode.setWindowTitleColor(colorArray);
		
		if(WindowColorMode.isWindows10)
		{
			WindowColorMode.redrawWindowHeader();
		}
	}

	private function triggerWindowCornerTypeEvent(flValue1:Null<Float>)
	{
		var cornerType:Int = 0;
		
		if(flValue1 != null)
		{
			cornerType = Std.int(flValue1);
		}
		
		WindowColorMode.setWindowCornerType(cornerType);
		
		if(WindowColorMode.isWindows10)
		{
			WindowColorMode.redrawWindowHeader();
		}
	}
	#end
}

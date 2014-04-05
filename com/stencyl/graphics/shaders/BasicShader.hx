package com.stencyl.graphics.shaders;

import com.stencyl.Engine;

class BasicShader
{
	public var model:PostProcess;
	
	public function new()
	{
	}
	
	public function setProperty(name:String, value:Float)
	{
		model.setUniform(name, value);
	}
	
	public function tweenProperty(name:String, targetValue:Float, duration:Float = 1, easing:Dynamic = null)
	{
		model.tweenUniform(name, targetValue, duration, easing);
	}
	
	public function enable()
	{
		Engine.engine.clearShaders();
		Engine.engine.addShader(model);
	}
	
	//Doesn't work.
	/*public function enableOnLayer(layerID:Int)
	{
		Engine.engine.clearShaders();
		var layer = Engine.engine.layers.get(layerID);
		layer.addChild(model);
		Engine.engine.addShader(model, false);
	}*/
	
	public function disable()
	{
		Engine.engine.clearShaders();
		model.parent.removeChild(model);
	}
	
	//Some shaders need to be set to 0.001 to work properly.
	public function setTimeScale(amount:Float)
	{
		model.timeScale = amount;
	}
}
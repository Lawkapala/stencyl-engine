package com.stencyl.models;

import nme.display.Sprite;
import nme.display.Bitmap;
import nme.display.BitmapData;
import nme.display.Tilesheet;
import nme.display.DisplayObject;
import nme.display.DisplayObjectContainer;
import nme.Assets;
import nme.display.Graphics;
import nme.geom.Point;
import nme.geom.Rectangle;

import com.stencyl.Input;
import com.stencyl.Engine;

import com.stencyl.graphics.G;
import com.stencyl.graphics.AbstractAnimation;
import com.stencyl.graphics.BitmapAnimation;
import com.stencyl.graphics.SheetAnimation;

import com.stencyl.behavior.Behavior;
import com.stencyl.behavior.BehaviorManager;

import com.stencyl.models.actor.Group;
import com.stencyl.models.actor.Collision;
import com.stencyl.models.actor.CollisionPoint;
import com.stencyl.models.actor.AngleHolder;
import com.stencyl.models.actor.ActorType;
import com.stencyl.models.scene.ActorInstance;
import com.stencyl.models.actor.Animation;
import com.stencyl.models.GameModel;

import com.stencyl.utils.Utils;
import com.stencyl.utils.HashMap;

import com.eclecticdesignstudio.motion.Actuate;
import com.eclecticdesignstudio.motion.easing.Back;
import com.eclecticdesignstudio.motion.easing.Cubic;
import com.eclecticdesignstudio.motion.easing.Elastic;
import com.eclecticdesignstudio.motion.easing.Expo;
import com.eclecticdesignstudio.motion.easing.Linear;
import com.eclecticdesignstudio.motion.easing.Quad;
import com.eclecticdesignstudio.motion.easing.Quart;
import com.eclecticdesignstudio.motion.easing.Quint;
import com.eclecticdesignstudio.motion.easing.Sine;

import box2D.dynamics.B2Body;
import box2D.dynamics.B2BodyDef;
import box2D.dynamics.B2Fixture;
import box2D.dynamics.B2FixtureDef;
import box2D.dynamics.B2World;
import box2D.collision.shapes.B2Shape;
import box2D.collision.shapes.B2PolygonShape;
import box2D.collision.shapes.B2MassData;
import box2D.dynamics.contacts.B2Contact;
import box2D.dynamics.contacts.B2ContactEdge;
import box2D.common.math.B2Vec2;
import box2D.common.math.B2Transform;
import box2D.collision.B2WorldManifold;

import com.stencyl.models.collision.Mask;
import com.stencyl.models.collision.Hitbox;

import nme.filters.BitmapFilter;

#if flash
import flash.filters.ColorMatrixFilter;
import com.stencyl.utils.ColorMatrix;
#end


class Actor extends Sprite 
{	
	//*-----------------------------------------------
	//* Globals
	//*-----------------------------------------------
	
	private var engine:Engine;
	

	//*-----------------------------------------------
	//* Properties
	//*-----------------------------------------------
	
	public var ID:Int;
	public var groupID:Int;
	public var layerID:Int;
	public var typeID:Int;
	public var type:ActorType;
	
	private var groupsToCollideWith:Array<Int>; //cached value
	
	public static var GROUP_OFFSET:Int = 1000000; //for collision reporting
	
	
	//*-----------------------------------------------
	//* States
	//*-----------------------------------------------

	public var recycled:Bool;
	public var paused:Bool;
	
	public var isRegion:Bool;
	public var isTerrainRegion:Bool;
	public var isTerrain:Bool;

	public var destroyed:Bool;	
	public var drawActor:Bool;	
	public var isHUD:Bool;
	public var alwaysSimulate:Bool;
	
	public var isCamera:Bool;
	public var killLeaveScreen:Bool;	
	public var isLightweight:Bool;
	public var autoScale:Bool;
	
	public var dead:Bool; //gone from the game - don't touch
	public var dying:Bool; //in the process of dying but not yet removed
	
	public var fixedRotation:Bool;
	public var ignoreGravity:Bool;
	public var collidable:Bool;
	public var solid:Bool; //for non Box2D collisions
	

	//*-----------------------------------------------
	//* Position / Motion
	//*-----------------------------------------------
	
	public var originX:Float;
	public var originY:Float;
	
	public var realX:Float;
	public var realY:Float;

	public var xSpeed:Float;
	public var ySpeed:Float;
	public var rSpeed:Float;
	
	public var tweenLoc:Point;
	public var tweenAngle:AngleHolder;
	public var activeAngleTweens:Int;
	public var activePositionTweens:Int;
	
	//Cache values
	public var cacheX:Float;
	public var cacheY:Float;
	public var cacheWidth:Float;
	public var cacheHeight:Float;
	
	
	//*-----------------------------------------------
	//* Sprite-Based Animation
	//*-----------------------------------------------
	
	public var currAnimationAsAnim:AbstractAnimation;
	public var currAnimation:DisplayObject;
	public var currAnimationName:String;
	public var animationMap:Hash<DisplayObject>;
	
	public var sprite:com.stencyl.models.actor.Sprite;
	
	public var shapeMap:Hash<Dynamic>;
	public var originMap:Hash<Dynamic>;
	public var defaultAnim:String;
	
	public var currOrigin:Point;
	public var currOffset:Point;
	
	
	//*-----------------------------------------------
	//* Behaviors
	//*-----------------------------------------------
	
	public var behaviors:BehaviorManager;
	
	
	//*-----------------------------------------------
	//* Actor Values
	//*-----------------------------------------------
	
	public var registry:Hash<Dynamic>;

	
	//*-----------------------------------------------
	//* Events
	//*-----------------------------------------------	
	
	public var allListeners:HashMap<Dynamic,Dynamic>;
	public var allListenerReferences:Array<Dynamic>;
	
	public var whenCreatedListeners:Array<Dynamic>;
	public var whenUpdatedListeners:Array<Dynamic>;
	public var whenDrawingListeners:Array<Dynamic>;
	public var whenKilledListeners:Array<Dynamic>;		
	public var mouseOverListeners:Array<Dynamic>;
	public var positionListeners:Array<Dynamic>;
	public var collisionListeners:Array<Dynamic>;
	
	public var mouseState:Int;
	public var lastScreenState:Bool;
	public var lastSceneState:Bool;
	
	
	//*-----------------------------------------------
	//* Physics (Box2D)
	//*-----------------------------------------------
	
	public var body:B2Body;
	public var bodyDef:B2BodyDef;
	public var md:B2MassData;
	public var bodyScale:Point;
	
	public var handlesCollisions:Bool;
	public var contacts:IntHash<B2Contact>;
	public var regionContacts:IntHash<B2Contact>;
	public var collisions:IntHash<Collision>;
	
	private var dummy:B2Vec2;
	private var zero:B2Vec2;
	

	//*-----------------------------------------------
	//* Collisions
	//*-----------------------------------------------

	public static var lastCollided:Actor;

	
	
	//*-----------------------------------------------
	//* Init
	//*-----------------------------------------------

	public function new
	(
		engine:Engine, 
		ID:Int,
		groupID:Int,
		x:Float=0, 
		y:Float=0, 
		layerID:Int=0,
		width:Float=32, 
		height:Float=32,
		sprite:com.stencyl.models.actor.Sprite=null,
		behaviorValues:Hash<Dynamic>=null,
		actorType:ActorType=null,
		bodyDef:B2BodyDef=null,
		isSensor:Bool=false,
		isStationary:Bool=false,
		isKinematic:Bool=false,
		canRotate:Bool=false,
		shape:Dynamic=null, //B2Shape or Mask - Used only for terrain.
		typeID:Int = 0,
		isLightweight:Bool=false,
		autoScale:Bool=true
	)
	{
		super();
		
		//---
		
		dummy = new B2Vec2();
		zero = new B2Vec2(0, 0);
		
		_point = Utils.point;
		_moveX = _moveY = 0;
		
		HITBOX = new Mask();
		HITBOX.assignTo(this);
		
		if(Std.is(this, Region) && Engine.NO_PHYSICS)
		{
			shape = new Hitbox(Std.int(width), Std.int(height));
			setShape(shape);
		}
		
		//---
		
		this.x = 0;
		this.y = 0;
		this.rotation = 0;
		
		realX = 0;
		realY = 0;
		
		originX = 0;
		originY = 0;
		collidable = true;
		solid = true;
		
		if(isLightweight)
		{
			this.x = x * Engine.physicsScale;
			this.y = y * Engine.physicsScale;
		}
		
		else
		{
			this.x = x;
			this.y = y;
		}

		realX = x;
		realY = y;

		activeAngleTweens = 0;
		activePositionTweens = 0;
		
		//---
		
		tweenLoc = new Point(0, 0);
		tweenAngle = new AngleHolder();
		
		currOrigin = new Point(0, 0);
		currOffset = new Point(0, 0);			
		registry = new Hash<Dynamic>();
		
		this.isLightweight = isLightweight;
		this.autoScale = autoScale;
		xSpeed = 0;
		ySpeed = 0;
		rSpeed = 0;
		
		mouseState = 0;
		
		lastScreenState = false;
		lastSceneState = false;			
		
		isCamera = false;
		isRegion = false;
		isTerrainRegion = false;
		drawActor = true;
		
		killLeaveScreen = false;
		alwaysSimulate = false;
		isHUD = false;

		fixedRotation = false;
		ignoreGravity = false;
		
		//---
		
		resetListeners();
		
		//---
		
		this.recycled = false;
		this.paused = false;
		this.destroyed = false;
		
		this.name = "Unknown";
		this.ID = ID;
		this.groupID = groupID;
		this.layerID = layerID;
		this.typeID = typeID;
		this.engine = engine;
		
		groupsToCollideWith = GameModel.get().groupsCollidesWith.get(groupID);
		
		collisions = new IntHash<Collision>();
		contacts = new IntHash<B2Contact>();
		regionContacts = new IntHash<B2Contact>();
		
		handlesCollisions = true;
		
		//---
		
		behaviors = new BehaviorManager();
		
		//---
		
		currAnimationName = "";
		animationMap = new Hash<DisplayObject>();
		shapeMap = new Hash<Dynamic>();
		originMap = new Hash<Dynamic>();
		
		this.sprite = sprite;
		
		//---
		
		if(sprite != null)
		{
			var s:com.stencyl.models.actor.Sprite = cast(Data.get().resources.get(actorType.spriteID), com.stencyl.models.actor.Sprite);
			
			if(s != null)
			{
				this.type = cast(Data.get().resources.get(typeID), ActorType);
				
				var defaultAnim:String = "";
				
				for(a in s.animations)
				{
					addAnim
					(
						a.animName, 
						a.imgData, 
						a.framesAcross, 
						Math.floor(a.imgWidth / a.framesAcross), 
						Math.floor(a.imgHeight / a.framesDown), 
						a.originX,
						a.originY,
						a.durations, 
						a.looping,
						a.shapes
					);
					
					if(a.animID == s.defaultAnimation)
					{
						defaultAnim = a.animName;
					}
				}
			}
		}
		
		//--
		
		addAnim("recyclingDefault", null, 1, 1, 1, 1, 1, [1000], false, null);

		if(bodyDef != null && !isLightweight)
		{
			if(bodyDef.bullet)
			{
				B2World.m_continuousPhysics = true;
			}
			
			bodyDef.groupID = groupID;

			initFromBody(bodyDef);	
			
			//XXX: Box2D seems to require this to be done, otherwise it will refuse to create any shapes in the future!
			var box = new B2PolygonShape();
			box.setAsBox(1, 1);
			body.createFixture2(box, 0.1);
			
			md = new B2MassData();
			md.mass = bodyDef.mass;
			md.I = bodyDef.aMass;
			md.center.x = 0;
			md.center.y = 0;
			
			body.setMassData(md);
			bodyScale = new Point(1, 1);
		}
		
		else
		{
			if(shape == null)
			{
				shape = createBox(width, height);
			}
			
			if(Std.is(this, Region))
			{
				isSensor = true;
				canRotate = false;
			}
			
			if(Std.is(this, Terrain))
			{
				canRotate = false;
			}
			
			if(shape != null && Std.is(shape, com.stencyl.models.collision.Mask))
			{
				setShape(shape);
				isTerrain = true;
			}
			
			else if(!isLightweight)
			{
				initBody(groupID, isSensor, isStationary, isKinematic, canRotate, shape);
			}
		}

		switchToDefaultAnimation();
		
		//Use set location to align actors
		if(sprite != null)
		{ 
			setLocation(Engine.toPixelUnits(x), Engine.toPixelUnits(y));
		}
		
		else
		{
			if(shape != null && Std.is(shape, com.stencyl.models.collision.Mask))
			{
				//TODO: Very inefficient for CPP/mobile - can we force width/height a different way?
				var dummy = new Bitmap(new BitmapData(1, 1, true, 0));
				dummy.x = width;
				dummy.y = height;
				addChild(dummy);
				this.width = width;
				this.height = height;
			}
			
			else if(!isLightweight)
			{
				body.setPosition(new B2Vec2(x, y));
			}
		}
		
		//No IC - Default to what the ActorType uses
		if(behaviorValues == null && actorType != null)
		{
			behaviorValues = actorType.behaviorValues;
		}

		Engine.initBehaviors(behaviors, behaviorValues, this, engine, false);
	}	
	
	public function destroy()
	{
		if(destroyed)
		{
			return;
		}
		
		destroyed = true;
		
		for(anim in animationMap)
		{
			anim.visible = false;
		}
		
		Utils.removeAllChildren(this);

		if(body != null && !isLightweight)
		{
			var contact:B2ContactEdge = body.getContactList();
			
			while(contact != null)
			{	
				Engine.engine.world.m_contactManager.m_contactListener.endContact(contact.contact);
				contact = contact.next;
			}
			
			Engine.engine.world.destroyBody(body);
		}			
		
		lastCollided = null;
		
		shapeMap = null;
		originMap = null;
		defaultAnim = null;
		animationMap = null;
		currAnimationAsAnim = null;
		currAnimation = null;
		currOffset = null;
		currOrigin = null;
		body = null;
		sprite = null;
		contacts = null;
		regionContacts = null;
		
		whenCreatedListeners = null;
		whenUpdatedListeners = null;
		whenDrawingListeners = null;
		whenKilledListeners = null;
		mouseOverListeners = null;
		positionListeners = null;
		
		registry = null;
		
		collisions = null;
		
		behaviors.destroy();
	}
	
	public function resetListeners()
	{
		allListeners = new HashMap<Dynamic, Dynamic>();
		allListenerReferences = new Array<Dynamic>();
		
		whenCreatedListeners = new Array<Dynamic>();
		whenUpdatedListeners = new Array<Dynamic>();
		whenDrawingListeners = new Array<Dynamic>();
		whenKilledListeners = new Array<Dynamic>();
		mouseOverListeners = new Array<Dynamic>();
		positionListeners = new Array<Dynamic>();
		collisionListeners = new Array<Dynamic>();
	}
	
	public function addAnim
	(
		name:String, 
		imgData:BitmapData, 
		frameCount:Int=1, 
		frameWidth:Int=0, 
		frameHeight:Int = 0, 
		originX:Float = 0,
		originY:Float = 0,
		durations:Array<Int>=null, 
		looping:Bool=true, 
		shapes:IntHash<B2FixtureDef>=null
	)
	{
		if(shapes != null)
		{
			var arr = new Array<B2FixtureDef>();
			
			for(s in shapes)
			{
				arr.push(s);
			}
			
			shapeMap.set(name, arr);
		}
	
		if(imgData == null)
		{
			animationMap.set(name, new Sprite());
			return;
		}
	
		#if cpp
		var tilesheet = new Tilesheet(imgData);
		
		for(i in 0...frameCount)
		{
			tilesheet.addTileRect(new nme.geom.Rectangle(frameWidth * i, 0, frameWidth, frameHeight)); 	
		}
		 	
		var sprite = new SheetAnimation(tilesheet, durations, frameWidth, frameHeight);
		animationMap.set(name, sprite);
		#end
		
		#if (flash || js)
		var sprite = new BitmapAnimation(imgData, frameCount, durations);
		animationMap.set(name, sprite);
		#end	
	}
	
	public function initScripts()
	{		
		handlesCollisions = true;
		behaviors.initScripts();
		
		var r = 0;
		
		while(r < whenCreatedListeners.length)
		{
			try
			{
				var f:Array<Dynamic>->Void = whenCreatedListeners[r];			
				f(whenCreatedListeners);
				
				if(Utils.indexOf(whenCreatedListeners, f) == -1)
				{
					r--;
				}
			}
			
			catch(e:String)
			{
				trace(e);
			}
			
			r++;
		}			
	}
	
	static public function createBox(width:Float, height:Float):B2PolygonShape
	{
		var boxShape:B2PolygonShape = new B2PolygonShape();
		boxShape.setAsBox(Engine.toPhysicalUnits(width/2), Engine.toPhysicalUnits(height/2));
		return boxShape;
	}
	
	private function initFromBody(bodyDef:B2BodyDef)
	{	
		bodyDef.allowSleep = false;
		bodyDef.userData = this;
		this.bodyDef = bodyDef;
		body = Engine.engine.world.createBody(bodyDef);
	}

	private function initBody(groupID:Int, isSensor:Bool, isStationary:Bool, isKinematic:Bool, canRotate:Bool, shape:Dynamic)
	{			
		var bodyDef:B2BodyDef = new B2BodyDef();
		
		bodyDef.groupID = groupID;
		bodyDef.position.x = Engine.toPhysicalUnits(x);
		bodyDef.position.y = Engine.toPhysicalUnits(y);
			
		bodyDef.angle = 0;
		bodyDef.fixedRotation = !canRotate;
		bodyDef.allowSleep = false;

		if(isStationary)
		{
			bodyDef.type = B2Body.b2_staticBody;
		}
		
		else if(isKinematic)
		{
			bodyDef.type = B2Body.b2_kinematicBody;
		}
		
		else
		{
			bodyDef.type = B2Body.b2_dynamicBody;
		}
		
		if(Std.is(shape, Array))
		{
			bodyDef.userData = this;
			body = Engine.engine.world.createBody(bodyDef);			
				
			var arr:Array<Dynamic> = cast(shape, Array<Dynamic>);
		
			for(item in arr)
			{
				var fixtureDef:B2FixtureDef = new B2FixtureDef();
				fixtureDef.shape = item;
				fixtureDef.friction = 1.0;
				fixtureDef.density = 0.1;
				fixtureDef.restitution = 0;
				fixtureDef.isSensor = false;
				fixtureDef.groupID = GameModel.TERRAIN_ID;
				fixtureDef.userData = this;
							
				body.createFixture(fixtureDef);
			}
		}

		else
		{
			var fixtureDef:B2FixtureDef = new B2FixtureDef();
			fixtureDef.shape = shape;
			fixtureDef.friction = 1.0;
			fixtureDef.density = 0.1;
			fixtureDef.restitution = 0;
			fixtureDef.isSensor = isSensor;
			fixtureDef.groupID = -1000;
			fixtureDef.userData = this;
						
			bodyDef.userData = this;
			body = Engine.engine.world.createBody(bodyDef);			
			body.createFixture(fixtureDef);
		}

		this.bodyDef = bodyDef;
	}   	
   	
   	//*-----------------------------------------------
	//* Animation
	//*-----------------------------------------------
   	
	public function addAnimation(name:String, sprite:DisplayObject)
	{
		animationMap.set(name, sprite);
	}
	
	public function getAnimation():String
	{
		return currAnimationName;
	}
	
	public function setAnimation(name:String)
	{
		switchAnimation(name);
	}
	
	public function switchToDefaultAnimation()
	{
		if(sprite != null && sprite.animations.size > 0)
		{
			var anim = sprite.animations.get(sprite.defaultAnimation);
		
			//In case the animation ID is bogus...
			if(anim == null)
			{
				for(a in sprite.animations)
				{
					anim = a;
					break;
				}
			}
			
			defaultAnim = cast(anim, Animation).animName;
			switchAnimation(defaultAnim);
			setCurrentFrame(0);
		}
	}
	
	public function isAnimationPlaying():Bool
	{
		if(Std.is(currAnimation, AbstractAnimation))
		{
			return !cast(currAnimation, AbstractAnimation).isFinished();
		}
		
		else
		{
			return true;
		}
	}
	
	public function getCurrentFrame():Int
	{
		if(Std.is(currAnimation, AbstractAnimation))
		{
			return cast(currAnimation, AbstractAnimation).getCurrentFrame();
		}
		
		else
		{
			return 0;
		}
	}
	
	public function setCurrentFrame(frame:Int)
	{
		if(Std.is(currAnimation, AbstractAnimation))
		{
			cast(currAnimation, AbstractAnimation).setFrame(frame);
		}
	}
	
	public function getNumFrames():Int
	{
		if(Std.is(currAnimation, AbstractAnimation))
		{
			return cast(currAnimation, AbstractAnimation).getNumFrames();
		}
		
		else
		{
			return 0;
		}
	}
	
	public function switchAnimation(name:String)
	{
		if(name != currAnimationName)
		{
			var newAnimation = animationMap.get(name);
			
			if(newAnimation == null)
			{
				return;
			}
			
			if(currAnimation != null)
			{
				removeChild(currAnimation);
			}
			
			currAnimationName = name;
			currAnimation = newAnimation;
			
			currAnimationAsAnim = cast(currAnimation, AbstractAnimation);
			
			addChild(newAnimation);
			
			//----------------
			
			//var animOrigin:V2 = originMap[name];		
			
			if(!isLightweight)
			{
				updateTweenProperties();
			}
			
			//var centerx = (currSprite.width / 2) - animOrigin.x;
			//var centery = (currSprite.height / 2) - animOrigin.y;
			
			if(body != null && !isLightweight)
			{
				//Remember regions
				var regions = new Array<Region>();
			
				//BEGIN EXPLICIT ENDCONTACT HACK
				//SECRET/showthread.php?tid=9564
				var contact = body.getContactList();
				
				while(contact != null)
				{
					if(Std.is(contact.other.getUserData(), Region) && contact.contact.isTouching())
					{
						regions.push(contact.other.getUserData());
					}
					
					Engine.engine.world.m_contactManager.m_contactListener.endContact(contact.contact);
					contact = contact.next;
				}
				
				//Catch any residual contacts.
				//SECRET/showthread.php?tid=9773&page=3
				for(k in collisions.keys()) 
				{
					collisions.remove(k);
				}
				
				collisions = new IntHash<Collision>();
				contacts = new IntHash<B2Contact>();
				regionContacts = new IntHash<B2Contact>();
				//END HACK

				while(body.m_fixtureCount > 0)
				{			
					body.DestroyFixture(body.getFixtureList());
				}
				
				for(f in cast(shapeMap.get(name), Array<Dynamic>))
				{
					var originFixDef = new B2FixtureDef();
					
					if(bodyDef.friction < Utils.NUMBER_MAX_VALUE)
					{
						originFixDef.friction = bodyDef.friction;
						originFixDef.restitution = bodyDef.bounciness;							
						
						if(bodyDef.mass > 0)
						{
							originFixDef.density = 0.1;//bodyDef.mass;
						}
					}
					
					originFixDef.density = f.density;						
					originFixDef.isSensor = f.isSensor;
					originFixDef.groupID = f.groupID;
					originFixDef.shape = f.shape;

					//TODO: Origin point junk goes here
					
					var fix = body.createFixture(originFixDef);
					fix.SetUserData(this);	
				}
				
				if(body.getFixtureList() != null)
				{
					bodyScale.x = 1;
					bodyScale.y = 1;
			
					for(r in regions)
					{
						var mine = body.getFixtureList().m_aabb;
						var other = r.getBody().getFixtureList().m_aabb;
						
						if(other.testOverlap(mine))
						{
							r.addActor(this);
						}
					}
				}
				
				if(md != null)
				{
					body.setMassData(md);
				}
			}	
			
			//Origin setter
			/*if(animOrigin != null)
			{	
				setOriginPoint(animOrigin.x, animOrigin.y);				
			}*/
			
			//----------------
			
			if(Std.is(currAnimation, AbstractAnimation))
			{
				cast(currAnimation, AbstractAnimation).reset();
			}
			
			//----------------
			
			//TEMP: Origin = Center
			//originX = Math.floor(newAnimation.width/2);
			//originY = Math.floor(newAnimation.height/2);
			
			//this.x = realX + Math.floor(newAnimation.width/2);
			//this.y = realY + Math.floor(newAnimation.height/2);
			
			cacheWidth = getWidth();
			cacheHeight = getHeight();
			cacheX = getX();
			cacheY = getY();
		}
	}
	
	//*-----------------------------------------------
	//* Events - Update
	//*-----------------------------------------------
	
	public function update(elapsedTime:Float)
	{
		innerUpdate(elapsedTime, true);
	}
	
	//mouse/col/screen checks kill 5 FPS (is it even active?)
	//actor update kills 20-25 FPS (!!)
	//internal update kills 5 FPS
	public function innerUpdate(elapsedTime:Float, hudCheck:Bool)
	{
		//HUD / always simulate actors are updated separately to prevent double updates.
		if(paused || isCamera || dying || dead || destroyed || hudCheck && (isHUD || alwaysSimulate))
		{
			return;
		}
		
		if(mouseOverListeners.length > 0)
		{
			//Previously was checkMouseState() - inlined for performance. See Region:innerUpdate for other instance
			var mouseOver:Bool = isMouseOver();
				
			if(mouseState <= 0 && mouseOver)
			{
				//Just Entered
				mouseState = 1;
			}
					
			else if(mouseState >= 1 && mouseOver)
			{
				//Over
				mouseState = 2;
						
				if(Input.mousePressed)
				{
					//Clicked On
					mouseState = 3;
				}
						
				else if(Input.mouseDown)
				{
					//Dragged
					mouseState = 4;
				}
						
				if(Input.mouseReleased)
				{
					//Released
					mouseState = 5;
				}
			}
					
			else if(mouseState > 0 && !mouseOver)
			{
				//Just Exited
				mouseState = -1;
			}
				
			else if(mouseState == -1 && !mouseOver)
			{
				mouseState = 0;
			}	
			
			Engine.invokeListeners2(mouseOverListeners, mouseState);
		}
		
		var checkType = type.ID;
		var groupType = GROUP_OFFSET + groupID;
		
		var ec = engine.collisionListeners;
		var ep = engine.typeGroupPositionListeners;
				
		if(!isLightweight)
		{
			//TODO: .length is a function call, degrades performance on mobile by 2-3 FPS
			if(collisionListeners.length > 0 || 
			   ec.exists(checkType) || 
			   ec.exists(groupType)) 
			{
				handleCollisions();		
			}
		}

		internalUpdate(elapsedTime, true);
		Engine.invokeListeners2(whenUpdatedListeners, elapsedTime);		

		//TODO: .length is a function call, degrades performance on mobile by 2-3 FPS
		if(positionListeners.length > 0 || 
		   ep.exists(checkType) || 
		   ep.exists(groupType))
		{
			checkScreenState();
		}
	}
	
	//doAll prevents super.update from being called, which can often muck with
	//animations happening if they are updated before play() is called.
	public function internalUpdate(elapsedTime:Float, doAll:Bool)
	{
		if(paused)
		{
			return;
		}
		
		//TODO: Actor now off by half in no-physics mode :(	
		if(isLightweight)
		{		
			if(xSpeed != 0 || ySpeed != 0)
			{
				moveActorBy(elapsedTime * xSpeed * 0.01, elapsedTime * ySpeed * 0.01, groupsToCollideWith);
				
				cacheX = x;
				cacheY = y;
			}
			
			if(rSpeed != 0)
			{
				this.rotation += elapsedTime * rSpeed;
			}
			
			if(fixedRotation)
			{
				this.rotation = 0;
				this.rSpeed = 0;
			}
		}
		
		else
		{
			var p = body.getPosition();
					
			//x = Math.round(p.x * Engine.physicsScale - Math.floor(width / 2) - currOffset.x);
			//y = Math.round(p.y * Engine.physicsScale - Math.floor(height / 2) - currOffset.y);	
			
			cacheX = x = Math.round(p.x * Engine.physicsScale);
			cacheY = y = Math.round(p.y * Engine.physicsScale);		
			
			#if js
			//TODO: Flawed - it rotates by top left corner
			currAnimation.rotation = body.getAngle() * Utils.DEG;
			
			//Goes haywire with this :(
			//rotation = body.getAngle() * Utils.DEG;
			#end
			
			#if !js
			rotation = body.getAngle() * Utils.DEG;
			#end
			
			//TODO: Why isn't this above too?
			if(isHUD)
			{
				transform.matrix.identity();
				transform.matrix.translate(Engine.cameraX, Engine.cameraY);
			}
		}
		
		if(doAll)
		{
   			//This may be a slowdown on iOS by 3-5 FPS due to clear and redraw?
   			currAnimationAsAnim.update(elapsedTime);
		}
		
		if(!isLightweight)
		{
			updateTweenProperties();
		}
	}	
	
	private function updateTweenProperties()
	{
		//In lightweight mode, none of this junk has to happen - it just works like it should!
		if(isLightweight)
		{
			return;
		}
	
		//Since we can't tween directly on the Box2D values and can't make direct function calls,
		//we have to reverse the normal flow of information from body -> NME to tween -> body
		var a:Bool = activePositionTweens > 0;
		var b:Bool = activeAngleTweens > 0;
				
		/*if(autoScale && !isLightweight && body != null && bodyDef.type != b2Body.b2_staticBody && (bodyScale.x != currSprite.scale.x || bodyScale.y != currSprite.scale.y))
		{
			if(currSprite.scale.x > 0 && currSprite.scale.y > 0)
			{
				scaleBody(currSprite.scale.x, currSprite.scale.y);
			}
		}*/
		
		if(a && b)
		{
			//x = tweenLoc.x;
			//y = tweenLoc.y;
			//rotation = tweenAngle.angle;
			
			dummy.x = Engine.toPhysicalUnits(x);
			dummy.y = Engine.toPhysicalUnits(y);
			
			body.setPositionAndAngle
			(
				dummy,
				Utils.RAD * rotation
			);
		}
		
		else
		{
			if(a)
			{
				setX(tweenLoc.x);
				setY(tweenLoc.y);
			}
			
			if(b)
			{
				setAngle(tweenAngle.angle, false);
			}
		}
	}
		
	//*-----------------------------------------------
	//* Events - Other
	//*-----------------------------------------------
	
	public function scaleBody(width:Float, height:Float)
	{
		/*var fixtureList:Array = new Array;

		for(var fixture:b2Fixture = getBody().GetFixtureList(); fixture; fixture = fixture.GetNext())
		{
			fixtureList.push(fixture);
		}
			
		for each(var f:b2Fixture in fixtureList)
		{ 
			var poly:b2Shape = f.GetShape();
			var center:V2 = getBody().GetLocalCenter();
			if(poly instanceof b2CircleShape)
			{
				var factor:Number = (1 / bodyScale.x) * width;					
				
				var p:V2 = (poly as b2CircleShape).m_p.v2;
				var positionVector:V2 = V2.subtract(p, center);
				positionVector.x = positionVector.x * factor;
				positionVector.y = positionVector.y * factor;	
				
				(poly as b2CircleShape).m_p.v2 = V2.add(center, positionVector);
				poly.m_radius = poly.m_radius * factor;								
			}

			if(poly instanceof b2PolygonShape)
			{
  				var verts:Vector.<V2> = (poly as b2PolygonShape).m_vertices;
				var newVerts:Vector.<V2> = new Vector.<V2>();

				for each(var v:V2 in verts)
				{
					var positionVector:V2 = V2.subtract(v,center);
					positionVector.x = positionVector.x * (1 / bodyScale.x) * width;
					positionVector.y = positionVector.y * (1 / bodyScale.y) * height;	
					var newV2:V2 = V2.add(center, positionVector);

					newVerts.push(newV2);
				}

				(poly as b2PolygonShape).Set(newVerts);   					
			}
		}	
		
		bodyScale.x = width;
		bodyScale.y = height;*/
	}
	
	private function checkScreenState()
	{
		var onScreen:Bool = isOnScreen();
		var inScene:Bool = onScreen || isInScene();
		
		var enteredScreen:Bool = !lastScreenState && onScreen;
		var enteredScene:Bool = !lastSceneState && inScene;
		var exitedScreen:Bool = lastScreenState && !onScreen;
		var exitedScene:Bool = lastSceneState && !inScene;
		
		Engine.invokeListeners5(positionListeners, enteredScreen, exitedScreen, enteredScene, exitedScene);
		
		var typeListeners = cast(engine.typeGroupPositionListeners.get(groupID), Array<Dynamic>);
		var groupListeners = cast(engine.typeGroupPositionListeners.get(typeID), Array<Dynamic>);
		
		if(typeListeners != null)
		{
			Engine.invokeListeners6(typeListeners, this, enteredScreen, exitedScreen, enteredScene, exitedScene);
		}
		
		if(groupListeners != null)
		{
			Engine.invokeListeners6(groupListeners, this, enteredScreen, exitedScreen, enteredScene, exitedScene);
		}
		
		lastScreenState = onScreen;
		lastSceneState = inScene;
	}
		
	//*-----------------------------------------------
	//* Collision
	//*-----------------------------------------------
	
	private function handleCollisions()
	{		
		var otherActor:Actor;
		var otherShape:B2Fixture;
		var thisShape:B2Fixture;
		//var manifold = new B2WorldManifold();
				
		for(p in contacts)
		{
			var a1 = cast(p.getFixtureA().getUserData(), Actor);
			var a2 = cast(p.getFixtureB().getUserData(), Actor);
			var key = p.key;
				
			if(a1 == this)
			{
				otherActor = a2;
				otherShape = p.getFixtureB();
				thisShape = p.getFixtureA();
			}
			
			else
			{
				otherActor = a1;
				otherShape = p.getFixtureA();
				thisShape = p.getFixtureB();
			}
							
			if(collisions.exists(key))
			{
				continue;
			}
			
			//TODO: roll this out and reuse instead
			var d:Collision = new Collision();
			d.otherActor = otherActor;
			d.otherShape = otherShape;
			d.thisActor = this;
			d.thisShape = thisShape;
			d.actorA = a1;
			d.actorB = a2;
			
			//TODO: Don't remake this each loop! Is there a side-effect to that?
			var manifold = new B2WorldManifold();
			p.getWorldManifold(manifold);
			
			var cp = new CollisionPoint(manifold.getPoint(), manifold.m_normal);

			collisions.set(key, d);
			
			if(cp.point != null)
			{
				d.points.push(cp);
				
				d.thisFromBottom = collidedFromBottom(p, cp.normal);					
				d.thisFromTop = collidedFromTop(p, cp.normal);						
				d.thisFromLeft = collidedFromLeft(p, cp.normal);					
				d.thisFromRight = collidedFromRight(p, cp.normal);		
				
				d.otherFromBottom = otherActor.collidedFromBottom(p, cp.normal);					
				d.otherFromTop = otherActor.collidedFromTop(p, cp.normal);						
				d.otherFromLeft = otherActor.collidedFromLeft(p, cp.normal);					
				d.otherFromRight = otherActor.collidedFromRight(p, cp.normal);
			}
			
			//Can use logical OR assignment shortcut if we switch back to multipoint collisions
			d.thisCollidedWithActor = collidedWithActor(otherActor);						
			d.thisCollidedWithTerrain = collidedWithTerrain(otherActor);				
			d.thisCollidedWithTile = collidedWithTile(otherActor);
			d.thisCollidedWithSensor = otherShape.isSensor();		
			
			d.otherCollidedWithActor = collidedWithActor(this);						
			d.otherCollidedWithTerrain = collidedWithTerrain(this);				
			d.otherCollidedWithTile = collidedWithTile(this);
			d.otherCollidedWithSensor = thisShape.isSensor();		
		}
		
		for(collision in collisions)
		{
			if
			(
			   collision == null || collision.thisActor == null || collision.otherActor == null ||
			   !collision.thisActor.handlesCollisions || 
			   !collision.otherActor.handlesCollisions)
			{
				continue;
			}
			
			lastCollided = collision.otherActor;
			Engine.invokeListeners2(collisionListeners, collision);
			
			engine.handleCollision(this, collision);	
		}
		
		//TODO: Can we avoid remaking this?
		contacts = new IntHash<B2Contact>();
	}
	
	public function collidedFromBottom(c:B2Contact, normal:B2Vec2):Bool
	{
		var thisActor:Actor = this;
		var body = thisActor.getBody();	
		var body1 = c.getFixtureA().getBody();
		var body2 = c.getFixtureB().getBody();

		if(body1 == body)
		{
			return normal.y > 0;
		}
		
		if(body2 == body)
		{
			return normal.y < 0;
		}

		return false;
	}
	
	public function collidedFromTop(c:B2Contact, normal:B2Vec2):Bool
	{
		var thisActor:Actor = this;
		var body = thisActor.getBody();	
		var body1 = c.getFixtureA().getBody();
		var body2 = c.getFixtureB().getBody();
		
		if(body1 == body)
		{
			return normal.y < 0;
		}
		
		if(body2 == body)
		{
			return normal.y > 0;
		}
		
		return false;
	}
	
	public function collidedFromLeft(c:B2Contact, normal:B2Vec2):Bool
	{
		var thisActor:Actor = this;
		var body = thisActor.getBody();	
		var body1 = c.getFixtureA().getBody();
		var body2 = c.getFixtureB().getBody();
		
		if(body1 == body)
		{
			return normal.x < 0;
		}
		
		if(body2 == body)
		{
			return normal.x > 0;
		}
		
		return false;
	}
	
	public function collidedFromRight(c:B2Contact, normal:B2Vec2):Bool
	{
		var thisActor:Actor = this;
		var body = thisActor.getBody();	
		var body1 = c.getFixtureA().getBody();
		var body2 = c.getFixtureB().getBody();
		
		if(body1 == body)
		{
			return normal.x > 0;
		}
		
		if(body2 == body)
		{
			return normal.x < 0;
		}
		
		return false;
	}
	
	private function collidedWithActor(a:Actor):Bool
	{
		if(a != null)
		{
			return a.groupID != 1 && a.groupID != -2 && !a.isTerrainRegion; //not tile, region, or terrain
		}
		
		return false;
	}
	
	private function collidedWithTerrain(a:Actor):Bool
	{
		if(a != null)
		{
			return a.isTerrainRegion;   //Terrain Region?
		}
		
		return false;
	}
	
	private function collidedWithTile(a:Actor):Bool
	{
		if(a != null)
		{
			return a.groupID == 1; //Game.TILE_GROUP_ID;
		}
		
		return false;
	}
	
	public inline function addContact(point:B2Contact)
	{
		if(contacts != null)
		{
			contacts.set(point.key, point);
			collisions.remove(point.key);
		}
	}
	
	public inline function removeContact(point:B2Contact)
	{
		if(collisions != null)
		{
			collisions.remove(point.key);
		}
		
		if(contacts != null)
		{
			contacts.remove(point.key);
		}
	}
	
	public inline function addRegionContact(point:B2Contact)
	{
		if(regionContacts != null)
		{
			regionContacts.set(point.key, point);
		}			
	}
	
	public inline function removeRegionContact(point:B2Contact)
	{
		if(regionContacts != null)
		{
			regionContacts.remove(point.key);
		}
	}
	
	//*-----------------------------------------------
	//* Properties
	//*-----------------------------------------------
	
	public function getID():Int
	{
		return ID;
	}
	
	public function getName():String
	{
		return name;
	}
	
	public function getGroupID():Int
	{
		if(isLightweight)
		{
			return groupID;
		}
		
		else
		{
			return body.groupID;
		}
	}
	
	public function getLayerID():Int
	{
		return layerID;
	}
	
	public function getLayerOrder():Int
	{
		return engine.getOrderForLayerID(layerID) + 1;
	}
	
	public function getType():ActorType
	{
		if(typeID == -1)
		{
			return null;
		}
		
		return cast(Data.get().resources.get(typeID), ActorType);
	}
		
	//*-----------------------------------------------
	//* State
	//*-----------------------------------------------
		
	public function isPausable():Bool
	{
		return getType().pausable;
	}
	
	public function isPaused():Bool
	{
		return paused;
	}
	
	public function pause()
	{
		if(isPausable())
		{
			this.paused = true;
			
			if(!isLightweight)
			{
				this.body.setPaused(true);
			}
		}
	}
	
	public function unpause()
	{
		if(isPausable())
		{
			this.paused = false;
			
			if(!isLightweight)
			{
				this.body.setPaused(false);
			}
		}
	}
	
	//*-----------------------------------------------
	//* Type
	//*-----------------------------------------------
	
	public function getGroup():Group
	{
		return engine.groups.get(getGroupID());
	}
	
	public function getIsRegion():Bool
	{
		return isRegion;
	}
	
	public function getIsTerrainRegion():Bool
	{
		return isTerrainRegion;
	}
	
	//*-----------------------------------------------
	//* Layering
	//*-----------------------------------------------
	
	public function moveToLayer(layerID:Int)
	{
		engine.moveToLayer(this, layerID);
	}
	
	public function bringToFront()
	{
		engine.bringToFront(this);
	}
	
	public function bringForward()
	{
		engine.bringForward(this);
	}
	
	public function sendToBack()
	{
		engine.sendToBack(this);
	}
	
	public function sendBackward()
	{
		engine.sendBackward(this);
	}
	
	//*-----------------------------------------------
	//* Physics: Position
	//*-----------------------------------------------
	
	//Big Change: Returns relative to the origin point as (0,0). Meaning if the origin = center, the center is now (0,0)!
	
	public function getX():Float
	{
		if(!Engine.NO_PHYSICS)
		{
			if(isRegion || isTerrainRegion)
			{
				return Math.round(Engine.toPixelUnits(body.getPosition().x) - width/2);
			}
			
			else if(!isLightweight)
			{
				return Math.round(body.getPosition().x * Engine.physicsScale - Math.floor(width / 2) - currOffset.x);
			}
		}
		
		return x - currOffset.x;
	}
	
	public function getY():Float
	{
		if(!Engine.NO_PHYSICS)
		{
			if(isRegion || isTerrainRegion)
			{
				return Math.round(Engine.toPixelUnits(body.getPosition().y) - height/2);
			}
			
			else if(!isLightweight)
			{
				return Math.round(body.getPosition().y * Engine.physicsScale - Math.floor(height / 2) - currOffset.y);
			}
		}
		
		return y - currOffset.y;
	}
	
	//TODO: Eliminate?
	public function getXCenter():Float
	{
		if(!isLightweight)
		{
			return Math.round(Engine.toPixelUnits(body.getWorldCenter().x) - currOffset.x);
		}
		
		else
		{
			return x + width/2 - currOffset.x;
		}
	}
	
	//TODO: Eliminate?
	public function getYCenter():Float
	{
		if(!isLightweight)
		{
			return Math.round(Engine.toPixelUnits(body.getWorldCenter().y) - currOffset.y);
		}
		
		else
		{
			return y + height/2 - currOffset.y;
		}
	}
	
	public function getScreenX():Float
	{
		if(isHUD)
		{
			return getX();
		}
		
		else
		{
			return getX() + Engine.cameraX;
		}
	}
	
	public function getScreenY():Float
	{
		if(isHUD)
		{
			return getY();
		}
			
		else
		{
			return getY() + Engine.cameraY;
		}
	}
	
	public function setX(x:Float, resetSpeed:Bool = false)
	{
		if(isLightweight)
		{
			moveActorTo(x, y);
		}
		
		else
		{
			if(isRegion || isTerrainRegion)
			{
				dummy.x = Engine.toPhysicalUnits(x);
			}
				
			else
			{
				dummy.x = Engine.toPhysicalUnits(x + Math.floor(width/2) + currOffset.x);
			}			
			
			dummy.y = body.getPosition().y;
			
			body.setPosition(dummy);
			
			if(resetSpeed)
			{
				body.setLinearVelocity(zero);
			}
		}
	}
	
	public function setY(y:Float, resetSpeed:Bool = false)
	{
		if(isLightweight)
		{
			moveActorTo(x, y);
		}
		
		else
		{	
			if(isRegion || isTerrainRegion)
			{
				dummy.y = Engine.toPhysicalUnits(y);
			}
				
			else
			{
				dummy.y = Engine.toPhysicalUnits(y + Math.floor(height/2) + currOffset.y);
			}
			
			dummy.x = body.getPosition().x;
			
			body.setPosition(dummy);		
			
			if(resetSpeed)
			{
				body.setLinearVelocity(zero);
			}
		}
	}
	
	public function follow(a:Actor)
	{
		if(isLightweight)
		{
			moveActorTo(a.getXCenter(), a.getYCenter());	
			return;
		}
		
		body.setPosition(a.body.getWorldCenter());
	}
	
	public function followWithOffset(a:Actor, ox:Int, oy:Int)
	{
		if(isLightweight)
		{
			moveActorTo(a.getXCenter() + ox, a.getYCenter() + oy);
			return;
		}
		
		var pt:B2Vec2 = a.body.getWorldCenter();
		
		pt.x += Engine.toPhysicalUnits(ox);
		pt.y += Engine.toPhysicalUnits(oy);
		
		body.setPosition(pt);
	}
	
	public function setOriginPoint(x:Int, y:Int)
	{
		/*var resetPosition:V2;
		
		if (!isLightweight)
		{
			resetPosition = body.GetPosition();
		}
		
		else
		{
			resetPosition = new V2(GameState.toPhysicalUnits(this.x), GameState.toPhysicalUnits(this.y));
		}
		
		var offsetDiff:V2 = new V2(currOffset.x, currOffset.y);
		var radians:Number = getAngle();			
		
		var newOffX:int = x - (currSprite.width / 2);
		var newOffY:int = y - (currSprite.height / 2);
		
		if (currOrigin != null && (int(currOffset.x) != newOffX || int(currOffset.y) != newOffY) && angle != 0)
		{
			var oldAng:Number = radians + Math.atan2( -currOffset.y, -currOffset.x);
			var newAng:Number = radians + Math.atan2( -newOffY, -newOffX);
			var oldDist:Number = Math.sqrt(Math.pow(currOffset.x, 2) + Math.pow(currOffset.y, 2));
			var newDist:Number = Math.sqrt(Math.pow(newOffX, 2) + Math.pow(newOffY, 2));
							
			var oldFixCenterX:int = Math.round(currOrigin.x + Math.cos(oldAng) * oldDist);
			var oldFixCenterY:int = Math.round(currOrigin.y + Math.sin(oldAng) * oldDist);
			var newFixCenterX:int = Math.round(x + Math.cos(newAng) * newDist);
			var newFixCenterY:int = Math.round(y + Math.sin(newAng) * newDist);
						
			resetPosition.x += GameState.toPhysicalUnits(oldFixCenterX - newFixCenterX);
			resetPosition.y += GameState.toPhysicalUnits(oldFixCenterY - newFixCenterY);
		}
		
		currOrigin.x = x;
		currOrigin.y = y;
		currOffset.x = newOffX;
		currOffset.y = newOffY;		
					
		offsetDiff.x = currOffset.x - offsetDiff.x;
		offsetDiff.y = currOffset.y - offsetDiff.y;
		
		currSprite.origin.x = x;
		currSprite.origin.y = y;			
			
		resetPosition.x += GameState.toPhysicalUnits(offsetDiff.x);
		resetPosition.y += GameState.toPhysicalUnits(offsetDiff.y);
		
		if (!isLightweight)
		{
			body.SetPosition(resetPosition);
		}
		
		else
		{
			x = GameState.toPixelUnits(resetPosition.x);
			y = GameState.toPixelUnits(resetPosition.y);
		}*/
	}
	
	//*-----------------------------------------------
	//* Physics: Velocity
	//*-----------------------------------------------
	
	public function getXVelocity():Float
	{
		if(isLightweight)
		{
			return xSpeed;
		}
		
		return body.getLinearVelocity().x;
	}
	
	public function getYVelocity():Float
	{
		if(isLightweight)
		{
			return ySpeed;
		}
		
		return body.getLinearVelocity().y;
	}
	
	public function setXVelocity(dx:Float)
	{
		if(isLightweight)
		{
			xSpeed = dx;
			return;
		}
		
		var v = body.getLinearVelocity();
		v.x = dx;
		body.setLinearVelocity(v);
		body.setAwake(true);
	}
	
	public function setYVelocity(dy:Float)
	{
		if(isLightweight)
		{
			ySpeed = dy;
			return;
		}
		
		var v = body.getLinearVelocity();
		v.y = dy;
		body.setLinearVelocity(v);
		body.setAwake(true);
	}
	
	public function setVelocity(angle:Float, speed:Float)
	{
		setXVelocity(speed * Math.cos(Utils.RAD * angle));
		setYVelocity(speed * Math.sin(Utils.RAD * angle));
	}
	
	public function accelerateX(dx:Float)
	{
		setXVelocity(getXVelocity() + dx);
	}
	
	public function accelerateY(dy:Float)
	{
		setYVelocity(getYVelocity() + dy);
	}
	
	public function accelerate(angle:Float, speed:Float)
	{
		setXVelocity(getXVelocity() + speed * Math.cos(Utils.RAD * angle));
		setYVelocity(getYVelocity() + speed * Math.sin(Utils.RAD * angle));
	}
	
	//*-----------------------------------------------
	//* Physics: Angles and Angular Velocity
	//*-----------------------------------------------
	
	public function getAngle():Float
	{
		if(isLightweight)
		{
			return Utils.RAD * rotation;
		}
		
		return body.getAngle();
	}
	
	public function getAngleInDegrees():Float
	{
		if(isLightweight)
		{
			return rotation;
		}
		
		return Utils.DEG * body.getAngle();
	}
	
	public function setAngle(angle:Float, inRadians:Bool = true)
	{
		if(inRadians)
		{
			if(isLightweight)
			{
				this.rotation = Utils.DEG * angle;
			}
			
			else
			{
				body.setAngle(angle);				
			}
		}
		
		else
		{
			if(isLightweight)
			{
				this.rotation = angle;
			}
			
			else
			{
				body.setAngle(Utils.RAD * angle);		
			}
		}
	}
	
	public function rotate(angle:Float, inRadians:Bool = true)
	{
		if(inRadians)
		{
			if(isLightweight)
			{
				this.rotation += Utils.DEG * angle;
			}
			
			else
			{
				body.setAngle(body.getAngle() + angle);
			}
		}
			
		else
		{
			if(isLightweight)
			{
				this.rotation += angle;
			}
			
			else
			{
				body.setAngle(body.getAngle() + (Utils.RAD * angle));
			}	
		}
	}
	
	public function getAngularVelocity():Float
	{
		if(isLightweight)
		{
			return Utils.RAD * rSpeed;
		}
		
		return body.getAngularVelocity();
	}
	
	public function setAngularVelocity(omega:Float)
	{
		if(isLightweight)
		{
			rSpeed = Utils.DEG * omega;
		}
		
		else
		{
			body.setAngularVelocity(omega);	
			body.setAwake(true);
		}
	}
	
	public function changeAngularVelocity(omega:Float)
	{
		if(isLightweight)
		{
			rSpeed += Utils.DEG * omega;
		}
		
		else
		{
			body.setAngularVelocity(body.getAngularVelocity() + omega);
			body.setAwake(true);
		}
	}
	
	//*-----------------------------------------------
	//* Physics: Forces
	//*-----------------------------------------------
	
	public function push(dirX:Float, dirY:Float, magnitude:Float)
	{
		if(isLightweight)
		{
			dummy.x = dirX;
			dummy.y = dirY;
			dummy.normalize();
		
			accelerateX(dummy.x * magnitude);
			accelerateY(dummy.y * magnitude);
			return;
		}
		
		if(dirX == 0 && dirY == 0)
		{
			return;
		}
		
		dummy.x = dirX;
		dummy.y = dirY;
		dummy.normalize();
		
		if(magnitude > 0)
		{
			dummy.multiply(magnitude);
		}
		
		body.applyForce(dummy, body.getWorldCenter());
	}
	
	//in degrees
	public function pushInDirection(angle:Float, speed:Float)
	{
		push
		(
			Math.cos(Utils.RAD * angle),
			Math.sin(Utils.RAD * angle),
			speed
		);
	}
	
	public function applyImpulse(dirX:Float, dirY:Float, magnitude:Float)
	{
		if(isLightweight)
		{
			dummy.x = dirX;
			dummy.y = dirY;
			dummy.normalize();
		
			accelerateX(dummy.x * magnitude * 8);
			accelerateY(dummy.y * magnitude * 8);
			return;
		}
		
		if(dirX == 0 && dirY == 0)
		{
			return;
		}
		
		dummy.x = dirX;
		dummy.y = dirY;
		dummy.normalize();
		
		if(magnitude > 0)
		{
			dummy.multiply(magnitude);
		}
		
		body.applyImpulse(dummy, body.getWorldCenter());
	}
	
	//in degrees
	public function applyImpulseInDirection(angle:Float, speed:Float)
	{
		applyImpulse
		(
			Math.cos(Utils.RAD * angle),
			Math.sin(Utils.RAD * angle),
			speed
		);
	}
	
	public function applyTorque(torque:Float)
	{
		if(isLightweight)
		{
			if(!fixedRotation)
			{
				rSpeed -= torque;
			}
		}
		
		else
		{
			body.applyTorque(torque);
			body.setAwake(true);
		}
	}
	
	//*-----------------------------------------------
	//* Size
	//*-----------------------------------------------
	
	public function getWidth():Float
	{
		return width;
	}
	
	public function getHeight():Float
	{
		return height;
	}
	
	public function getPhysicsWidth():Float
	{
		return width / Engine.physicsScale;
	}
	
	public function getPhysicsHeight():Float
	{
		return height / Engine.physicsScale;
	}
	
	//*-----------------------------------------------
	//* Physics Flags
	//*-----------------------------------------------
	
	public function getBody():B2Body
	{
		return body;
	}
	
	public function setFriction(value:Float)
	{
		if(!isLightweight)
		{
			body.setFriction(value);
		}
	}
	
	public function setBounciness(value:Float)
	{
		if(!isLightweight)
		{
			body.setBounciness(value);
		}
	}
	
	public function enableRotation()
	{
		if(isLightweight)
		{
			fixedRotation = false;
		}
		
		else
		{
			body.setFixedRotation(false);
		}
	}
	
	public function disableRotation()
	{
		if(isLightweight)
		{
			fixedRotation = true;
		}
		
		else
		{
			body.setFixedRotation(true);
		}
	}
	
	public function setIgnoreGravity(state:Bool)
	{
		ignoreGravity = state;
	
		if(!isLightweight)
		{
			body.setIgnoreGravity(state);
		}
	}
	
	public function ignoresGravity():Bool
	{
		if(isLightweight)
		{
			return ignoreGravity;
		}
		
		return body.isIgnoringGravity();
	}
	
	//*-----------------------------------------------
	//* Mouse Convenience
	//*-----------------------------------------------
	
	public function isMouseOver():Bool
	{
		//This may need to be in global x/y???
		var mx = Input.mouseX;
		var my = Input.mouseY;
		
		var xPos = cacheX; //getX();
		var yPos = cacheY; //getY();
		
		if(isHUD)
		{
			//This said screen x/y???
			//mx = Input.mouseX;
			//my = Input.mouseY;
			
			xPos = cacheX + Engine.cameraX; //getScreenX();
			yPos = cacheY + Engine.cameraY; //getScreenY();
		}
		
		return (mx >= xPos && 
		   		my >= yPos && 
		   		mx < xPos + cacheWidth && 
		   		my < yPos + cacheHeight);
	}
	
	public function isMouseHover():Bool
	{
		return isMouseOver() && Input.mouseUp;
	}
	
	public function isMouseDown():Bool
	{
		return isMouseOver() && Input.mouseDown;
	}
	
	public function isMousePressed():Bool
	{
		return isMouseOver() && Input.mousePressed;
	}
	
	public function isMouseReleased():Bool
	{
		return isMouseOver() && Input.mouseReleased;
	}
	
	//*-----------------------------------------------
	//* Tween Convenience
	//*-----------------------------------------------
	
	public function cancelTweens()
	{
		Actuate.stop(this);
	}
	
	public function fadeTo(value:Float, duration:Float = 1, easing:Dynamic = null)
	{	
		if(easing == null)
		{
			easing = Linear.easeNone;
		}
	
		Actuate.tween(this, duration, {alpha:value}).ease(easing);
	}
	
	public function growTo(scaleX:Float = 1, scaleY:Float = 1, duration:Float = 1, easing:Dynamic = null)
	{
		if(easing == null)
		{
			easing = Linear.easeNone;
		}
	
		Actuate.tween(this, duration, {scaleX:scaleX, scaleY:scaleY}).ease(easing);
	}
	
	//In degrees
	public function spinTo(angle:Float, duration:Float = 1, easing:Dynamic = null)
	{
		tweenAngle.angle = this.rotation;

		if(easing == null)
		{
			easing = Linear.easeNone;
		}
		
		activeAngleTweens++;
	
		if(isLightweight)
		{
			Actuate.tween(this, duration, {rotation:angle}).ease(easing).onComplete(onTweenAngleComplete);
		}
		
		else
		{
			Actuate.tween(tweenAngle, duration, {angle:angle}).ease(easing).onComplete(onTweenAngleComplete);
		}
	}
	
	public function moveTo(x:Float, y:Float, duration:Float = 1, easing:Dynamic = null)
	{
		tweenLoc.x = getX();
		tweenLoc.y = getY();
		
		if(easing == null)
		{
			easing = Linear.easeNone;
		}
		
		activePositionTweens++;
		
		if(isLightweight)
		{
			Actuate.tween(this, duration, {x:x, y:y}).ease(easing).onComplete(onTweenPositionComplete);
		}
		
		else
		{
			Actuate.tween(tweenLoc, duration, {x:x, y:y}).ease(easing).onComplete(onTweenPositionComplete);
		}
	}
	
	//In degrees
	public function spinBy(angle:Float, duration:Float = 1, easing:Dynamic = null)
	{
		spinTo(this.rotation + angle, duration, easing);
	}
	
	public function moveBy(x:Float, y:Float, duration:Float = 1, easing:Dynamic = null)
	{
		moveTo(getX() + x, getY() + y, duration, easing);
	}
	
	public function onTweenAngleComplete()
	{
		activeAngleTweens--;
	}
	
	public function onTweenPositionComplete()
	{
		activePositionTweens--;
	}
	
	
	//*-----------------------------------------------
	//* Drawing
	//*-----------------------------------------------
	
	public function drawImage(g:G)
	{
		if(currAnimation != null)
		{
			cast(currAnimation, AbstractAnimation).draw(g, 0, 0);
		}
	}
	
	public function enableActorDrawing()
	{
		drawActor = true;
		
		if(currAnimation != null)
		{
			currAnimation.visible = true;
		}
	}
	
	public function disableActorDrawing()
	{
		drawActor = false;
		
		if(currAnimation != null)
		{
			currAnimation.visible = false;
		}
	}
	
	public function drawsImage():Bool
	{
		return drawActor;
	}
	
	//*-----------------------------------------------
	//* Filters
	//*-----------------------------------------------

	public function setFilter(filter:Array<Dynamic>)
	{			
		filters = filter;
	}
	
	public function clearFilters()
	{
		filters = [];
	}
	
	//*-----------------------------------------------
	//* Behaviors
	//*-----------------------------------------------
	
	public function addBehavior(b:Behavior)
	{
		if(behaviors != null)
		{
			behaviors.add(b);
		}
	}
	
	public function hasBehavior(name:String):Bool
	{
		if(behaviors != null)
		{
			return behaviors.hasBehavior(name);
		}
		
		return false;
	}
	
	public function enableBehavior(name:String)
	{
		if(behaviors != null)
		{
			behaviors.enableBehavior(name);
		}
	}
	
	public function disableBehavior(name:String)
	{
		if(behaviors != null)
		{
			behaviors.disableBehavior(name);
		}
	}
	
	public function isBehaviorEnabled(name:String):Bool
	{
		if(behaviors != null)
		{
			return behaviors.isBehaviorEnabled(name);
		}
		
		return false;
	}
	
	public function enableAllBehaviors()
	{
		if(behaviors != null)
		{
			for(b in behaviors.behaviors)
			{
				b.enabled = true;
			}
		}
	}
		
	//*-----------------------------------------------
	//* Messaging
	//*-----------------------------------------------
	
	public function getValue(behaviorName:String, attributeName:String):Dynamic
	{
		return behaviors.getAttribute(behaviorName, attributeName);
	}
	
	public function setValue(behaviorName:String, attributeName:String, value:Dynamic)
	{
		behaviors.setAttribute(behaviorName, attributeName, value);
	}
	
	public function shout(msg:String, args:Array<Dynamic> = null):Dynamic
	{
		return behaviors.call(msg, args);
	}
	
	public function say(behaviorName:String, msg:String, args:Array<Dynamic> = null):Dynamic
	{
		return behaviors.call2(behaviorName, msg, args);
	}
	
	//*-----------------------------------------------
	//* Actor-Level Attributes
	//*-----------------------------------------------
	
	public function setActorValue(name:String, value:Dynamic)
	{
		if(registry != null)
		{
			registry.set(name, value);
		}
	}
	
	public function getActorValue(name:String):Dynamic
	{
		if(registry == null)
		{
			return null;
		}
		
		else
		{
			return registry.get(name);
		}
	}
	
	public function hasActorValue(name:String):Dynamic
	{
		if(registry == null)
		{
			return null;
		}
		
		return registry.get(name) != null;
	}
	
	//*-----------------------------------------------
	//* Events Plumbing
	//*-----------------------------------------------
	
	public function registerListener(type:Array<Dynamic>, listener:Dynamic)
	{
		var listenerList:Array<Dynamic> = allListeners.get(type);
		
		if(listenerList == null)
		{
			listenerList = new Array<Dynamic>();
			allListeners.set(type, listenerList);
		}
		
		listenerList.push(listener);
	}
	
	public function removeAllListeners()
	{			
		for(k in allListeners.keys())
		{
			var listener = cast(k, Array<Dynamic>);
			
			if(listener != null)
			{
				var list:Array<Dynamic> = cast(allListeners.get(listener), Array<Dynamic>);
				
				if(list != null)
				{
					for(r in 0...list.length)
					{
						Utils.removeValueFromArray(listener, list[r]);
					}
				}
			}
		}
		
		//Not Needed?
		for(dict in allListenerReferences)
		{
			dict.delete(this);
		}
		
		Utils.clear(allListenerReferences);
	}	
	
	//*-----------------------------------------------
	//* Misc
	//*-----------------------------------------------	
	
	public function anchorToScreen()
	{
		if(!isLightweight)
		{
			body.setAlwaysActive(true);
		}
		
		isHUD = true;			
		engine.addHUDActor(this);
		engine.removeActorFromLayer(this, layerID);
		engine.hudLayer.addChild(this);
	}
	
	public function unanchorFromScreen()
	{
		if(!isLightweight)
		{
			body.setAlwaysActive(alwaysSimulate);
		}
		
		isHUD = false;			
		engine.removeHUDActor(this);
		engine.moveActorToLayer(this, layerID);
		engine.hudLayer.removeChild(this);
	}
	
	public function isAnchoredToScreen():Bool
	{
		return isHUD;
	}
	
	public function makeAlwaysSimulate()
	{
		if(!isLightweight)
		{
			body.setAlwaysActive(true);
		}
		
		alwaysSimulate = true;			
		engine.addAlwaysOnActor(this);
	}
	
	public function makeSometimesSimulate()
	{
		if(!isLightweight)
		{
			body.setAlwaysActive(false);
		}
		
		alwaysSimulate = false;			
		engine.removeHUDActor(this);
	}
	
	public function alwaysSimulates():Bool
	{
		return alwaysSimulate;
	}
	
	public function die()
	{
		dying = true;
		
		var a = engine.whenTypeGroupDiesListeners.get(getType());
		var b = engine.whenTypeGroupDiesListeners.get(getGroup());
	
		Engine.invokeListeners(whenKilledListeners);

		if(a != null)
		{
			Engine.invokeListeners2(a, this);
		}
		
		if(b != null)
		{
			Engine.invokeListeners2(b, this);
		}
		
		removeAllListeners();
	}
		
	public function isDying():Bool
	{
		return dying;
	}
	
	public function isAlive():Bool
	{
		return !(dead || dying || recycled);
	}

	//hand-inlined to engine to avoid overhead
	public function isOnScreen():Bool
	{
		var cameraX = Engine.cameraX;
		var cameraY = Engine.cameraY;
		
		var left = Engine.paddingLeft;
		var top = Engine.paddingTop;
		var right = Engine.paddingRight;
		var bottom = Engine.paddingBottom;
	
		return (isLightweight || body.isActive()) && 
			   getX() >= -cameraX - left && 
			   getY() >= -cameraY - top &&
			   getX() < -cameraX + Engine.screenWidth + right &&
			   getY() < -cameraY + Engine.screenHeight + bottom;
	}
	
	public function isInScene():Bool
	{
		return (isLightweight || body.isActive()) && 
			   getX() >= 0 && 
			   getY() >= 0 &&
			   getX() < Engine.sceneWidth &&
			   getY() < Engine.sceneHeight;
	}
	
	public function getLastCollidedActor():Actor
	{
		return Actor.lastCollided;
	}
	

	//Kills this actor after it leaves the screen
	public function killSelfAfterLeavingScreen()
	{
		killLeaveScreen = true;
	}
	
	override public function toString():String
	{
		if(name == null)
		{
			return "Unknown Actor " + ID;
		}
		
		return "[Actor " + ID + "," + name + "]";
	}
	
	//*-----------------------------------------------
	//* Camera-Only
	//*-----------------------------------------------
	
	public function setLocation(x:Float, y:Float)
	{
		this.x = x;
		this.y = y;
		
		setX(x);
		setY(y);
	}
	
	//*-----------------------------------------------
	//* Simple Collision system (via FlashPunk)
	//*-----------------------------------------------

	/**
	 * An optional Mask component, used for specialized collision. If this is
	 * not assigned, collision checks will use the Entity's hitbox by default.
	 */
	public var shape(getShape, setShape):Mask;
	private inline function getShape():Mask { return _mask; }
	private function setShape(value:Mask):Mask
	{
		if (_mask == value) return value;
		if (_mask != null) _mask.assignTo(null);
		_mask = value;
		if (value != null) _mask.assignTo(this);
		return _mask;
	}
	
	/**
	 * Checks for a collision against an Entity type.
	 * @param	type		The Entity type to check for.
	 * @param	x			Virtual x position to place this Entity.
	 * @param	y			Virtual y position to place this Entity.
	 * @return	The first Entity collided with, or null if none were collided.
	 */
	public function collide(groupID:Int, x:Float, y:Float):Actor
	{
		//Grab all actors from a group. For us, that means grabbing the group! (instead of a string type)
		var actorList = engine.getGroup(groupID);
		
		_x = this.x; _y = this.y;
		this.x = x; this.y = y;

		if (_mask == null)
		{
			for(actor in actorList.list)
			{
				var e = actor;
				
				if (x - originX + width > e.x - e.originX
				&& y - originY + height > e.y - e.originY
				&& x - originX < e.x - e.originX + e.width
				&& y - originY < e.y - e.originY + e.height
				&& e.collidable && e != this)
				{
					if (e._mask == null || e._mask.collide(HITBOX))
					{
						if(solid && e.solid)
						{
							this.x = _x; this.y = _y;
						}
						
						return e;
					}
				}
			}
			this.x = _x; this.y = _y;
			return null;
		}

		for(actor in actorList.list)
		{
			var e = actor;
	
			if (x - originX + width > e.x - e.originX
			&& y - originY + height > e.y - e.originY
			&& x - originX < e.x - e.originX + e.width
			&& y - originY < e.y - e.originY + e.height
			&& e.collidable && e != this)
			{
				if (_mask.collide(e._mask != null ? e._mask : e.HITBOX))
				{
					if(solid && e.solid)
					{
						this.x = _x; this.y = _y;
					}
					
					return e;
				}
			}
		}
		this.x = _x; this.y = _y;
		return null;
	}

	/**
	 * Checks for collision against multiple Entity types.
	 * @param	types		An Array or Vector of Entity types to check for.
	 * @param	x			Virtual x position to place this Entity.
	 * @param	y			Virtual y position to place this Entity.
	 * @return	The first Entity collided with, or null if none were collided.
	 */
	public function collideTypes(types:Dynamic, x:Float, y:Float):Actor
	{
		if (Std.is(types, String))
		{
			return collide(types, x, y);
		}
		else
		{
			var a:Array<Int> = cast types;
			if (a != null)
			{
				var e:Actor;
				var type:Int;
				for (type in a)
				{
					e = collide(type, x, y);
					if (e != null) return e;
				}
			}
		}

		return null;
	}

	/**
	 * Checks if this Entity collides with a specific Entity.
	 * @param	e		The Entity to collide against.
	 * @param	x		Virtual x position to place this Entity.
	 * @param	y		Virtual y position to place this Entity.
	 * @return	The Entity if they overlap, or null if they don't.
	 */
	public function collideWith(e:Actor, x:Float, y:Float):Actor
	{
		_x = this.x; _y = this.y;
		this.x = x; this.y = y;

		if (x - originX + width > e.x - e.originX
		&& y - originY + height > e.y - e.originY
		&& x - originX < e.x - e.originX + e.width
		&& y - originY < e.y - e.originY + e.height
		&& collidable && e.collidable)
		{
			if (_mask == null)
			{
				if (e._mask == null || e._mask.collide(HITBOX))
				{
					this.x = _x; this.y = _y;
					return e;
				}
				this.x = _x; this.y = _y;
				return null;
			}
			if (_mask.collide(e._mask != null ? e._mask : e.HITBOX))
			{
				this.x = _x; this.y = _y;
				return e;
			}
		}
		this.x = _x; this.y = _y;
		return null;
	}

	/**
	 * Populates an array with all collided Entities of a type.
	 * @param	type		The Entity type to check for.
	 * @param	x			Virtual x position to place this Entity.
	 * @param	y			Virtual y position to place this Entity.
	 * @param	array		The Array or Vector object to populate.
	 * @return	The array, populated with all collided Entities.
	 */
	public function collideInto(groupID:Int, x:Float, y:Float, array:Array<Actor>)
	{
		//Grab all actors from a group. For us, that means grabbing the group! (instead of a string type)
		var actorList = engine.getGroup(groupID);

		_x = this.x; _y = this.y;
		this.x = x; this.y = y;
		var n:Int = array.length;

		if (_mask == null)
		{
			for(actor in actorList.list)
			{
				var e = actor;
				
				if (x - originX + width > e.x - e.originX
				&& y - originY + height > e.y - e.originY
				&& x - originX < e.x - e.originX + e.width
				&& y - originY < e.y - e.originY + e.height
				&& e.collidable && e != this)
				{
					if (e._mask == null || e._mask.collide(HITBOX)) array[n++] = e;
				}
			}
			this.x = _x; this.y = _y;
			return;
		}

		for(actor in actorList.list)
		{
			var e = actor;
			
			if (x - originX + width > e.x - e.originX
			&& y - originY + height > e.y - e.originY
			&& x - originX < e.x - e.originX + e.width
			&& y - originY < e.y - e.originY + e.height
			&& e.collidable && e != this)
			{
				if (_mask.collide(e._mask != null ? e._mask : e.HITBOX)) array[n++] = e;
			};
		}
		this.x = _x; this.y = _y;
		return;
	}

	/**
	 * Populates an array with all collided Entities of multiple types.
	 * @param	types		An array of Entity types to check for.
	 * @param	x			Virtual x position to place this Entity.
	 * @param	y			Virtual y position to place this Entity.
	 * @param	array		The Array or Vector object to populate.
	 * @return	The array, populated with all collided Entities.
	 */
	public function collideTypesInto(types:Array<Int>, x:Float, y:Float, array:Array<Actor>)
	{
		var type:String;
		for (type in types) collideInto(type, x, y, array);
	}

	public function moveActorBy(x:Float, y:Float, solidType:Dynamic = null, sweep:Bool = false)
	{
		_moveX += x;
		_moveY += y;
		x = Math.round(_moveX);
		y = Math.round(_moveY);
		_moveX -= x;
		_moveY -= y;
		if (solidType != null)
		{
			var sign:Int, e:Actor;
			if (x != 0)
			{
				if (collidable && (sweep || collideTypes(solidType, this.x + x, this.y) != null))
				{
					sign = x > 0 ? 1 : -1;
					while (x != 0)
					{
						if ((e = collideTypes(solidType, this.x + sign, this.y)) != null)
						{
							moveCollideX(e);
							break;
						}
						else
						{
							this.x += sign;
							x -= sign;
						}
					}
				}
				else this.x += x;
			}
			if (y != 0)
			{
				if (collidable && (sweep || collideTypes(solidType, this.x, this.y + y) != null))
				{
					sign = y > 0 ? 1 : -1;
					while (y != 0)
					{
						if ((e = collideTypes(solidType, this.x, this.y + sign)) != null)
						{
							moveCollideY(e);
							break;
						}
						else
						{
							this.y += sign;
							y -= sign;
						}
					}
				}
				else this.y += y;
			}
		}
		else
		{
			this.x += x;
			this.y += y;
		}
	}
	
	/**
	 * Moves the Entity to the position, retaining integer values for its x and y.
	 * @param	x			X position.
	 * @param	y			Y position.
	 * @param	solidType	An optional collision type to stop flush against upon collision.
	 * @param	sweep		If sweeping should be used (prevents fast-moving objects from going through solidType).
	 */
	public inline function moveActorTo(x:Float, y:Float, solidType:Dynamic = null, sweep:Bool = false)
	{
		moveActorBy(x - this.x, y - this.y, solidType, sweep);
	}

	/**
	 * Moves towards the target position, retaining integer values for its x and y.
	 * @param	x			X target.
	 * @param	y			Y target.
	 * @param	amount		Amount to move.
	 * @param	solidType	An optional collision type to stop flush against upon collision.
	 * @param	sweep		If sweeping should be used (prevents fast-moving objects from going through solidType).
	 */
	public inline function moveActorTowards(x:Float, y:Float, amount:Float, solidType:Dynamic = null, sweep:Bool = false)
	{
		_point.x = x - this.x;
		_point.y = y - this.y;
		_point.normalize(amount);
		moveActorBy(_point.x, _point.y, solidType, sweep);
	}

	/**
	 * When you collide with an Entity on the x-axis with moveTo() or moveBy().
	 * @param	e		The Entity you collided with.
	 */
	public function moveCollideX(a:Actor)
	{
		handleCollisionsSimple(a, true, false);
	}

	/**
	 * When you collide with an Entity on the y-axis with moveTo() or moveBy().
	 * @param	e		The Entity you collided with.
	 */
	public function moveCollideY(a:Actor)
	{
		handleCollisionsSimple(a, false, true);
	}
	
	private function handleCollisionsSimple(a:Actor, fromX:Bool, fromY:Bool)
	{
		if(Std.is(a, Region))
		{
			var region = cast(a, Region);
			region.addActor(this);
			return;
		}
	
		Utils.collision.thisActor = Utils.collision.actorA = this;
		Utils.collision.otherActor = Utils.collision.actorB = a;
		
		if(fromX)
		{
			Utils.collision.thisFromLeft = a.x < this.x;
			Utils.collision.thisFromRight = a.x > this.x;
			
			Utils.collision.otherFromLeft = !Utils.collision.thisFromLeft;
			Utils.collision.otherFromRight = !Utils.collision.thisFromRight;
		
			Utils.collision.thisFromTop = Utils.collision.otherFromTop = false;
			Utils.collision.thisFromBottom = Utils.collision.otherFromBottom = false;
		}
		
		if(fromY)
		{
			Utils.collision.thisFromTop = a.y < this.y;
			Utils.collision.thisFromBottom = a.y > this.y;
		
			Utils.collision.otherFromTop = !Utils.collision.thisFromTop;
			Utils.collision.otherFromBottom = !Utils.collision.thisFromBottom;
		
			Utils.collision.thisFromLeft = Utils.collision.otherFromLeft = false;
			Utils.collision.thisFromRight = Utils.collision.otherFromRight = false;
		}
		
		//TODO
		Utils.collision.thisCollidedWithActor = true;
		Utils.collision.thisCollidedWithTile = false;
		Utils.collision.thisCollidedWithSensor = false;
		Utils.collision.thisCollidedWithTerrain = false;
		
		Utils.collision.otherCollidedWithActor = true;
		Utils.collision.otherCollidedWithTile = false;
		Utils.collision.otherCollidedWithSensor = false;
		Utils.collision.otherCollidedWithTerrain = false;

		lastCollided = a;
		Engine.invokeListeners2(collisionListeners, Utils.collision);
		engine.handleCollision(this, Utils.collision);
		
		lastCollided = this;
		Engine.invokeListeners2(a.collisionListeners, Utils.collision.switchData());
	}
	
	private var HITBOX:Mask;
	private var _mask:Mask;
	private var _x:Float;
	private var _y:Float;
	private var _moveX:Float;
	private var _moveY:Float;
	private var _point:Point;
}

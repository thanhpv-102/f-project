///////////////////////////////////////////////////////////////////////////////
//
// Licensed Source Code - Property of F-Project
//
// Copyright © 2014 F-Project. All Rights Reserved.
//
///////////////////////////////////////////////////////////////////////////////
package net.fproject.di
{
	import flash.utils.Dictionary;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getQualifiedSuperclassName;
	
	import net.fproject.utils.DataUtil;
	
	import org.as3commons.lang.ClassUtils;
	
	public class InstanceFactory
	{
		private static var classToImpl:Dictionary = new Dictionary(true);
		private static var implToInstance:Dictionary = new Dictionary(true);
		
		/**
		 * @see #setInstanceFactoryConfig()
		 */
		private static var factoryConfig:XML
		
		/**
		 * Set InstanceFactory configuration 
		 * @param config the InstanceFactory configuration, using the following sample format:
		 * <pre>
		 *   &lt;ImplementationConfig&gt;
		 *    	&lt;Implementation abstractor="net.fproject.rpc.IRemoteObject" impl="net.fproject.rpc.JSONRemoteObject"/&gt;
		 * 	&lt;Implementation abstractor="com.myorg.IMyService" impl="com.myorg.MyServiceImpl"/&gt;
		 *   &lt;/ImplementationConfig&gt;
		 *</pre>
		 * 
		 */
		public static function setFactoryConfig(config:XML):void
		{
			factoryConfig = config;
		}
		
		public static function addImplementation(implDefinition:Object):void
		{
			if(implDefinition is XML)
				factoryConfig = DataUtil.addXmlChild(factoryConfig, implDefinition as XML, <ImplementationConfig/>);
			else if(implDefinition is Implementation)
				ImplementationConfig.instance.addImplementation(implDefinition as Implementation);
		}
		
		/**
		 * Instantiate a class using singleton and dependency injection.
		 * @param abstractor The class, abstract class or interface name to instantiate
		 * @param constructorArgs The constructor argument list (if any)
		 * @return The singleton instance
		 * 
		 */
		public static function getInstance(abstractor:Class, constructorArgs:*=undefined, singleton:Boolean=true):Object
		{
			if(singleton && implToInstance[abstractor] != undefined)
				return implToInstance[abstractor];
			
			if(classToImpl[abstractor] != undefined)
			{
				var impl:Class = classToImpl[abstractor];
				return getInstanceByImpl(abstractor, impl, constructorArgs, singleton);
			}
			
			for each (var i:Object in ImplementationConfig.instance.impls)
			{
				if(i is Implementation)
				{
					if(Implementation(i).abstractor == abstractor)
					{
						impl = Implementation(i).impl;
						break;
					}
				}
			}
			
			if(impl == null)
			{
				var abstractorName:String = getQualifiedClassName(abstractor).replace("::",".");
				
				if(factoryConfig != null)
				{
					for each (var implXml:XML in factoryConfig.ImplementationConfig.Implementation)
					{
						var implAbs:String = implXml.@abstractor;
						if(implAbs.replace("::",".") == abstractorName)
						{
							var implName:String = implXml.@impl as String;
							if(implName != null)
								impl = getDefinitionByName(implName) as Class;
							break;
						}
					}
				}
				
				if(impl == null && (abstractor == Object || getQualifiedSuperclassName(abstractor) != null))
				{
					impl = abstractor;
				}
			}
			
			return getInstanceByImpl(abstractor, impl, constructorArgs, singleton);
		}
		
		private static function getInstanceByImpl(abstractor:Class, impl:Class, constructorArgs:*, singleton:Boolean):*
		{
			if(impl != null)
			{
				if(singleton && implToInstance[impl] != undefined)
					return implToInstance[impl];
				
				if(constructorArgs == undefined)
				{
					var instance:Object = new impl();
				}
				else
				{
					if(!(constructorArgs is Array))
						constructorArgs = [constructorArgs];
					instance = ClassUtils.newInstance(impl, constructorArgs);
				}
				
				if(singleton)
				{
					implToInstance[impl] = instance;
					if(impl !== abstractor)
						implToInstance[abstractor] == instance;
				}
				
				classToImpl[abstractor] = impl;
				return instance;
			}
			else
			{
				return null;
			}
		}
	}
}
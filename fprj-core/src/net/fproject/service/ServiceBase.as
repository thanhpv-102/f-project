///////////////////////////////////////////////////////////////////////////////
//
// © Copyright f-project.net 2010-present.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
///////////////////////////////////////////////////////////////////////////////
package net.fproject.service
{
	import flash.utils.Dictionary;
	
	import mx.rpc.AsyncToken;
	import mx.rpc.CallResponder;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	import net.fproject.fproject_internal;
	import net.fproject.core.AppContext;
	import net.fproject.event.AppContextEvent;
	import net.fproject.rpc.IRemoteObject;
	import net.fproject.rpc.RPCUtil;
	import net.fproject.rpc.RemoteObjectFactory;
	import net.fproject.utils.DateTimeUtil;
	import net.fproject.utils.LoggingUtil;

	/**
	 * <p>This is the base class for all service classes.
	 * Provides common properties and methods for all drived service classes</p>
	 * <p>The access to remote service is performed via <code>remoteObject</code> object that is a
	 * public field of this class.</p>
	 * 
	 * <p>The fields <code>source</code> and <code>destination</code> of RemoteObject is defined as below:
	 * <ul>
	 * <li><code>source</code> of service can be directly defined using AS3 code, by the first metadata parameter
	 * <code>[RemoteObject("SourceName")]</code></li> of service class.
	 * <li>If the second metadata parameter exists, for example <br/>
	 * <code>[RemoteObject("SourceName","destination")]</code><br/> then this parameter's value will be the destination
	 * of remote object</li>
	 * <li>If there's no destination defined in the class metadata, it will be looked-up from XML of <code>AppContextData</code></li>
	 * </ul>
	 * </p>
	 * 
	 * @see mx.rpc.remoting.RemoteObject
	 * @see net.fproject.service.ActiveService
	 * @author Bui Sy Nguyen
	 * 
	 */
	public class ServiceBase
	{	
		/**
		 * Constructor 
		 * 
		 */		
		public function ServiceBase(remoteObject:IRemoteObject=null)
		{
			_remoteObject = remoteObject;
			if(_remoteObject != null)
				initRemoteObject(_remoteObject);
		}
		
		private var _lastCallResponder:CallResponder;
		
		public function get lastCallResponder():CallResponder
		{
			return _lastCallResponder;
		}
		
		private var _remoteObject:IRemoteObject;

		/**
		 * 
		 * The remote service object
		 * 
		 */
		public function get remoteObject():Object
		{
			if(_remoteObject == null)
			{
				_remoteObject = createRemoteObject();
			}
			
			if(responderToCallbackInfo == null)
			{
				//Initialize callback dictionary
				responderToCallbackInfo = new Dictionary(true);	
			}
				
			return _remoteObject;
		}

		private var responderToCallbackInfo:Dictionary;
		
		/**
		 * 
		 * Construct the remote object using RemoteObjectFactory.
		 * This is an optional function, primarily intended for framework 
		 * developers who need to install a hook to process the remote object construction.
		 * 
		 * For example, you can override this method to set the <code>convertResultHandler</code>
		 * or <code>convertParametersHandler</code> function. 
		 * 
		 */
		protected function createRemoteObject():IRemoteObject
		{
			if(_remoteObject != null)
				return _remoteObject;
			
			var ro:IRemoteObject = RemoteObjectFactory.getInstance(this);
			
			initRemoteObject(ro);
			
			return ro;
		}
		
		private function initRemoteObject(ro:IRemoteObject):void
		{
			//Set default request timeout to 1 minute.
			ro.requestTimeout = 60;
			
			//Set credentials if needed
			if(ro.channelSet.authenticated == false && appContext.loginUser != null)
			{
				ro.setAuthToken(appContext.loginUser.token);
			}				
			
			ro.addEventListener(FaultEvent.FAULT, onServiceFailed, false, 0, true);
		}
		
		protected function deleteServiceCall(responder:CallResponder):void
		{
			responder.removeEventListener(ResultEvent.RESULT, onCallComplete);
			responder.removeEventListener(FaultEvent.FAULT, onCallFailed);
			delete responderToCallbackInfo[responder];
		}
		
		protected function onServiceFailed(e:FaultEvent):void
		{
			if(RPCUtil.getNetworkFaultCode(e.fault) != null)
			{
				changeNetworkAvailability(false);
			}
			
			LoggingUtil.error(ServiceBase, "Service failed: " + e.currentTarget.source + "\n" + e.message);
		}
		
		protected function onCallFailed(e:FaultEvent):void
		{
			var info:* = responderToCallbackInfo[e.currentTarget];
			
			if (info != undefined && info["failCallback"] != undefined)
				info.failCallback(e.fault);
			
			LoggingUtil.error(ServiceBase, "\n[" + DateTimeUtil.formatIsoDate(new Date) + "] Service call failed: " + e.toString());
			
			deleteServiceCall(CallResponder(e.currentTarget));
			
			if(appContext.hasEventListener(AppContextEvent.SERVICE_CALL_FAILED))
				appContext.dispatchEvent(new AppContextEvent(AppContextEvent.SERVICE_CALL_FAILED, e.fault));
		}
		
		protected function onCallComplete(e:ResultEvent):void
		{
			changeNetworkAvailability(true);
			
			var info:* = responderToCallbackInfo[e.currentTarget];
			
			if (info != undefined && info["completeCallback"] != undefined)
				info.completeCallback(e.result);
			
			if(appContext.hasEventListener(AppContextEvent.SERVICE_CALL_COMPLETED))
				appContext.dispatchEvent(new AppContextEvent(AppContextEvent.SERVICE_CALL_COMPLETED,this));
			deleteServiceCall(CallResponder(e.currentTarget));
		}
		
		/**
		 * Create a remote call and initialize callbacks for it.
		 * @param callToken the service call token. Just pass a service call this parameter.
		 * @param completeCallback the call-back function that will be invoked after
		 * the remote object call succesfully returned. This function must have one parameter,
		 * which will be passed an result object of ResultEvent after the call responsed
		 * @param failCallback the call-back function that will be invoked after
		 * the remote object call failed. This function must have one parameter in type Fault:
		 * <pre>function failedHandler(fault:Fault):void</pre>
		 * 
		 * @return A call responder object
		 */
		protected function createServiceCall(callToken:AsyncToken,
											 completeCallback:Function, failCallback:Function,
											 responder:CallResponder=null):CallResponder
		{
			_lastCallResponder = responder != null ? responder : new CallResponder();
			_lastCallResponder.token = callToken;
			
			_lastCallResponder.addEventListener(ResultEvent.RESULT, onCallComplete);	
			_lastCallResponder.addEventListener(FaultEvent.FAULT, onCallFailed);	
			
			if(appContext.hasEventListener(AppContextEvent.SERVICE_CALL_STARTED))
				appContext.dispatchEvent(new AppContextEvent(AppContextEvent.SERVICE_CALL_STARTED,this));
			
			responderToCallbackInfo[_lastCallResponder] = {};
			
			if(completeCallback != null)
				responderToCallbackInfo[_lastCallResponder].completeCallback = completeCallback;
			if(failCallback != null)
				responderToCallbackInfo[_lastCallResponder].failCallback = failCallback;
			
			return _lastCallResponder;
		}
		
		private function get appContext():AppContext
		{
			return AppContext.instance;
		}
		
		private static const FAILED_THRESHOLD:uint = 20;
		private static var failedCount:int;
		
		private function changeNetworkAvailability(value:Boolean):void
		{
			if(value)
				failedCount = 0;
			else
				failedCount++;
			if(failedCount > FAILED_THRESHOLD)
				appContext.fproject_internal::setNetworkAvailability(false);
		}
	}
}
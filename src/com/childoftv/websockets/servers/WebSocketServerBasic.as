/*
Copyright (C) 2012 Ben Morrow

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package com.childoftv.websockets.servers
{
	import com.childoftv.websockets.WebSocketServer;
	import com.childoftv.websockets.events.ClientEvent;
	import com.childoftv.websockets.events.ServerEvent;
	
	import flash.display.Sprite;

	public class WebSocketServerBasic extends Sprite
	{
		public var PORT:uint=8087;
		public var BIND_ADDRESS:String;
		
		protected var wss:WebSocketServer=new WebSocketServer();
		public function WebSocketServerBasic(port:uint,bindAddress:String)
		{
			init(port,bindAddress);
		}
		protected function init(port:uint,bindAddress:String):void
		{
			PORT=port;
			BIND_ADDRESS=bindAddress;
			wss.addEventListener(ServerEvent.SERVER_BOUND_SUCCESS,handleServerIsReady);
			wss.addEventListener(ClientEvent.CLIENT_CONNECT_EVENT,handleClientConnect);
			wss.addEventListener(ClientEvent.CLIENT_MESSAGE_EVENT,handleClientMessage);
			wss.addEventListener(ClientEvent.CLIENT_DISCONNECT_EVENT,handleClientDisconnect);
			wss.attemptBind(PORT,BIND_ADDRESS);
		}
		
		protected function handleClientDisconnect(event:ClientEvent):void
		{
			//wss.sendALL(event.msg);
		}
		
		protected function handleClientConnect(event:ClientEvent):void
		{
			trace("Client connected: ",event.socket.remoteAddress+":"+event.socket.remotePort);
			//var location:String=wss.getClientKeyBySocket(event.socket);
			//wss.sendALL(location+" connected");
		}
		protected function handleClientMessage(event:ClientEvent):void
		{
			var location:String=wss.getClientKeyBySocket(event.socket);
			trace("Client message from ",location,event.msg);
			//wss.sendALL(location+" sent: "+event.msg);
		}
		
		private function handleServerIsReady(e:ServerEvent):void
		{
			trace("WEBSOCKET SERVER IS READY @ "+getServerAddress());
		}
		
		private function getServerAddress():String
		{
			return "ws://"+BIND_ADDRESS+":"+PORT;
		}
	}
}
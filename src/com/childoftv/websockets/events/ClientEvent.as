package com.childoftv.websockets.events
{
	import flash.events.Event;
	import flash.net.Socket;
	
	public class ClientEvent extends Event
	{
		public static const CLIENT_CONNECT_EVENT:String="CLIENT_CONNECT_EVENT";
		public static const CLIENT_DISCONNECT_EVENT:String="CLIENT_DISCONNECT_EVENT";
		public static const CLIENT_MESSAGE_EVENT:String="CLIENT_MESSAGE_EVENT";
		
		public var socket:Socket;
		public var msg:String;
		public function ClientEvent(type:String,_socket:Socket,_msg:String=null)
		{
			socket=_socket;
			msg=_msg;
			super(type, true, true);
		}
	}
}
package com.childoftv.websockets
{
	import flash.net.Socket;

	public class ClientEntry
	{
		public var handshakeDone:Boolean=false;
		public var key:String;

		public var socket:Socket;
		
		public function ClientEntry(_key:String,_socket:Socket)
		{
			key=_key;
			socket=_socket;
		}
		public function dispose():void
		{
			socket=null;
		}
	}
}
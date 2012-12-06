/*
Copyright (C) 2012 Ben Morrow

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package com.childoftv.websockets
{
	import com.adobe.crypto.SHA1;
	import com.childoftv.websockets.events.ClientEvent;
	import com.childoftv.websockets.events.ServerEvent;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.setTimeout;
	
	public class WebSocketServer extends Sprite
	{
		public static const WEB_SOCKET_MAGIC_STRING:String="258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
		private static const RETRY_BIND_TIME:uint=2000;
		
		private var serverSocket:ServerSocket = new ServerSocket();
		public var clientDict:Dictionary=new Dictionary();

		public function WebSocketServer()
		{
			
		}
		
		private function shutdown():void
		{
			closeAllClientSockets();
			//Close Server Socket
			if(serverSocket)
			{
				serverSocket.close();
			}
		}
		
		private function closeAllClientSockets():void
		{
			for each(var ce:ClientEntry in clientDict)
			{
				var clientSocket:Socket=ce.socket;
				
				if(clientSocket)
				{
					clientSocket.close();
				}
			}
		}
		
		private function onConnect( event:ServerSocketConnectEvent ):void
		{
			if(event.socket.remotePort!=0)
			{
				var clientSocket:Socket=registerClient(event.socket).socket;
				clientSocket.addEventListener( ProgressEvent.SOCKET_DATA, onClientSocketData );
				clientSocket.addEventListener(Event.CLOSE,handleSocketClose);
				log( "Connection from address: "+ getClientKeyBySocket(clientSocket));
				
				dispatchEvent(new ClientEvent(ClientEvent.CLIENT_CONNECT_EVENT,clientSocket));
			}
		}
		
		protected function handleSocketClose(event:Event):void
		{
			var clientSocket:Socket=event.currentTarget as Socket;
			clientSocket.removeEventListener( ProgressEvent.SOCKET_DATA, onClientSocketData );
			clientSocket.removeEventListener(Event.CLOSE,handleSocketClose);
			var oldKey:String=unregisterClient(clientSocket);
			dispatchEvent(new ClientEvent(ClientEvent.CLIENT_DISCONNECT_EVENT,clientSocket,oldKey+" disconnected"));
		}
		
		private function unregisterClient(clientSocket:Socket):String
		{
			var location:String;
			
			if(clientDict[clientSocket]){
				var ce:ClientEntry=clientDict[clientSocket] as ClientEntry;
				location=ce.key;
				ce.dispose();
				clientDict[clientSocket]=null;
				delete clientDict[clientSocket];
				clientDict[location]=null;
				delete clientDict[location];
			}
			return location;
		}
		private function doHandShake(clientSocket:Socket,clientEntry:ClientEntry):void
		{
			var socketBytes:ByteArray = new ByteArray();
			clientSocket.readBytes(socketBytes,0,clientSocket.bytesAvailable);
			var message:String = socketBytes.readUTFBytes(socketBytes.bytesAvailable);
			//log(message);
			
			clientEntry.handshakeDone=true;
			var i:uint = 0;
			if(message.indexOf("GET ") == 0)
			{
				var messageLines:Array = message.split("\n");
				var fields:Object = {};
				var requestedURL:String = "";
				for(i = 0; i < messageLines.length; i++)
				{
					var line:String = messageLines[i];
					if(i == 0)
					{
						var getSplit:Array = line.split(" ");
						if(getSplit.length > 1)
						{
							requestedURL = getSplit[1];
						}
					}
					else
					{
						var index:int = line.indexOf(":");
						if(index > -1)
						{
							var key:String = line.substr(0, index);
							fields[key] = line.substr(index + 1).replace( /^([\s|\t|\n]+)?(.*)([\s|\t|\n]+)?$/gm, "$2" );
						}
					}
				}
				
				if(fields["Sec-WebSocket-Key"] != null)
				{
					
					var joinedKey:String=fields["Sec-WebSocket-Key"]+WEB_SOCKET_MAGIC_STRING;
					
					//hash it
					var base64hash:String = SHA1.hashToBase64(joinedKey);
					var response:String = "HTTP/1.1 101 Switching Protocols\r\n" +
						"Upgrade: WebSocket\r\n" +
						"Connection: Upgrade\r\n" +
						"Sec-WebSocket-Accept: "+base64hash+"\r\n"+
						"Sec-WebSocket-Origin: " + fields["Origin"] + "\r\n" +
						"Sec-WebSocket-Location: ws://" + fields["Host"] + requestedURL + "\r\n" +
						"\r\n";
					var responseBytes:ByteArray = new ByteArray();
					responseBytes.writeUTFBytes(response);
					responseBytes.position = 0;
					clientSocket.writeBytes(responseBytes);
					clientSocket.flush();
					socketBytes.clear();
				}
			}
		}
		private function onClientSocketData( event:ProgressEvent ):void
		{
			var socket:Socket=event.currentTarget as Socket;
			var clientEntry:ClientEntry=getClientEntryBySocket(socket);
			var clientSocket:Socket=clientEntry.socket;
			if (!clientEntry.handshakeDone){
				doHandShake(clientSocket,clientEntry);
			}else{
				
				readMessage(clientSocket);
			}
		}
		private function readMessage(clientSocket:Socket):void
		{
			/*var policy_file = '<cross-domain-policy><allow-access-from domain="*" to-ports="*" /></cross-domain-policy>';
			clientSocket.writeUTFBytes(policy_file);
			clientSocket.flush();*/
			var buffer:ByteArray = new ByteArray();
			var outBuffer:ByteArray=new ByteArray();
			var mask:ByteArray=new ByteArray();
			
			//discard for now
			var typeByte:int=clientSocket.readByte();
			
			var byteTwo:int=clientSocket.readByte() & 127;
			//trace("byteTwo ",byteTwo);
			
			var sizeArray:ByteArray=new ByteArray();
			
			if(byteTwo==126)
			{
				//large frame size, 2 more frame size bytes
				clientSocket.readBytes(sizeArray,0,2);
			}else if(byteTwo==127)
			{
				//larger frame size (8 more frame size bytes)
				clientSocket.readBytes(sizeArray,0,8);
			}
			//Read the mask bytes
			clientSocket.readBytes(mask,0,4);
			
			//Copy payload data into buffer
			clientSocket.readBytes(buffer,0,clientSocket.bytesAvailable);
			buffer.position=0;
			var len:uint=buffer.bytesAvailable;
			for(var j:uint=0;j<len;j++)
			{
				//unmask buffer data into output buffer
				outBuffer.writeByte(applyMask(mask,buffer.readByte(),j));
			}
			outBuffer.position=0;
			var msg:String=outBuffer.readUTFBytes(outBuffer.bytesAvailable);
			
			dispatchEvent(new ClientEvent(ClientEvent.CLIENT_MESSAGE_EVENT,clientSocket,msg));
		}
		
		private function getClientEntryBySocket(socket:Socket):ClientEntry
		{
			return clientDict[getClientKeyBySocket(socket)];
		}
		
		public function getClientKeyBySocket(socket:Socket):String
		{
			return socket.remoteAddress+":"+socket.remotePort;
		}		
		
		private function registerClient(socket:Socket):ClientEntry
		{
			var key:String=getClientKeyBySocket(socket);
			trace("register client: "+key);
			var client:ClientEntry;
			if(clientDict[key])
			{
				client=clientDict[key];
			}else{
				client=new ClientEntry(key,socket);
				clientDict[getClientKeyBySocket(socket)]=client;
				clientDict[client.socket]=client;
			}
			return client;
		}
		private function applyMask(mask:ByteArray,byte:int,index:uint):int
		{
			mask.position=index % 4;
			var maskByte:int=mask.readByte();
			
			return byte ^ maskByte;
		}
		public function attemptBind(localPort:uint,localIP:String):void
		{
			try{
				if( serverSocket.bound ) 
				{
					serverSocket.close();
					serverSocket = new ServerSocket();
					
				}
				serverSocket.bind( localPort, localIP );
				serverSocket.addEventListener( ServerSocketConnectEvent.CONNECT, onConnect );
				serverSocket.listen();
				//log( "Bound to: " + serverSocket.localAddress + ":" + serverSocket.localPort );
				dispatchEvent(new ServerEvent(ServerEvent.SERVER_BOUND_SUCCESS));
			}catch(e)
			{
				trace("retry bind");
				setTimeout(attemptBind,RETRY_BIND_TIME,localPort,localIP);
			}
		}
		
		public function sendALL(msg:String):void
		{
			for(var key:* in clientDict)
			{
				if(key is String)
				{
					try{
						var clientSocket:Socket=(clientDict[key] as ClientEntry).socket;
						sendMessage(clientSocket,msg);
					}
					catch ( error:Error )
					{
						log( error.message );
					}
				}
			}
		}
		
		public function sendMessage(clientSocket:Socket,msg:String,continuation:Boolean=false):void
		{
			if( clientSocket != null && clientSocket.connected )
			{
				var rawData:ByteArray=new ByteArray()
				var indexStartRawData:uint;
				rawData.writeUTFBytes( msg );
				rawData.position=0;
				var bytesFormatted:Array=[];
				
				if(continuation)
				{
					bytesFormatted[0] = 128;
				}else{
					//Text Payload
					bytesFormatted[0] = 129; 
				}
				
				if (rawData.length <= 125)
				{
					bytesFormatted[1] = rawData.length;
					
					//indexStartRawData = 2;
				}else if(rawData.length >= 126 && rawData.length <= 65535){
					
					
					bytesFormatted[1] = 126
					bytesFormatted[2] = ( rawData.length >> 8 ) & 255
					bytesFormatted[3] = ( rawData.length) & 255
					
					//indexStartRawData = 4
				}else{
					bytesFormatted[1] = 127
					bytesFormatted[2] = ( rawData.length >> 56 ) & 255
					bytesFormatted[3] = ( rawData.length >> 48 ) & 255
					bytesFormatted[4] = ( rawData.length >> 40 ) & 255
					bytesFormatted[5] = ( rawData.length >> 32 ) & 255
					bytesFormatted[6] = ( rawData.length >> 24 ) & 255
					bytesFormatted[7] = ( rawData.length >> 16 ) & 255
					bytesFormatted[8] = ( rawData.length >>  8 ) & 255
					bytesFormatted[9] = ( rawData.length       ) & 255
					
					//indexStartRawData = 10;
				}
				
				// put raw data at the correct index
				var dataOut:ByteArray=new ByteArray();
				
				for(var i:uint=0;i<bytesFormatted.length;i++)
				{
					dataOut.writeByte(bytesFormatted[i]);
				}
				
				dataOut.writeBytes(rawData);
				dataOut.position=0;
				clientSocket.writeBytes(dataOut);
				clientSocket.flush(); 
				log( "Sent message to "+getClientKeyBySocket(clientSocket)+" msg="+msg);
			}else{
				log("No socket connection.");
			}
		}
		
		private function log( text:String ):void
		{
			trace( text );
		}
		       
	}
}
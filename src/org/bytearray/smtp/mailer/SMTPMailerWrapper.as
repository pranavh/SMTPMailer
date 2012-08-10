package org.bytearray.smtp.mailer {
	import com.hurlant.crypto.tls.TLSSocket;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.net.Socket;
	import flash.utils.ByteArray;

	[Event(name = "mailSent", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "authenticated", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "mailError", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "badSequence", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "connected", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "disconnected", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "error", type = "org.bytearray.smtp.events.SMTPEvent")]
	public class SMTPMailerWrapper extends EventDispatcher {
		public static const NONE:String = "none";

		public static const TLS:String = "tls";

		public static const SSL:String = "ssl";

		private var encryption:String;
		
		public var sockets:Array;
		
		private var listeners:Array;
		
		public function SMTPMailerWrapper(oencryption:Object) {
			super();
			if (oencryption is int) {
				if (oencryption == 0) {
					encryption=NONE;
				} else {
					encryption=(oencryption==1 ? TLS : SSL);
				}
			} else if (oencryption is String) {
				if (oencryption.toLowerCase() == NONE) {
					encryption=NONE;
				} else {
					encryption=oencryption.toString().toLowerCase();
				}
			} else {
				throw new Error("Invalid encryption value: SMTPMailerWrapper");
			}
			listeners=[];
			sockets=[];
			
		}

		public function addSocket(host:String, port:int, username:String, password:String):ISMTPMailer {
			var obj:ISMTPMailer;
			switch(encryption) {
				case NONE:
					obj=new SMTPMailer(host, port);
					break;
				case TLS:
				case SSL:
					obj=new SMTPTLSMailer(host, port);
					break;
			}
			
			for each(var l:Object in listeners) {
				(obj as IEventDispatcher).addEventListener(l.type, l.listener, l.useCapture, l.priority, l.useWeakReference);
			}
			
			obj.login=username;
			obj.password=password;
			
			sockets.push(obj);
			return obj;
		}
		
		public override function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void {
			var o:Object={type:type, listener:listener, useCapture:useCapture, priority:priority, useWeakReference:useWeakReference};
			listeners.push(o);
			for each(var mo:EventDispatcher in sockets) {
				mo.addEventListener(type, listener, useCapture, priority, useWeakReference);
			}
		}

		public function authenticate(socket:ISMTPMailer, login:String="", password:String=""):void {
			if(socket.login=="" || socket.password=="") {
				socket.authenticate(socket.login, socket.password);
			} else {
				socket.authenticate(login, password);
			}
		}

		public function sendHTMLMail(socket:ISMTPMailer, pFrom:String, pDest:String, pSubject:String, pMess:String, fromName:String=""):void {
			socket.sendHTMLMail(pFrom, pDest, pSubject, pMess, fromName);
		}

		public function sendAttachedMail(socket:ISMTPMailer, pFrom:String, pDest:String, pSubject:String, pMess:String, pByteArray:ByteArray, pFileName:String, fromName:String=""):void {
			socket.sendAttachedMail(pFrom, pDest, pSubject, pMess, pByteArray, pFileName, fromName);
		}

		public function sendPlainTextMail(socket:ISMTPMailer, from:String, to:String, subject:String, message:String, fromName:String=""):void {
			socket.sendPlainTextMail(from, to, subject, message, fromName);
		}
		
		public function sendTestMail(socket:ISMTPMailer, from:String, to:String, fromName:String=""):void {
			socket.sendTestMail(from, to, from);
		}

		public function cancelAll(socket:Object):void {
			
		}
		
		public function close(socket:Object):void {
			//(socket as ISMTPMailer).quit();
		}
		
		public function invokeAll(method:Function, from:String, recepients:Array, subject:String, message:String, fromName:String):void {
			if(recepients.length < sockets.length) {
				sockets.length = recepients.length;
			} else if(sockets.length < recepients.length) {
				recepients.length = sockets.length;
				trace("Not enough sockets. Recepients will be trimmed.");
			}
			
			for(var i:int=0; i<recepients.length; i++) {
				method((sockets[i] as ISMTPMailer), from, recepients[i], subject, message, fromName);
			}
		}
	}
}
